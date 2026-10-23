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

class DomainProgress {
  final String domain;
  final double score;
  final bool isCompleted;
  final int activitiesDone;

  const DomainProgress({
    required this.domain,
    required this.score,
    required this.isCompleted,
    this.activitiesDone = 0,
  });

  bool get isMastered => isCompleted || score >= 70.0;

  String get status {
    if (isMastered) return 'Mastered';
    if (activitiesDone > 0 && score < 70.0) return 'Practice Recommended';
    if (activitiesDone > 0 || score > 0.0) return 'In Progress';
    return 'Not Started';
  }

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'completed': isCompleted,
      'activitiesDone': activitiesDone,
    };
  }

  factory DomainProgress.fromMap(String domain, Map<String, dynamic> map) {
    final sc = (map['score'] is num) ? (map['score'] as num).toDouble() : 0.0;
    final comp = map['completed'] == true || sc >= 70.0;
    final done = (map['activitiesDone'] is num) ? (map['activitiesDone'] as num).toInt() : 0;
    return DomainProgress(
      domain: domain,
      score: sc,
      isCompleted: comp,
      activitiesDone: done,
    );
  }
}

class LevelProgress {
  final List<String> completed;
  final int total;
  final bool isUnlocked;
  final List<String> activityIds;
  final Map<String, DomainProgress> domains;

  LevelProgress({
    required this.completed,
    this.total = 6,
    this.isUnlocked = false,
    this.activityIds = const [],
    this.domains = const {},
  });

  /// Domain-level mastery counts (score >= 70)
  int get masteredDomainCount {
    if (domains.isNotEmpty) {
      return domains.values.where((d) => d.isMastered).length;
    }
    return completed.length;
  }

  int get totalDomains => domains.isNotEmpty ? domains.length : (total > 0 ? total : 6);

  /// Level mastery is satisfied ONLY when all 6 domains meet 70% threshold
  bool get isCompleted => masteredDomainCount >= totalDomains && totalDomains > 0;

  double get progressFraction => totalDomains > 0 ? (masteredDomainCount / totalDomains).clamp(0.0, 1.0) : 0.0;
  int get progressPercent => (progressFraction * 100).round();

  Map<String, dynamic> toMap() {
    final domainMap = <String, dynamic>{};
    domains.forEach((k, v) => domainMap[k] = v.toMap());

    return {
      'completed': completed,
      'total': total,
      'isUnlocked': isUnlocked,
      'activityIds': activityIds,
      'domains': domainMap,
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

    Map<String, DomainProgress> parsedDomains = {};
    if (map['domains'] is Map) {
      (map['domains'] as Map).forEach((k, v) {
        if (v is Map) {
          parsedDomains[k.toString()] = DomainProgress.fromMap(k.toString(), Map<String, dynamic>.from(v));
        }
      });
    }

    return LevelProgress(
      completed: completedList,
      total: totalCount,
      isUnlocked: isUnl,
      activityIds: parseList(map['activityIds']),
      domains: parsedDomains,
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

  Map<String, DomainProgress> get currentLevelDomains => levelProgress[currentLevel]?.domains ?? {};

  int get masteredDomainCount => levelProgress[currentLevel]?.masteredDomainCount ?? 0;

  List<String> get pendingDomainKeys {
    final curDomains = currentLevelDomains;
    if (curDomains.isEmpty) {
      return ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative'];
    }
    return curDomains.entries
        .where((e) => !e.value.isMastered)
        .map((e) => e.key)
        .toList();
  }

  DomainProgress? get lowestScoringPendingDomain {
    final curDomains = currentLevelDomains;
    if (curDomains.isEmpty) return null;
    final pending = curDomains.values.where((d) => !d.isMastered).toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.score.compareTo(b.score));
    return pending.first;
  }

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
      if (rawMap['levels'] is Map) {
        (rawMap['levels'] as Map).forEach((key, value) {
          final lvl = int.tryParse(key.toString()) ?? 1;
          if (value is Map) {
            final domains = value['domains'] as Map?;
            Map<String, DomainProgress> domainMap = {};
            List<String> masteredDomains = [];
            if (domains != null) {
              domains.forEach((dKey, dVal) {
                if (dVal is Map) {
                  final dp = DomainProgress.fromMap(dKey.toString(), Map<String, dynamic>.from(dVal));
                  domainMap[dKey.toString()] = dp;
                  if (dp.isMastered) {
                    masteredDomains.add(dKey.toString());
                  }
                }
              });
            }
            final isUnl = (rawMap['unlockedLevels'] is List)
                ? (rawMap['unlockedLevels'] as List).map((e) => int.tryParse(e.toString()) ?? 1).contains(lvl)
                : (lvl == 1);
            result[lvl] = LevelProgress(
              completed: masteredDomains,
              total: 6,
              isUnlocked: isUnl,
              domains: domainMap,
            );
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
