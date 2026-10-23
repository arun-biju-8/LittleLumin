// ignore_for_file: constant_identifier_names
// lib/services/score_ledger_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ScoreLedgerService {
  final FirebaseFirestore? _customFirestore;
  final http.Client? _customHttpClient;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  static const String backendUrl = 'https://littlelumin-backend.onrender.com';

  ScoreLedgerService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _customFirestore = firestore,
        _customHttpClient = httpClient;

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

  /// Record an authoritative score event via backend or simulated fallback in test mode
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

    // Secure flow: In production, route score events to the authoritative backend endpoint
    // to calculate deltas and create ledger records server-side via Firebase Admin SDK.
    if (_customFirestore == null) {
      try {
        final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (idToken != null && idToken.isNotEmpty) {
          final uri = Uri.parse('$backendUrl/api/cases/record-activity-score');
          final client = _customHttpClient ?? http.Client();
          final response = await client.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'child_id': childId,
              'activity_id': activityId,
              'activity_title': activityTitle,
              'activity_source': activitySource,
              'skill_domain': normalizedDomain,
              'difficulty': difficulty,
              'child_response': feedback['childResponse']?.toString() ?? 'great',
              'engagement': feedback['engagement']?.toString() ?? 'high',
              'confidence': feedback['confidence']?.toString() ?? 'confident',
              'time_estimate': feedback['timeEstimate']?.toString(),
              'notes': feedback['notes']?.toString(),
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            return {
              'eventId': data['event_id'] ?? 'server_evt_${DateTime.now().millisecondsSinceEpoch}',
              'scoreBefore': (data['score_before'] as num?)?.toDouble() ?? 0.0,
              'scoreAfter': (data['score_after'] as num?)?.toDouble() ?? 0.0,
              'rawDelta': rawScoreDelta,
              'appliedDelta': (data['applied_score_delta'] as num?)?.toDouble() ?? appliedDelta,
              'weight': (data['weight_applied'] as num?)?.toDouble() ?? weight,
              'source': activitySource,
              'isDomainMastered': data['is_domain_mastered'] ?? false,
              'isLevelCompleted': data['is_level_completed'] ?? false,
              'currentLevel': data['current_level'],
              'unlockedLevels': data['unlocked_levels'],
            };
          }
        }
      } catch (err) {
        debugPrint('⚠️ Backend growth endpoint call failed or offline, using fallback: $err');
      }
    }

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
