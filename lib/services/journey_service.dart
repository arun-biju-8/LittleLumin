// lib/services/journey_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/journey_model.dart';
import '../models/activity_model.dart';

class JourneyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'journeyProgress';

  // 1. Stream journey progress for a child
  Stream<JourneyProgress?> getJourneyProgress(String childId) {
    if (childId.isEmpty) return Stream.value(null);

    return _firestore.collection(_collection).doc(childId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return JourneyProgress.fromMap(childId, doc.data()!);
      }
      return null;
    });
  }

  // 2. Fetch or initialize journey progress for a child
  Future<JourneyProgress> getOrInitializeJourney(String childId, {int age = 4}) async {
    try {
      final doc = await _firestore.collection(_collection).doc(childId).get();

      if (doc.exists && doc.data() != null) {
        return JourneyProgress.fromMap(childId, doc.data()!);
      }

      // Initialize default journey structure using available activities from Firestore
      return await _initializeJourneyData(childId, age);
    } catch (e) {
      debugPrint('Error in getOrInitializeJourney: $e');
      return _buildFallbackJourney(childId);
    }
  }

  // Helper: Initialize journey with activities across domains for levels 1-4
  Future<JourneyProgress> _initializeJourneyData(String childId, int age) async {
    final Map<int, LevelProgress> levelProgress = {};

    try {
      final snapshot = await _firestore
          .collection('activities')
          .where('isActive', isEqualTo: true)
          .get();

      final List<ActivityModel> allActivities = snapshot.docs
          .map((doc) => ActivityModel.fromMap(doc.id, doc.data()))
          .toList();

      final List<String> domains = ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'];

      // Level 1: Easy difficulty
      final level1Ids = _selectActivitiesForLevel(allActivities, difficulty: 'Easy', domains: domains);

      // Level 2: Medium difficulty
      final level2Ids = _selectActivitiesForLevel(allActivities, difficulty: 'Medium', domains: domains);

      // Level 3: Hard difficulty
      final level3Ids = _selectActivitiesForLevel(allActivities, difficulty: 'Hard', domains: domains);

      // Level 4: Complex / Remaining activities
      final level4Ids = _selectActivitiesForLevel(allActivities, difficulty: 'Hard', domains: domains, offset: 1);

      levelProgress[1] = LevelProgress(
        completed: [],
        total: level1Ids.isNotEmpty ? level1Ids.length : 6,
        isUnlocked: true,
        activityIds: level1Ids,
      );

      levelProgress[2] = LevelProgress(
        completed: [],
        total: level2Ids.isNotEmpty ? level2Ids.length : 6,
        isUnlocked: false,
        activityIds: level2Ids,
      );

      levelProgress[3] = LevelProgress(
        completed: [],
        total: level3Ids.isNotEmpty ? level3Ids.length : 6,
        isUnlocked: false,
        activityIds: level3Ids,
      );

      levelProgress[4] = LevelProgress(
        completed: [],
        total: level4Ids.isNotEmpty ? level4Ids.length : 6,
        isUnlocked: false,
        activityIds: level4Ids,
      );

      final initialJourney = JourneyProgress(
        childId: childId,
        currentLevel: 1,
        levelProgress: levelProgress,
        completedActivities: [],
        unlockedActivities: level1Ids,
      );

      await _firestore.collection(_collection).doc(childId).set(initialJourney.toMap());
      return initialJourney;
    } catch (e) {
      debugPrint('Error populating journey data: $e');
      final fallback = _buildFallbackJourney(childId);
      await _firestore.collection(_collection).doc(childId).set(fallback.toMap());
      return fallback;
    }
  }

  List<String> _selectActivitiesForLevel(
    List<ActivityModel> activities, {
    required String difficulty,
    required List<String> domains,
    int offset = 0,
  }) {
    final List<String> selectedIds = [];

    for (final domain in domains) {
      final domainMatches = activities.where((a) {
        final matchesDifficulty = a.difficulty.toLowerCase() == difficulty.toLowerCase() ||
            (difficulty == 'Hard' && a.difficulty == 'Medium');
        return a.skillType.toLowerCase() == domain.toLowerCase() && matchesDifficulty;
      }).toList();

      if (domainMatches.length > offset) {
        final act = domainMatches[offset];
        if (act.id != null && !selectedIds.contains(act.id)) {
          selectedIds.add(act.id!);
        }
      } else if (domainMatches.isNotEmpty) {
        final act = domainMatches.first;
        if (act.id != null && !selectedIds.contains(act.id)) {
          selectedIds.add(act.id!);
        }
      }
    }

    // Fill remaining if less than 6
    if (selectedIds.length < 6) {
      for (final act in activities) {
        if (act.id != null && !selectedIds.contains(act.id)) {
          selectedIds.add(act.id!);
          if (selectedIds.length == 6) break;
        }
      }
    }

    return selectedIds;
  }

  JourneyProgress _buildFallbackJourney(String childId) {
    return JourneyProgress(
      childId: childId,
      currentLevel: 1,
      levelProgress: {
        1: LevelProgress(completed: [], total: 6, isUnlocked: true, activityIds: []),
        2: LevelProgress(completed: [], total: 6, isUnlocked: false, activityIds: []),
        3: LevelProgress(completed: [], total: 6, isUnlocked: false, activityIds: []),
        4: LevelProgress(completed: [], total: 6, isUnlocked: false, activityIds: []),
      },
    );
  }

  // 3. Start Activity (sets activeActivity to in_progress)
  Future<bool> startActivity({
    required String childId,
    required String activityId,
    required String activityTitle,
    required int level,
  }) async {
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
    } catch (e) {
      debugPrint('Error starting activity in JourneyService: $e');
      return false;
    }
  }

  // 4. Discard active activity
  Future<bool> discardActiveActivity(String childId) async {
    try {
      await _firestore.collection(_collection).doc(childId).update({
        'activeActivity': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error discarding active activity: $e');
      return false;
    }
  }

  // 5. Complete Activity & check for Level Up
  Future<Map<String, dynamic>> completeActivity({
    required String childId,
    required String activityId,
    required int level,
  }) async {
    try {
      final doc = await _firestore.collection(_collection).doc(childId).get();
      if (!doc.exists || doc.data() == null) {
        return {'levelCompleted': false};
      }

      final journey = JourneyProgress.fromMap(childId, doc.data()!);

      // 1. Update completed activities list
      final Set<String> updatedCompleted = Set<String>.from(journey.completedActivities)..add(activityId);

      // 2. Update level progress for the specified level
      final Map<int, LevelProgress> updatedLevelProgress = Map<int, LevelProgress>.from(journey.levelProgress);
      final currentLvlProg = updatedLevelProgress[level] ?? LevelProgress(completed: []);

      final Set<String> lvlCompleted = Set<String>.from(currentLvlProg.completed)..add(activityId);

      updatedLevelProgress[level] = LevelProgress(
        completed: lvlCompleted.toList(),
        total: currentLvlProg.total,
        isUnlocked: currentLvlProg.isUnlocked,
        activityIds: currentLvlProg.activityIds,
      );

      bool levelJustCompleted = lvlCompleted.length >= currentLvlProg.total;
      int nextLevel = journey.currentLevel;
      String? trophyEarned;

      if (levelJustCompleted && level == journey.currentLevel && level < 4) {
        nextLevel = level + 1;
        // Unlock next level
        final nextLvlProg = updatedLevelProgress[nextLevel];
        if (nextLvlProg != null) {
          updatedLevelProgress[nextLevel] = LevelProgress(
            completed: nextLvlProg.completed,
            total: nextLvlProg.total,
            isUnlocked: true,
            activityIds: nextLvlProg.activityIds,
          );
        }

        // Determine trophy name
        switch (level) {
          case 1:
            trophyEarned = 'Foundation Builder 🏆';
            break;
          case 2:
            trophyEarned = 'Skill Builder 🌟';
            break;
          case 3:
            trophyEarned = 'Advanced Explorer 🚀';
            break;
          case 4:
            trophyEarned = 'Mastery Champion 👑';
            break;
        }

        // Save trophy to rewards collection
        if (trophyEarned != null) {
          await _addBadgeToRewards(childId, trophyEarned);
        }
      }

      // Convert updatedLevelProgress map to firestore format
      final Map<String, dynamic> levelProgressMap = {};
      updatedLevelProgress.forEach((k, v) {
        levelProgressMap[k.toString()] = v.toMap();
      });

      await _firestore.collection(_collection).doc(childId).update({
        'completedActivities': updatedCompleted.toList(),
        'levelProgress': levelProgressMap,
        'currentLevel': nextLevel,
        'activeActivity': null, // Clear active activity after feedback is completed
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'levelCompleted': levelJustCompleted,
        'completedLevel': level,
        'nextLevel': nextLevel,
        'trophyEarned': trophyEarned,
      };
    } catch (e) {
      debugPrint('Error completing activity in JourneyService: $e');
      return {'levelCompleted': false};
    }
  }

  // Helper to add badge to child rewards in Firestore
  Future<void> _addBadgeToRewards(String childId, String badgeName) async {
    try {
      final rewardRef = _firestore.collection('rewards').doc(childId);
      final doc = await rewardRef.get();

      if (doc.exists) {
        await rewardRef.update({
          'badges': FieldValue.arrayUnion([badgeName]),
          'stars': FieldValue.increment(20), // 20 bonus stars for level complete
        });
      } else {
        await rewardRef.set({
          'childId': childId,
          'stars': 20,
          'streak': 1,
          'badges': [badgeName],
        });
      }
    } catch (e) {
      debugPrint('Error adding badge to rewards: $e');
    }
  }

  // 6. Fetch full ActivityModel list for level activity IDs
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
    } catch (e) {
      debugPrint('Error fetching activities for level: $e');
      return [];
    }
  }
}
