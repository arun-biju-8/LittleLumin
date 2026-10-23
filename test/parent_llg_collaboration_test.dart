// test/parent_llg_collaboration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/recommendation_model.dart';
import 'package:littlelumin/models/message_model.dart';
import 'package:littlelumin/models/contact_consent_model.dart';
import 'package:littlelumin/models/consultation_summary_model.dart';

void main() {
  group('RecommendationModel Lifecycle & Responses', () {
    test('serializes and deserializes correctly with full metadata', () {
      final now = DateTime(2026, 10, 23, 10, 0);
      final rec = RecommendationModel(
        id: 'rec_123',
        caseId: 'case_456',
        childId: 'child_789',
        childName: 'Aarav',
        parentId: 'parent_101',
        llgId: 'llg_202',
        llgName: 'Dr. Priya Sharma',
        llgRole: 'learning_guide',
        title: 'Tactile Sand Sensory Practice',
        rationale: 'Strengthens fine motor pincer grasp and bilateral hand coordination.',
        skillDomain: 'motor',
        instructions: [
          'Spread fine sand in a shallow tray.',
          'Demonstrate letter curves with index finger.',
          'Have child trace matching patterns.',
        ],
        materials: ['Shallow tray', 'Sand or fine semolina'],
        durationMinutes: 15,
        frequency: 'Daily',
        safetyGuidance: 'Adult supervision required at all times.',
        status: RecommendationStatus.recommended,
        recommendedAt: now,
        reviewDate: now.add(const Duration(days: 7)),
        createdAt: now,
      );

      final map = rec.toMap();
      expect(map['title'], 'Tactile Sand Sensory Practice');
      expect(map['status'], 'recommended');
      expect(map['skillDomain'], 'motor');
      expect(map['instructions'].length, 3);

      final reconstructed = RecommendationModel.fromMap(map, 'rec_123');
      expect(reconstructed.id, 'rec_123');
      expect(reconstructed.title, rec.title);
      expect(reconstructed.llgName, 'Dr. Priya Sharma');
      expect(reconstructed.status, RecommendationStatus.recommended);
      expect(reconstructed.materials.length, 2);
    });

    test('supports non-blaming parent feedback: completed, partial, struggled, skipped', () {
      final now = DateTime(2026, 10, 23);
      final rec = RecommendationModel(
        id: 'rec_456',
        caseId: 'case_456',
        childId: 'child_789',
        childName: 'Aarav',
        parentId: 'parent_101',
        llgId: 'llg_202',
        llgName: 'Guide Anita',
        title: 'Bedtime Rhythm Tapping',
        rationale: 'Assists with auditory processing and self-regulation.',
        skillDomain: 'creative',
        instructions: ['Tap rhythmic patterns on soft pillow.'],
        status: RecommendationStatus.recommended,
        recommendedAt: now,
        createdAt: now,
        parentResponse: ParentActivityResponse.struggled,
        parentFeedback: 'Aarav was tired and became overwhelmed by the tempo.',
        parentRespondedAt: now.add(const Duration(hours: 4)),
      );

      final map = rec.toMap();
      expect(map['parentResponse'], 'struggled');
      expect(map['parentFeedback'], contains('overwhelmed'));

      final reconstructed = RecommendationModel.fromMap(map, 'rec_456');
      expect(reconstructed.parentResponse, ParentActivityResponse.struggled);

      // Verify non-punitive skipped feedback
      final skippedRec = rec.copyWith(
        parentResponse: ParentActivityResponse.skipped,
        skippedReason: 'Activity materials unavailable today, will resume tomorrow.',
        status: RecommendationStatus.paused,
      );
      expect(skippedRec.parentResponse, ParentActivityResponse.skipped);
      expect(skippedRec.skippedReason, contains('unavailable'));
      expect(skippedRec.status, RecommendationStatus.paused);
    });
  });

  group('MessageModel & Participant Authorization', () {
    test('creates and validates persistent two-way messages', () {
      final now = DateTime(2026, 10, 23, 11, 0);
      final msg = MessageModel(
        id: 'msg_001',
        caseId: 'case_456',
        childId: 'child_789',
        senderId: 'parent_101',
        senderName: 'Sanjay Kumar (Parent)',
        senderRole: 'parent',
        recipientId: 'llg_202',
        content: 'Hello Dr. Sharma, Aarav enjoyed the sand activity today!',
        timestamp: now,
        status: MessageStatus.sent,
      );

      final map = msg.toMap();
      expect(map['caseId'], 'case_456');
      expect(map['senderRole'], 'parent');
      expect(map['content'], contains('Aarav enjoyed'));
      expect(msg.isRead, false);

      final reconstructed = MessageModel.fromMap(map, 'msg_001');
      expect(reconstructed.id, 'msg_001');
      expect(reconstructed.senderName, 'Sanjay Kumar (Parent)');
      expect(reconstructed.isRead, false);

      // Verify read-receipt transition
      final readMsg = reconstructed.copyWith(
        status: MessageStatus.read,
        readAt: now.add(const Duration(minutes: 5)),
      );
      expect(readMsg.isRead, true);
      expect(readMsg.readAt, isNotNull);
    });
  });

  group('ContactConsentModel & Data Boundary Revocation', () {
    test('enforces explicit field-level consent and revocation', () {
      final now = DateTime(2026, 10, 23);
      final consent = ContactConsentModel(
        id: 'consent_case_456',
        caseId: 'case_456',
        childId: 'child_789',
        requesterId: 'llg_202',
        requesterName: 'Dr. Sharma',
        requesterRole: 'llg',
        recipientId: 'parent_101',
        recipientName: 'Sanjay Kumar',
        recipientRole: 'parent',
        requestedItem: ContactItemType.phone,
        status: ContactConsentStatus.approved,
        purpose: 'Direct WhatsApp and phone consultations for developmental coaching.',
        sharedContactValue: '+91 98765 43210',
        requestedAt: now,
        respondedAt: now.add(const Duration(minutes: 10)),
      );

      expect(consent.isApproved, true);
      expect(consent.sharedContactValue, '+91 98765 43210');

      // Test revocation wipes contact accessibility immediately
      final revokedConsent = consent.copyWith(
        status: ContactConsentStatus.revoked,
        revokedAt: now.add(const Duration(days: 2)),
        declineOrRevokeReason: 'Parent chose to keep communications strictly in-app.',
        clearSharedContactValue: true,
      );

      expect(revokedConsent.isApproved, false);
      expect(revokedConsent.sharedContactValue, isNull);
      expect(revokedConsent.permittedContactValue, isNull);
      expect(revokedConsent.status, ContactConsentStatus.revoked);
      expect(revokedConsent.declineOrRevokeReason, contains('strictly in-app'));
    });
  });

  group('ConsultationSummaryModel & External Session Tracking', () {
    test('records validated consultation summary with audit trail', () {
      final now = DateTime(2026, 10, 23, 15, 30);
      final summary = ConsultationSummaryModel(
        id: 'summary_001',
        caseId: 'case_456',
        childId: 'child_789',
        childName: 'Aarav',
        parentId: 'parent_101',
        parentName: 'Sanjay Kumar',
        llgId: 'llg_202',
        llgName: 'Dr. Sharma',
        consultationMode: 'WhatsApp',
        consultationDate: now,
        consultationReason: 'Monthly developmental milestone review',
        concernsDiscussed: ['Sensory sensitivity', 'Language articulation'],
        guidanceProvided: 'Recommended daily 15-minute sound-matching play and positive reinforcement.',
        parentQuestionsOrFeedback: 'Parent asked about strategies to ease bedtime transition anxiety.',
        agreedFollowUpActions: [
          'Try sound-matching cards twice a day.',
          'Document response in LittleLumin My Growth tab.',
          'Schedule follow-up session in 14 days.',
        ],
        nextReviewDate: now.add(const Duration(days: 14)),
        createdAt: now,
      );

      final map = summary.toMap();
      expect(map['consultationMode'], 'WhatsApp');
      expect(map['caseId'], 'case_456');
      expect(map['agreedFollowUpActions'].length, 3);

      final reconstructed = ConsultationSummaryModel.fromMap(map, 'summary_001');
      expect(reconstructed.id, 'summary_001');
      expect(reconstructed.llgName, 'Dr. Sharma');
      expect(reconstructed.consultationMode, 'WhatsApp');
      expect(reconstructed.agreedFollowUpActions.first, contains('sound-matching'));
    });
  });
}
