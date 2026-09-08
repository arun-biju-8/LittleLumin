// lib/models/child_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String childId;
  final String parentId;
  final String name;
  final DateTime dateOfBirth;
  final String gender;

  // ✅ Health & Profile Fields
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

  // ✅ VABS-II Assessment Fields
  final bool? vabsCompleted;
  final bool? vabsSkipped;
  final DateTime? vabsCompletedAt;
  final Map<String, double>? vabsScores;

  final bool isFlagged;
  final String? flagReason;
  final DateTime? flaggedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // ✅ Getter for calculated age in years
  int get age {
    final now = DateTime.now();
    int years = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  // ✅ Getter for age display string ("3 years", "4 months", etc.)
  String get ageDisplay {
    final now = DateTime.now();
    int years = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      years--;
    }
    if (years >= 1) {
      return '$years ${years == 1 ? 'year' : 'years'}';
    }

    int months = (now.year - dateOfBirth.year) * 12 + (now.month - dateOfBirth.month);
    if (now.day < dateOfBirth.day) {
      months--;
    }
    if (months <= 0) months = 0;
    return '$months ${months == 1 ? 'month' : 'months'}';
  }

  // ✅ Calculate profile completion percentage
  int get profileCompletion {
    int totalFields = 0;
    int filledFields = 0;

    final fields = {
      'name': name.isNotEmpty,
      'dateOfBirth': true,
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
    required this.dateOfBirth,
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
    this.vabsCompleted,
    this.vabsSkipped,
    this.vabsCompletedAt,
    this.vabsScores,
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
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
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
      'vabsCompleted': vabsCompleted,
      'vabsSkipped': vabsSkipped,
      'vabsCompletedAt': vabsCompletedAt != null ? Timestamp.fromDate(vabsCompletedAt!) : null,
      'vabsScores': vabsScores,
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'flaggedAt': flaggedAt != null ? Timestamp.fromDate(flaggedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDob;
    if (map['dateOfBirth'] is Timestamp) {
      parsedDob = (map['dateOfBirth'] as Timestamp).toDate();
    } else if (map['dateOfBirth'] is String) {
      parsedDob = DateTime.tryParse(map['dateOfBirth']) ?? DateTime.now();
    } else if (map['age'] != null && map['age'] is int && (map['age'] as int) > 0) {
      final years = map['age'] as int;
      parsedDob = DateTime(DateTime.now().year - years, DateTime.now().month, DateTime.now().day);
    } else {
      parsedDob = DateTime.now();
    }

    Map<String, double>? parseVabsScores(dynamic raw) {
      if (raw is Map) {
        Map<String, double> res = {};
        raw.forEach((key, val) {
          if (val is num) res[key.toString()] = val.toDouble();
        });
        return res;
      }
      return null;
    }

    DateTime? parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return ChildModel(
      childId: map['childId'] ?? '',
      parentId: map['parentId'] ?? '',
      name: map['name'] ?? '',
      dateOfBirth: parsedDob,
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
      vabsCompleted: map['vabsCompleted'] as bool?,
      vabsSkipped: map['vabsSkipped'] as bool?,
      vabsCompletedAt: parseDate(map['vabsCompletedAt']),
      vabsScores: parseVabsScores(map['vabsScores']),
      isFlagged: map['isFlagged'] ?? false,
      flagReason: map['flagReason'],
      flaggedAt: parseDate(map['flaggedAt']),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}