// ignore_for_file: constant_identifier_names
// lib/services/journey_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/journey_model.dart';
import '../models/activity_model.dart';
import '../models/learning_update_model.dart';

class JourneyService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  JourneyService({FirebaseFirestore? firestore}) : _customFirestore = firestore;
  static const String _collection = 'journeyProgress';
  static final Map<String, LearningUpdateModel> _latestUpdatesCache = {};

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

  /// Synchronizes journeyProgress with authoritative skillProfiles data
  /// Recalculates domain completion and unlocks next level if all 6 domains >= PASSING_SCORE (70)
  Future<JourneyProgress> syncJourneyWithSkillProfile(String childId) async {
    if (childId.trim().isEmpty) throw ArgumentError('childId cannot be empty');

    try {
      await initializeJourney(childId);

      final profileDoc = await _firestore.collection('skillProfiles').doc(childId).get();
      final profileData = profileDoc.data() ?? {};

      final journeyRef = _firestore.collection(_collection).doc(childId);
      final journeyDoc = await journeyRef.get();
      final journeyData = Map<String, dynamic>.from(journeyDoc.data() ?? {});

      final currentLevel = (journeyData['currentLevel'] is num)
          ? (journeyData['currentLevel'] as num).toInt()
          : 1;
      final levelKey = '$currentLevel';
      final levels = Map<String, dynamic>.from(journeyData['levels'] ?? {});
      final levelData = Map<String, dynamic>.from(levels[levelKey] ?? {});
      final domains = Map<String, dynamic>.from(levelData['domains'] ?? {});

      bool changed = false;

      for (var d in DOMAINS) {
        final domainMap = Map<String, dynamic>.from(domains[d] is Map ? domains[d] : {});
        final currentScore = (domainMap['score'] is num) ? (domainMap['score'] as num).toDouble() : 0.0;
        final profileScore = (profileData[d] is num) ? (profileData[d] as num).toDouble() : currentScore;

        // Take authoritative score from profile if higher/updated
        final effectiveScore = profileScore > currentScore ? profileScore : currentScore;
        final isMastered = effectiveScore >= PASSING_SCORE;

        if (domainMap['score'] != effectiveScore || domainMap['completed'] != isMastered) {
          domainMap['score'] = effectiveScore;
          domainMap['completed'] = isMastered;
          domains[d] = domainMap;
          changed = true;
        } else if (!domains.containsKey(d)) {
          domains[d] = {'score': effectiveScore, 'completed': isMastered, 'activitiesDone': 0};
          changed = true;
        }
      }

      levelData['domains'] = domains;

      // Check if all 6 domains achieved PASSING_SCORE (70)
      final allComplete = DOMAINS.every((d) {
        final dd = domains[d] as Map?;
        return dd?['completed'] == true;
      });

      final unlockedRaw = journeyData['unlockedLevels'];
      final unlocked = (unlockedRaw is List)
          ? unlockedRaw.map((e) => int.tryParse(e.toString()) ?? 1).toList()
          : <int>[1];

      if (allComplete) {
        if (levelData['isCompleted'] != true) {
          levelData['isCompleted'] = true;
          levelData['completedAt'] = FieldValue.serverTimestamp();
          changed = true;
        }

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
          journeyData['currentLevel'] = nextLevel;
          changed = true;
        }
      }

      journeyData['unlockedLevels'] = unlocked;
      levels[levelKey] = levelData;
      journeyData['levels'] = levels;

      if (changed) {
        journeyData['updatedAt'] = FieldValue.serverTimestamp();
        await journeyRef.set(journeyData, SetOptions(merge: true));
        debugPrint('✅ Reconciled journey progress with skill profile for child $childId');
      }

      return JourneyProgress.fromMap(childId, journeyData);
    } catch (e, stack) {
      debugPrint('❌ Error syncing journey with skill profile for $childId: $e\n$stack');
      final fallbackDoc = await _firestore.collection(_collection).doc(childId).get();
      return JourneyProgress.fromMap(childId, fallbackDoc.data() ?? {});
    }
  }

  /// Fetch or initialize journey progress for a child (compatible model)
  Future<JourneyProgress> getOrInitializeJourney(String childId, {int age = 4}) async {
    try {
      final doc = await _firestore.collection(_collection).doc(childId).get();
      if (!doc.exists || doc.data() == null) {
        await initializeJourney(childId);
      }
      return await syncJourneyWithSkillProfile(childId);
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

  /// Complete Activity helper (clears activeActivity, tracks activity ID, and recalculates level eligibility)
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

      // Reconcile and check if this level has met all mastery goals
      final progress = await syncJourneyWithSkillProfile(childId);
      final isNowCompleted = progress.levelProgress[level]?.isCompleted ?? false;
      final nextLevel = level + 1;
      final trophy = JourneyLevelConfig.defaultLevels
          .firstWhere((l) => l.level == level, orElse: () => JourneyLevelConfig.defaultLevels.first)
          .trophyName;

      return {
        'levelCompleted': isNowCompleted,
        'completedLevel': level,
        'nextLevel': nextLevel,
        'trophyEarned': trophy,
      };
    } catch (e, stack) {
      debugPrint('❌ Error completing activity: $e\n$stack');
      return {'levelCompleted': false};
    }
  }

  /// Backward-compatibility helper for journey_activity_detail_page
  Future<void> markActivityComplete(String childId, String activityId, String skillType) async {
    await completeActivity(childId: childId, activityId: activityId, level: 1);
  }

  /// Find or select a recommended practice activity for the pending domain with lowest score
  Future<Map<String, dynamic>?> getRecommendedPracticeActivity({
    required String childId,
    required int childAge,
    int level = 1,
  }) async {
    try {
      final journeyDoc = await _firestore.collection(_collection).doc(childId).get();
      if (!journeyDoc.exists || journeyDoc.data() == null) return null;

      final journey = JourneyProgress.fromMap(childId, journeyDoc.data()!);
      final pendingDomain = journey.lowestScoringPendingDomain;
      final targetDomain = pendingDomain?.domain ?? 'cognitive';
      final currentScore = pendingDomain?.score ?? 0.0;

      // 1. Check if a recommended activity already exists in Firestore cache
      try {
        final recDoc = await _firestore
            .collection('recommendedActivities')
            .doc(childId)
            .collection('domains')
            .doc(targetDomain.toLowerCase())
            .get();

        if (recDoc.exists && recDoc.data() != null) {
          final data = recDoc.data()!;
          final actData = data['activityData'];
          if (actData is Map<String, dynamic>) {
            final realActId = actData['id']?.toString() ?? data['activityId']?.toString() ?? recDoc.id;
            final act = ActivityModel.fromMap(realActId, actData);
            final actDomain = act.skillType.isNotEmpty ? act.skillType.toLowerCase() : targetDomain.toLowerCase();
            final reasonText = data['reason'] ?? 'Score is ${currentScore.round()} — needs more practice in $actDomain';
            return {
              'domain': actDomain,
              'targetDomain': actDomain,
              'activity': act,
              'score': currentScore,
              'currentScore': currentScore,
              'reason': reasonText,
              'rationale': reasonText,
              'source': 'ai_recommended',
            };
          }
        }
      } catch (e) {
        debugPrint('Note: no cached recommendation found for $targetDomain: $e');
      }

      // 2. Query preset activities library for an uncompleted activity in this domain
      final diff = level == 1 ? 'easy' : (level == 2 ? 'medium' : 'hard');
      final capDomain = '${targetDomain[0].toUpperCase()}${targetDomain.substring(1).toLowerCase()}';
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection('activities')
            .where('skillType', whereIn: [targetDomain.toLowerCase(), capDomain])
            .where('isActive', isEqualTo: true)
            .get();
      } catch (_) {
        // Fallback for emulators or collections without whereIn indexes
        snap = await _firestore
            .collection('activities')
            .where('skillType', isEqualTo: capDomain)
            .where('isActive', isEqualTo: true)
            .get();
        if (snap.docs.isEmpty) {
          snap = await _firestore
              .collection('activities')
              .where('skillType', isEqualTo: targetDomain.toLowerCase())
              .where('isActive', isEqualTo: true)
              .get();
        }
      }

      if (snap.docs.isNotEmpty) {
        final allActs = snap.docs.map((d) => ActivityModel.fromMap(d.id, d.data())).toList();
        final uncompleted = allActs.where((a) => !journey.isActivityCompleted(a.id ?? '')).toList();
        final matchingDiff = uncompleted.where((a) => a.difficulty.toLowerCase() == diff).toList();
        final selected = matchingDiff.isNotEmpty
            ? matchingDiff.first
            : (uncompleted.isNotEmpty ? uncompleted.first : allActs.first);

        final actDomain = selected.skillType.isNotEmpty ? selected.skillType.toLowerCase() : targetDomain.toLowerCase();
        final domainDisplay = actDomain[0].toUpperCase() + actDomain.substring(1);
        final rationale = currentScore > 0
            ? '$domainDisplay score is currently ${currentScore.round()}/100. Practicing this activity will help reach the 70% milestone to unlock Level 2.'
            : 'Starting with $domainDisplay skills will build foundational confidence for Level 2.';

        return {
          'domain': actDomain,
          'targetDomain': actDomain,
          'activity': selected,
          'score': currentScore,
          'currentScore': currentScore,
          'reason': rationale,
          'rationale': rationale,
          'source': 'library',
        };
      }

      return null;
    } catch (e, stack) {
      debugPrint('❌ Error in getRecommendedPracticeActivity: $e\n$stack');
      return null;
    }
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
        final capDom = '${domain[0].toUpperCase()}${domain.substring(1).toLowerCase()}';
        QuerySnapshot<Map<String, dynamic>> snapshot;
        try {
          snapshot = await _firestore
              .collection('activities')
              .where('skillType', whereIn: [domain.toLowerCase().trim(), capDom])
              .where('difficulty', isEqualTo: diff)
              .where('isActive', isEqualTo: true)
              .get();
        } catch (_) {
          snapshot = await _firestore
              .collection('activities')
              .where('skillType', isEqualTo: capDom)
              .where('difficulty', isEqualTo: diff)
              .where('isActive', isEqualTo: true)
              .get();
        }

        if (snapshot.docs.isNotEmpty) {
          final list = snapshot.docs.map((doc) => ActivityModel.fromMap(doc.id, doc.data())).toList();
          final matched = age != null ? list.where((a) => a.ageGroup.contains(age)).toList() : list;
          activities.add(matched.isNotEmpty ? matched.first : list.first);
        } else {
          final fallbackSnapshot = await _firestore
              .collection('activities')
              .where('skillType', whereIn: [domain.toLowerCase().trim(), capDom])
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

  /// Save the latest Learning Update snapshot for a specific child
  Future<void> saveLatestLearningUpdate(String childId, LearningUpdateModel update) async {
    if (childId.trim().isEmpty) return;
    try {
      _latestUpdatesCache[childId] = update;
      await _firestore.collection(_collection).doc(childId).set({
        'latestLearningUpdate': update.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Saved latest learning update for child $childId: ${update.activityTitle}');
    } catch (e) {
      debugPrint('⚠️ Error saving latest learning update: $e');
    }
  }

  /// Retrieve the latest Learning Update snapshot for a specific child
  Future<LearningUpdateModel?> getLatestLearningUpdate(String childId) async {
    if (childId.trim().isEmpty) return null;
    if (_latestUpdatesCache.containsKey(childId)) {
      return _latestUpdatesCache[childId];
    }
    try {
      if (Firebase.apps.isEmpty && _customFirestore == null) {
        return null;
      }
      final doc = await _firestore.collection(_collection).doc(childId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['latestLearningUpdate'] is Map) {
          final model = LearningUpdateModel.fromMap(
            Map<String, dynamic>.from(data['latestLearningUpdate'] as Map),
          );
          _latestUpdatesCache[childId] = model;
          return model;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting latest learning update: $e');
    }
    return null;
  }

  /// Clear in-memory latest update cache (useful for testing and child profile switching)
  static void clearLatestUpdateCache({String? childId}) {
    if (childId != null) {
      _latestUpdatesCache.remove(childId);
    } else {
      _latestUpdatesCache.clear();
    }
  }
}
