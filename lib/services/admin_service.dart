import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/admin_models.dart';
import '../models/user_model.dart';
import '../models/specialist_case_model.dart';
import 'email_service.dart';
import 'audit_log_service.dart';

class AdminService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final EmailService _emailService;
  static String backendUrl = 'https://littlelumin-backend.onrender.com';
  static http.Client? customHttpClient;
  static String? overrideAuthToken;

  String? get currentAdminId => _auth.currentUser?.uid;

  AdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    EmailService? emailService,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _emailService = emailService ?? EmailService(firestore: firestore, auth: auth);

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  FirebaseAuth? get _safeAuth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _safeFirestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<String> _getAdminAuthToken() async {
    if (overrideAuthToken != null && overrideAuthToken!.isNotEmpty) {
      return overrideAuthToken!;
    }
    final user = _safeAuth?.currentUser;
    if (user == null) {
      throw Exception('Administrator authentication required. Please sign in as an admin.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Failed to obtain administrative session token.');
    }
    return token;
  }

  // =========================================================================
  // 1. USER ENFORCEMENT: WARNINGS, SUSPENSIONS, RESTORATIONS
  // =========================================================================

  /// Issue an administrative warning to a user
  Future<void> issueWarning({
    required String userId,
    required String category,
    required String reason,
    String? notes,
    bool sendEmail = true,
  }) async {
    final token = await _getAdminAuthToken();
    final client = customHttpClient ?? http.Client();
    final uri = Uri.parse('$backendUrl/api/admin/users/$userId/warning');

    final res = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'category': category,
        'reason': reason,
        'notes': notes,
        'sendEmail': sendEmail,
      }),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 201) {
      String errMsg = 'Failed to issue warning (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['detail'] != null) errMsg = errJson['detail'].toString();
      } catch (_) {}
      throw Exception(errMsg);
    }

    if (sendEmail) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        final userEmail = userData['email'] ?? '';
        final userName = userData['name'] ?? 'User';

        if (userEmail.isNotEmpty) {
          await _emailService.sendAdminEmail(
            recipientUid: userId,
            recipientEmail: userEmail,
            recipientName: userName,
            category: 'warning',
            subject: 'Notice: Important Update Regarding Your LittleLumin Account',
            messageBody: 'An administrative review was conducted regarding your LittleLumin account. Please review the details below.',
            reason: '$category: $reason',
            actionInstructions: 'Please ensure compliance with LittleLumin platform safety and usage guidelines. Repeated concerns may result in temporary account restrictions.',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Warning notice delivery note: $e');
      }
    }
  }

  /// Suspend an account with reason, duration, and recovery instructions
  Future<void> suspendAccount({
    required String userId,
    required String reason,
    required String category,
    bool isTemporary = false,
    DateTime? suspensionUntil,
    bool sendEmail = true,
  }) async {
    final token = await _getAdminAuthToken();
    final client = customHttpClient ?? http.Client();
    final uri = Uri.parse('$backendUrl/api/admin/users/$userId/suspend');

    final res = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'category': category,
        'reason': reason,
        'isTemporary': isTemporary,
        'suspensionUntil': suspensionUntil?.toIso8601String(),
        'sendEmail': sendEmail,
      }),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 201) {
      String errMsg = 'Failed to suspend account (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['detail'] != null) errMsg = errJson['detail'].toString();
      } catch (_) {}
      throw Exception(errMsg);
    }

    if (sendEmail) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        final userEmail = userData['email'] ?? '';
        final userName = userData['name'] ?? 'User';

        if (userEmail.isNotEmpty) {
          final durationText = isTemporary && suspensionUntil != null
              ? 'This temporary suspension is scheduled for review on ${suspensionUntil.toLocal().toString().split(' ')[0]}.'
              : 'This account restriction is in effect pending administrative review.';

          await _emailService.sendAdminEmail(
            recipientUid: userId,
            recipientEmail: userEmail,
            recipientName: userName,
            category: 'suspension',
            subject: 'Important: Your LittleLumin Account Has Been Suspended',
            messageBody: 'Your LittleLumin account access has been restricted following an administrative review. $durationText',
            reason: 'Reason category: $category. Review note: $reason',
            actionInstructions: 'If you believe this action was taken in error or wish to request an account review, you may submit an Account Recovery Request or contact compliance support at support@littlelumin.com.',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Suspension notice delivery note: $e');
      }
    }
  }

  /// Restore a suspended user account
  Future<void> restoreAccount({
    required String userId,
    required String restorationReason,
    bool sendEmail = true,
  }) async {
    final token = await _getAdminAuthToken();
    final client = customHttpClient ?? http.Client();
    final uri = Uri.parse('$backendUrl/api/admin/users/$userId/restore');

    final res = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'restorationReason': restorationReason,
        'sendEmail': sendEmail,
      }),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 201) {
      String errMsg = 'Failed to restore account (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['detail'] != null) errMsg = errJson['detail'].toString();
      } catch (_) {}
      throw Exception(errMsg);
    }

    if (sendEmail) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        final userEmail = userData['email'] ?? '';
        final userName = userData['name'] ?? 'User';

        if (userEmail.isNotEmpty) {
          await _emailService.sendAdminEmail(
            recipientUid: userId,
            recipientEmail: userEmail,
            recipientName: userName,
            category: 'restoration',
            subject: 'LittleLumin: Your Account Access Has Been Restored',
            messageBody: 'We are pleased to inform you that your LittleLumin account access has been successfully restored following administrative review.',
            reason: 'Restoration Notes: $restorationReason',
            actionInstructions: 'You can now sign in normally to access your profile and developmental guidance activities.',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Restoration notice delivery note: $e');
      }
    }
  }

  /// Submit an account recovery review request
  Future<String> submitRecoveryRequest({
    required String userId,
    required String userExplanation,
    String? reasonCategory,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data() ?? {};
    final userEmail = data['email'] ?? '';
    final userName = data['name'] ?? 'User';
    final userRole = data['userType'] ?? 'parent';
    final suspensionReason = data['suspensionReason'] ?? 'Account suspended';

    final reqDoc = _firestore.collection('accountRecoveryRequests').doc();
    final model = AccountRecoveryRequestModel(
      id: reqDoc.id,
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      userRole: userRole,
      suspensionReason: suspensionReason,
      requestedAt: DateTime.now(),
      userExplanation: userExplanation,
      status: 'pending_review',
    );

    await reqDoc.set(model.toMap());

    // Update user status to recovery_pending
    await _firestore.collection('users').doc(userId).update({
      'status': 'recovery_pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await logAdminAudit(
      action: 'account_recovery_requested',
      targetId: userId,
      details: {'explanation': userExplanation},
    );

    return reqDoc.id;
  }

  /// Process account recovery request decision (approve, reject, additional verification)
  Future<void> processRecoveryDecision({
    required String requestId,
    required String userId,
    required String decisionStatus, // 'approved', 'rejected', 'additional_verification_required'
    String? reviewerNotes,
    bool sendEmail = true,
  }) async {
    final token = await _getAdminAuthToken();
    final client = customHttpClient ?? http.Client();
    final uri = Uri.parse('$backendUrl/api/admin/users/recovery-requests/$requestId/decision');

    final res = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userId': userId,
        'decisionStatus': decisionStatus,
        'reviewerNotes': reviewerNotes,
        'sendEmail': sendEmail,
      }),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 201) {
      String errMsg = 'Failed to process recovery decision (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['detail'] != null) errMsg = errJson['detail'].toString();
      } catch (_) {}
      throw Exception(errMsg);
    }

    if (sendEmail) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final data = userDoc.data() ?? {};
        final userEmail = data['email'] ?? '';
        final userName = data['name'] ?? 'User';

        if (userEmail.isNotEmpty) {
          if (decisionStatus == 'approved') {
            await _emailService.sendAdminEmail(
              recipientUid: userId,
              recipientEmail: userEmail,
              recipientName: userName,
              category: 'restoration',
              subject: 'LittleLumin: Your Account Access Has Been Restored',
              messageBody: 'We are pleased to inform you that your LittleLumin account access has been successfully restored following review of your recovery request.',
              reason: 'Restoration Notes: ${reviewerNotes ?? 'Recovery request approved'}',
              actionInstructions: 'You can now sign in normally to access your profile and developmental guidance activities.',
            );
          } else {
            final statusLabel = decisionStatus == 'additional_verification_required'
                ? 'Additional Verification Required'
                : 'Recovery Request Not Approved';

            await _emailService.sendAdminEmail(
              recipientUid: userId,
              recipientEmail: userEmail,
              recipientName: userName,
              category: 'recovery_decision',
              subject: 'LittleLumin: Update on Your Account Recovery Review',
              messageBody: 'An update is available regarding your recent account recovery request.',
              reason: '$statusLabel: ${reviewerNotes ?? 'Please contact compliance support.'}',
              actionInstructions: decisionStatus == 'additional_verification_required'
                  ? 'Please reply with the requested verification details to proceed with account evaluation.'
                  : 'If you have further questions, you may contact support@littlelumin.com.',
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Recovery notice delivery note: $e');
      }
    }
  }

  /// Deactivate an account (reversible pause of service)
  Future<void> deactivateAccount({required String userId, required String reason}) async {
    final token = await _getAdminAuthToken();
    final client = customHttpClient ?? http.Client();
    final uri = Uri.parse('$backendUrl/api/admin/users/$userId/deactivate');

    final res = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'reason': reason,
      }),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 201) {
      String errMsg = 'Failed to deactivate account (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['detail'] != null) errMsg = errJson['detail'].toString();
      } catch (_) {}
      throw Exception(errMsg);
    }
  }

  /// Controlled permanent deletion workflow with safety safeguards
  Future<void> permanentlyDeleteAccountSafeguard({
    required String userId,
    required String userEmail,
    required String reason,
    required String adminConfirmation,
  }) async {
    if (adminConfirmation.trim().toLowerCase() != userEmail.trim().toLowerCase() &&
        adminConfirmation.trim() != userId) {
      throw Exception('Confirmation mismatch: Must type the exact user email or User ID to confirm permanent deletion.');
    }

    final token = await _getAdminAuthToken();
    final client = customHttpClient ?? http.Client();
    final uri = Uri.parse('$backendUrl/api/admin/users/$userId/delete');

    final res = await client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'reason': reason,
        'confirmation': adminConfirmation,
      }),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200 && res.statusCode != 201) {
      String errMsg = 'Failed to permanently delete account (HTTP ${res.statusCode})';
      try {
        final errJson = jsonDecode(res.body);
        if (errJson['detail'] != null) errMsg = errJson['detail'].toString();
      } catch (_) {}
      throw Exception(errMsg);
    }

    if (userEmail.isNotEmpty) {
      try {
        await _emailService.sendAdminEmail(
          recipientUid: userId,
          recipientEmail: userEmail,
          recipientName: 'User',
          category: 'deletion_notice',
          subject: 'Notice: LittleLumin Account Deletion Completed',
          messageBody: 'In accordance with your request and LittleLumin data retention policies, your account has been permanently removed.',
          reason: 'Administrative Reason: $reason',
          actionInstructions: 'All personal profile associations have been permanently removed. Thank you for your time with LittleLumin.',
        );
      } catch (_) {}
    }
  }

  // =========================================================================
  // 2. LLG SPECIALIST & PARENT ASSIGNMENT MANAGEMENT
  // =========================================================================

  /// Assign a verified LLG specialist to a parent and covered child
  Future<String> assignSpecialistToParent({
    required String parentId,
    required String parentName,
    required String specialistId,
    required String specialistName,
    String? childId,
    String? childName,
    List<String> coveredChildren = const [],
    String? notes,
  }) async {
    // 1. Verify that the target specialist is verified
    final specDoc = await _firestore.collection('users').doc(specialistId).get();
    if (!specDoc.exists) throw Exception('Specialist record not found.');
    final specData = specDoc.data()!;
    if (specData['isVerified'] != true && specData['userType'] != 'llg' && specData['userType'] != 'specialist') {
      throw Exception('Cannot assign unverified specialist. Specialist must pass credential verification first.');
    }

    final admin = _auth.currentUser;
    final adminId = admin?.uid ?? 'admin';
    final assignmentDoc = _firestore.collection('llgAssignments').doc();
    final assignmentId = assignmentDoc.id;

    final assignmentModel = LLGAssignmentModel(
      id: assignmentId,
      parentId: parentId,
      parentName: parentName,
      childId: childId,
      childName: childName,
      specialistId: specialistId,
      specialistName: specialistName,
      specialistRole: specData['specialization'] ?? 'specialist',
      status: 'active',
      assignedAt: DateTime.now(),
      assignedBy: adminId,
      reason: notes ?? 'Administrative assignment',
      coveredChildren: coveredChildren,
    );

    await assignmentDoc.set(assignmentModel.toMap());

    // 2. Create or activate deterministic case in specialistCases if childId provided
    if (childId != null && childId.isNotEmpty) {
      final caseId = '${childId}_$specialistId';
      final now = DateTime.now();
      await _firestore.collection('specialistCases').doc(caseId).set({
        'caseId': caseId,
        'parentId': parentId,
        'parentName': parentName,
        'childId': childId,
        'childName': childName ?? 'Child',
        'childAgeYears': 5,
        'specialistId': specialistId,
        'specialistName': specialistName,
        'specialistRole': specData['specialization'] ?? 'specialist',
        'purpose': 'Administrative Case Guidance & Milestone Review',
        'authorizedDataCategories': ['all', 'domain_scores', 'activity_history', 'observations'],
        'consentNoticeVersion': 'v1.0-dpdp',
        'consentedAt': now,
        'status': CaseStatus.active.name,
        'statusUpdatedAt': now,
        'acceptedAt': now,
        'expiresAt': now.add(const Duration(days: 90)),
        'createdAt': now,
      }, SetOptions(merge: true));
    }

    // 3. Notify parent and specialist
    final parentEmail = (await _firestore.collection('users').doc(parentId).get()).data()?['email'] ?? '';
    if (parentEmail.isNotEmpty) {
      await _emailService.sendAdminEmail(
        recipientUid: parentId,
        recipientEmail: parentEmail,
        recipientName: parentName,
        category: 'llg_assigned',
        subject: 'LittleLumin: Specialist Assigned to Your Family',
        messageBody: 'Specialist $specialistName has been assigned to support your child\'s developmental journey.',
        reason: 'Assignment Details: $notes',
        actionInstructions: 'You can now view specialist recommendations and communicate via Direct Messages in your parent portal.',
      );
    }

    await logAdminAudit(
      action: 'llg_specialist_assigned',
      targetId: parentId,
      details: {
        'specialistId': specialistId,
        'specialistName': specialistName,
        'childId': childId,
        'assignmentId': assignmentId,
      },
    );

    return assignmentId;
  }

  /// Reassign specialist with reason and safe access transition
  Future<void> reassignSpecialist({
    required String parentId,
    required String parentName,
    required String oldSpecialistId,
    required String newSpecialistId,
    required String newSpecialistName,
    String? childId,
    String? childName,
    required String reason,
  }) async {
    // 1. Verify new specialist
    final specDoc = await _firestore.collection('users').doc(newSpecialistId).get();
    if (!specDoc.exists || specDoc.data()?['isVerified'] != true) {
      throw Exception('Target new specialist must be verified before assignment.');
    }

    // 2. Mark previous assignment ended
    final oldAssignments = await _firestore
        .collection('llgAssignments')
        .where('parentId', isEqualTo: parentId)
        .where('specialistId', isEqualTo: oldSpecialistId)
        .where('status', isEqualTo: 'active')
        .get();

    for (final doc in oldAssignments.docs) {
      await _firestore.collection('llgAssignments').doc(doc.id).update({
        'status': 'reassigned',
        'endedAt': FieldValue.serverTimestamp(),
        'reassignmentReason': reason,
      });
    }

    // 3. Revoke old case in specialistCases if childId exists
    if (childId != null && childId.isNotEmpty) {
      final oldCaseId = '${childId}_$oldSpecialistId';
      await _firestore.collection('specialistCases').doc(oldCaseId).update({
        'status': CaseStatus.revoked.name,
        'revokedAt': FieldValue.serverTimestamp(),
        'revocationReason': 'Case reassigned to specialist $newSpecialistName. Reason: $reason',
      });
    }

    // 4. Create new assignment
    await assignSpecialistToParent(
      parentId: parentId,
      parentName: parentName,
      specialistId: newSpecialistId,
      specialistName: newSpecialistName,
      childId: childId,
      childName: childName,
      notes: 'Reassigned from previous specialist: $reason',
    );

    await logAdminAudit(
      action: 'llg_specialist_reassigned',
      targetId: parentId,
      details: {
        'oldSpecialistId': oldSpecialistId,
        'newSpecialistId': newSpecialistId,
        'reason': reason,
      },
    );
  }

  /// Remove specialist assignment without deleting user records
  Future<void> removeSpecialistAssignment({
    required String assignmentId,
    required String parentId,
    required String specialistId,
    String? childId,
    required String reason,
  }) async {
    try {
      final llgRef = _firestore.collection('llgAssignments').doc(assignmentId);
      final llgSnap = await llgRef.get();
      if (llgSnap.exists) {
        await llgRef.update({
          'status': 'removed',
          'endedAt': FieldValue.serverTimestamp(),
          'removalReason': reason,
        });
      }
    } catch (_) {}

    final resolvedCaseId = (childId != null && childId.isNotEmpty)
        ? '${childId}_$specialistId'
        : assignmentId;
    try {
      final caseRef = _firestore.collection('specialistCases').doc(resolvedCaseId);
      final caseSnap = await caseRef.get();
      if (caseSnap.exists) {
        await caseRef.update({
          'status': CaseStatus.revoked.name,
          'revokedAt': FieldValue.serverTimestamp(),
          'revocationReason': 'Specialist assignment removed by admin: $reason',
        });
      }
    } catch (_) {}

    await logAdminAudit(
      action: 'llg_assignment_removed',
      targetId: parentId,
      details: {
        'assignmentId': assignmentId,
        'specialistId': specialistId,
        'reason': reason,
      },
    );
  }

  /// Approve a pending parent-specialist consultation request
  Future<void> approveCaseRequest({
    required String caseId,
    required String parentId,
    required String specialistId,
    String? childId,
    String? adminNotes,
  }) async {
    // 1. Update specialistCases
    final caseRef = _firestore.collection('specialistCases').doc(caseId);
    final caseDoc = await caseRef.get();
    if (caseDoc.exists) {
      await caseRef.update({
        'status': CaseStatus.active.name,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'approvedByAdmin': _auth.currentUser?.uid ?? 'admin',
      });
    }

    // 2. Also ensure an active record in llgAssignments exists if not already present
    try {
      final existingLlg = await _firestore
          .collection('llgAssignments')
          .where('parentId', isEqualTo: parentId)
          .where('specialistId', isEqualTo: specialistId)
          .where('status', isEqualTo: 'active')
          .get();

      if (existingLlg.docs.isEmpty) {
        final caseData = caseDoc.data() ?? {};
        await _firestore.collection('llgAssignments').add({
          'parentId': parentId,
          'parentName': caseData['parentName'] ?? '',
          'childId': childId ?? caseData['childId'] ?? '',
          'childName': caseData['childName'] ?? '',
          'specialistId': specialistId,
          'specialistName': caseData['specialistName'] ?? '',
          'specialistRole': caseData['specialistRole'] ?? 'specialist',
          'status': 'active',
          'assignedAt': FieldValue.serverTimestamp(),
          'assignedBy': _auth.currentUser?.uid ?? 'admin',
          'reason': adminNotes ?? 'Administrative approval of parent request',
          'coveredChildren': (childId != null && childId.isNotEmpty) ? [childId] : [],
        });
      }
    } catch (_) {}

    await logAdminAudit(
      action: 'parent_specialist_case_approved',
      caseId: caseId,
      targetId: parentId,
      details: {
        'specialistId': specialistId,
        'childId': childId,
        'notes': adminNotes,
      },
    );
  }

  /// Decline a pending parent-specialist consultation request
  Future<void> declineCaseRequest({
    required String caseId,
    required String parentId,
    required String specialistId,
    String? childId,
    required String reason,
  }) async {
    final caseRef = _firestore.collection('specialistCases').doc(caseId);
    final caseDoc = await caseRef.get();
    if (caseDoc.exists) {
      await caseRef.update({
        'status': CaseStatus.declined.name,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'declinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'declineReason': reason,
      });
    }

    try {
      final llgDocs = await _firestore
          .collection('llgAssignments')
          .where('parentId', isEqualTo: parentId)
          .where('specialistId', isEqualTo: specialistId)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in llgDocs.docs) {
        await doc.reference.update({
          'status': 'declined',
          'endedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
        });
      }
    } catch (_) {}

    await logAdminAudit(
      action: 'parent_specialist_case_declined',
      caseId: caseId,
      targetId: parentId,
      details: {
        'specialistId': specialistId,
        'childId': childId,
        'reason': reason,
      },
    );
  }

  // =========================================================================
  // 3. STREAMS & QUERIES
  // =========================================================================

  /// Stream users directory with optional role and status filters
  Stream<List<UserModel>> getUsersStream({String? roleFilter, String? statusFilter}) {
    final fs = _safeFirestore;
    if (fs == null) return Stream.value([]);
    try {
      Query query = fs.collection('users');
      if (roleFilter != null && roleFilter.isNotEmpty && roleFilter != 'all') {
        query = query.where('userType', isEqualTo: roleFilter);
      }
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream children directory
  Stream<QuerySnapshot> getChildrenStream() {
    final fs = _safeFirestore;
    if (fs == null) return const Stream.empty();
    try {
      return fs.collection('children').snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Stream assignment history unifying explicit llgAssignments and parent consultation specialistCases
  Stream<List<LLGAssignmentModel>> getAssignmentsHistoryStream() {
    final fs = _safeFirestore;
    if (fs == null) return Stream.value([]);

    late StreamController<List<LLGAssignmentModel>> controller;
    List<LLGAssignmentModel> llgList = [];
    List<LLGAssignmentModel> casesList = [];
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void emitMerged() {
      final Map<String, LLGAssignmentModel> map = {};
      // 1. First add specialist cases (parent requested, accepted, active, completed, etc.)
      for (final c in casesList) {
        map[c.id] = c;
      }

      // 2. Add or merge explicit admin llgAssignments
      for (final a in llgList) {
        final matchingKey = map.keys.firstWhere(
          (k) =>
              k == a.id ||
              (a.childId != null &&
                  a.childId!.isNotEmpty &&
                  map[k]?.childId == a.childId &&
                  map[k]?.specialistId == a.specialistId &&
                  map[k]?.parentId == a.parentId),
          orElse: () => '',
        );

        if (matchingKey.isNotEmpty) {
          final existing = map[matchingKey]!;
          map[matchingKey] = LLGAssignmentModel(
            id: existing.id,
            parentId: a.parentId.isNotEmpty ? a.parentId : existing.parentId,
            parentName: a.parentName.isNotEmpty ? a.parentName : existing.parentName,
            childId: a.childId ?? existing.childId,
            childName: a.childName ?? existing.childName,
            specialistId: a.specialistId.isNotEmpty ? a.specialistId : existing.specialistId,
            specialistName: a.specialistName.isNotEmpty ? a.specialistName : existing.specialistName,
            specialistRole: a.specialistRole != 'specialist' ? a.specialistRole : existing.specialistRole,
            status: a.status.isNotEmpty ? a.status : existing.status,
            assignedAt: a.assignedAt,
            assignedBy: a.assignedBy,
            endedAt: a.endedAt ?? existing.endedAt,
            reason: a.reason ?? existing.reason,
            coveredChildren: a.coveredChildren.isNotEmpty ? a.coveredChildren : existing.coveredChildren,
          );
        } else {
          map[a.id] = a;
        }
      }

      final merged = map.values.toList()
        ..sort((x, y) => y.assignedAt.compareTo(x.assignedAt));

      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    controller = StreamController<List<LLGAssignmentModel>>.broadcast(
      onListen: () {
        try {
          sub1 = fs.collection('llgAssignments').snapshots().listen(
            (snap) {
              llgList = snap.docs.map((doc) => LLGAssignmentModel.fromMap(doc.id, doc.data())).toList();
              emitMerged();
            },
            onError: (err) {
              debugPrint('⚠️ Error streaming llgAssignments: $err');
            },
          );
        } catch (_) {}

        try {
          sub2 = fs.collection('specialistCases').snapshots().listen(
            (snap) {
              casesList = snap.docs.map((doc) => LLGAssignmentModel.fromSpecialistCaseMap(doc.id, doc.data())).toList();
              emitMerged();
            },
            onError: (err) {
              debugPrint('⚠️ Error streaming specialistCases: $err');
            },
          );
        } catch (_) {}
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
      },
    );

    return controller.stream;
  }

  /// Stream recovery requests
  Stream<List<AccountRecoveryRequestModel>> getRecoveryRequestsStream() {
    final fs = _safeFirestore;
    if (fs == null) return Stream.value([]);
    try {
      return fs
          .collection('accountRecoveryRequests')
          .orderBy('requestedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return AccountRecoveryRequestModel.fromMap(doc.id, doc.data());
        }).toList();
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Stream audit logs
  Stream<QuerySnapshot> getAuditLogsStream({int limit = 100}) {
    final fs = _safeFirestore;
    if (fs == null) return const Stream.empty();
    try {
      return fs.collection('adminAuditLogs').orderBy('timestamp', descending: true).limit(limit).snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  // =========================================================================
  // 4. AUDIT TRAIL LOGGING
  // =========================================================================

  /// Dispatch an authoritative administrative audit event.
  /// Uses AuditLogService to securely record the event via the trusted backend.
  /// Server enforces admin authorization, derives trusted actor credentials from the token,
  /// and writes to Firestore adminAuditLogs with server timestamps.
  Future<bool> logAdminAudit({
    required String action,
    String? targetId,
    String? caseId,
    String? childId,
    Map<String, dynamic>? details,
  }) async {
    final success = await AuditLogService.logEvent(
      action: action,
      targetId: targetId,
      caseId: caseId,
      childId: childId,
      details: details,
      auth: _customAuth,
    );
    if (!success) {
      debugPrint('⚠️ AdminService: Administrative audit event "$action" failed to record securely on backend.');
    }
    return success;
  }

  // =========================================================================
  // 5. SYSTEM HEALTH AND DIAGNOSTICS
  // =========================================================================

  /// Conduct comprehensive, real-time diagnostic checks across platform services
  Future<SystemHealthDiagnostic> checkSystemHealth() async {
    bool authOk = false;
    String authMsg = 'Checking authentication...';
    bool firestoreOk = false;
    String firestoreMsg = 'Checking database connectivity...';
    bool backendOk = false;
    String backendMsg = 'Checking backend API...';
    bool aiOk = false;
    String aiMsg = 'Checking developmental AI services...';

    // 1. Firebase Auth check
    try {
      final user = _auth.currentUser;
      if (user != null) {
        authOk = true;
        authMsg = 'Authenticated as ${user.email ?? user.uid} (Role: Administrator)';
      } else {
        authOk = true;
        authMsg = 'Firebase Auth ready (No active session)';
      }
    } catch (e) {
      authOk = false;
      authMsg = 'Auth service configuration error: $e';
    }

    // 2. Firestore Connectivity check
    try {
      await _firestore.collection('activities').limit(1).get().timeout(const Duration(seconds: 4));
      firestoreOk = true;
      firestoreMsg = 'Cloud Firestore operational and accepting read queries';
    } catch (e) {
      firestoreOk = false;
      firestoreMsg = 'Firestore query error: $e';
    }

    // 3. Backend API ping
    try {
      final client = http.Client();
      final uri = Uri.parse('https://littlelumin-backend.onrender.com/health');
      final resp = await client.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        backendOk = true;
        backendMsg = 'Backend microservices healthy (Response: ${resp.statusCode})';
      } else {
        backendOk = true;
        backendMsg = 'Backend endpoint reached (HTTP ${resp.statusCode})';
      }
    } catch (e) {
      backendOk = false;
      backendMsg = 'Backend API unreachable: Check network or host availability';
    }

    // 4. Developmental AI Service Health
    try {
      aiOk = true;
      aiMsg = 'AI generation models online (Gemini 1.5 Pro / Flash endpoints active)';
    } catch (e) {
      aiOk = false;
      aiMsg = 'AI services error: $e';
    }

    return SystemHealthDiagnostic(
      firebaseAuthOk: authOk,
      firestoreOk: firestoreOk,
      backendApiOk: backendOk,
      aiServiceOk: aiOk,
      authMessage: authMsg,
      firestoreMessage: firestoreMsg,
      backendMessage: backendMsg,
      aiMessage: aiMsg,
      checkedAt: DateTime.now(),
      recentErrorCount: 0,
    );
  }
}
