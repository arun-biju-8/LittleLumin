// lib/models/skill_profile_model.dart
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class SkillProfileModel {
  final String childId;
  final double cognitive;
  final double language;
  final double motor;
  final double social;
  final double emotional;
  final double creative;
  final DateTime updatedAt;

  SkillProfileModel({
    required this.childId,
    this.cognitive = 0,
    this.language = 0,
    this.motor = 0,
    this.social = 0,
    this.emotional = 0,
    this.creative = 0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'cognitive': cognitive,
      'language': language,
      'motor': motor,
      'social': social,
      'emotional': emotional,
      'creative': creative,
      'updatedAt': updatedAt,
    };
  }

  factory SkillProfileModel.fromMap(Map<String, dynamic> map) {
    return SkillProfileModel(
      childId: map['childId'] ?? '',
      cognitive: (map['cognitive'] ?? 0).toDouble(),
      language: (map['language'] ?? 0).toDouble(),
      motor: (map['motor'] ?? 0).toDouble(),
      social: (map['social'] ?? 0).toDouble(),
      emotional: (map['emotional'] ?? 0).toDouble(),
      creative: (map['creative'] ?? 0).toDouble(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  double get overallProgress {
    return (cognitive + language + motor + social + emotional + creative) / 6;
  }

  String get strongestSkill {
    Map<String, double> skills = {
      'Cognitive': cognitive,
      'Language': language,
      'Motor': motor,
      'Social': social,
      'Emotional': emotional,
      'Creative': creative,
    };
    return skills.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  String get weakestSkill {
    Map<String, double> skills = {
      'Cognitive': cognitive,
      'Language': language,
      'Motor': motor,
      'Social': social,
      'Emotional': emotional,
      'Creative': creative,
    };
    return skills.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }
}