// lib/models/consultation_summary_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ConsultationSummaryModel {
  final String id;
  final String caseId;
  final String childId;
  final String childName;
  final String parentId;
  final String parentName;
  final String llgId;
  final String llgName;
  final String consultationMode; // 'WhatsApp', 'Video Call', 'In-Person', 'Audio Call'
  final DateTime consultationDate;
  final String consultationReason;
  final List<String> concernsDiscussed;
  final String guidanceProvided;
  final String? parentQuestionsOrFeedback;
  final List<String> agreedFollowUpActions;
  final DateTime? nextReviewDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ConsultationSummaryModel({
    required this.id,
    required this.caseId,
    required this.childId,
    required this.childName,
    required this.parentId,
    required this.parentName,
    required this.llgId,
    required this.llgName,
    this.consultationMode = 'WhatsApp',
    required this.consultationDate,
    required this.consultationReason,
    required this.concernsDiscussed,
    required this.guidanceProvided,
    this.parentQuestionsOrFeedback,
    required this.agreedFollowUpActions,
    this.nextReviewDate,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'childId': childId,
      'childName': childName,
      'parentId': parentId,
      'parentName': parentName,
      'llgId': llgId,
      'llgName': llgName,
      'consultationMode': consultationMode,
      'consultationDate': Timestamp.fromDate(consultationDate),
      'consultationReason': consultationReason,
      'concernsDiscussed': concernsDiscussed,
      'guidanceProvided': guidanceProvided,
      'parentQuestionsOrFeedback': parentQuestionsOrFeedback,
      'agreedFollowUpActions': agreedFollowUpActions,
      'nextReviewDate': nextReviewDate != null ? Timestamp.fromDate(nextReviewDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory ConsultationSummaryModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    List<String> parseList(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) return [val];
      return [];
    }

    return ConsultationSummaryModel(
      id: docId,
      caseId: map['caseId'] ?? '',
      childId: map['childId'] ?? '',
      childName: map['childName'] ?? 'Child',
      parentId: map['parentId'] ?? '',
      parentName: map['parentName'] ?? 'Parent',
      llgId: map['llgId'] ?? '',
      llgName: map['llgName'] ?? 'Specialist',
      consultationMode: map['consultationMode'] ?? 'WhatsApp',
      consultationDate: parseDate(map['consultationDate']),
      consultationReason: map['consultationReason'] ?? '',
      concernsDiscussed: parseList(map['concernsDiscussed']),
      guidanceProvided: map['guidanceProvided'] ?? '',
      parentQuestionsOrFeedback: map['parentQuestionsOrFeedback'],
      agreedFollowUpActions: parseList(map['agreedFollowUpActions']),
      nextReviewDate: map['nextReviewDate'] != null ? parseDate(map['nextReviewDate']) : null,
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }
}
