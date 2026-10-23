// lib/models/contact_consent_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum ContactConsentStatus {
  pending,
  approved,
  declined,
  revoked,
}

enum ContactItemType {
  phone,
  email,
  whatsapp,
  all,
}

class ContactConsentModel {
  final String id;
  final String caseId;
  final String childId;
  final String requesterId;
  final String requesterName;
  final String requesterRole; // 'parent', 'llg'
  final String recipientId;
  final String recipientName;
  final String recipientRole;
  final ContactItemType requestedItem;
  final String purpose; // Reason for request
  final ContactConsentStatus status;
  final String? sharedContactValue; // Revealed ONLY after approval
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final DateTime? revokedAt;
  final String? declineOrRevokeReason;

  const ContactConsentModel({
    required this.id,
    required this.caseId,
    required this.childId,
    required this.requesterId,
    required this.requesterName,
    required this.requesterRole,
    required this.recipientId,
    required this.recipientName,
    required this.recipientRole,
    required this.requestedItem,
    required this.purpose,
    this.status = ContactConsentStatus.pending,
    this.sharedContactValue,
    required this.requestedAt,
    this.respondedAt,
    this.revokedAt,
    this.declineOrRevokeReason,
  });

  bool get isApproved => status == ContactConsentStatus.approved && revokedAt == null;

  /// Returns the contact value ONLY if consent is actively approved and not revoked
  String? get permittedContactValue => isApproved ? sharedContactValue : null;

  /// Returns whether consent has been approved for a given contact category
  bool hasValidConsentFor(String item) {
    if (!isApproved) return false;
    if (requestedItem == ContactItemType.all) return true;
    final normalized = item.toLowerCase().trim();
    if (normalized == 'phone') {
      return requestedItem == ContactItemType.phone || requestedItem == ContactItemType.whatsapp;
    }
    return requestedItem.name == normalized;
  }

  bool get isPending => status == ContactConsentStatus.pending;
  bool get isRevoked => status == ContactConsentStatus.revoked || revokedAt != null;
  bool get isDeclined => status == ContactConsentStatus.declined;

  /// Convenience getter for shared phone number
  String? get sharedPhoneNumber {
    if (hasValidConsentFor('phone') || hasValidConsentFor('whatsapp')) {
      return permittedContactValue;
    }
    return null;
  }

  /// Convenience getter for shared email
  String? get sharedEmail {
    if (hasValidConsentFor('email')) {
      return permittedContactValue;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'childId': childId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterRole': requesterRole,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'requestedItem': requestedItem.name,
      'purpose': purpose,
      'status': status.name,
      'sharedContactValue': sharedContactValue,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'revokedAt': revokedAt != null ? Timestamp.fromDate(revokedAt!) : null,
      'declineOrRevokeReason': declineOrRevokeReason,
    };
  }

  factory ContactConsentModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    ContactConsentStatus parseStatus(dynamic val) {
      if (val == null) return ContactConsentStatus.pending;
      final str = val.toString().toLowerCase().trim();
      return ContactConsentStatus.values.firstWhere(
        (e) => e.name == str,
        orElse: () => ContactConsentStatus.pending,
      );
    }

    ContactItemType parseItem(dynamic val) {
      if (val == null) return ContactItemType.phone;
      final str = val.toString().toLowerCase().trim();
      return ContactItemType.values.firstWhere(
        (e) => e.name == str,
        orElse: () => ContactItemType.phone,
      );
    }

    return ContactConsentModel(
      id: docId,
      caseId: map['caseId'] ?? '',
      childId: map['childId'] ?? '',
      requesterId: map['requesterId'] ?? '',
      requesterName: map['requesterName'] ?? 'User',
      requesterRole: map['requesterRole'] ?? 'parent',
      recipientId: map['recipientId'] ?? '',
      recipientName: map['recipientName'] ?? 'User',
      recipientRole: map['recipientRole'] ?? 'llg',
      requestedItem: parseItem(map['requestedItem']),
      purpose: map['purpose'] ?? 'Direct consultation follow-up',
      status: parseStatus(map['status']),
      sharedContactValue: map['sharedContactValue'],
      requestedAt: parseDate(map['requestedAt']),
      respondedAt: map['respondedAt'] != null ? parseDate(map['respondedAt']) : null,
      revokedAt: map['revokedAt'] != null ? parseDate(map['revokedAt']) : null,
      declineOrRevokeReason: map['declineOrRevokeReason'],
    );
  }

  ContactConsentModel copyWith({
    String? id,
    String? caseId,
    String? childId,
    String? requesterId,
    String? requesterName,
    String? requesterRole,
    String? recipientId,
    String? recipientName,
    String? recipientRole,
    ContactItemType? requestedItem,
    String? purpose,
    ContactConsentStatus? status,
    String? sharedContactValue,
    bool clearSharedContactValue = false,
    DateTime? requestedAt,
    DateTime? respondedAt,
    DateTime? revokedAt,
    String? declineOrRevokeReason,
  }) {
    return ContactConsentModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      childId: childId ?? this.childId,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterRole: requesterRole ?? this.requesterRole,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      recipientRole: recipientRole ?? this.recipientRole,
      requestedItem: requestedItem ?? this.requestedItem,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      sharedContactValue: clearSharedContactValue ? null : (sharedContactValue ?? this.sharedContactValue),
      requestedAt: requestedAt ?? this.requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      declineOrRevokeReason: declineOrRevokeReason ?? this.declineOrRevokeReason,
    );
  }
}
