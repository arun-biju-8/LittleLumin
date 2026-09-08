// lib/models/journey_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class JourneyLevelConfig {
  final int level;
  final String title;
  final String description;
  final String difficulty;
  final String trophyName;
  final List<String> domainRequirements;

  const JourneyLevelConfig({
    required this.level,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.trophyName,
    required this.domainRequirements,
  });

  static const List<JourneyLevelConfig> defaultLevels = [
    JourneyLevelConfig(
      level: 1,
      title: 'Level 1: Foundation Skills',
      description: 'Easy activities across all 6 core developmental domains',
      difficulty: 'Easy',
      trophyName: 'Foundation Builder 🏆',
      domainRequirements: ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'],
    ),
    JourneyLevelConfig(
      level: 2,
      title: 'Level 2: Building Skills',
      description: 'Medium difficulty activities to expand core competencies',
      difficulty: 'Medium',
      trophyName: 'Skill Builder 🌟',
      domainRequirements: ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'],
    ),
    JourneyLevelConfig(
      level: 3,
      title: 'Level 3: Advanced Skills',
      description: 'Challenging activities to deepen understanding and problem solving',
      difficulty: 'Hard',
      trophyName: 'Advanced Explorer 🚀',
      domainRequirements: ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'],
    ),
    JourneyLevelConfig(
      level: 4,
      title: 'Level 4: Mastery Challenges',
      description: 'Complex milestone activities for complete developmental mastery',
      difficulty: 'Complex',
      trophyName: 'Mastery Champion 👑',
      domainRequirements: ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'],
    ),
  ];
}

class LevelProgress {
  final List<String> completed;
  final int total;
  final bool isUnlocked;
  final List<String> activityIds;

  LevelProgress({
    required this.completed,
    this.total = 6,
    this.isUnlocked = false,
    this.activityIds = const [],
  });

  bool get isCompleted => completed.length >= total && total > 0;
  double get progressFraction => total > 0 ? (completed.length / total).clamp(0.0, 1.0) : 0.0;
  int get progressPercent => (progressFraction * 100).round();

  Map<String, dynamic> toMap() {
    return {
      'completed': completed,
      'total': total,
      'isUnlocked': isUnlocked,
      'activityIds': activityIds,
    };
  }

  factory LevelProgress.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    final completedList = parseList(map['completed']);
    final totalCount = (map['total'] is num) ? (map['total'] as num).toInt() : 6;
    final isUnl = map['isUnlocked'] ?? (completedList.length >= totalCount);

    return LevelProgress(
      completed: completedList,
      total: totalCount,
      isUnlocked: isUnl,
      activityIds: parseList(map['activityIds']),
    );
  }
}

class ActiveActivityState {
  final String activityId;
  final String activityTitle;
  final DateTime startedAt;
  final String status; // 'in_progress' | 'completed'
  final int level;

  ActiveActivityState({
    required this.activityId,
    required this.activityTitle,
    required this.startedAt,
    required this.status,
    required this.level,
  });

  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'activityTitle': activityTitle,
      'startedAt': Timestamp.fromDate(startedAt),
      'status': status,
      'level': level,
    };
  }

  factory ActiveActivityState.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return ActiveActivityState(
      activityId: map['activityId'] ?? '',
      activityTitle: map['activityTitle'] ?? 'Activity',
      startedAt: parseTime(map['startedAt']),
      status: map['status'] ?? 'in_progress',
      level: (map['level'] is num) ? (map['level'] as num).toInt() : 1,
    );
  }
}

class JourneyProgress {
  final String childId;
  final int currentLevel;
  final Map<int, LevelProgress> levelProgress;
  final ActiveActivityState? activeActivity;
  final List<String> completedActivities;
  final List<String> unlockedActivities;
  final List<int> unlockedLevels;
  final DateTime? updatedAt;

  JourneyProgress({
    required this.childId,
    this.currentLevel = 1,
    required this.levelProgress,
    this.activeActivity,
    this.completedActivities = const [],
    this.unlockedActivities = const [],
    this.unlockedLevels = const [1],
    this.updatedAt,
  });

  LevelProgress? get currentLevelProgress => levelProgress[currentLevel];

  bool isActivityCompleted(String activityId) {
    return completedActivities.contains(activityId);
  }

  bool isLevelUnlocked(int level) {
    if (level == 1) return true;
    if (unlockedLevels.contains(level)) return true;
    return levelProgress[level]?.isUnlocked ?? (level <= currentLevel);
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> levelProgressMap = {};
    levelProgress.forEach((key, value) {
      levelProgressMap[key.toString()] = value.toMap();
    });

    return {
      'childId': childId,
      'currentLevel': currentLevel,
      'levelProgress': levelProgressMap,
      'activeActivity': activeActivity?.toMap(),
      'completedActivities': completedActivities,
      'unlockedActivities': unlockedActivities,
      'unlockedLevels': unlockedLevels,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory JourneyProgress.fromMap(String childId, Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    List<int> parseIntList(dynamic val) {
      if (val is List) return val.map((e) => int.tryParse(e.toString()) ?? 1).toList();
      return [1];
    }

    Map<int, LevelProgress> parseLevelProgress(Map<String, dynamic> rawMap) {
      Map<int, LevelProgress> result = {};
      if (rawMap['levelProgress'] is Map) {
        (rawMap['levelProgress'] as Map).forEach((key, value) {
          final levelKey = int.tryParse(key.toString().replaceAll('level_', '')) ?? 1;
          if (value is Map<String, dynamic>) {
            result[levelKey] = LevelProgress.fromMap(value);
          } else if (value is Map) {
            result[levelKey] = LevelProgress.fromMap(Map<String, dynamic>.from(value));
          }
        });
      }
      for (int i = 1; i <= 4; i++) {
        if (!result.containsKey(i) && rawMap.containsKey('level_$i') && rawMap['level_$i'] is Map) {
          final lData = rawMap['level_$i'];
          if (lData is Map<String, dynamic>) {
            result[i] = LevelProgress.fromMap(lData);
          } else if (lData is Map) {
            result[i] = LevelProgress.fromMap(Map<String, dynamic>.from(lData));
          }
        }
      }
      return result;
    }

    DateTime? parseTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    ActiveActivityState? active;
    if (map['activeActivity'] != null) {
      final activeMap = map['activeActivity'];
      if (activeMap is Map<String, dynamic>) {
        active = ActiveActivityState.fromMap(activeMap);
      } else if (activeMap is Map) {
        active = ActiveActivityState.fromMap(Map<String, dynamic>.from(activeMap));
      }
    }

    return JourneyProgress(
      childId: childId,
      currentLevel: (map['currentLevel'] is num) ? (map['currentLevel'] as num).toInt() : 1,
      levelProgress: parseLevelProgress(map),
      activeActivity: active,
      completedActivities: parseList(map['completedActivities']),
      unlockedActivities: parseList(map['unlockedActivities']),
      unlockedLevels: map['unlockedLevels'] != null ? parseIntList(map['unlockedLevels']) : [1],
      updatedAt: parseTime(map['updatedAt']),
    );
  }
}
