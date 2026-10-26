import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlelumin/models/admin_models.dart';
import 'package:littlelumin/models/user_model.dart';
import 'package:littlelumin/services/audit_log_service.dart';
import 'package:littlelumin/services/admin_service.dart';
import 'package:littlelumin/services/email_service.dart';

void main() {
  group('1. Account Status Lifecycle & Helpers Tests', () {
    test('AccountStatus correctly converts to and from string representations', () {
      expect(AccountStatusExtension.fromString('active'), AccountStatus.active);
      expect(AccountStatusExtension.fromString('warning_issued'), AccountStatus.warningIssued);
      expect(AccountStatusExtension.fromString('warned'), AccountStatus.warningIssued);
      expect(AccountStatusExtension.fromString('suspended'), AccountStatus.suspended);
      expect(AccountStatusExtension.fromString('recovery_pending'), AccountStatus.recoveryPending);
      expect(AccountStatusExtension.fromString('deactivated'), AccountStatus.deactivated);
      expect(AccountStatusExtension.fromString('inactive'), AccountStatus.deactivated);
      expect(AccountStatusExtension.fromString('deletion_pending'), AccountStatus.deletionPending);
      expect(AccountStatusExtension.fromString('unknown_status'), AccountStatus.active);

      expect(AccountStatus.active.displayName, 'Active');
      expect(AccountStatus.warningIssued.displayName, 'Warning Issued');
      expect(AccountStatus.suspended.displayName, 'Suspended');
      expect(AccountStatus.recoveryPending.displayName, 'Recovery Pending');
      expect(AccountStatus.deactivated.displayName, 'Deactivated');
      expect(AccountStatus.deletionPending.displayName, 'Deletion Pending');
    });

    test('UserModel helper getters accurately reflect account status flags', () {
      final now = DateTime.now();
      final activeUser = UserModel(
        uid: 'user_active',
        name: 'Active User',
        email: 'active@example.com',
        userType: 'parent',
        status: 'active',
        createdAt: now,
      );
      expect(activeUser.isActive, true);
      expect(activeUser.isSuspended, false);
      expect(activeUser.isWarned, false);
      expect(activeUser.isDeactivated, false);
      expect(activeUser.isRecoveryPending, false);

      final suspendedUser = UserModel(
        uid: 'user_suspended',
        name: 'Suspended User',
        email: 'suspended@example.com',
        userType: 'parent',
        status: 'suspended',
        createdAt: now,
      );
      expect(suspendedUser.isSuspended, true);
      expect(suspendedUser.isActive, false);

      final warnedUser = UserModel(
        uid: 'user_warned',
        name: 'Warned User',
        email: 'warned@example.com',
        userType: 'parent',
        status: 'warning_issued',
        createdAt: now,
      );
      expect(warnedUser.isWarned, true);

      final recoveryUser = UserModel(
        uid: 'user_recovery',
        name: 'Recovery User',
        email: 'recovery@example.com',
        userType: 'parent',
        status: 'recovery_pending',
        createdAt: now,
      );
      expect(recoveryUser.isRecoveryPending, true);

      final deactivatedUser = UserModel(
        uid: 'user_deactivated',
        name: 'Deactivated User',
        email: 'deactivated@example.com',
        userType: 'parent',
        status: 'deactivated',
        createdAt: now,
      );
      expect(deactivatedUser.isDeactivated, true);
    });
  });

  group('2. Administrative Models Serialization Tests', () {
    test('UserWarningRecord serializes and deserializes accurately', () {
      final now = DateTime(2026, 10, 24, 14, 30);
      final record = UserWarningRecord(
        warningId: 'warn_101',
        category: 'Suspicious activity',
        reason: 'Repeated unrecognized login requests',
        notes: 'Advised user to update credentials',
        issuedAt: now,
        issuedBy: 'admin_master',
        emailSent: true,
      );

      final map = record.toMap();
      expect(map['warningId'], 'warn_101');
      expect(map['category'], 'Suspicious activity');
      expect(map['emailSent'], true);

      final parsed = UserWarningRecord.fromMap(map);
      expect(parsed.warningId, record.warningId);
      expect(parsed.category, record.category);
      expect(parsed.reason, record.reason);
      expect(parsed.notes, record.notes);
      expect(parsed.issuedBy, record.issuedBy);
      expect(parsed.emailSent, record.emailSent);
    });

    test('AccountRecoveryRequestModel serializes and deserializes accurately', () {
      final now = DateTime(2026, 10, 24, 15, 0);
      final req = AccountRecoveryRequestModel(
        id: 'rec_202',
        userId: 'user_99',
        userEmail: 'parent@example.com',
        userName: 'Jane Doe',
        userRole: 'parent',
        suspensionReason: 'Suspicious activity flagged',
        requestedAt: now,
        userExplanation: 'My account was accessed while traveling.',
        status: 'pending_review',
        reviewerId: 'admin_review',
        reviewerNotes: 'Verification document approved',
      );

      final map = req.toMap();
      expect(map['id'], 'rec_202');
      expect(map['userId'], 'user_99');
      expect(map['userEmail'], 'parent@example.com');
      expect(map['status'], 'pending_review');

      final parsed = AccountRecoveryRequestModel.fromMap('rec_202', map);
      expect(parsed.id, req.id);
      expect(parsed.userId, req.userId);
      expect(parsed.userEmail, req.userEmail);
      expect(parsed.userExplanation, req.userExplanation);
      expect(parsed.reviewerNotes, req.reviewerNotes);
    });

    test('LLGAssignmentModel serializes and deserializes accurately', () {
      final now = DateTime(2026, 10, 24, 16, 0);
      final assignment = LLGAssignmentModel(
        id: 'asg_303',
        parentId: 'parent_1',
        parentName: 'Parent One',
        childId: 'child_1',
        childName: 'Child One',
        specialistId: 'spec_1',
        specialistName: 'Dr. Sarah Connor',
        specialistRole: 'Pediatric Specialist',
        status: 'active',
        assignedAt: now,
        assignedBy: 'admin_1',
        reason: 'Early speech milestone support',
        coveredChildren: ['child_1', 'child_2'],
      );

      final map = assignment.toMap();
      expect(map['id'], 'asg_303');
      expect(map['parentId'], 'parent_1');
      expect(map['specialistId'], 'spec_1');
      expect(map['coveredChildren'], ['child_1', 'child_2']);

      final parsed = LLGAssignmentModel.fromMap('asg_303', map);
      expect(parsed.id, assignment.id);
      expect(parsed.parentId, assignment.parentId);
      expect(parsed.parentName, assignment.parentName);
      expect(parsed.specialistId, assignment.specialistId);
      expect(parsed.specialistName, assignment.specialistName);
      expect(parsed.coveredChildren.length, 2);
    });

    test('AdminEmailLogModel serializes and deserializes accurately', () {
      final now = DateTime(2026, 10, 24, 17, 0);
      final log = AdminEmailLogModel(
        id: 'mail_404',
        recipientUid: 'user_404',
        recipientEmail: 'user@example.com',
        recipientName: 'Alex User',
        category: 'suspension',
        subject: 'Important: Your LittleLumin Account Has Been Suspended',
        bodySnippet: 'Notice: suspension applied',
        timestamp: now,
        status: 'sent',
        providerMessageId: 'msg_resend_998877',
      );

      final map = log.toMap();
      expect(map['id'], 'mail_404');
      expect(map['recipientEmail'], 'user@example.com');
      expect(map['providerMessageId'], 'msg_resend_998877');

      final parsed = AdminEmailLogModel.fromMap('mail_404', map);
      expect(parsed.id, log.id);
      expect(parsed.recipientEmail, log.recipientEmail);
      expect(parsed.subject, log.subject);
      expect(parsed.status, 'sent');
    });
  });

  group('3. Administrative Reports Engine & CSV Generation Tests', () {
    test('All 9 AdminReportCategory entries are defined with valid metadata', () {
      expect(AdminReportCategory.values.length, 9);
      expect(AdminReportCategory.platformSummary.displayName.contains('Platform Summary'), true);
      expect(AdminReportCategory.userManagement.displayName.contains('User Management'), true);
      expect(AdminReportCategory.llgVerification.displayName.contains('LLG Verification'), true);
      expect(AdminReportCategory.parentLlgAssignment.displayName.contains('Parent–LLG Assignment'), true);
      expect(AdminReportCategory.activityPerformance.displayName.contains('Activity Performance'), true);
      expect(AdminReportCategory.parentEngagement.displayName.contains('Parent Engagement'), true);
      expect(AdminReportCategory.aiUsage.displayName.contains('AI Usage'), true);
      expect(AdminReportCategory.accountEnforcement.displayName.contains('Account Enforcement'), true);
      expect(AdminReportCategory.adminAudit.displayName.contains('Administrative Audit'), true);
    });

    test('AdminReportResult accurately outputs RFC-compliant CSV formatted data', () {
      final report = AdminReportResult(
        id: 'rep_test',
        category: AdminReportCategory.userManagement,
        title: 'User Management & Lifecycle Report',
        generatedAt: DateTime(2026, 10, 24, 18, 0),
        generatedBy: 'Admin QA',
        dateRangeLabel: 'Last 30 Days',
        summaryMetrics: {
          'Total Scanned': 25,
          'Active Accounts': 20,
        },
        columnHeaders: ['UID', 'Name', 'Role', 'Status'],
        dataRows: [
          ['u_1', 'Alice "Joy" Smith', 'Parent', 'ACTIVE'],
          ['u_2', 'Dr. Bob Specialist', 'LLG', 'ACTIVE'],
        ],
      );

      expect(report.recordsCount, 2);
      expect(report.headers, ['UID', 'Name', 'Role', 'Status']);

      final csv = report.toCsv();
      expect(csv.contains('"Report: User Management & Lifecycle Report"'), true);
      expect(csv.contains('"Period: Last 30 Days"'), true);
      expect(csv.contains('"UID","Name","Role","Status"'), true);
      expect(csv.contains('"u_1","Alice ""Joy"" Smith","Parent","ACTIVE"'), true);
      expect(csv.contains('"u_2","Dr. Bob Specialist","LLG","ACTIVE"'), true);
    });
  });

  group('4. System Health Diagnostic Model Tests', () {
    test('SystemHealthDiagnostic correctly computes overall health status', () {
      final healthy = SystemHealthDiagnostic(
        firebaseAuthOk: true,
        firestoreOk: true,
        backendApiOk: true,
        aiServiceOk: true,
        authMessage: 'Auth online',
        firestoreMessage: 'Firestore online',
        backendMessage: 'Backend online',
        aiMessage: 'AI models online',
        checkedAt: DateTime.now(),
        recentErrorCount: 0,
      );
      expect(healthy.isFullyHealthy, true);

      final degraded = SystemHealthDiagnostic(
        firebaseAuthOk: true,
        firestoreOk: true,
        backendApiOk: false, // Microservices down
        aiServiceOk: true,
        authMessage: 'Auth online',
        firestoreMessage: 'Firestore online',
        backendMessage: 'Backend timed out',
        aiMessage: 'AI models online',
        checkedAt: DateTime.now(),
        recentErrorCount: 1,
      );
      expect(degraded.isFullyHealthy, false);
    });
  });

  group('5. Authoritative Audit Logging & Backend Integration Tests', () {
    test('AuditLogService.logEvent sends Bearer token and returns true on HTTP 201', () async {
      http.Request? capturedRequest;
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'log_id': 'audit_test_999',
            'action': 'user_warning_issued',
            'message': 'Audit event securely recorded.'
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final success = await AuditLogService.logEvent(
        action: 'user_warning_issued',
        targetId: 'usr_target_42',
        caseId: 'case_88',
        childId: 'child_12',
        details: {'reason': 'Policy breach'},
        client: mockClient,
        overrideToken: 'jwt_valid_admin_token',
      );

      expect(success, true);
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/cases/audit-logs');
      expect(capturedRequest!.headers['Authorization'], 'Bearer jwt_valid_admin_token');
      expect(capturedRequest!.headers['Content-Type'], 'application/json');
      expect(capturedBody!['action'], 'user_warning_issued');
      expect(capturedBody!['target_id'], 'usr_target_42');
      expect(capturedBody!['case_id'], 'case_88');
      expect(capturedBody!['child_id'], 'child_12');
      expect(capturedBody!['details']['reason'], 'Policy breach');
    });

    test('AuditLogService.logEvent returns false when backend rejects with 403 or 500', () async {
      final mockForbiddenClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Forbidden: Administrative privileges required'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final success403 = await AuditLogService.logEvent(
        action: 'account_suspended',
        targetId: 'usr_1',
        client: mockForbiddenClient,
        overrideToken: 'parent_non_admin_token',
      );
      expect(success403, false);

      final mockErrorClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Database offline'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final success500 = await AuditLogService.logEvent(
        action: 'account_suspended',
        targetId: 'usr_1',
        client: mockErrorClient,
        overrideToken: 'admin_token',
      );
      expect(success500, false);
    });

    test('AuditLogService.logEvent handles network errors gracefully and returns false', () async {
      final mockThrowingClient = MockClient((request) async {
        throw http.ClientException('Network connection failed');
      });

      final success = await AuditLogService.logEvent(
        action: 'account_restored',
        targetId: 'usr_2',
        client: mockThrowingClient,
        overrideToken: 'admin_token',
      );
      expect(success, false);
    });

    test('AdminService.logAdminAudit handles missing authentication safely and returns false', () async {
      final adminService = AdminService();
      final success = await adminService.logAdminAudit(
        action: 'account_suspended',
        targetId: 'usr_orphan',
      );
      expect(success, false);
    });
  });

  group('6. User Lifecycle Backend Integration & Safeguard Tests', () {
    late AdminService adminService;
    late EmailService emailService;

    setUp(() {
      adminService = AdminService();
      emailService = EmailService();
      AdminService.overrideAuthToken = 'mock_admin_token';
      EmailService.overrideAuthToken = 'mock_admin_token';
    });

    tearDown(() {
      AdminService.overrideAuthToken = null;
      AdminService.customHttpClient = null;
      EmailService.overrideAuthToken = null;
      EmailService.customHttpClient = null;
    });

    test('AdminService.suspendAccount dispatches POST to backend with Bearer token and valid body', () async {
      http.Request? capturedRequest;
      Map<String, dynamic>? capturedBody;

      AdminService.customHttpClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Account suspended',
            'user_id': 'usr_susp_target',
            'auth_disabled': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await adminService.suspendAccount(
        userId: 'usr_susp_target',
        reason: 'Investigating anomalous case activity',
        category: 'Security review',
        isTemporary: true,
        suspensionUntil: DateTime(2026, 11, 1),
        sendEmail: true,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/admin/users/usr_susp_target/suspend');
      expect(capturedRequest!.headers['Authorization'], 'Bearer mock_admin_token');
      expect(capturedRequest!.headers['Content-Type'], 'application/json');
      expect(capturedBody!['reason'], 'Investigating anomalous case activity');
      expect(capturedBody!['category'], 'Security review');
      expect(capturedBody!['isTemporary'], true);
      expect(capturedBody!['sendEmail'], true);
    });

    test('AdminService.restoreAccount dispatches POST to restore endpoint', () async {
      http.Request? capturedRequest;
      Map<String, dynamic>? capturedBody;

      AdminService.customHttpClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Account restored',
            'user_id': 'usr_rest_target',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await adminService.restoreAccount(
        userId: 'usr_rest_target',
        restorationReason: 'Completed credential re-verification',
        sendEmail: false,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/admin/users/usr_rest_target/restore');
      expect(capturedRequest!.headers['Authorization'], 'Bearer mock_admin_token');
      expect(capturedBody!['restorationReason'], 'Completed credential re-verification');
      expect(capturedBody!['sendEmail'], false);
    });

    test('AdminService.deactivateAccount dispatches POST to deactivate endpoint', () async {
      http.Request? capturedRequest;
      Map<String, dynamic>? capturedBody;

      AdminService.customHttpClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Account deactivated',
            'user_id': 'usr_deact_target',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await adminService.deactivateAccount(
        userId: 'usr_deact_target',
        reason: 'User requested temporary break',
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/admin/users/usr_deact_target/deactivate');
      expect(capturedRequest!.headers['Authorization'], 'Bearer mock_admin_token');
      expect(capturedBody!['reason'], 'User requested temporary break');
    });

    test('AdminService.permanentlyDeleteAccountSafeguard enforces email confirmation mismatch', () async {
      expect(
        () async => await adminService.permanentlyDeleteAccountSafeguard(
          userId: 'usr_del_1',
          userEmail: 'target@example.com',
          reason: 'DPDP erasure request',
          adminConfirmation: 'WRONG@EXAMPLE.COM',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('AdminService.permanentlyDeleteAccountSafeguard dispatches to delete endpoint on match', () async {
      http.Request? capturedRequest;
      Map<String, dynamic>? capturedBody;

      AdminService.customHttpClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'User account permanently removed',
            'user_id': 'usr_del_target',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await adminService.permanentlyDeleteAccountSafeguard(
        userId: 'usr_del_target',
        userEmail: 'target@example.com',
        reason: 'Verified DPDP erasure request',
        adminConfirmation: 'target@example.com',
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/admin/users/usr_del_target/delete');
      expect(capturedRequest!.headers['Authorization'], 'Bearer mock_admin_token');
      expect(capturedBody!['confirmation'], 'target@example.com');
      expect(capturedBody!['reason'], 'Verified DPDP erasure request');
    });

    test('AdminService.processRecoveryDecision dispatches to recovery decision endpoint', () async {
      http.Request? capturedRequest;
      Map<String, dynamic>? capturedBody;

      AdminService.customHttpClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Recovery decision processed',
            'request_id': 'req_rec_42',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await adminService.processRecoveryDecision(
        requestId: 'req_rec_42',
        userId: 'usr_rec_user',
        decisionStatus: 'approved',
        reviewerNotes: 'Verified identity via secondary authentication channel',
        sendEmail: true,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/admin/users/recovery-requests/req_rec_42/decision');
      expect(capturedRequest!.headers['Authorization'], 'Bearer mock_admin_token');
      expect(capturedBody!['decisionStatus'], 'approved');
      expect(capturedBody!['reviewerNotes'], 'Verified identity via secondary authentication channel');
      expect(capturedBody!['sendEmail'], true);
    });

    test('AdminService.issueWarning dispatches to warning endpoint', () async {
      http.Request? capturedRequest;
      Map<String, dynamic>? capturedBody;

      AdminService.customHttpClient = MockClient((request) async {
        capturedRequest = request;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Warning successfully issued',
            'user_id': 'usr_warn_target',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await adminService.issueWarning(
        userId: 'usr_warn_target',
        category: 'Policy violation',
        reason: 'Excessive inaccurate submissions',
        notes: 'Follow up if continued',
        sendEmail: true,
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.url.path, '/api/admin/users/usr_warn_target/warning');
      expect(capturedRequest!.headers['Authorization'], 'Bearer mock_admin_token');
      expect(capturedBody!['category'], 'Policy violation');
      expect(capturedBody!['reason'], 'Excessive inaccurate submissions');
      expect(capturedBody!['notes'], 'Follow up if continued');
      expect(capturedBody!['sendEmail'], true);
    });

    test('EmailService.sendAdminEmail honestly reports pending_configuration when backend provider is unconfigured', () async {
      EmailService.customHttpClient = MockClient((request) async {
        return http.Response('Provider not configured', 404);
      });

      final log = await emailService.sendAdminEmail(
        recipientUid: 'usr_email_1',
        recipientEmail: 'parent@example.com',
        recipientName: 'Parent User',
        category: 'warning',
        subject: 'Official Warning Notice',
        messageBody: 'Your account has received an administrative warning.',
      );

      expect(log.status, 'pending_configuration');
      expect(log.providerMessageId, 'PENDING_CONFIG');
      expect(log.errorMessage, isNotNull);
      expect(log.errorMessage, contains('Provider configuration required'));
    });

    test('EmailService.sendAdminEmail reports delivered when backend provider returns 200', () async {
      EmailService.customHttpClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'sent', 'message_id': 'msg_live_123'}), 200);
      });

      final log = await emailService.sendAdminEmail(
        recipientUid: 'usr_email_2',
        recipientEmail: 'parent@example.com',
        recipientName: 'Parent User',
        category: 'restoration',
        subject: 'Account Access Restored',
        messageBody: 'Your account access has been restored.',
      );

      expect(log.status, 'delivered');
      expect(log.providerMessageId, startsWith('MSG-'));
      expect(log.errorMessage, isNull);
    });
  });

  group('9. LLG Credential Metadata & Verification Document Tests', () {
    test('extractCredentials handles completely unsubmitted documents truthfully', () {
      final emptyLlgData = {
        'name': 'Dr. Unsubmitted',
        'email': 'unsubmitted@example.com',
        'license': 'LIC-PENDING-001',
      };

      final docs = LLGCredentialDocument.extractCredentials(emptyLlgData);
      expect(docs.length, 5); // 5 standard categories
      for (final doc in docs) {
        expect(doc.isSubmitted, false);
        expect(doc.verificationStatus, 'unsubmitted');
        expect(doc.filename, 'No document submitted');
        expect(doc.isImage, false);
        expect(doc.isPdf, false);
      }
    });

    test('extractCredentials correctly identifies image, PDF, and filename formats', () {
      final sampleLlgData = {
        'name': 'Dr. Sarah Connor',
        'email': 'sarah@pediatrics.org',
        'license': 'MH-MED-2024-9981',
        'qualificationCertificateLink': 'https://firebasestorage.googleapis.com/v0/b/project.appspot.com/o/credentials%2Fsarah_degree.pdf?alt=media',
        'licenseCertificateLink': 'https://firebasestorage.googleapis.com/v0/b/project.appspot.com/o/credentials%2Fmedical_board_license.png?alt=media',
        'experienceCertificateLink': 'https://firebasestorage.googleapis.com/v0/b/project.appspot.com/o/credentials%2Fhospital_experience.jpg?token=abc',
        'identityProofLink': '',
        'professionalAssociationLink': 'https://firebasestorage.googleapis.com/v0/b/project.appspot.com/o/credentials%2Fmembership.doc?alt=media',
      };

      final verificationMap = {
        'qualification': {
          'status': 'verified',
          'verifiedByAdminId': 'admin_1',
        },
        'license': {
          'status': 'rejected',
          'rejectionReason': 'Expired medical license date',
        },
      };

      final docs = LLGCredentialDocument.extractCredentials(sampleLlgData, verificationMap: verificationMap);
      expect(docs.length, 5);

      // 1. Qualification: PDF, verified
      final qualDoc = docs.firstWhere((d) => d.key == 'qualification');
      expect(qualDoc.isSubmitted, true);
      expect(qualDoc.isPdf, true);
      expect(qualDoc.isImage, false);
      expect(qualDoc.verificationStatus, 'verified');
      expect(qualDoc.filename, 'sarah_degree.pdf');

      // 2. License: PNG Image, rejected with reason
      final licDoc = docs.firstWhere((d) => d.key == 'license');
      expect(licDoc.isSubmitted, true);
      expect(licDoc.isImage, true);
      expect(licDoc.isPdf, false);
      expect(licDoc.verificationStatus, 'rejected');
      expect(licDoc.rejectionReason, 'Expired medical license date');
      expect(licDoc.filename, 'medical_board_license.png');

      // 3. Experience: JPG Image, pending
      final expDoc = docs.firstWhere((d) => d.key == 'experience');
      expect(expDoc.isSubmitted, true);
      expect(expDoc.isImage, true);
      expect(expDoc.verificationStatus, 'pending');
      expect(expDoc.filename, 'hospital_experience.jpg');

      // 4. Identity: empty, unsubmitted
      final idDoc = docs.firstWhere((d) => d.key == 'identity');
      expect(idDoc.isSubmitted, false);
      expect(idDoc.verificationStatus, 'unsubmitted');

      // 5. Professional: non-image, non-pdf format
      final profDoc = docs.firstWhere((d) => d.key == 'professional');
      expect(profDoc.isSubmitted, true);
      expect(profDoc.isImage, false);
      expect(profDoc.isPdf, false);
      expect(profDoc.filename, 'membership.doc');
    });

    test('License resolution prefers "license" then "licenseNumber" then "Pending submission"', () {
      final docWithLicense = {'license': 'LIC-12345'};
      final docWithLicenseNumber = {'licenseNumber': 'LIC-67890'};
      final docWithNeither = <String, dynamic>{};

      expect(docWithLicense['license'] ?? docWithLicense['licenseNumber'] ?? 'Pending submission', 'LIC-12345');
      expect(docWithLicenseNumber['license'] ?? docWithLicenseNumber['licenseNumber'] ?? 'Pending submission', 'LIC-67890');
      expect(docWithNeither['license'] ?? docWithNeither['licenseNumber'] ?? 'Pending submission', 'Pending submission');
    });
  });

  group('10. Parent–LLG Relationship Mapping & Status Classification Tests', () {
    test('LLGAssignmentModel.fromSpecialistCaseMap correctly maps pending parent consultation request', () {
      final now = DateTime.now();
      final caseData = {
        'caseId': 'child_alpha_spec_omega',
        'parentId': 'parent_100',
        'parentName': 'Priya Sharma',
        'childId': 'child_alpha',
        'childName': 'Aarav Sharma',
        'specialistId': 'spec_omega',
        'specialistName': 'Dr. Maya Patel',
        'specialistRole': 'Speech & Language Pathologist',
        'purpose': 'Delayed speech milestones evaluation',
        'status': 'pending',
        'consentedAt': now.toIso8601String(),
      };

      final model = LLGAssignmentModel.fromSpecialistCaseMap('child_alpha_spec_omega', caseData);

      expect(model.id, 'child_alpha_spec_omega');
      expect(model.parentId, 'parent_100');
      expect(model.parentName, 'Priya Sharma');
      expect(model.childId, 'child_alpha');
      expect(model.childName, 'Aarav Sharma');
      expect(model.specialistId, 'spec_omega');
      expect(model.specialistName, 'Dr. Maya Patel');
      expect(model.status, 'pending');
      expect(model.isPending, true);
      expect(model.isActive, false);
      expect(model.isCompletedOrCancelled, false);
      expect(model.reason, 'Delayed speech milestones evaluation');
      expect(model.coveredChildren, ['child_alpha']);
    });

    test('LLGAssignmentModel.fromSpecialistCaseMap correctly maps accepted/active status', () {
      final caseData = {
        'caseId': 'child_beta_spec_omega',
        'parentId': 'parent_200',
        'parentName': 'Rajesh Kumar',
        'childId': 'child_beta',
        'childName': 'Ananya Kumar',
        'specialistId': 'spec_omega',
        'specialistName': 'Dr. Maya Patel',
        'status': 'accepted',
      };

      final model = LLGAssignmentModel.fromSpecialistCaseMap('child_beta_spec_omega', caseData);
      expect(model.status, 'active');
      expect(model.isActive, true);
      expect(model.isPending, false);
      expect(model.isCompletedOrCancelled, false);
    });

    test('LLGAssignmentModel.fromSpecialistCaseMap correctly maps completed, declined, and revoked statuses', () {
      final completedData = {'status': 'completed', 'specialistName': 'Dr. Maya', 'parentId': 'p1', 'specialistId': 's1'};
      final declinedData = {'status': 'declined', 'specialistName': 'Dr. Maya', 'parentId': 'p1', 'specialistId': 's1'};
      final revokedData = {'status': 'revoked', 'specialistName': 'Dr. Maya', 'parentId': 'p1', 'specialistId': 's1'};

      final compModel = LLGAssignmentModel.fromSpecialistCaseMap('case_1', completedData);
      final decModel = LLGAssignmentModel.fromSpecialistCaseMap('case_2', declinedData);
      final revModel = LLGAssignmentModel.fromSpecialistCaseMap('case_3', revokedData);

      expect(compModel.status, 'completed');
      expect(compModel.isCompletedOrCancelled, true);

      expect(decModel.status, 'declined');
      expect(decModel.isCompletedOrCancelled, true);

      expect(revModel.status, 'revoked');
      expect(revModel.isCompletedOrCancelled, true);
    });

    test('Deduplication logic accurately preserves communication case IDs without duplicating records', () {
      final caseModel = LLGAssignmentModel(
        id: 'child_1_spec_1',
        parentId: 'parent_1',
        parentName: 'Parent One',
        childId: 'child_1',
        childName: 'Child One',
        specialistId: 'spec_1',
        specialistName: 'Dr. Specialist',
        specialistRole: 'Pediatric Specialist',
        status: 'active',
        assignedAt: DateTime(2026, 10, 20),
        assignedBy: 'system',
      );

      final llgModel = LLGAssignmentModel(
        id: 'llg_assign_auto_generated',
        parentId: 'parent_1',
        parentName: 'Parent One',
        childId: 'child_1',
        childName: 'Child One',
        specialistId: 'spec_1',
        specialistName: 'Dr. Specialist',
        specialistRole: 'Pediatric Specialist',
        status: 'active',
        assignedAt: DateTime(2026, 10, 21),
        assignedBy: 'admin',
      );

      // Simulating deduplication dictionary
      final map = <String, LLGAssignmentModel>{};
      map[caseModel.id] = caseModel;

      // Merge llgModel
      final matchingKey = map.keys.firstWhere(
        (k) =>
            k == llgModel.id ||
            (llgModel.childId != null &&
                llgModel.childId!.isNotEmpty &&
                map[k]?.childId == llgModel.childId &&
                map[k]?.specialistId == llgModel.specialistId &&
                map[k]?.parentId == llgModel.parentId),
        orElse: () => '',
      );

      if (matchingKey.isNotEmpty) {
        // Preserves primary caseId
        expect(matchingKey, 'child_1_spec_1');
      } else {
        map[llgModel.id] = llgModel;
      }

      // Ensure no duplicate record created
      expect(map.length, 1);
      expect(map.containsKey('child_1_spec_1'), true);
      // Ensures the messaging thread path conversations/child_1_spec_1 is completely preserved
    });
  });

  group('11. Parent Selection & Specialist Assignment Eligibility Tests', () {
    final now = DateTime(2026, 10, 26);

    test('isEligibleParent allows active and warned parents', () {
      final activeParent = UserModel(
        uid: 'parent_1',
        name: 'Aarav Sharma',
        email: 'aarav@example.com',
        userType: 'parent',
        status: 'active',
        createdAt: now,
      );
      expect(activeParent.isParent, true);
      expect(activeParent.isEligibleParent, true);
      expect(AdminService.isEligibleParent(activeParent), true);

      final warnedParent = UserModel(
        uid: 'parent_2',
        name: 'Priya Patel',
        email: 'priya@example.com',
        userType: 'parent',
        status: 'warning_issued',
        createdAt: now,
      );
      expect(warnedParent.isParent, true);
      expect(warnedParent.isEligibleParent, true);
      expect(AdminService.isEligibleParent(warnedParent), true);
    });

    test('isEligibleParent explicitly rejects non-parent roles (LLG specialists, admins, pending, rejected)', () {
      final llgUser = UserModel(
        uid: 'spec_1',
        name: 'Dr. Sarah Connor',
        email: 'sarah@example.com',
        userType: 'llg',
        status: 'active',
        createdAt: now,
      );
      expect(llgUser.isSpecialist, true);
      expect(llgUser.isParent, false);
      expect(llgUser.isEligibleParent, false);

      final clinicalSpec = UserModel(
        uid: 'spec_2',
        name: 'Dr. John Doe',
        email: 'john@example.com',
        userType: 'clinical_specialist',
        status: 'active',
        createdAt: now,
      );
      expect(clinicalSpec.isSpecialist, true);
      expect(clinicalSpec.isParent, false);
      expect(clinicalSpec.isEligibleParent, false);

      final educationalSpec = UserModel(
        uid: 'spec_3',
        name: 'Emily Guide',
        email: 'emily@example.com',
        userType: 'specialist',
        status: 'active',
        createdAt: now,
      );
      expect(educationalSpec.isSpecialist, true);
      expect(educationalSpec.isParent, false);
      expect(educationalSpec.isEligibleParent, false);

      final adminUser = UserModel(
        uid: 'admin_1',
        name: 'Admin Chief',
        email: 'admin@example.com',
        userType: 'admin',
        status: 'active',
        createdAt: now,
      );
      expect(adminUser.isAdmin, true);
      expect(adminUser.isParent, false);
      expect(adminUser.isEligibleParent, false);

      final pendingLLG = UserModel(
        uid: 'pending_1',
        name: 'Pending LLG',
        email: 'pending@example.com',
        userType: 'llg_pending',
        status: 'pending',
        createdAt: now,
      );
      expect(pendingLLG.isParent, false);
      expect(pendingLLG.isEligibleParent, false);

      final rejectedUser = UserModel(
        uid: 'rejected_1',
        name: 'Rejected Applicant',
        email: 'rejected@example.com',
        userType: 'rejected',
        status: 'rejected',
        createdAt: now,
      );
      expect(rejectedUser.isParent, false);
      expect(rejectedUser.isEligibleParent, false);
    });

    test('isEligibleParent rejects ineligible account statuses (suspended, deactivated, deleted, deletion_pending, recovery_pending)', () {
      final suspendedParent = UserModel(
        uid: 'p_susp',
        name: 'Suspended Parent',
        email: 'susp@example.com',
        userType: 'parent',
        status: 'suspended',
        createdAt: now,
      );
      expect(suspendedParent.isEligibleParent, false);

      final deactivatedParent = UserModel(
        uid: 'p_deact',
        name: 'Deactivated Parent',
        email: 'deact@example.com',
        userType: 'parent',
        status: 'deactivated',
        createdAt: now,
      );
      expect(deactivatedParent.isEligibleParent, false);

      final inactiveParent = UserModel(
        uid: 'p_inact',
        name: 'Inactive Parent',
        email: 'inact@example.com',
        userType: 'parent',
        status: 'inactive',
        createdAt: now,
      );
      expect(inactiveParent.isEligibleParent, false);

      final deletionPendingParent = UserModel(
        uid: 'p_del',
        name: 'Deletion Pending Parent',
        email: 'del@example.com',
        userType: 'parent',
        status: 'deletion_pending',
        createdAt: now,
      );
      expect(deletionPendingParent.isEligibleParent, false);

      final recoveryPendingParent = UserModel(
        uid: 'p_rec',
        name: 'Recovery Pending Parent',
        email: 'rec@example.com',
        userType: 'parent',
        status: 'recovery_pending',
        createdAt: now,
      );
      expect(recoveryPendingParent.isEligibleParent, false);
    });

    test('UserModel.fromMap accurately extracts role/userRole fallback', () {
      final fromRole = UserModel.fromMap('u_role', {
        'name': 'Role Specialist',
        'email': 'spec@example.com',
        'role': 'llg',
        'status': 'active',
      });
      expect(fromRole.userType, 'llg');
      expect(fromRole.isSpecialist, true);
      expect(fromRole.isEligibleParent, false);

      final fromAdminRole = UserModel.fromMap('u_admin_role', {
        'name': 'Role Admin',
        'email': 'adm@example.com',
        'role': 'admin',
        'status': 'active',
      });
      expect(fromAdminRole.userType, 'admin');
      expect(fromAdminRole.isAdmin, true);
      expect(fromAdminRole.isEligibleParent, false);
    });

    test('Parent deduplication correctly collapses duplicate stable user IDs without removing same-name distinct users', () {
      final parentA = UserModel(
        uid: 'uid_100',
        name: 'Ananya Rao',
        email: 'ananya.primary@example.com',
        userType: 'parent',
        status: 'active',
        createdAt: now,
      );
      // Duplicate entry for the same user ID (e.g. from multiple collection queries or documents)
      final parentADuplicate = UserModel(
        uid: 'uid_100',
        name: 'Ananya Rao',
        email: 'ananya.alias@example.com',
        userType: 'parent',
        status: 'active',
        createdAt: now,
      );
      // A different parent who happens to share the same display name
      final parentBDifferentUidSameName = UserModel(
        uid: 'uid_200',
        name: 'Ananya Rao',
        email: 'ananya.different@example.com',
        userType: 'parent',
        status: 'active',
        createdAt: now,
      );
      // Ineligible specialist in raw list
      final specialist = UserModel(
        uid: 'uid_300',
        name: 'Dr. Specialist',
        email: 'spec@example.com',
        userType: 'llg',
        status: 'active',
        createdAt: now,
      );

      final rawList = [parentA, parentADuplicate, parentBDifferentUidSameName, specialist];

      final Map<String, UserModel> uniqueParents = {};
      for (final p in rawList) {
        if (AdminService.isEligibleParent(p)) {
          uniqueParents.putIfAbsent(p.uid, () => p);
        }
      }

      final filtered = uniqueParents.values.toList();
      // Should have exactly 2 eligible parents (uid_100 and uid_200), specialist excluded, duplicate uid_100 removed
      expect(filtered.length, 2);
      expect(filtered.map((u) => u.uid).toSet(), equals({'uid_100', 'uid_200'}));
      expect(filtered.any((u) => u.uid == 'uid_300'), false);
    });
  });
}
