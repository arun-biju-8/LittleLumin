// lib/models/learning_update_model.dart
import 'activity_model.dart';

class LearningUpdateModel {
  final String childId;
  final String childName;
  final String activityId;
  final String activityTitle;
  final String domain;
  final int level;
  final String? skill;
  final double scoreBefore;
  final double scoreAfter;
  final double scoreDelta;
  final bool isMastered;
  final bool levelCompleted;
  final int? nextLevel;
  final Map<String, dynamic> ratings;
  final DateTime completedAt;
  final String? aiHeadline;
  final String? aiMessage;
  final ActivityModel? nextActivity;

  const LearningUpdateModel({
    required this.childId,
    required this.childName,
    required this.activityId,
    required this.activityTitle,
    required this.domain,
    this.level = 1,
    this.skill,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.scoreDelta,
    this.isMastered = false,
    this.levelCompleted = false,
    this.nextLevel,
    this.ratings = const {},
    required this.completedAt,
    this.aiHeadline,
    this.aiMessage,
    this.nextActivity,
  });

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'childName': childName,
      'activityId': activityId,
      'activityTitle': activityTitle,
      'domain': domain,
      'level': level,
      'skill': skill,
      'scoreBefore': scoreBefore,
      'scoreAfter': scoreAfter,
      'scoreDelta': scoreDelta,
      'isMastered': isMastered,
      'levelCompleted': levelCompleted,
      'nextLevel': nextLevel,
      'ratings': ratings,
      'completedAt': completedAt.toIso8601String(),
      'aiHeadline': aiHeadline,
      'aiMessage': aiMessage,
      if (nextActivity != null) 'nextActivity': nextActivity!.toMap(),
    };
  }

  factory LearningUpdateModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      final ca = map['completedAt'];
      if (ca is String) {
        parsedDate = DateTime.parse(ca);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (_) {
      parsedDate = DateTime.now();
    }

    ActivityModel? nextAct;
    if (map['nextActivity'] is Map) {
      try {
        final actMap = Map<String, dynamic>.from(map['nextActivity'] as Map);
        final actId = actMap['id']?.toString() ?? 'next_act';
        nextAct = ActivityModel.fromMap(actId, actMap);
      } catch (_) {}
    }

    return LearningUpdateModel(
      childId: map['childId']?.toString() ?? '',
      childName: map['childName']?.toString() ?? 'Your child',
      activityId: map['activityId']?.toString() ?? '',
      activityTitle: map['activityTitle']?.toString() ?? 'Learning Activity',
      domain: map['domain']?.toString() ?? 'cognitive',
      level: (map['level'] is num) ? (map['level'] as num).toInt() : 1,
      skill: map['skill']?.toString(),
      scoreBefore: (map['scoreBefore'] is num) ? (map['scoreBefore'] as num).toDouble() : 0.0,
      scoreAfter: (map['scoreAfter'] is num) ? (map['scoreAfter'] as num).toDouble() : 0.0,
      scoreDelta: (map['scoreDelta'] is num) ? (map['scoreDelta'] as num).toDouble() : 0.0,
      isMastered: map['isMastered'] == true,
      levelCompleted: map['levelCompleted'] == true,
      nextLevel: (map['nextLevel'] is num) ? (map['nextLevel'] as num).toInt() : null,
      ratings: map['ratings'] is Map ? Map<String, dynamic>.from(map['ratings'] as Map) : const {},
      completedAt: parsedDate,
      aiHeadline: map['aiHeadline']?.toString(),
      aiMessage: map['aiMessage']?.toString(),
      nextActivity: nextAct,
    );
  }

  LearningUpdateModel copyWith({
    String? childId,
    String? childName,
    String? activityId,
    String? activityTitle,
    String? domain,
    int? level,
    String? skill,
    double? scoreBefore,
    double? scoreAfter,
    double? scoreDelta,
    bool? isMastered,
    bool? levelCompleted,
    int? nextLevel,
    Map<String, dynamic>? ratings,
    DateTime? completedAt,
    String? aiHeadline,
    String? aiMessage,
    ActivityModel? nextActivity,
  }) {
    return LearningUpdateModel(
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      activityId: activityId ?? this.activityId,
      activityTitle: activityTitle ?? this.activityTitle,
      domain: domain ?? this.domain,
      level: level ?? this.level,
      skill: skill ?? this.skill,
      scoreBefore: scoreBefore ?? this.scoreBefore,
      scoreAfter: scoreAfter ?? this.scoreAfter,
      scoreDelta: scoreDelta ?? this.scoreDelta,
      isMastered: isMastered ?? this.isMastered,
      levelCompleted: levelCompleted ?? this.levelCompleted,
      nextLevel: nextLevel ?? this.nextLevel,
      ratings: ratings ?? this.ratings,
      completedAt: completedAt ?? this.completedAt,
      aiHeadline: aiHeadline ?? this.aiHeadline,
      aiMessage: aiMessage ?? this.aiMessage,
      nextActivity: nextActivity ?? this.nextActivity,
    );
  }
}
