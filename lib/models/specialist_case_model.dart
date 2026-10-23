// lib/models/specialist_case_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum CaseStatus {
  pending,
  accepted,
  active,
  completed,
  declined,
  revoked,
}

class SpecialistCaseModel {
  final String caseId;
  final String parentId;
  final String parentName;
  final String childId;
  final String childName;
  final int childAgeYears;
  final String specialistId;
  final String specialistName;
  final String specialistRole; // 'learning_guide', 'specialist', 'clinical_specialist'
  final String purpose;
  final List<String> authorizedDataCategories;
  final String consentNoticeVersion;
  final DateTime consentedAt;
  final CaseStatus status;
  final DateTime statusUpdatedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? revokedAt;
  final String? revocationReason;
  final DateTime? expiresAt;
  final String? parentNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SpecialistCaseModel({
    required this.caseId,
    required this.parentId,
    required this.parentName,
    required this.childId,
    required this.childName,
    required this.childAgeYears,
    required this.specialistId,
    required this.specialistName,
    this.specialistRole = 'specialist',
    required this.purpose,
    required this.authorizedDataCategories,
    this.consentNoticeVersion = 'v1.0-dpdp',
    required this.consentedAt,
    this.status = CaseStatus.pending,
    required this.statusUpdatedAt,
    this.acceptedAt,
    this.completedAt,
    this.revokedAt,
    this.revocationReason,
    this.expiresAt,
    this.parentNotes,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convenience getters for UI compatibility
  String get id => caseId;
  List<String> get authorizedCategories => authorizedDataCategories;
  DateTime? get consentExpiresAt => expiresAt;

  /// True if consent was granted and has not been revoked or expired
  bool get isConsentActive {
    if (status == CaseStatus.revoked || status == CaseStatus.declined) return false;
    if (revokedAt != null) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// True if specialist has been accepted and is actively authorized to view child records
  bool get canAccessChildData {
    return isConsentActive && (status == CaseStatus.accepted || status == CaseStatus.active);
  }

  /// Check if a specific data category is authorized
  bool isCategoryAuthorized(String category) {
    if (!canAccessChildData) return false;
    return authorizedDataCategories.contains(category) || authorizedDataCategories.contains('all');
  }

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'parentId': parentId,
      'parentName': parentName,
      'childId': childId,
      'childName': childName,
      'childAgeYears': childAgeYears,
      'specialistId': specialistId,
      'specialistName': specialistName,
      'specialistRole': specialistRole,
      'purpose': purpose,
      'authorizedDataCategories': authorizedDataCategories,
      'consentCategories': authorizedDataCategories,
      'consentNoticeVersion': consentNoticeVersion,
      'consentedAt': Timestamp.fromDate(consentedAt),
      'status': status.name,
      'statusUpdatedAt': Timestamp.fromDate(statusUpdatedAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'revokedAt': revokedAt != null ? Timestamp.fromDate(revokedAt!) : null,
      'revocationReason': revocationReason,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'consentExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'parentNotes': parentNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory SpecialistCaseModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    CaseStatus parseStatus(dynamic val) {
      if (val == null) return CaseStatus.pending;
      final str = val.toString().toLowerCase().trim();
      return CaseStatus.values.firstWhere(
        (e) => e.name == str,
        orElse: () => CaseStatus.pending,
      );
    }

    final rawCategories = map['authorizedDataCategories'] ?? map['consentCategories'];
    final rawExpiry = map['consentExpiresAt'] ?? map['expiresAt'];

    return SpecialistCaseModel(
      caseId: (docId != null && docId.isNotEmpty) ? docId : (map['caseId'] ?? ''),
      parentId: map['parentId'] ?? '',
      parentName: map['parentName'] ?? 'Parent',
      childId: map['childId'] ?? '',
      childName: map['childName'] ?? 'Child',
      childAgeYears: (map['childAgeYears'] as num?)?.toInt() ?? 4,
      specialistId: map['specialistId'] ?? '',
      specialistName: map['specialistName'] ?? 'Specialist',
      specialistRole: map['specialistRole'] ?? 'specialist',
      purpose: map['purpose'] ?? 'Developmental review',
      authorizedDataCategories: List<String>.from(rawCategories ?? ['domain_scores', 'observations']),
      consentNoticeVersion: map['consentNoticeVersion'] ?? 'v1.0-dpdp',
      consentedAt: parseDate(map['consentedAt']),
      status: parseStatus(map['status']),
      statusUpdatedAt: parseDate(map['statusUpdatedAt']),
      acceptedAt: map['acceptedAt'] != null ? parseDate(map['acceptedAt']) : null,
      completedAt: map['completedAt'] != null ? parseDate(map['completedAt']) : null,
      revokedAt: map['revokedAt'] != null ? parseDate(map['revokedAt']) : null,
      revocationReason: map['revocationReason'],
      expiresAt: rawExpiry != null ? parseDate(rawExpiry) : null,
      parentNotes: map['parentNotes'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }

  SpecialistCaseModel copyWith({
    String? caseId,
    String? parentId,
    String? parentName,
    String? childId,
    String? childName,
    int? childAgeYears,
    String? specialistId,
    String? specialistName,
    String? specialistRole,
    String? purpose,
    List<String>? authorizedDataCategories,
    String? consentNoticeVersion,
    DateTime? consentedAt,
    CaseStatus? status,
    DateTime? statusUpdatedAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? revokedAt,
    String? revocationReason,
    DateTime? expiresAt,
    String? parentNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpecialistCaseModel(
      caseId: caseId ?? this.caseId,
      parentId: parentId ?? this.parentId,
      parentName: parentName ?? this.parentName,
      childId: childId ?? this.childId,
      childName: childName ?? this.childName,
      childAgeYears: childAgeYears ?? this.childAgeYears,
      specialistId: specialistId ?? this.specialistId,
      specialistName: specialistName ?? this.specialistName,
      specialistRole: specialistRole ?? this.specialistRole,
      purpose: purpose ?? this.purpose,
      authorizedDataCategories: authorizedDataCategories ?? this.authorizedDataCategories,
      consentNoticeVersion: consentNoticeVersion ?? this.consentNoticeVersion,
      consentedAt: consentedAt ?? this.consentedAt,
      status: status ?? this.status,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      revocationReason: revocationReason ?? this.revocationReason,
      expiresAt: expiresAt ?? this.expiresAt,
      parentNotes: parentNotes ?? this.parentNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
