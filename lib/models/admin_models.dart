// lib/models/admin_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Account status lifecycle
enum AccountStatus {
  active,
  warningIssued,
  suspended,
  recoveryPending,
  deactivated,
  deletionPending,
}

extension AccountStatusExtension on AccountStatus {
  String get name {
    switch (this) {
      case AccountStatus.active:
        return 'active';
      case AccountStatus.warningIssued:
        return 'warning_issued';
      case AccountStatus.suspended:
        return 'suspended';
      case AccountStatus.recoveryPending:
        return 'recovery_pending';
      case AccountStatus.deactivated:
        return 'deactivated';
      case AccountStatus.deletionPending:
        return 'deletion_pending';
    }
  }

  String get displayName {
    switch (this) {
      case AccountStatus.active:
        return 'Active';
      case AccountStatus.warningIssued:
        return 'Warning Issued';
      case AccountStatus.suspended:
        return 'Suspended';
      case AccountStatus.recoveryPending:
        return 'Recovery Pending';
      case AccountStatus.deactivated:
        return 'Deactivated';
      case AccountStatus.deletionPending:
        return 'Deletion Pending';
    }
  }

  static AccountStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'warning_issued':
      case 'warned':
        return AccountStatus.warningIssued;
      case 'suspended':
        return AccountStatus.suspended;
      case 'recovery_pending':
        return AccountStatus.recoveryPending;
      case 'deactivated':
      case 'inactive':
        return AccountStatus.deactivated;
      case 'deletion_pending':
        return AccountStatus.deletionPending;
      case 'active':
      default:
        return AccountStatus.active;
    }
  }
}

/// Warning record
class UserWarningRecord {
  final String warningId;
  final String category;
  final String reason;
  final String? notes;
  final DateTime issuedAt;
  final String issuedBy;
  final bool emailSent;

  UserWarningRecord({
    required this.warningId,
    required this.category,
    required this.reason,
    this.notes,
    required this.issuedAt,
    required this.issuedBy,
    this.emailSent = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'warningId': warningId,
      'category': category,
      'reason': reason,
      'notes': notes,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'issuedBy': issuedBy,
      'emailSent': emailSent,
    };
  }

  factory UserWarningRecord.fromMap(Map<String, dynamic> map) {
    return UserWarningRecord(
      warningId: map['warningId'] ?? '',
      category: map['category'] ?? 'General Policy Concern',
      reason: map['reason'] ?? '',
      notes: map['notes'],
      issuedAt: (map['issuedAt'] is Timestamp)
          ? (map['issuedAt'] as Timestamp).toDate()
          : (map['issuedAt'] is DateTime ? map['issuedAt'] : DateTime.now()),
      issuedBy: map['issuedBy'] ?? 'Admin',
      emailSent: map['emailSent'] ?? true,
    );
  }
}

/// Account Recovery Request Model
class AccountRecoveryRequestModel {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String userRole;
  final String suspensionReason;
  final DateTime requestedAt;
  final String userExplanation;
  final String status; // 'pending_review', 'additional_verification_required', 'approved', 'rejected', 'completed'
  final DateTime? reviewedAt;
  final String? reviewerId;
  final String? reviewerNotes;

  AccountRecoveryRequestModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userRole,
    required this.suspensionReason,
    required this.requestedAt,
    required this.userExplanation,
    this.status = 'pending_review',
    this.reviewedAt,
    this.reviewerId,
    this.reviewerNotes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'userRole': userRole,
      'suspensionReason': suspensionReason,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'userExplanation': userExplanation,
      'status': status,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewerId': reviewerId,
      'reviewerNotes': reviewerNotes,
    };
  }

  factory AccountRecoveryRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return AccountRecoveryRequestModel(
      id: id,
      userId: map['userId'] ?? '',
      userEmail: map['userEmail'] ?? '',
      userName: map['userName'] ?? '',
      userRole: map['userRole'] ?? 'parent',
      suspensionReason: map['suspensionReason'] ?? '',
      requestedAt: (map['requestedAt'] is Timestamp)
          ? (map['requestedAt'] as Timestamp).toDate()
          : DateTime.now(),
      userExplanation: map['userExplanation'] ?? '',
      status: map['status'] ?? 'pending_review',
      reviewedAt: (map['reviewedAt'] is Timestamp) ? (map['reviewedAt'] as Timestamp).toDate() : null,
      reviewerId: map['reviewerId'],
      reviewerNotes: map['reviewerNotes'],
    );
  }
}

/// LLG Specialist Assignment Model
class LLGAssignmentModel {
  final String id;
  final String parentId;
  final String parentName;
  final String? childId;
  final String? childName;
  final String specialistId;
  final String specialistName;
  final String specialistRole;
  final String status; // 'active', 'reassigned', 'removed', 'pending'
  final DateTime assignedAt;
  final String assignedBy;
  final DateTime? endedAt;
  final String? reason;
  final List<String> coveredChildren;

  LLGAssignmentModel({
    required this.id,
    required this.parentId,
    required this.parentName,
    this.childId,
    this.childName,
    required this.specialistId,
    required this.specialistName,
    this.specialistRole = 'specialist',
    this.status = 'active',
    required this.assignedAt,
    required this.assignedBy,
    this.endedAt,
    this.reason,
    this.coveredChildren = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentId': parentId,
      'parentName': parentName,
      'childId': childId,
      'childName': childName,
      'specialistId': specialistId,
      'specialistName': specialistName,
      'specialistRole': specialistRole,
      'status': status,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'assignedBy': assignedBy,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'reason': reason,
      'coveredChildren': coveredChildren,
    };
  }

  factory LLGAssignmentModel.fromMap(String id, Map<String, dynamic> map) {
    return LLGAssignmentModel(
      id: id,
      parentId: map['parentId'] ?? '',
      parentName: map['parentName'] ?? '',
      childId: map['childId'],
      childName: map['childName'],
      specialistId: map['specialistId'] ?? '',
      specialistName: map['specialistName'] ?? '',
      specialistRole: map['specialistRole'] ?? 'specialist',
      status: map['status'] ?? 'active',
      assignedAt: (map['assignedAt'] is Timestamp)
          ? (map['assignedAt'] as Timestamp).toDate()
          : DateTime.now(),
      assignedBy: map['assignedBy'] ?? 'Admin',
      endedAt: (map['endedAt'] is Timestamp) ? (map['endedAt'] as Timestamp).toDate() : null,
      reason: map['reason'],
      coveredChildren: List<String>.from(map['coveredChildren'] ?? []),
    );
  }

  bool get isPending => status == 'pending' || status == 'requested' || status == 'pending_review';
  bool get isActive => status == 'active' || status == 'accepted';
  bool get isCompletedOrCancelled =>
      status == 'completed' ||
      status == 'cancelled' ||
      status == 'removed' ||
      status == 'revoked' ||
      status == 'declined' ||
      status == 'reassigned';

  factory LLGAssignmentModel.fromSpecialistCaseMap(String docId, Map<String, dynamic> map) {
    final rawStatus = (map['status'] ?? 'pending').toString().toLowerCase();
    String mappedStatus = 'pending';
    if (rawStatus == 'accepted' || rawStatus == 'active') {
      mappedStatus = 'active';
    } else if (rawStatus == 'completed') {
      mappedStatus = 'completed';
    } else if (rawStatus == 'declined') {
      mappedStatus = 'declined';
    } else if (rawStatus == 'revoked') {
      mappedStatus = 'revoked';
    } else {
      mappedStatus = rawStatus;
    }

    DateTime assignedDate = DateTime.now();
    if (map['acceptedAt'] is Timestamp) {
      assignedDate = (map['acceptedAt'] as Timestamp).toDate();
    } else if (map['consentedAt'] is Timestamp) {
      assignedDate = (map['consentedAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is Timestamp) {
      assignedDate = (map['createdAt'] as Timestamp).toDate();
    } else if (map['statusUpdatedAt'] is Timestamp) {
      assignedDate = (map['statusUpdatedAt'] as Timestamp).toDate();
    }

    DateTime? endedDate;
    if (map['revokedAt'] is Timestamp) {
      endedDate = (map['revokedAt'] as Timestamp).toDate();
    } else if (map['completedAt'] is Timestamp) {
      endedDate = (map['completedAt'] as Timestamp).toDate();
    }

    final childId = map['childId']?.toString();

    return LLGAssignmentModel(
      id: docId,
      parentId: map['parentId'] ?? '',
      parentName: (map['parentName'] != null && map['parentName'].toString().isNotEmpty)
          ? map['parentName'].toString()
          : 'Parent',
      childId: childId,
      childName: map['childName']?.toString(),
      specialistId: map['specialistId'] ?? '',
      specialistName: (map['specialistName'] != null && map['specialistName'].toString().isNotEmpty)
          ? map['specialistName'].toString()
          : 'Specialist',
      specialistRole: map['specialistRole'] ?? 'specialist',
      status: mappedStatus,
      assignedAt: assignedDate,
      assignedBy: (map['parentName'] != null && map['parentName'].toString().isNotEmpty)
          ? '${map['parentName']} (Parent Request)'
          : 'Parent Consultation Request',
      endedAt: endedDate,
      reason: map['purpose'] ?? map['parentNotes'],
      coveredChildren: (childId != null && childId.isNotEmpty) ? [childId] : [],
    );
  }
}

/// LLG Specialist Credential Document Model
class LLGCredentialDocument {
  final String key; // 'qualification', 'license', 'experience', 'identity', 'professional', 'general'
  final String title;
  final String url;
  final String? fileName;
  final DateTime? uploadDate;
  final String verificationStatus; // 'verified', 'rejected', 'pending', 'unsubmitted'
  final String? rejectionReason;

  LLGCredentialDocument({
    required this.key,
    required this.title,
    required this.url,
    this.fileName,
    this.uploadDate,
    this.verificationStatus = 'pending',
    this.rejectionReason,
  });

  bool get isSubmitted => url.trim().isNotEmpty;

  bool get isImage {
    if (!isSubmitted) return false;
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.svg');
  }

  bool get isPdf {
    if (!isSubmitted) return false;
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.pdf');
  }

  String get categoryKey => key;
  String get categoryLabel => title;
  String get filename => effectiveFileName;

  String get effectiveFileName {
    if (fileName != null && fileName!.isNotEmpty) return fileName!;
    if (url.trim().isEmpty) return 'No document submitted';
    try {
      final pathPart = url.split('?').first;
      final decoded = Uri.decodeComponent(pathPart);
      final name = decoded.split('/').last.trim();
      if (name.isNotEmpty && name.contains('.')) return name;
    } catch (_) {}
    return isPdf ? '$title.pdf' : (isImage ? '$title.jpg' : title);
  }

  static List<LLGCredentialDocument> extractCredentials(
    Map<String, dynamic> data, {
    Map<String, dynamic>? verificationMap,
  }) {
    final list = <LLGCredentialDocument>[];

    DateTime? uploadDate;
    if (data['submittedAt'] is Timestamp) {
      uploadDate = (data['submittedAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is Timestamp) {
      uploadDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['appliedAt'] is Timestamp) {
      uploadDate = (data['appliedAt'] as Timestamp).toDate();
    }

    final configs = [
      {'key': 'qualification', 'title': 'Qualification Certificate', 'field': 'qualificationCertificateLink'},
      {'key': 'license', 'title': 'Medical / Clinical License', 'field': 'licenseCertificateLink'},
      {'key': 'experience', 'title': 'Experience Certificate', 'field': 'experienceCertificateLink'},
      {'key': 'identity', 'title': 'Identity Proof', 'field': 'identityProofLink'},
      {'key': 'professional', 'title': 'Professional Association Membership', 'field': 'professionalAssociationLink'},
    ];

    for (final c in configs) {
      final url = (data[c['field']] ?? '').toString().trim();
      String status = 'pending';
      String? reason;

      if (verificationMap != null && verificationMap.containsKey(c['key'])) {
        final v = verificationMap[c['key']];
        if (v is Map) {
          status = v['status'] ?? 'pending';
          reason = v['rejectionReason'];
        }
      } else if (data['isVerified'] == true) {
        status = 'verified';
      }

      list.add(LLGCredentialDocument(
        key: c['key']!,
        title: c['title']!,
        url: url,
        uploadDate: uploadDate,
        verificationStatus: url.isEmpty ? 'unsubmitted' : status,
        rejectionReason: reason,
      ));
    }

    // Support any generic certificateUrl / documentUrl field if present and not matching standard slots
    final genericUrl = (data['certificateUrl'] ?? data['documentUrl'] ?? data['credentialUrl'] ?? '').toString().trim();
    if (genericUrl.isNotEmpty && !list.any((d) => d.url == genericUrl)) {
      list.add(LLGCredentialDocument(
        key: 'general',
        title: 'General Credential Document',
        url: genericUrl,
        uploadDate: uploadDate,
        verificationStatus: data['isVerified'] == true ? 'verified' : (data['verificationStatus'] ?? 'pending'),
      ));
    }

    return list;
  }
}

/// Transactional Email Delivery Log
class AdminEmailLogModel {
  final String id;
  final String recipientUid;
  final String recipientEmail;
  final String recipientName;
  final String category; // 'warning', 'suspension', 'restoration', 'recovery_decision', 'llg_verified', 'llg_rejected', 'llg_assigned', 'llg_reassigned', 'deletion_notice'
  final String subject;
  final String bodySnippet;
  final String status; // 'queued', 'sent', 'delivered', 'failed'
  final DateTime timestamp;
  final String? providerMessageId;
  final String? errorMessage;
  final int retryCount;

  AdminEmailLogModel({
    required this.id,
    required this.recipientUid,
    required this.recipientEmail,
    required this.recipientName,
    required this.category,
    required this.subject,
    required this.bodySnippet,
    this.status = 'queued',
    required this.timestamp,
    this.providerMessageId,
    this.errorMessage,
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipientUid': recipientUid,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'category': category,
      'subject': subject,
      'bodySnippet': bodySnippet,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'providerMessageId': providerMessageId,
      'errorMessage': errorMessage,
      'retryCount': retryCount,
    };
  }

  factory AdminEmailLogModel.fromMap(String id, Map<String, dynamic> map) {
    return AdminEmailLogModel(
      id: id,
      recipientUid: map['recipientUid'] ?? '',
      recipientEmail: map['recipientEmail'] ?? '',
      recipientName: map['recipientName'] ?? 'User',
      category: map['category'] ?? 'notification',
      subject: map['subject'] ?? 'LittleLumin Notification',
      bodySnippet: map['bodySnippet'] ?? '',
      status: map['status'] ?? 'queued',
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      providerMessageId: map['providerMessageId'],
      errorMessage: map['errorMessage'],
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Administrative Report Model
enum AdminReportCategory {
  platformSummary,
  userManagement,
  llgVerification,
  parentLlgAssignment,
  activityPerformance,
  parentEngagement,
  aiUsage,
  accountEnforcement,
  adminAudit,
}

extension AdminReportCategoryExtension on AdminReportCategory {
  String get displayName {
    switch (this) {
      case AdminReportCategory.platformSummary:
        return '1. Platform Summary Report';
      case AdminReportCategory.userManagement:
        return '2. User Management Report';
      case AdminReportCategory.llgVerification:
        return '3. LLG Verification Report';
      case AdminReportCategory.parentLlgAssignment:
        return '4. Parent–LLG Assignment Report';
      case AdminReportCategory.activityPerformance:
        return '5. Activity Performance Report';
      case AdminReportCategory.parentEngagement:
        return '6. Parent Engagement Report';
      case AdminReportCategory.aiUsage:
        return '7. AI Usage Report';
      case AdminReportCategory.accountEnforcement:
        return '8. Account Enforcement Report';
      case AdminReportCategory.adminAudit:
        return '9. Administrative Audit Report';
    }
  }

  String get shortName {
    switch (this) {
      case AdminReportCategory.platformSummary:
        return 'Platform Summary';
      case AdminReportCategory.userManagement:
        return 'User Management';
      case AdminReportCategory.llgVerification:
        return 'LLG Verification';
      case AdminReportCategory.parentLlgAssignment:
        return 'Assignments';
      case AdminReportCategory.activityPerformance:
        return 'Activity Performance';
      case AdminReportCategory.parentEngagement:
        return 'Parent Engagement';
      case AdminReportCategory.aiUsage:
        return 'AI Usage';
      case AdminReportCategory.accountEnforcement:
        return 'Enforcement';
      case AdminReportCategory.adminAudit:
        return 'Audit Logs';
    }
  }
}

class AdminReportResult {
  final String id;
  final AdminReportCategory category;
  final String title;
  final DateTime generatedAt;
  final String generatedBy;
  final String dateRangeLabel;
  final Map<String, dynamic> summaryMetrics;
  final List<String> columnHeaders;
  final List<List<String>> dataRows;

  AdminReportResult({
    required this.id,
    required this.category,
    required this.title,
    required this.generatedAt,
    required this.generatedBy,
    required this.dateRangeLabel,
    required this.summaryMetrics,
    required this.columnHeaders,
    required this.dataRows,
  });

  int get recordsCount => dataRows.length;
  List<String> get headers => columnHeaders;
  List<List<String>> get rows => dataRows;

  String toCsv() {
    final buffer = StringBuffer();
    // Metadata Header
    buffer.writeln('"Report: $title"');
    buffer.writeln('"Category: ${category.displayName}"');
    buffer.writeln('"Generated At: ${generatedAt.toIso8601String()}"');
    buffer.writeln('"Generated By: $generatedBy"');
    buffer.writeln('"Period: $dateRangeLabel"');
    buffer.writeln('');

    // Summary Metrics
    buffer.writeln('"Summary Metrics"');
    summaryMetrics.forEach((k, v) {
      buffer.writeln('"$k","$v"');
    });
    buffer.writeln('');

    // Table
    buffer.writeln(columnHeaders.map((c) => '"$c"').join(','));
    for (final row in dataRows) {
      buffer.writeln(row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','));
    }

    return buffer.toString();
  }
}

/// System Health Diagnostic Status
class SystemHealthDiagnostic {
  final bool firebaseAuthOk;
  final bool firestoreOk;
  final bool backendApiOk;
  final bool aiServiceOk;
  final String authMessage;
  final String firestoreMessage;
  final String backendMessage;
  final String aiMessage;
  final DateTime checkedAt;
  final String appVersion;
  final int recentErrorCount;

  SystemHealthDiagnostic({
    required this.firebaseAuthOk,
    required this.firestoreOk,
    required this.backendApiOk,
    required this.aiServiceOk,
    required this.authMessage,
    required this.firestoreMessage,
    required this.backendMessage,
    required this.aiMessage,
    required this.checkedAt,
    this.appVersion = '2.4.0 (LittleLumin Enterprise)',
    this.recentErrorCount = 0,
  });

  bool get isAllHealthy => firebaseAuthOk && firestoreOk && backendApiOk && aiServiceOk;
  bool get isFullyHealthy => isAllHealthy;
}

// =========================================================================
// 8. LLG SUSPENSION & WARNING APPEAL MODEL
// =========================================================================

class LLGAppealModel {
  final String id;
  final String llgId;
  final String llgName;
  final String llgEmail;
  final String suspensionReason;
  final String appealText;
  final String supportingEvidence;
  final DateTime submittedAt;
  final String status; // 'pending', 'under_review', 'approved', 'rejected'
  final String? adminDecisionNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final List<String>? restorationConditions;

  LLGAppealModel({
    required this.id,
    required this.llgId,
    required this.llgName,
    required this.llgEmail,
    required this.suspensionReason,
    required this.appealText,
    this.supportingEvidence = '',
    required this.submittedAt,
    this.status = 'pending',
    this.adminDecisionNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.restorationConditions,
  });

  DateTime get createdAt => submittedAt;
  String? get adminNotes => adminDecisionNotes;
  List<String>? get conditionsForRestoration => restorationConditions;

  bool get isPending => status == 'pending' || status == 'under_review';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  Map<String, dynamic> toMap() {
    return {
      'llgId': llgId,
      'llgName': llgName,
      'llgEmail': llgEmail,
      'suspensionReason': suspensionReason,
      'appealText': appealText,
      'supportingEvidence': supportingEvidence,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'createdAt': Timestamp.fromDate(submittedAt),
      'status': status,
      'adminDecisionNotes': adminDecisionNotes,
      'adminNotes': adminDecisionNotes,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'restorationConditions': restorationConditions,
      'conditionsForRestoration': restorationConditions,
    };
  }

  factory LLGAppealModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<String>? parseConditions(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return [v];
      return null;
    }

    final rawDate = map['submittedAt'] ?? map['createdAt'];
    final rawNotes = map['adminDecisionNotes'] ?? map['adminNotes'];
    final rawConditions = map['restorationConditions'] ?? map['conditionsForRestoration'];

    return LLGAppealModel(
      id: id,
      llgId: map['llgId'] ?? '',
      llgName: map['llgName'] ?? 'LLG Specialist',
      llgEmail: map['llgEmail'] ?? '',
      suspensionReason: map['suspensionReason'] ?? 'Administrative policy review',
      appealText: map['appealText'] ?? '',
      supportingEvidence: map['supportingEvidence'] ?? '',
      submittedAt: parseDate(rawDate),
      status: map['status'] ?? 'pending',
      adminDecisionNotes: rawNotes,
      reviewedBy: map['reviewedBy'],
      reviewedAt: parseNullableDate(map['reviewedAt']),
      restorationConditions: parseConditions(rawConditions),
    );
  }
}

// =========================================================================
// 9. PARENT COMPLAINT MODEL
// =========================================================================

enum ParentComplaintCategory {
  unprofessionalConduct,
  missedSession,
  inappropriateFeedback,
  privacyConcern,
  billingCommunication,
  other;

  String get displayName {
    switch (this) {
      case ParentComplaintCategory.unprofessionalConduct:
        return 'Unprofessional Conduct';
      case ParentComplaintCategory.missedSession:
        return 'Missed Consultation / Late Response';
      case ParentComplaintCategory.inappropriateFeedback:
        return 'Inappropriate Developmental Feedback';
      case ParentComplaintCategory.privacyConcern:
        return 'Privacy or Data Sensitivity';
      case ParentComplaintCategory.billingCommunication:
        return 'Communication Disagreement';
      case ParentComplaintCategory.other:
        return 'General Grievance';
    }
  }

  String get value {
    switch (this) {
      case ParentComplaintCategory.unprofessionalConduct:
        return 'unprofessional_conduct';
      case ParentComplaintCategory.missedSession:
        return 'missed_session';
      case ParentComplaintCategory.inappropriateFeedback:
        return 'inappropriate_feedback';
      case ParentComplaintCategory.privacyConcern:
        return 'privacy_concern';
      case ParentComplaintCategory.billingCommunication:
        return 'billing_communication';
      case ParentComplaintCategory.other:
        return 'other';
    }
  }

  static ParentComplaintCategory fromString(String val) {
    switch (val) {
      case 'unprofessional_conduct':
      case 'unprofessionalConduct':
        return ParentComplaintCategory.unprofessionalConduct;
      case 'missed_session':
      case 'missedSession':
        return ParentComplaintCategory.missedSession;
      case 'inappropriate_feedback':
      case 'inappropriateFeedback':
        return ParentComplaintCategory.inappropriateFeedback;
      case 'privacy_concern':
      case 'privacyConcern':
        return ParentComplaintCategory.privacyConcern;
      case 'billing_communication':
      case 'billingCommunication':
        return ParentComplaintCategory.billingCommunication;
      default:
        return ParentComplaintCategory.other;
    }
  }
}

class ParentComplaintModel {
  final String id;
  final String parentId;
  final String parentName;
  final String parentEmail;
  final String llgId;
  final String llgName;
  final String? caseId;
  final String? childId;
  final String? childName;
  final String category; // 'unprofessional_conduct', 'missed_session', 'inappropriate_feedback', 'privacy_concern', 'billing_communication', 'other'
  final String description;
  final String supportingEvidence;
  final String status; // 'pending', 'under_investigation', 'resolved', 'dismissed'
  final String? adminNotes;
  final String? resolutionSummary;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  ParentComplaintModel({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.parentEmail,
    required this.llgId,
    required this.llgName,
    this.caseId,
    this.childId,
    this.childName,
    required this.category,
    required this.description,
    this.supportingEvidence = '',
    this.status = 'pending',
    this.adminNotes,
    this.resolutionSummary,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  String get specialistName => llgName;
  String? get investigationNotes => adminNotes;
  ParentComplaintCategory get categoryEnum => ParentComplaintCategory.fromString(category);

  bool get isPending => status == 'pending';
  bool get isUnderInvestigation => status == 'under_investigation';
  bool get isResolved => status == 'resolved';
  bool get isDismissed => status == 'dismissed';

  String get categoryDisplayName {
    switch (category) {
      case 'unprofessional_conduct':
        return 'Unprofessional Conduct';
      case 'missed_session':
        return 'Missed Consultation / Late Response';
      case 'inappropriate_feedback':
        return 'Inappropriate Developmental Feedback';
      case 'privacy_concern':
        return 'Privacy or Data Sensitivity';
      case 'billing_communication':
        return 'Communication Disagreement';
      default:
        return 'General Grievance';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'parentId': parentId,
      'parentName': parentName,
      'parentEmail': parentEmail,
      'llgId': llgId,
      'llgName': llgName,
      'caseId': caseId,
      'childId': childId,
      'childName': childName,
      'category': category,
      'description': description,
      'supportingEvidence': supportingEvidence,
      'status': status,
      'adminNotes': adminNotes,
      'resolutionSummary': resolutionSummary,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'resolvedBy': resolvedBy,
    };
  }

  factory ParentComplaintModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return ParentComplaintModel(
      id: id,
      parentId: map['parentId'] ?? '',
      parentName: map['parentName'] ?? 'Parent',
      parentEmail: map['parentEmail'] ?? '',
      llgId: map['llgId'] ?? map['specialistId'] ?? '',
      llgName: map['llgName'] ?? map['specialistName'] ?? 'LLG Specialist',
      caseId: map['caseId'],
      childId: map['childId'],
      childName: map['childName'],
      category: map['category'] ?? 'other',
      description: map['description'] ?? '',
      supportingEvidence: map['supportingEvidence'] ?? '',
      status: map['status'] ?? 'pending',
      adminNotes: map['adminNotes'] ?? map['investigationNotes'],
      resolutionSummary: map['resolutionSummary'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseNullableDate(map['updatedAt']),
      resolvedAt: parseNullableDate(map['resolvedAt']),
      resolvedBy: map['resolvedBy'],
    );
  }
}

// =========================================================================
// 10. SPECIALIST REVIEW & RATING MODEL
// =========================================================================

class SpecialistReviewModel {
  final String id;
  final String llgId;
  final String llgName;
  final String parentId;
  final String parentName;
  final String? caseId;
  final String? childId;
  final double rating; // 1.0 to 5.0
  final String reviewText;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isModerated;
  final String? moderationReason;
  final String? moderatedBy;
  final DateTime? moderatedAt;

  SpecialistReviewModel({
    required this.id,
    required this.llgId,
    required this.llgName,
    required this.parentId,
    required this.parentName,
    this.caseId,
    this.childId,
    required this.rating,
    this.reviewText = '',
    required this.createdAt,
    this.updatedAt,
    this.isModerated = false,
    this.moderationReason,
    this.moderatedBy,
    this.moderatedAt,
  });

  String get specialistName => llgName;
  bool get isPositive => rating >= 4.0;
  int get starCount => rating.round().clamp(1, 5);

  Map<String, dynamic> toMap() {
    return {
      'llgId': llgId,
      'llgName': llgName,
      'parentId': parentId,
      'parentName': parentName,
      'caseId': caseId,
      'childId': childId,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'isModerated': isModerated,
      'moderationReason': moderationReason,
      'moderatedBy': moderatedBy,
      'moderatedAt': moderatedAt != null ? Timestamp.fromDate(moderatedAt!) : null,
    };
  }

  factory SpecialistReviewModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    double parseRating(dynamic v) {
      if (v is num) return v.toDouble().clamp(1.0, 5.0);
      if (v is String) return (double.tryParse(v) ?? 5.0).clamp(1.0, 5.0);
      return 5.0;
    }

    return SpecialistReviewModel(
      id: id,
      llgId: map['llgId'] ?? '',
      llgName: map['llgName'] ?? 'LLG Specialist',
      parentId: map['parentId'] ?? '',
      parentName: map['parentName'] ?? 'Parent',
      caseId: map['caseId'],
      childId: map['childId'],
      rating: parseRating(map['rating']),
      reviewText: map['reviewText'] ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseNullableDate(map['updatedAt']),
      isModerated: map['isModerated'] == true,
      moderationReason: map['moderationReason'],
      moderatedBy: map['moderatedBy'],
      moderatedAt: parseNullableDate(map['moderatedAt']),
    );
  }
}
