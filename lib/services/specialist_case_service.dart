// lib/services/specialist_case_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/specialist_case_model.dart';
import 'audit_log_service.dart';

class SpecialistCaseService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  SpecialistCaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  static const String collection = 'specialistCases';
  static const String currentConsentNoticeVersion = 'v1.0-dpdp';

  /// Submit a formal, consent-backed specialist case request
  Future<String> createCaseRequest({
    required String parentId,
    required String parentName,
    required String childId,
    required String childName,
    required int childAgeYears,
    required String specialistId,
    required String specialistName,
    String specialistRole = 'specialist',
    required String purpose,
    required List<String> authorizedDataCategories,
    String? parentNotes,
    Duration consentValidity = const Duration(days: 90),
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Authentication required to submit specialist consultation request.');
    }
    if (currentUser.uid != parentId) {
      throw Exception('Parent ID mismatch: unauthorized operation.');
    }
    if (authorizedDataCategories.isEmpty) {
      throw Exception('At least one data category must be authorized.');
    }

    final now = DateTime.now();
    final expiresAt = now.add(consentValidity);

    final caseId = '${childId}_$specialistId';
    final caseDocRef = _firestore.collection(collection).doc(caseId);

    final caseModel = SpecialistCaseModel(
      caseId: caseId,
      parentId: parentId,
      parentName: parentName,
      childId: childId,
      childName: childName,
      childAgeYears: childAgeYears,
      specialistId: specialistId,
      specialistName: specialistName,
      specialistRole: specialistRole,
      purpose: purpose,
      authorizedDataCategories: authorizedDataCategories,
      consentNoticeVersion: currentConsentNoticeVersion,
      consentedAt: now,
      status: CaseStatus.pending,
      statusUpdatedAt: now,
      expiresAt: expiresAt,
      parentNotes: parentNotes,
      createdAt: now,
    );

    await caseDocRef.set(caseModel.toMap());

    // 1. Send targeted notification to the specialist
    try {
      await _firestore.collection('notifications').add({
        'userId': specialistId,
        'type': 'specialist_case_requested',
        'caseId': caseId,
        'childId': childId,
        'childName': childName,
        'parentId': parentId,
        'parentName': parentName,
        'title': 'New Case Request for $childName',
        'body': 'Parent $parentName requested consultation: $purpose',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Non-critical notification error: $e');
    }

    // 2. Write immutable audit record via trusted backend
    await AuditLogService.logEvent(
      action: 'specialist_case_consent_granted',
      caseId: caseId,
      childId: childId,
      targetId: specialistId,
      details: {
        'specialistId': specialistId,
        'consentNoticeVersion': currentConsentNoticeVersion,
        'authorizedDataCategories': authorizedDataCategories,
      },
    );

    return caseId;
  }

  /// Stream cases exclusively assigned to the signed-in specialist
  Stream<List<SpecialistCaseModel>> getSpecialistCasesStream({required String specialistId, CaseStatus? statusFilter}) {
    Query query = _firestore.collection(collection).where('specialistId', isEqualTo: specialistId);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return SpecialistCaseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Stream consultation requests submitted by the signed-in parent
  Stream<List<SpecialistCaseModel>> getParentCasesStream(String parentId, {String? childId}) {
    Query query = _firestore.collection(collection).where('parentId', isEqualTo: parentId);
    if (childId != null && childId.isNotEmpty) {
      query = query.where('childId', isEqualTo: childId);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return SpecialistCaseModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Specialist accepts a pending case
  Future<void> acceptCase(String caseId, {required String specialistId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != specialistId) {
      throw Exception('Unauthorized: only the assigned specialist can accept this case.');
    }

    final caseRef = _firestore.collection(collection).doc(caseId);
    final caseDoc = await caseRef.get();
    if (!caseDoc.exists) throw Exception('Case record not found.');

    final data = caseDoc.data()!;
    if (data['specialistId'] != specialistId) {
      throw Exception('Case is not assigned to this specialist.');
    }
    if (data['status'] == CaseStatus.revoked.name) {
      throw Exception('Cannot accept case: Parent has withdrawn consent.');
    }

    await caseRef.update({
      'status': CaseStatus.accepted.name,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify parent
    try {
      await _firestore.collection('notifications').add({
        'userId': data['parentId'],
        'type': 'specialist_case_accepted',
        'caseId': caseId,
        'childId': data['childId'],
        'specialistId': specialistId,
        'specialistName': data['specialistName'],
        'title': 'Case Accepted by ${data['specialistName']}',
        'body': 'Your specialist review request for ${data['childName']} has been accepted.',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // Authoritative backend audit log
    await AuditLogService.logEvent(
      action: 'specialist_case_accepted',
      caseId: caseId,
      childId: data['childId']?.toString(),
      targetId: data['parentId']?.toString(),
    );
  }

  /// Specialist declines a case
  Future<void> declineCase(String caseId, {required String specialistId, String? reason}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != specialistId) {
      throw Exception('Unauthorized: only the assigned specialist can decline this case.');
    }

    final caseRef = _firestore.collection(collection).doc(caseId);
    final caseDoc = await caseRef.get();
    if (!caseDoc.exists) throw Exception('Case record not found.');

    final data = caseDoc.data()!;
    if (data['specialistId'] != specialistId) {
      throw Exception('Case is not assigned to this specialist.');
    }

    await caseRef.update({
      'status': CaseStatus.declined.name,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'declinedAt': FieldValue.serverTimestamp(),
      'declineReason': reason ?? 'Specialist unavailable.',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify parent
    try {
      await _firestore.collection('notifications').add({
        'userId': data['parentId'],
        'type': 'specialist_case_declined',
        'caseId': caseId,
        'childId': data['childId'],
        'title': 'Case Update: Request Declined',
        'body': '${data['specialistName']} is currently unable to accept this case.',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Specialist completes / marks resolved a case
  Future<void> closeCase(String caseId, {required String specialistId, String? resolutionNotes}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != specialistId) {
      throw Exception('Unauthorized: only the assigned specialist can close this case.');
    }

    final caseRef = _firestore.collection(collection).doc(caseId);
    final caseDoc = await caseRef.get();
    if (!caseDoc.exists) throw Exception('Case record not found.');

    final data = caseDoc.data()!;
    if (data['specialistId'] != specialistId) {
      throw Exception('Case is not assigned to this specialist.');
    }

    await caseRef.update({
      'status': CaseStatus.completed.name,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'resolutionNotes': resolutionNotes,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Authoritative backend audit log
    await AuditLogService.logEvent(
      action: 'specialist_case_completed',
      caseId: caseId,
      childId: data['childId']?.toString(),
      details: {
        'resolutionNotes': resolutionNotes,
      },
    );
  }

  /// Parent revokes / withdraws consent for a case
  Future<void> revokeConsent(String caseId, String parentId, {String? reason}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != parentId) {
      throw Exception('Unauthorized: only the parent can revoke consent.');
    }

    final caseRef = _firestore.collection(collection).doc(caseId);
    final caseDoc = await caseRef.get();
    if (!caseDoc.exists) throw Exception('Case record not found.');

    final data = caseDoc.data()!;
    if (data['parentId'] != parentId) {
      throw Exception('Unauthorized: not the parent of this case.');
    }

    await caseRef.update({
      'status': CaseStatus.revoked.name,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'revokedAt': FieldValue.serverTimestamp(),
      'revocationReason': reason ?? 'Parent revoked consent.',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify specialist that access has been terminated
    try {
      await _firestore.collection('notifications').add({
        'userId': data['specialistId'],
        'type': 'specialist_consent_revoked',
        'caseId': caseId,
        'childId': data['childId'],
        'title': 'Consent Revoked for Case',
        'body': 'Parent has withdrawn consent for ${data['childName']}. Access to records has ended.',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // Authoritative backend audit log
    await AuditLogService.logEvent(
      action: 'specialist_case_consent_revoked',
      caseId: caseId,
      childId: data['childId']?.toString(),
      targetId: data['specialistId']?.toString(),
      details: {
        'reason': reason ?? 'Parent revoked consent.',
      },
    );
  }

  /// Verify whether a specialist is actively authorized to access a child's records
  Future<bool> verifySpecialistAccess(String specialistId, String childId) async {
    try {
      final snap = await _firestore
          .collection(collection)
          .where('specialistId', isEqualTo: specialistId)
          .where('childId', isEqualTo: childId)
          .where('status', whereIn: [CaseStatus.accepted.name, CaseStatus.active.name])
          .get();

      if (snap.docs.isEmpty) return false;

      // Check for unrevoked and valid unexpired consent
      final now = DateTime.now();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['revokedAt'] != null) continue;
        final rawExpiry = data['consentExpiresAt'] ?? data['expiresAt'];
        if (rawExpiry == null) continue; // Access denied if expiry is missing!
        if (rawExpiry is Timestamp) {
          if (now.isAfter(rawExpiry.toDate())) continue;
        } else if (rawExpiry is DateTime) {
          if (now.isAfter(rawExpiry)) continue;
        } else {
          continue; // Malformed expiry
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error verifying specialist access: $e');
      return false;
    }
  }
}
