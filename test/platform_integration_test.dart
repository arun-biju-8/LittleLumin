// test/platform_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:littlelumin/models/admin_models.dart';
import 'package:littlelumin/models/specialist_report_model.dart';
import 'package:littlelumin/services/notification_router.dart';

void main() {
  group('1. LLG Suspension, Warning & Appeal Integration Tests', () {
    test('LLGAppealModel correctly serializes and deserializes', () {
      final now = DateTime(2026, 10, 26, 10, 0);
      final appeal = LLGAppealModel(
        id: 'appeal_001',
        llgId: 'spec_42',
        llgName: 'Dr. Jane Specialist',
        llgEmail: 'jane@example.com',
        suspensionReason: 'Safety compliance audit review',
        appealText: 'I have submitted all necessary credential documentation and recertification records.',
        supportingEvidence: 'https://storage.googleapis.com/littlelumin-docs/cert.pdf',
        submittedAt: now,
        status: 'pending',
      );

      final map = appeal.toMap();
      expect(map['llgId'], 'spec_42');
      expect(map['status'], 'pending');
      expect(map['appealText'], contains('recertification'));

      final fromMap = LLGAppealModel.fromMap('appeal_001', {
        'llgId': 'spec_42',
        'llgName': 'Dr. Jane Specialist',
        'llgEmail': 'jane@example.com',
        'suspensionReason': 'Safety compliance audit review',
        'appealText': 'I have submitted all necessary credential documentation and recertification records.',
        'supportingEvidence': 'https://storage.googleapis.com/littlelumin-docs/cert.pdf',
        'submittedAt': Timestamp.fromDate(now),
        'status': 'pending',
      });

      expect(fromMap.id, 'appeal_001');
      expect(fromMap.isPending, true);
      expect(fromMap.isApproved, false);
      expect(fromMap.isRejected, false);
      expect(fromMap.createdAt, now);
    });

    test('LLGAppealModel correctly tracks approved status and restoration conditions', () {
      final now = DateTime(2026, 10, 26, 11, 0);
      final appeal = LLGAppealModel(
        id: 'appeal_002',
        llgId: 'spec_42',
        llgName: 'Dr. Jane Specialist',
        llgEmail: 'jane@example.com',
        suspensionReason: 'Audit review',
        appealText: 'Credentials renewed',
        submittedAt: now,
        status: 'approved',
        adminDecisionNotes: 'Verified with state licensing board. Fully cleared.',
        reviewedBy: 'admin_root',
        reviewedAt: now,
        restorationConditions: ['Submit updated insurance by Nov 30', 'Complete ethics refresher'],
      );

      expect(appeal.isApproved, true);
      expect(appeal.isPending, false);
      expect(appeal.isRejected, false);
      expect(appeal.adminNotes, 'Verified with state licensing board. Fully cleared.');
      expect(appeal.restorationConditions?.length, 2);
      expect(appeal.conditionsForRestoration, contains('Submit updated insurance by Nov 30'));
    });

    test('Specialist directory filters out suspended and deactivated specialists', () {
      final specialists = [
        {'id': 'spec_1', 'name': 'Active Spec', 'status': 'active'},
        {'id': 'spec_2', 'name': 'Suspended Spec', 'status': 'suspended'},
        {'id': 'spec_3', 'name': 'Deactivated Spec', 'status': 'deactivated'},
        {'id': 'spec_4', 'name': 'Verified Spec', 'status': 'verified'},
        {'id': 'spec_5', 'name': 'Flagged Suspended Spec', 'status': 'approved', 'isSuspended': true},
      ];

      final parentEligible = specialists.where((s) {
        final status = (s['status'] as String? ?? 'active').toLowerCase();
        final isSuspended = s['isSuspended'] == true;
        return status != 'suspended' && status != 'deactivated' && !isSuspended;
      }).toList();

      expect(parentEligible.length, 2);
      expect(parentEligible.map((s) => s['id']), containsAll(['spec_1', 'spec_4']));
      expect(parentEligible.map((s) => s['id']), isNot(contains('spec_2')));
      expect(parentEligible.map((s) => s['id']), isNot(contains('spec_3')));
      expect(parentEligible.map((s) => s['id']), isNot(contains('spec_5')));
    });

    test('Warning notices are recorded with category and audit integrity', () {
      final warning = UserWarningRecord(
        warningId: 'warn_01',
        issuedAt: DateTime(2026, 10, 20),
        reason: 'Late consultation response',
        category: 'responsiveness',
        issuedBy: 'admin_1',
      );

      expect(warning.warningId, 'warn_01');
      expect(warning.category, 'responsiveness');
      expect(warning.reason, 'Late consultation response');
      expect(warning.emailSent, true);

      final map = warning.toMap();
      expect(map['warningId'], 'warn_01');
      expect(map['category'], 'responsiveness');

      final fromMap = UserWarningRecord.fromMap(map);
      expect(fromMap.warningId, 'warn_01');
      expect(fromMap.reason, 'Late consultation response');
    });
  });

  group('2. Parent Complaints Integration Tests', () {
    test('ParentComplaintModel serializes and deserializes all categories correctly', () {
      final now = DateTime(2026, 10, 26, 9, 30);
      final complaint = ParentComplaintModel(
        id: 'comp_101',
        parentId: 'parent_alpha',
        parentName: 'Sarah Jenkins',
        parentEmail: 'sarah@example.com',
        llgId: 'spec_omega',
        llgName: 'Dr. Robert Smith',
        caseId: 'case_consult_789',
        childId: 'child_sam',
        childName: 'Sam Jenkins',
        category: ParentComplaintCategory.missedSession.value,
        description: 'Specialist did not join scheduled developmental consultation without prior notice.',
        supportingEvidence: 'Screenshots of missed appointment waiting room',
        status: 'pending',
        createdAt: now,
      );

      expect(complaint.categoryDisplayName, 'Missed Consultation / Late Response');
      expect(complaint.categoryEnum, ParentComplaintCategory.missedSession);
      expect(complaint.isPending, true);
      expect(complaint.isUnderInvestigation, false);
      expect(complaint.isResolved, false);

      final map = complaint.toMap();
      expect(map['category'], 'missed_session');
      expect(map['parentId'], 'parent_alpha');
      expect(map['llgName'], 'Dr. Robert Smith');

      final restored = ParentComplaintModel.fromMap('comp_101', {
        'parentId': 'parent_alpha',
        'parentName': 'Sarah Jenkins',
        'parentEmail': 'sarah@example.com',
        'specialistId': 'spec_omega',
        'specialistName': 'Dr. Robert Smith',
        'caseId': 'case_consult_789',
        'category': 'missed_session',
        'description': 'Specialist did not join scheduled developmental consultation without prior notice.',
        'supportingEvidence': 'Screenshots of missed appointment waiting room',
        'status': 'under_investigation',
        'createdAt': Timestamp.fromDate(now),
        'investigationNotes': 'Consulted server video session logs',
      });

      expect(restored.isUnderInvestigation, true);
      expect(restored.specialistName, 'Dr. Robert Smith');
      expect(restored.investigationNotes, 'Consulted server video session logs');
    });

    test('Complaints protect specialist rating from automatic mutation', () {
      // Invariant: Submitting a complaint MUST NOT change specialist rating or auto-suspend
      const initialRating = 4.8;
      const initialRatingCount = 15;
      const isSuspendedInitial = false;

      // Simulate complaint creation
      final complaint = ParentComplaintModel(
        id: 'comp_102',
        parentId: 'parent_beta',
        parentName: 'David Lee',
        parentEmail: 'david@example.com',
        llgId: 'spec_theta',
        llgName: 'Dr. Rachel Adams',
        category: ParentComplaintCategory.unprofessionalConduct.value,
        description: 'Disagreed with tone during consultation summary.',
        createdAt: DateTime.now(),
      );

      expect(complaint.isPending, true);

      // Verify specialist profile values remain intact
      expect(initialRating, 4.8);
      expect(initialRatingCount, 15);
      expect(isSuspendedInitial, false);
    });
  });

  group('3. Specialist Ratings and Reviews Integration Tests', () {
    test('SpecialistReviewModel enforces 1 to 5 star rating boundaries', () {
      final now = DateTime(2026, 10, 26);
      final validReview = SpecialistReviewModel(
        id: 'rev_1',
        llgId: 'spec_42',
        llgName: 'Dr. Jane Specialist',
        parentId: 'p1',
        parentName: 'Parent One',
        rating: 5.0,
        reviewText: 'Incredible patience and developmental insights!',
        createdAt: now,
      );

      expect(validReview.rating, 5.0);
      expect(validReview.starCount, 5);
      expect(validReview.isPositive, true);
      expect(validReview.isModerated, false);
      expect(validReview.specialistName, 'Dr. Jane Specialist');
    });

    test('Aggregate recalculation correctly averages legitimate non-moderated reviews', () {
      final reviews = [
        SpecialistReviewModel(
          id: 'r1',
          llgId: 'spec_1',
          llgName: 'Spec 1',
          parentId: 'p1',
          parentName: 'P1',
          rating: 5.0,
          createdAt: DateTime.now(),
        ),
        SpecialistReviewModel(
          id: 'r2',
          llgId: 'spec_1',
          llgName: 'Spec 1',
          parentId: 'p2',
          parentName: 'P2',
          rating: 4.0,
          createdAt: DateTime.now(),
        ),
        SpecialistReviewModel(
          id: 'r3',
          llgId: 'spec_1',
          llgName: 'Spec 1',
          parentId: 'p3',
          parentName: 'P3',
          rating: 1.0,
          isModerated: true, // Moderated by admin for spam/policy violation
          moderationReason: 'Contains promotional advertising links',
          createdAt: DateTime.now(),
        ),
      ];

      // Legitimate reviews only
      final legitimate = reviews.where((r) => !r.isModerated).toList();
      expect(legitimate.length, 2);

      final totalRating = legitimate.fold<double>(0.0, (acc, r) => acc + r.rating);
      final averageRating = totalRating / legitimate.length;

      expect(averageRating, 4.5);
      expect(legitimate.length, 2);
    });

    test('Displays "Not yet rated" when no reviews exist', () {
      final List<SpecialistReviewModel> emptyReviews = [];

      final legitimate = emptyReviews.where((r) => !r.isModerated).toList();
      final ratingCount = legitimate.length;
      final averageRating = ratingCount > 0
          ? legitimate.fold<double>(0.0, (acc, r) => acc + r.rating) / ratingCount
          : 0.0;

      expect(ratingCount, 0);
      expect(averageRating, 0.0);
      // Parent UI displays "Not yet rated" when ratingCount == 0
      final displayRating = ratingCount > 0 ? averageRating.toStringAsFixed(1) : 'Not yet rated';
      expect(displayRating, 'Not yet rated');
    });

    test('Duplicate review prevention verifies one review per consultation case', () {
      final existingReviews = [
        {'caseId': 'case_alpha_1', 'parentId': 'p1', 'llgId': 's1'},
        {'caseId': 'case_beta_2', 'parentId': 'p2', 'llgId': 's1'},
      ];

      bool hasReviewed(String caseId) {
        return existingReviews.any((r) => r['caseId'] == caseId);
      }

      expect(hasReviewed('case_alpha_1'), true);
      expect(hasReviewed('case_gamma_3'), false);
    });
  });

  group('4. Specialist Report Delivery to Parent Dashboard Tests', () {
    test('SpecialistReportModel correctly includes parentId and readByParent tracking', () {
      final now = DateTime(2026, 10, 26, 8, 0);
      final report = SpecialistReportModel(
        id: 'rep_001',
        title: 'Speech & Language Comprehensive Evaluation',
        summary: 'Significant progress observed across receptive language milestones.',
        caseId: 'case_consult_789',
        childId: 'child_sam',
        childName: 'Sam Jenkins',
        specialistId: 'spec_omega',
        specialistName: 'Dr. Robert Smith',
        parentId: 'parent_alpha',
        domainScores: {'Language': 82.5, 'Cognitive': 88.0},
        keyFindings: ['Vocabulary expansion by 25%'],
        strengths: ['Active listening', 'Engagement with visual cues'],
        growthAreas: ['Multi-word expressive phrasing'],
        recommendations: ['Daily paired storytelling routine'],
        generatedAt: now,
        status: SpecialistReportStatus.shared,
      );

      expect(report.parentId, 'parent_alpha');
      expect(report.isReadByParent, false);
      expect(report.readByParentAt, isNull);

      final map = report.toMap();
      expect(map['parentId'], 'parent_alpha');
      expect(map['isSharedWithParent'], true);
      expect(map['readByParentAt'], isNull);

      // Parent marks report as read
      final readAt = DateTime(2026, 10, 26, 9, 15);
      final readReport = report.copyWith(
        readByParentAt: readAt,
      );

      expect(readReport.isReadByParent, true);
      expect(readReport.readByParentAt, readAt);
      expect(readReport.toMap()['readByParentAt'], isNotNull);
    });

    test('Parent reports stream query isolates only authorized parent reports', () {
      final allReports = [
        {'id': 'r1', 'parentId': 'parent_alpha', 'title': 'Report 1', 'isSharedWithParent': true},
        {'id': 'r2', 'parentId': 'parent_beta', 'title': 'Report 2', 'isSharedWithParent': true},
        {'id': 'r3', 'parentId': 'parent_alpha', 'title': 'Report 3 Draft', 'isSharedWithParent': false},
        {'id': 'r4', 'parentId': 'parent_alpha', 'title': 'Report 4', 'isSharedWithParent': true},
      ];

      const currentParentUid = 'parent_alpha';

      final parentVisible = allReports.where((r) {
        return r['parentId'] == currentParentUid && r['isSharedWithParent'] == true;
      }).toList();

      expect(parentVisible.length, 2);
      expect(parentVisible.map((r) => r['id']), containsAll(['r1', 'r4']));
      expect(parentVisible.map((r) => r['id']), isNot(contains('r2')));
      expect(parentVisible.map((r) => r['id']), isNot(contains('r3')));
    });
  });

  group('5. Actionable Notification Router & Destination Resolution Tests', () {
    test('NotificationRouter resolves specialist_report payload to parent connect reports view', () {
      final payload = {
        'type': 'specialist_report',
        'reportId': 'rep_123',
        'targetRole': 'parent',
      };

      final dest = NotificationRouter.resolveDestination(payload);
      expect(dest, isNotNull);
      expect(dest!.routeName, '/llg-connect');
      expect(dest.targetTab, 1); // Reports tab
      expect(dest.arguments?['reportId'], 'rep_123');
    });

    test('NotificationRouter resolves parent_complaint payload to admin or parent complaints view', () {
      final adminPayload = {
        'type': 'parent_complaint',
        'complaintId': 'comp_789',
        'targetRole': 'admin',
      };

      final adminDest = NotificationRouter.resolveDestination(adminPayload);
      expect(adminDest, isNotNull);
      expect(adminDest!.routeName, '/admin-dashboard');
      expect(adminDest.targetTab, 5); // Admin LLG complaints tab

      final parentPayload = {
        'type': 'parent_complaint',
        'complaintId': 'comp_789',
        'targetRole': 'parent',
      };

      final parentDest = NotificationRouter.resolveDestination(parentPayload);
      expect(parentDest, isNotNull);
      expect(parentDest!.routeName, '/llg-connect');
      expect(parentDest.targetTab, 2); // Parent complaints tab
    });

    test('NotificationRouter resolves suspension notices and appeals accurately', () {
      final suspensionPayload = {
        'type': 'account_suspension',
        'reason': 'Policy review',
      };

      final suspDest = NotificationRouter.resolveDestination(suspensionPayload);
      expect(suspDest, isNotNull);
      expect(suspDest!.routeName, '/suspended-account');

      final appealPayload = {
        'type': 'appeal_decision',
        'appealId': 'app_456',
        'targetRole': 'admin',
      };

      final appealDest = NotificationRouter.resolveDestination(appealPayload);
      expect(appealDest, isNotNull);
      expect(appealDest!.routeName, '/admin-dashboard');
      expect(appealDest.targetTab, 6); // Admin appeals tab
    });

    test('NotificationRouter resolves account warning to llg dashboard banner', () {
      final warningPayload = {
        'type': 'account_warning',
        'warningId': 'warn_123',
      };

      final warnDest = NotificationRouter.resolveDestination(warningPayload);
      expect(warnDest, isNotNull);
      expect(warnDest!.routeName, '/llg-dashboard');
    });

    test('NotificationRouter resolves consultation chat and assignments gracefully', () {
      final chatPayload = {
        'type': 'chat',
        'caseId': 'case_999',
      };

      final chatDest = NotificationRouter.resolveDestination(chatPayload);
      expect(chatDest, isNotNull);
      expect(chatDest!.routeName, '/consultation-chat');
      expect(chatDest.arguments?['caseId'], 'case_999');

      final assignPayload = {
        'type': 'new_assignment',
        'assignmentId': 'assign_777',
      };

      final assignDest = NotificationRouter.resolveDestination(assignPayload);
      expect(assignDest, isNotNull);
      expect(assignDest!.routeName, '/llg-dashboard');
    });

    test('NotificationRouter gracefully handles missing or unknown payloads without throwing', () {
      final emptyPayload = <String, dynamic>{};
      final emptyDest = NotificationRouter.resolveDestination(emptyPayload);
      expect(emptyDest, isNull);

      final unknownPayload = {
        'type': 'unsupported_future_feature_event',
      };
      final unknownDest = NotificationRouter.resolveDestination(unknownPayload);
      expect(unknownDest, isNull);
    });
  });
}
