// lib/models/recommendation_model.dart
// ignore_for_file: constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';

enum RecommendationStatus {
  recommended,
  in_progress,
  completed,
  partially_completed,
  skipped,
  paused,
  discontinued,
}

enum ParentActivityResponse {
  none,
  completed,
  partially_completed,
  struggled,
  skipped,
}

class RecommendationModel {
  final String id;
  final String caseId;
  final String childId;
  final String childName;
  final String parentId;
  final String llgId;
  final String llgName;
  final String llgRole; // 'learning_guide', 'clinical_specialist'

  final String title;
  final String rationale; // Why suggested
  final String skillDomain; // cognitive, language, motor, social, emotional, creative
  final List<String> instructions;
  final List<String> materials;
  final int durationMinutes;
  final String frequency; // e.g. "Daily", "3 times a week", "Weekends"
  final String safetyGuidance;
  final DateTime recommendedAt;
  final DateTime? reviewDate;
  final RecommendationStatus status;
  final String? statusReason; // e.g., reason for pausing or discontinuing

  // Parent Feedback / Response
  final ParentActivityResponse parentResponse;
  final String? parentFeedback;
  final String? skippedReason;
  final DateTime? parentRespondedAt;

  // LLG Review & Follow-up
  final String? llgFeedback;
  final DateTime? llgReviewedAt;
  final String? nextSteps;

  // Linked base activity ID if derived from catalogue
  final String? baseActivityId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const RecommendationModel({
    required this.id,
    required this.caseId,
    required this.childId,
    required this.childName,
    required this.parentId,
    required this.llgId,
    required this.llgName,
    this.llgRole = 'learning_guide',
    required this.title,
    required this.rationale,
    required this.skillDomain,
    required this.instructions,
    this.materials = const [],
    this.durationMinutes = 15,
    this.frequency = 'Daily',
    this.safetyGuidance = 'Adult supervision recommended at all times.',
    required this.recommendedAt,
    this.reviewDate,
    this.status = RecommendationStatus.recommended,
    this.statusReason,
    this.parentResponse = ParentActivityResponse.none,
    this.parentFeedback,
    this.skippedReason,
    this.parentRespondedAt,
    this.llgFeedback,
    this.llgReviewedAt,
    this.nextSteps,
    this.baseActivityId,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isAwaitingParent =>
      status == RecommendationStatus.recommended ||
      status == RecommendationStatus.in_progress;

  bool get hasParentResponded =>
      parentResponse != ParentActivityResponse.none ||
      (parentFeedback != null && parentFeedback!.isNotEmpty);

  bool get isAwaitingLLGReview =>
      hasParentResponded && llgFeedback == null;

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'childId': childId,
      'childName': childName,
      'parentId': parentId,
      'llgId': llgId,
      'llgName': llgName,
      'llgRole': llgRole,
      'title': title,
      'rationale': rationale,
      'skillDomain': skillDomain.toLowerCase().trim(),
      'instructions': instructions,
      'materials': materials,
      'durationMinutes': durationMinutes,
      'frequency': frequency,
      'safetyGuidance': safetyGuidance,
      'recommendedAt': Timestamp.fromDate(recommendedAt),
      'reviewDate': reviewDate != null ? Timestamp.fromDate(reviewDate!) : null,
      'status': status.name,
      'statusReason': statusReason,
      'parentResponse': parentResponse.name,
      'parentFeedback': parentFeedback,
      'skippedReason': skippedReason,
      'parentRespondedAt': parentRespondedAt != null ? Timestamp.fromDate(parentRespondedAt!) : null,
      'llgFeedback': llgFeedback,
      'llgReviewedAt': llgReviewedAt != null ? Timestamp.fromDate(llgReviewedAt!) : null,
      'nextSteps': nextSteps,
      'baseActivityId': baseActivityId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory RecommendationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    RecommendationStatus parseStatus(dynamic val) {
      if (val == null) return RecommendationStatus.recommended;
      final str = val.toString().toLowerCase().trim();
      return RecommendationStatus.values.firstWhere(
        (e) => e.name == str,
        orElse: () => RecommendationStatus.recommended,
      );
    }

    ParentActivityResponse parseResponse(dynamic val) {
      if (val == null) return ParentActivityResponse.none;
      final str = val.toString().toLowerCase().trim();
      return ParentActivityResponse.values.firstWhere(
        (e) => e.name == str,
        orElse: () => ParentActivityResponse.none,
      );
    }

    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) return [val];
      return [];
    }

    return RecommendationModel(
      id: docId,
      caseId: map['caseId'] ?? '',
      childId: map['childId'] ?? '',
      childName: map['childName'] ?? 'Child',
      parentId: map['parentId'] ?? '',
      llgId: map['llgId'] ?? '',
      llgName: map['llgName'] ?? 'Learning Guide',
      llgRole: map['llgRole'] ?? 'learning_guide',
      title: map['title'] ?? 'Personalized Activity',
      rationale: map['rationale'] ?? '',
      skillDomain: map['skillDomain'] ?? 'cognitive',
      instructions: parseList(map['instructions']),
      materials: parseList(map['materials']),
      durationMinutes: (map['durationMinutes'] is num) ? (map['durationMinutes'] as num).toInt() : 15,
      frequency: map['frequency'] ?? 'Daily',
      safetyGuidance: map['safetyGuidance'] ?? 'Adult supervision recommended at all times.',
      recommendedAt: parseDate(map['recommendedAt']),
      reviewDate: map['reviewDate'] != null ? parseDate(map['reviewDate']) : null,
      status: parseStatus(map['status']),
      statusReason: map['statusReason'],
      parentResponse: parseResponse(map['parentResponse']),
      parentFeedback: map['parentFeedback'],
      skippedReason: map['skippedReason'],
      parentRespondedAt: map['parentRespondedAt'] != null ? parseDate(map['parentRespondedAt']) : null,
      llgFeedback: map['llgFeedback'],
      llgReviewedAt: map['llgReviewedAt'] != null ? parseDate(map['llgReviewedAt']) : null,
      nextSteps: map['nextSteps'],
      baseActivityId: map['baseActivityId'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  RecommendationModel copyWith({
    String? id,
    String? caseId,
    String? childId,
    String? childName,
    String? parentId,
    String? llgId,
    String? llgName,
    String? llgRole,
    String? title,
    String? rationale,
    String? skillDomain,
    List<String>? instructions,
    List<String>? materials,
    int? durationMinutes,
    String? frequency,
    String? safetyGuidance,
    DateTime? recommendedAt,
    DateTime? reviewDate,
    RecommendationStatus? status,
    String? statusReason,
    ParentActivityResponse? parentResponse,
    String? parentFeedback,
    String? skippedReason,
    DateTime? parentRespondedAt,
    String? llgFeedback,
    DateTime? llgReviewedAt,
    String? nextSteps,
    String? baseActivityId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecommendationModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      parentId: parentId ?? this.parentId,
      llgId: llgId ?? this.llgId,
      llgName: llgName ?? this.llgName,
      llgRole: llgRole ?? this.llgRole,
      title: title ?? this.title,
      rationale: rationale ?? this.rationale,
      skillDomain: skillDomain ?? this.skillDomain,
      instructions: instructions ?? this.instructions,
      materials: materials ?? this.materials,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      frequency: frequency ?? this.frequency,
      safetyGuidance: safetyGuidance ?? this.safetyGuidance,
      recommendedAt: recommendedAt ?? this.recommendedAt,
      reviewDate: reviewDate ?? this.reviewDate,
      status: status ?? this.status,
      statusReason: statusReason ?? this.statusReason,
      parentResponse: parentResponse ?? this.parentResponse,
      parentFeedback: parentFeedback ?? this.parentFeedback,
      skippedReason: skippedReason ?? this.skippedReason,
      parentRespondedAt: parentRespondedAt ?? this.parentRespondedAt,
      llgFeedback: llgFeedback ?? this.llgFeedback,
      llgReviewedAt: llgReviewedAt ?? this.llgReviewedAt,
      nextSteps: nextSteps ?? this.nextSteps,
      baseActivityId: baseActivityId ?? this.baseActivityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
