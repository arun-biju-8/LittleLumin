// lib/models/activity_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String? id;
  final String title;
  final String skillType;
  final int duration;
  final String difficulty;
  final int ageGroup;
  final List<String> instructions;
  final List<String> learningGoals;
  final List<String> materials;
  final bool isActive;
  final String createdBy; // User UID of admin/LLG
  final DateTime createdAt;
  final DateTime? updatedAt;

  ActivityModel({
    this.id,
    required this.title,
    required this.skillType,
    required this.duration,
    required this.difficulty,
    required this.ageGroup,
    required this.instructions,
    required this.learningGoals,
    required this.materials,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'skillType': skillType,
      'duration': duration,
      'difficulty': difficulty,
      'ageGroup': ageGroup,
      'instructions': instructions,
      'learningGoals': learningGoals,
      'materials': materials,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory ActivityModel.fromMap(String id, Map<String, dynamic> map) {
    return ActivityModel(
      id: id,
      title: map['title'] ?? '',
      skillType: map['skillType'] ?? '',
      duration: map['duration'] ?? 10,
      difficulty: map['difficulty'] ?? 'Medium',
      ageGroup: map['ageGroup'] ?? 3,
      instructions: List<String>.from(map['instructions'] ?? []),
      learningGoals: List<String>.from(map['learningGoals'] ?? []),
      materials: List<String>.from(map['materials'] ?? []),
      isActive: map['isActive'] ?? true,
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}