// ignore_for_file: constant_identifier_names
// lib/services/score_ledger_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ScoreLedgerService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  ScoreLedgerService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  static const List<String> DOMAINS = [
    'cognitive',
    'language',
    'motor',
    'social',
    'emotional',
    'creative',
  ];

  /// Weight rules (Option C):
  /// - Levels 1-2: all sources = 1.0
  /// - Levels 3-4: ai_generated = 0.5, others = 1.0
  double getWeight(String source, int level) {
    if (level >= 3 && source == 'ai_generated') return 0.5;
    return 1.0;
  }

  /// Record an immutable score event and update the profile cache
  Future<Map<String, dynamic>> recordScoreEvent({
    required String childId,
    required String activityId,
    required String activityTitle,
    required String activitySource, // preset | ai_generated | llg_assigned | migration
    required String skillDomain,
    required String difficulty,
    required int levelAtTime,
    required double rawScoreDelta,
    required Map<String, dynamic> feedback,
    String? submittedByParentId,
  }) async {
    if (childId.trim().isEmpty) {
      throw ArgumentError('childId cannot be empty');
    }
    if (skillDomain.trim().isEmpty) {
      throw ArgumentError('skillDomain cannot be empty');
    }
    final normalizedDomain = skillDomain.trim().toLowerCase();
    if (!DOMAINS.contains(normalizedDomain)) {
      throw ArgumentError('Invalid skill domain: $skillDomain');
    }
    if (rawScoreDelta.isNaN || rawScoreDelta.isInfinite) {
      throw ArgumentError('rawScoreDelta must be a finite number');
    }

    final weight = getWeight(activitySource, levelAtTime);
    final appliedDelta = rawScoreDelta * weight;

    try {
      final profileRef = _firestore.collection('skillProfiles').doc(childId);
      final profileDoc = await profileRef.get();
      final profileData = profileDoc.data() ?? {};
      final scoreBefore = (profileData[normalizedDomain] is num)
          ? (profileData[normalizedDomain] as num).toDouble()
          : 0.0;
      final scoreAfter = (scoreBefore + appliedDelta).clamp(0.0, 100.0);
      if (scoreAfter < 0.0 || scoreAfter > 100.0 || scoreAfter.isNaN || scoreAfter.isInfinite) {
        throw ArgumentError('scoreAfter must be between 0 and 100');
      }

      // Immutable event document
      final eventRef = await _firestore.collection('scoreEvents').add({
        'childId': childId,
        'activityId': activityId,
        'activityTitle': activityTitle,
        'activitySource': activitySource,
        'skillDomain': normalizedDomain,
        'difficulty': difficulty,
        'levelAtTime': levelAtTime,
        'feedback': feedback,
        'rawScoreDelta': rawScoreDelta,
        'appliedScoreDelta': appliedDelta,
        'weightApplied': weight,
        'scoreBefore': scoreBefore,
        'scoreAfter': scoreAfter,
        'submittedByParentId': submittedByParentId,
        'createdAt': FieldValue.serverTimestamp(),
        'isImmutable': true,
      });

      // Profile cache (fast lookup recomputed directly from ledger delta)
      await profileRef.set({
        normalizedDomain: scoreAfter,
        'lastEventId': eventRef.id,
        'childId': childId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '✅ Score event: $normalizedDomain $scoreBefore → $scoreAfter (Δ$appliedDelta w$weight source:$activitySource)',
      );

      return {
        'eventId': eventRef.id,
        'scoreBefore': scoreBefore,
        'scoreAfter': scoreAfter,
        'rawDelta': rawScoreDelta,
        'appliedDelta': appliedDelta,
        'weight': weight,
        'source': activitySource,
      };
    } catch (e, stack) {
      debugPrint('❌ Failed to record score event: $e\n$stack');
      rethrow;
    }
  }

  /// Full audit history for a child
  Future<List<Map<String, dynamic>>> getScoreHistory({
    required String childId,
    String? skillDomain,
  }) async {
    try {
      Query q = _firestore.collection('scoreEvents').where('childId', isEqualTo: childId);
      if (skillDomain != null && skillDomain.isNotEmpty) {
        q = q.where('skillDomain', isEqualTo: skillDomain.trim().toLowerCase());
      }
      final snap = await q.orderBy('createdAt', descending: true).get();
      return snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
    } catch (e, stack) {
      debugPrint('❌ Failed to get score history: $e\n$stack');
      rethrow;
    }
  }

  /// Recompute profile from scratch (repair tool + verification)
  Future<Map<String, double>> recomputeProfile(String childId) async {
    try {
      final events = await getScoreHistory(childId: childId);
      // Reverse to process chronologically if ordered descending
      final chronological = events.reversed.toList();

      final Map<String, double> totals = {
        'cognitive': 0.0,
        'language': 0.0,
        'motor': 0.0,
        'social': 0.0,
        'emotional': 0.0,
        'creative': 0.0,
      };

      for (var e in chronological) {
        final rawDomain = e['skillDomain'] as String?;
        if (rawDomain == null) continue;
        final domain = rawDomain.trim().toLowerCase();
        if (totals.containsKey(domain)) {
          final delta = (e['appliedScoreDelta'] is num)
              ? (e['appliedScoreDelta'] as num).toDouble()
              : 0.0;
          totals[domain] = (totals[domain]! + delta).clamp(0.0, 100.0);
        }
      }

      await _firestore.collection('skillProfiles').doc(childId).set({
        ...totals,
        'childId': childId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Recomputed profile for $childId: $totals');
      return totals;
    } catch (e, stack) {
      debugPrint('❌ Failed to recompute profile: $e\n$stack');
      rethrow;
    }
  }

  /// Checkpoint 2: Data Migration for Existing Children
  /// Reads existing skillProfiles and writes traceable baseline scoreEvents
  Future<int> migrateExistingSkillProfiles() async {
    debugPrint('🔄 Starting Checkpoint 2 Migration for existing skill profiles...');
    int migratedCount = 0;

    try {
      final profilesSnap = await _firestore.collection('skillProfiles').get();

      for (var profileDoc in profilesSnap.docs) {
        final childId = profileDoc.id;
        final data = profileDoc.data();

        // Check if baseline migration events already exist for this child
        final existingMigrationSnap = await _firestore
            .collection('scoreEvents')
            .where('childId', isEqualTo: childId)
            .where('activitySource', isEqualTo: 'migration')
            .limit(1)
            .get();

        if (existingMigrationSnap.docs.isNotEmpty) {
          debugPrint('ℹ️ Child $childId already has baseline migration events. Skipping.');
          continue;
        }

        bool hasMigratedDomain = false;
        for (var domain in DOMAINS) {
          final score = (data[domain] is num) ? (data[domain] as num).toDouble() : 0.0;
          if (score > 0) {
            await _firestore.collection('scoreEvents').add({
              'childId': childId,
              'activityId': 'baseline_migration_$domain',
              'activityTitle': 'Historical Baseline Score Migration ($domain)',
              'activitySource': 'migration',
              'skillDomain': domain,
              'difficulty': 'baseline',
              'levelAtTime': 1,
              'feedback': {'migration': true, 'initialScore': score},
              'rawScoreDelta': score,
              'appliedScoreDelta': score,
              'weightApplied': 1.0,
              'scoreBefore': 0.0,
              'scoreAfter': score,
              'createdAt': FieldValue.serverTimestamp(),
              'isImmutable': true,
            });
            hasMigratedDomain = true;
          }
        }

        if (hasMigratedDomain) {
          migratedCount++;
          debugPrint('✅ Migrated baseline scores for child $childId');
        }
      }

      debugPrint('🎉 Migration complete. Total children migrated: $migratedCount');
      return migratedCount;
    } catch (e, stack) {
      debugPrint('❌ Migration failed: $e\n$stack');
      rethrow;
    }
  }
}
