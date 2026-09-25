// ignore_for_file: constant_identifier_names
// lib/services/journey_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/journey_model.dart';
import '../models/activity_model.dart';

class JourneyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'journeyProgress';

  static const int PASSING_SCORE = 70;
  static const int MAX_LEVEL = 4;
  static const List<String> DOMAINS = [
    'cognitive',
    'language',
    'motor',
    'social',
    'emotional',
    'creative',
  ];

  /// Initialize journeyProgress for a new child
  Future<void> initializeJourney(String childId) async {
    if (childId.trim().isEmpty) throw ArgumentError('childId cannot be empty');
    try {
      final ref = _firestore.collection(_collection).doc(childId);
      final doc = await ref.get();
      if (doc.exists) return;

      final domains = <String, dynamic>{};
      for (var d in DOMAINS) {
        domains[d] = {'score': 0.0, 'completed': false, 'activitiesDone': 0};
      }

      await ref.set({
        'childId': childId,
        'currentLevel': 1,
        'unlockedLevels': [1],
        'levels': {
          '1': {
            'domains': domains,
            'isCompleted': false,
            'completedAt': null,
          }
        },
        'completedActivities': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Initialized journeyProgress for child $childId');
    } catch (e, stack) {
      debugPrint('❌ Failed to initialize journey for $childId: $e\n$stack');
      rethrow;
    }
  }

  /// Process after a score event is recorded.
  /// Returns { nextAction, currentLevel, domainScore, domainCompleted, levelCompleted, allDomainsStatus }
  Future<Map<String, dynamic>> processActivityCompletion({
    required String childId,
    required String skillDomain,
    required double newDomainScore,
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
    if (newDomainScore.isNaN || newDomainScore.isInfinite || newDomainScore < 0.0 || newDomainScore > 100.0) {
      throw ArgumentError('newDomainScore must be between 0 and 100');
    }

    final ref = _firestore.collection(_collection).doc(childId);

    try {
      // Ensure journey document exists
      await initializeJourney(childId);

      final doc = await ref.get();
      final data = Map<String, dynamic>.from(doc.data() ?? {});
      final currentLevel = (data['currentLevel'] is num) ? (data['currentLevel'] as num).toInt() : 1;
      final levelKey = '$currentLevel';
      final levels = Map<String, dynamic>.from(data['levels'] ?? {});
      final levelData = Map<String, dynamic>.from(levels[levelKey] ?? {});
      final domains = Map<String, dynamic>.from(levelData['domains'] ?? {});

      // Ensure all 6 domains exist in domain map
      for (var d in DOMAINS) {
        if (!domains.containsKey(d) || domains[d] is! Map) {
          domains[d] = {'score': 0.0, 'completed': false, 'activitiesDone': 0};
        }
      }

      final domainData = Map<String, dynamic>.from(domains[normalizedDomain] ?? {});
      domainData['score'] = newDomainScore;
      domainData['activitiesDone'] = ((domainData['activitiesDone'] as num?)?.toInt() ?? 0) + 1;

      final wasCompleted = domainData['completed'] as bool? ?? false;
      final isNowComplete = newDomainScore >= PASSING_SCORE;
      domainData['completed'] = isNowComplete;
      domains[normalizedDomain] = domainData;
      levelData['domains'] = domains;

      // Check if whole level is complete (all 6 domains score >= 70)
      final allComplete = DOMAINS.every((d) {
        final dd = domains[d] as Map<String, dynamic>?;
        return dd?['completed'] == true;
      });

      bool levelJustCompleted = false;
      if (allComplete && !(levelData['isCompleted'] as bool? ?? false)) {
        levelData['isCompleted'] = true;
        levelData['completedAt'] = FieldValue.serverTimestamp();
        levelJustCompleted = true;

        final unlockedRaw = data['unlockedLevels'];
        final unlocked = (unlockedRaw is List)
            ? unlockedRaw.map((e) => int.tryParse(e.toString()) ?? 1).toList()
            : <int>[1];

        final nextLevel = currentLevel + 1;
        if (!unlocked.contains(nextLevel) && nextLevel <= MAX_LEVEL) {
          unlocked.add(nextLevel);
          final nextDomains = <String, dynamic>{};
          for (var d in DOMAINS) {
            nextDomains[d] = {'score': 0.0, 'completed': false, 'activitiesDone': 0};
          }
          levels['$nextLevel'] = {
            'domains': nextDomains,
            'isCompleted': false,
            'completedAt': null,
          };
          data['currentLevel'] = nextLevel;
        }
        data['unlockedLevels'] = unlocked;
      }

      levels[levelKey] = levelData;
      data['levels'] = levels;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await ref.set(data, SetOptions(merge: true));

      String nextAction;
      if (levelJustCompleted) {
        nextAction = 'level_complete';
      } else if (isNowComplete && !wasCompleted) {
        nextAction = 'domain_complete';
      } else if (!isNowComplete) {
        nextAction = 'generate_new_activity';
      } else {
        nextAction = 'continue';
      }

      debugPrint(
        '✅ processActivityCompletion for $childId: domain=$normalizedDomain score=$newDomainScore action=$nextAction levelCompleted=$levelJustCompleted',
      );

      return {
        'nextAction': nextAction,
        'currentLevel': currentLevel,
        'domainScore': newDomainScore,
        'domainCompleted': isNowComplete,
        'levelCompleted': levelJustCompleted,
        'allDomainsStatus': domains,
      };
    } catch (e, stack) {
      debugPrint('❌ Failed processActivityCompletion for $childId: $e\n$stack');
      rethrow;
    }
  }

  /// Read current journeyProgress doc data
  Future<Map<String, dynamic>?> getProgress(String childId) async {
    if (childId.isEmpty) return null;
    try {
      final doc = await _firestore.collection(_collection).doc(childId).get();
      return doc.data();
    } catch (e, stack) {
      debugPrint('❌ Failed to get progress for $childId: $e\n$stack');
      return null;
    }
  }

  /// Get domains that have not yet reached PASSING_SCORE (70)
  Future<List<String>> getPendingDomains(String childId) async {
    final data = await getProgress(childId);
    if (data == null) return DOMAINS;

    final currentLevel = (data['currentLevel'] is num) ? (data['currentLevel'] as num).toInt() : 1;
    final levels = data['levels'] as Map?;
    if (levels == null) return DOMAINS;

    final levelData = levels[currentLevel.toString()] as Map?;
    if (levelData == null) return DOMAINS;

    final domains = levelData['domains'] as Map?;
    if (domains == null) return DOMAINS;

    return DOMAINS.where((d) {
      final dd = domains[d] as Map?;
      return dd?['completed'] != true;
    }).toList();
  }

  // =========================================================================
  // COMPATIBILITY METHODS (for existing screens: journey_view, activities)
  // =========================================================================

  /// Stream journey progress for child
  Stream<JourneyProgress?> getJourneyProgress(String childId) {
    if (childId.isEmpty) return Stream.value(null);

    return _firestore.collection(_collection).doc(childId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return JourneyProgress.fromMap(childId, doc.data()!);
      }
      return null;
    });
  }

  /// Fetch or initialize journey progress for a child (compatible model)
  Future<JourneyProgress> getOrInitializeJourney(String childId, {int age = 4}) async {
    try {
      final doc = await _firestore.collection(_collection).doc(childId).get();
      if (doc.exists && doc.data() != null) {
        return JourneyProgress.fromMap(childId, doc.data()!);
      }

      await initializeJourney(childId);
      final newDoc = await _firestore.collection(_collection).doc(childId).get();
      return JourneyProgress.fromMap(childId, newDoc.data() ?? {});
    } catch (e, stack) {
      debugPrint('❌ Error in getOrInitializeJourney: $e\n$stack');
      return JourneyProgress(childId: childId, levelProgress: {});
    }
  }

  /// Start Activity (sets activeActivity in journey doc)
  Future<bool> startActivity({
    required String childId,
    required String activityId,
    required String activityTitle,
    required int level,
  }) async {
    if (childId.trim().isEmpty) throw ArgumentError('childId cannot be empty');
    if (activityId.trim().isEmpty) throw ArgumentError('activityId cannot be empty');
    if (level < 1 || level > MAX_LEVEL) throw ArgumentError('Invalid level: $level');

    try {
      final activeState = ActiveActivityState(
        activityId: activityId,
        activityTitle: activityTitle,
        startedAt: DateTime.now(),
        status: 'in_progress',
        level: level,
      );

      await _firestore.collection(_collection).doc(childId).set({
        'activeActivity': activeState.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e, stack) {
      debugPrint('❌ Error starting activity: $e\n$stack');
      return false;
    }
  }

  /// Discard active activity
  Future<bool> discardActiveActivity(String childId) async {
    try {
      await _firestore.collection(_collection).doc(childId).update({
        'activeActivity': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e, stack) {
      debugPrint('❌ Error discarding active activity: $e\n$stack');
      return false;
    }
  }

  /// Complete Activity helper (clears activeActivity and tracks activity ID)
  Future<Map<String, dynamic>> completeActivity({
    required String childId,
    required String activityId,
    required int level,
  }) async {
    if (childId.trim().isEmpty) throw ArgumentError('childId cannot be empty');
    if (activityId.trim().isEmpty) throw ArgumentError('activityId cannot be empty');

    try {
      final docRef = _firestore.collection(_collection).doc(childId);
      final doc = await docRef.get();
      if (!doc.exists) {
        await initializeJourney(childId);
      }

      await docRef.set({
        'completedActivities': FieldValue.arrayUnion([activityId]),
        'activeActivity': null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {'levelCompleted': false};
    } catch (e, stack) {
      debugPrint('❌ Error completing activity: $e\n$stack');
      return {'levelCompleted': false};
    }
  }

  /// Backward-compatibility helper for journey_activity_detail_page
  Future<void> markActivityComplete(String childId, String activityId, String skillType) async {
    await completeActivity(childId: childId, activityId: activityId, level: 1);
  }

  /// Fetch full ActivityModel list for level activity IDs
  Future<List<ActivityModel>> getActivitiesForLevel(List<String> activityIds) async {
    if (activityIds.isEmpty) return [];

    try {
      final List<ActivityModel> activities = [];
      for (final id in activityIds) {
        final doc = await _firestore.collection('activities').doc(id).get();
        if (doc.exists && doc.data() != null) {
          activities.add(ActivityModel.fromMap(doc.id, doc.data()!));
        }
      }
      return activities;
    } catch (e, stack) {
      debugPrint('❌ Error fetching activities for level: $e\n$stack');
      return [];
    }
  }

  /// Fetch activities for a level configuration when explicit IDs are not stored
  Future<List<ActivityModel>> getActivitiesForLevelConfig(JourneyLevelConfig config, {int? age}) async {
    final diff = config.difficulty.toLowerCase().trim() == 'complex'
        ? 'hard'
        : config.difficulty.toLowerCase().trim();

    final List<ActivityModel> activities = [];
    for (final domain in config.domainRequirements) {
      try {
        final snapshot = await _firestore
            .collection('activities')
            .where('skillType', isEqualTo: domain.toLowerCase().trim())
            .where('difficulty', isEqualTo: diff)
            .where('isActive', isEqualTo: true)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) => ActivityModel.fromMap(doc.id, doc.data())).toList();
          final matched = age != null ? list.where((a) => a.ageGroup.contains(age)).toList() : list;
          activities.add(matched.isNotEmpty ? matched.first : list.first);
        } else {
          final fallbackSnapshot = await _firestore
              .collection('activities')
              .where('skillType', isEqualTo: domain.toLowerCase().trim())
              .where('difficulty', isEqualTo: 'medium')
              .where('isActive', isEqualTo: true)
              .get();
          if (fallbackSnapshot.docs.isNotEmpty) {
            activities.add(ActivityModel.fromMap(fallbackSnapshot.docs.first.id, fallbackSnapshot.docs.first.data()));
          }
        }
      } catch (e) {
        debugPrint('Error getting activity for domain $domain: $e');
      }
    }
    return activities;
  }
}
