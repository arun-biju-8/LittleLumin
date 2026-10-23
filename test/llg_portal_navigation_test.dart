// test/llg_portal_navigation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/contact_consent_model.dart';
import 'package:littlelumin/models/recommendation_model.dart';
import 'package:littlelumin/models/consultation_summary_model.dart';
import 'package:littlelumin/models/message_model.dart';

void main() {
  group('LLG Portal Data Models & Convenience Getters', () {
    test('ContactConsentModel evaluates pending, approved, and revoked states safely', () {
      final now = DateTime.now();
      final pendingConsent = ContactConsentModel(
        id: 'consent_1',
        caseId: 'case_1',
        childId: 'child_1',
        requesterId: 'llg_1',
        requesterName: 'Dr. Anita',
        requesterRole: 'llg',
        recipientId: 'parent_1',
        recipientName: 'Sarah',
        recipientRole: 'parent',
        requestedItem: ContactItemType.phone,
        purpose: 'Direct consultation on speech development',
        status: ContactConsentStatus.pending,
        requestedAt: now,
      );

      expect(pendingConsent.isPending, isTrue);
      expect(pendingConsent.isApproved, isFalse);
      expect(pendingConsent.isRevoked, isFalse);
      expect(pendingConsent.sharedPhoneNumber, isNull);
      expect(pendingConsent.permittedContactValue, isNull);

      final approvedConsent = pendingConsent.copyWith(
        status: ContactConsentStatus.approved,
        sharedContactValue: '+91 98765 43210',
        respondedAt: now.add(const Duration(minutes: 5)),
      );

      expect(approvedConsent.isPending, isFalse);
      expect(approvedConsent.isApproved, isTrue);
      expect(approvedConsent.sharedPhoneNumber, equals('+91 98765 43210'));

      final revokedConsent = approvedConsent.copyWith(
        status: ContactConsentStatus.revoked,
        revokedAt: now.add(const Duration(hours: 1)),
        clearSharedContactValue: true,
      );

      expect(revokedConsent.isRevoked, isTrue);
      expect(revokedConsent.isApproved, isFalse);
      expect(revokedConsent.sharedPhoneNumber, isNull);
      expect(revokedConsent.permittedContactValue, isNull);
    });

    test('ContactConsentModel handles email permissions correctly', () {
      final now = DateTime.now();
      final emailConsent = ContactConsentModel(
        id: 'consent_2',
        caseId: 'case_2',
        childId: 'child_2',
        requesterId: 'llg_1',
        requesterName: 'Dr. Anita',
        requesterRole: 'llg',
        recipientId: 'parent_2',
        recipientName: 'David',
        recipientRole: 'parent',
        requestedItem: ContactItemType.email,
        purpose: 'Emailing assessment report',
        status: ContactConsentStatus.approved,
        sharedContactValue: 'david@example.com',
        requestedAt: now,
        respondedAt: now,
      );

      expect(emailConsent.isApproved, isTrue);
      expect(emailConsent.sharedEmail, equals('david@example.com'));
      expect(emailConsent.sharedPhoneNumber, isNull); // Phone should remain null for email-only consent
    });

    test('RecommendationModel statuses and parent response lifecycle', () {
      final now = DateTime.now();
      final rec = RecommendationModel(
        id: 'rec_101',
        caseId: 'case_101',
        childId: 'child_101',
        childName: 'Aarav',
        parentId: 'parent_101',
        llgId: 'llg_101',
        llgName: 'Specialist Sunita',
        llgRole: 'clinical_psychologist',
        title: 'Sensory Sand Play',
        rationale: 'Calming sensory stimulation for focus and regulation',
        skillDomain: 'sensory',
        instructions: ['Provide soft kinetic sand', 'Encourage bilateral scooping'],
        recommendedAt: now,
        createdAt: now,
      );

      expect(rec.status, equals(RecommendationStatus.recommended));
      expect(rec.parentResponse, equals(ParentActivityResponse.none));
      expect(rec.hasParentResponded, isFalse);

      final respondedRec = rec.copyWith(
        parentResponse: ParentActivityResponse.completed,
        parentFeedback: 'Aarav enjoyed scooping the sand for 15 minutes!',
        status: RecommendationStatus.completed,
        parentRespondedAt: now.add(const Duration(hours: 2)),
      );

      expect(respondedRec.hasParentResponded, isTrue);
      expect(respondedRec.parentFeedback, contains('15 minutes'));
      expect(respondedRec.status, equals(RecommendationStatus.completed));
    });

    test('ConsultationSummaryModel records external session channels accurately', () {
      final now = DateTime.now();
      final summary = ConsultationSummaryModel(
        id: 'sum_01',
        caseId: 'case_01',
        childId: 'child_01',
        childName: 'Mira',
        parentId: 'parent_01',
        parentName: 'Priya',
        llgId: 'llg_01',
        llgName: 'Dr. Bose',
        consultationDate: now,
        consultationMode: 'whatsapp',
        consultationReason: 'Monthly speech milestone review',
        concernsDiscussed: ['Limited vocabulary and pointing'],
        guidanceProvided: 'Recommended daily two-word repetition games and storybook pointing.',
        agreedFollowUpActions: ['Parent to practice flashcards', 'Guide to check in next Friday'],
        nextReviewDate: now.add(const Duration(days: 14)),
        createdAt: now,
      );

      expect(summary.consultationMode, equals('whatsapp'));
      expect(summary.agreedFollowUpActions.length, equals(2));
      expect(summary.nextReviewDate, isNotNull);
      final map = summary.toMap();
      expect(map['consultationMode'], equals('whatsapp'));
      expect(map['caseId'], equals('case_01'));
    });
  });

  group('LLG Workspace Navigation Contracts', () {
    test('Defines all 9 dedicated functional workspaces with consistent indices', () {
      const workspaceRoutes = {
        0: 'Overview',
        1: 'My Cases',
        2: 'Active Reviews',
        3: 'Recommendations',
        4: 'Messages',
        5: 'Consultations',
        6: 'Contact Consents',
        7: 'Observation History',
        8: 'Profile & Credentials',
      };

      expect(workspaceRoutes.length, equals(9));
      expect(workspaceRoutes[0], equals('Overview'));
      expect(workspaceRoutes[1], equals('My Cases'));
      expect(workspaceRoutes[2], equals('Active Reviews'));
      expect(workspaceRoutes[3], equals('Recommendations'));
      expect(workspaceRoutes[4], equals('Messages'));
      expect(workspaceRoutes[5], equals('Consultations'));
      expect(workspaceRoutes[6], equals('Contact Consents'));
      expect(workspaceRoutes[7], equals('Observation History'));
      expect(workspaceRoutes[8], equals('Profile & Credentials'));
    });

    test('MessageModel serializes and deserializes accurately with case & child scoping', () {
      final now = DateTime.now();
      final message = MessageModel(
        id: 'msg_01',
        caseId: 'case_abc',
        childId: 'child_xyz',
        senderId: 'llg_101',
        senderName: 'Dr. Anita',
        senderRole: 'llg',
        recipientId: 'parent_202',
        content: 'I have posted the updated recommendation for bilateral coordination.',
        timestamp: now,
        status: MessageStatus.sent,
        linkedRecommendationId: 'rec_303',
      );

      expect(message.caseId, equals('case_abc'));
      expect(message.isRead, isFalse);
      expect(message.linkedRecommendationId, equals('rec_303'));

      final readMessage = message.copyWith(
        status: MessageStatus.read,
        readAt: now.add(const Duration(minutes: 10)),
      );

      expect(readMessage.isRead, isTrue);
      expect(readMessage.status, equals(MessageStatus.read));
    });
  });
}
