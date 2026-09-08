// lib/models/activity_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String? id;
  final String title;
  final String? shortDescription;
  final String skillType;
  final String difficulty;
  final List<int> ageGroup;
  final int duration;
  final List<String> instructions;
  final List<String> learningGoals;
  final List<String> materials;
  final bool isActive;
  final bool isPreset;
  final bool isEditedFromPreset;
  final String? editedFromActivityId;
  final String? originalTitle;
  final String? childId;
  final String createdBy;
  final String createdByName;
  final List<String> tags;
  final String category;
  final String? imageUrl;
  final String? videoUrl;
  final String? videoThumbnail;
  final String? videoDuration;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final DateTime? editedAt;

  ActivityModel({
    this.id,
    required this.title,
    this.shortDescription,
    required this.skillType,
    required this.difficulty,
    required this.ageGroup,
    required this.duration,
    required this.instructions,
    required this.learningGoals,
    required this.materials,
    this.isActive = true,
    this.isPreset = true,
    this.isEditedFromPreset = false,
    this.editedFromActivityId,
    this.originalTitle,
    this.childId,
    this.createdBy = '',
    this.createdByName = 'System Admin',
    this.tags = const [],
    this.category = 'General',
    this.imageUrl,
    this.videoUrl,
    this.videoThumbnail,
    this.videoDuration,
    this.isCompleted = false,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.editedAt,
  });

  // Helper Getters
  String get difficultyIcon {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return '🟢';
      case 'medium':
        return '🟡';
      case 'hard':
        return '🔴';
      default:
        return '🟢';
    }
  }

  String get ageGroupDisplay {
    if (ageGroup.isEmpty) return 'All ages';
    final sorted = List<int>.from(ageGroup)..sort();
    if (sorted.length == 1) return '${sorted.first} years';

    bool isSequential = true;
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i + 1] != sorted[i] + 1) {
        isSequential = false;
        break;
      }
    }

    if (isSequential) {
      return '${sorted.first}-${sorted.last} years';
    } else {
      return '${sorted.join(', ')} years';
    }
  }

  bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'shortDescription': shortDescription,
      'skillType': skillType,
      'difficulty': difficulty,
      'ageGroup': ageGroup,
      'duration': duration,
      'instructions': instructions,
      'learningGoals': learningGoals,
      'materials': materials,
      'isActive': isActive,
      'isPreset': isPreset,
      'isEditedFromPreset': isEditedFromPreset,
      'editedFromActivityId': editedFromActivityId,
      'originalTitle': originalTitle,
      'childId': childId,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'tags': tags,
      'category': category,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'videoThumbnail': videoThumbnail,
      'videoDuration': videoDuration,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
    };
  }

  factory ActivityModel.fromMap(String id, Map<String, dynamic> map) {
    List<int> parseAgeGroup(dynamic raw) {
      if (raw == null) return [3, 4];
      if (raw is List) {
        return raw.map((e) => int.tryParse(e.toString()) ?? 3).toList();
      }
      if (raw is int) return [raw];
      return [3, 4];
    }

    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      if (raw is String && raw.isNotEmpty) return [raw];
      return [];
    }

    DateTime parseDateTime(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return ActivityModel(
      id: id,
      title: map['title'] ?? '',
      shortDescription: map['shortDescription'] as String?,
      skillType: map['skillType'] ?? 'Cognitive',
      difficulty: map['difficulty'] ?? 'Medium',
      ageGroup: parseAgeGroup(map['ageGroup']),
      duration: (map['duration'] is num) ? (map['duration'] as num).toInt() : 10,
      instructions: parseStringList(map['instructions']),
      learningGoals: parseStringList(map['learningGoals']),
      materials: parseStringList(map['materials']),
      isActive: map['isActive'] ?? true,
      isPreset: map['isPreset'] ?? true,
      isEditedFromPreset: map['isEditedFromPreset'] ?? false,
      editedFromActivityId: map['editedFromActivityId'] as String?,
      originalTitle: map['originalTitle'] as String?,
      childId: map['childId'] as String?,
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? 'Admin',
      tags: parseStringList(map['tags']),
      category: map['category'] ?? 'General',
      imageUrl: map['imageUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
      videoThumbnail: map['videoThumbnail'] as String?,
      videoDuration: map['videoDuration'] as String?,
      isCompleted: map['isCompleted'] ?? false,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDateTime(map['updatedAt']) : null,
      completedAt: map['completedAt'] != null ? parseDateTime(map['completedAt']) : null,
      editedAt: map['editedAt'] != null ? parseDateTime(map['editedAt']) : null,
    );
  }
}