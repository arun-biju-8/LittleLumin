// lib/models/child_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String childId;
  final String parentId;
  final String name;
  final int age;
  final String gender;

  // ✅ NEW FIELDS
  final String? deliveryType;       // "normal" or "cesarean"
  final String? gestationalAge;     // "full-term" or "premature"
  final double? birthWeight;        // in kg
  final String? birthComplications; // optional text
  final int? birthOrder;            // 1, 2, 3, etc.
  final int? motherAgeAtConception;
  final int? fatherAgeAtConception;
  final double? height;             // in cm
  final double? weight;             // in kg
  final String? sleepHabit;         // "good", "average", "poor"
  final int? sleepDuration;         // hours per day
  final int? nightWakings;          // times per night
  final String? mood;               // "happy", "calm", "irritable", "anxious"
  final String? attention;          // "focused", "average", "distracted"
  final String? socialInteraction;  // "responsive", "selective", "avoidant"

  final bool isFlagged;
  final String? flagReason;
  final DateTime? flaggedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // ✅ Calculate profile completion percentage
  int get profileCompletion {
    int totalFields = 0;
    int filledFields = 0;

    final fields = {
      'name': name.isNotEmpty,
      'age': age > 0,
      'gender': gender.isNotEmpty,
      'deliveryType': deliveryType != null,
      'gestationalAge': gestationalAge != null,
      'birthWeight': birthWeight != null,
      'birthComplications': birthComplications != null,
      'birthOrder': birthOrder != null,
      'motherAgeAtConception': motherAgeAtConception != null,
      'fatherAgeAtConception': fatherAgeAtConception != null,
      'height': height != null,
      'weight': weight != null,
      'sleepHabit': sleepHabit != null,
      'sleepDuration': sleepDuration != null,
      'nightWakings': nightWakings != null,
      'mood': mood != null,
      'attention': attention != null,
      'socialInteraction': socialInteraction != null,
    };

    totalFields = fields.length;
    filledFields = fields.values.where((v) => v == true).length;

    return (filledFields / totalFields * 100).round();
  }

  ChildModel({
    required this.childId,
    required this.parentId,
    required this.name,
    required this.age,
    required this.gender,
    this.deliveryType,
    this.gestationalAge,
    this.birthWeight,
    this.birthComplications,
    this.birthOrder,
    this.motherAgeAtConception,
    this.fatherAgeAtConception,
    this.height,
    this.weight,
    this.sleepHabit,
    this.sleepDuration,
    this.nightWakings,
    this.mood,
    this.attention,
    this.socialInteraction,
    this.isFlagged = false,
    this.flagReason,
    this.flaggedAt,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'parentId': parentId,
      'name': name,
      'age': age,
      'gender': gender,
      'deliveryType': deliveryType,
      'gestationalAge': gestationalAge,
      'birthWeight': birthWeight,
      'birthComplications': birthComplications,
      'birthOrder': birthOrder,
      'motherAgeAtConception': motherAgeAtConception,
      'fatherAgeAtConception': fatherAgeAtConception,
      'height': height,
      'weight': weight,
      'sleepHabit': sleepHabit,
      'sleepDuration': sleepDuration,
      'nightWakings': nightWakings,
      'mood': mood,
      'attention': attention,
      'socialInteraction': socialInteraction,
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'flaggedAt': flaggedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    return ChildModel(
      childId: map['childId'] ?? '',
      parentId: map['parentId'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? '',
      deliveryType: map['deliveryType'],
      gestationalAge: map['gestationalAge'],
      birthWeight: map['birthWeight']?.toDouble(),
      birthComplications: map['birthComplications'],
      birthOrder: map['birthOrder'],
      motherAgeAtConception: map['motherAgeAtConception'],
      fatherAgeAtConception: map['fatherAgeAtConception'],
      height: map['height']?.toDouble(),
      weight: map['weight']?.toDouble(),
      sleepHabit: map['sleepHabit'],
      sleepDuration: map['sleepDuration'],
      nightWakings: map['nightWakings'],
      mood: map['mood'],
      attention: map['attention'],
      socialInteraction: map['socialInteraction'],
      isFlagged: map['isFlagged'] ?? false,
      flagReason: map['flagReason'],
      flaggedAt: map['flaggedAt']?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}