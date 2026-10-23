// test/parent_llg_collaboration_experience_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/specialist_case_model.dart';
import 'package:littlelumin/models/recommendation_model.dart';
import 'package:littlelumin/models/contact_consent_model.dart';
import 'package:littlelumin/models/message_model.dart';
import 'package:littlelumin/screens/parent/tabs/more_tab.dart';
import 'package:littlelumin/screens/parent/home/widgets/specialist_support_card.dart';
import 'package:littlelumin/screens/parent/llg_connect_page.dart';
import 'package:littlelumin/screens/chat/chat_screen.dart';
import 'package:littlelumin/services/specialist_case_service.dart';
import 'package:littlelumin/services/messaging_service.dart';

// Mock SpecialistCaseService for testing SpecialistSupportCard states
class MockSpecialistCaseService extends SpecialistCaseService {
  final Stream<List<SpecialistCaseModel>> _stream;

  MockSpecialistCaseService(this._stream);

  @override
  Stream<List<SpecialistCaseModel>> getParentCasesStream(String parentId, {String? childId}) {
    return _stream;
  }
}

// Mock MessagingService for testing ChatScreen states
class MockMessagingService extends MessagingService {
  final Stream<List<MessageModel>> _messagesStream;

  MockMessagingService(this._messagesStream);

  @override
  Stream<List<MessageModel>> getMessagesStream(String caseId) {
    return _messagesStream;
  }
}

void main() {
  final testChild = ChildModel(
    childId: 'child_aarav_01',
    parentId: 'parent_sanjay_01',
    name: 'Aarav',
    dateOfBirth: DateTime(DateTime.now().year - 4, 3, 15),
    gender: 'Male',
    vabsScores: {'Cognitive': 76.0, 'Language': 70.0, 'Motor': 74.0},
    createdAt: DateTime(2023, 1, 1),
  );

  final activeCase = SpecialistCaseModel(
    caseId: 'child_aarav_01_llg_priya_01',
    parentId: 'parent_sanjay_01',
    parentName: 'Sanjay Kumar',
    childId: 'child_aarav_01',
    childName: 'Aarav',
    childAgeYears: 4,
    specialistId: 'llg_priya_01',
    specialistName: 'Dr. Priya Sharma',
    specialistRole: 'Pediatric Development Guide',
    purpose: 'Speech articulation and fine motor coordination support',
    status: CaseStatus.active,
    authorizedDataCategories: ['vabs_scores', 'milestones', 'activities'],
    consentedAt: DateTime(2026, 10, 1),
    statusUpdatedAt: DateTime(2026, 10, 1),
    expiresAt: DateTime(2026, 10, 1).add(const Duration(days: 90)),
    consentNoticeVersion: 'v1.0-dpdp',
    createdAt: DateTime(2026, 10, 1),
  );

  final pendingCase = SpecialistCaseModel(
    caseId: 'child_aarav_01_llg_anita_01',
    parentId: 'parent_sanjay_01',
    parentName: 'Sanjay Kumar',
    childId: 'child_aarav_01',
    childName: 'Aarav',
    childAgeYears: 4,
    specialistId: 'llg_anita_01',
    specialistName: 'Anita Desai',
    specialistRole: 'Early Learning Specialist',
    purpose: 'Sensory play guidance',
    status: CaseStatus.pending,
    authorizedDataCategories: ['milestones'],
    consentedAt: DateTime(2026, 10, 20),
    statusUpdatedAt: DateTime(2026, 10, 20),
    expiresAt: DateTime(2026, 10, 20).add(const Duration(days: 90)),
    consentNoticeVersion: 'v1.0-dpdp',
    createdAt: DateTime(2026, 10, 20),
  );

  group('Parent Navigation: Specialist & Support Integration', () {
    testWidgets('MoreTab renders dedicated SPECIALIST & SUPPORT section with all navigation items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoreTab(
              children: [testChild],
              activeChild: testChild,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify header
      expect(find.text('SPECIALIST & SUPPORT'), findsOneWidget);

      // Verify the 3 dedicated navigation items
      expect(find.text('Specialist & Support Hub'), findsOneWidget);
      expect(find.text('Connect with certified LittleLumin Guides (LLG)'), findsOneWidget);

      expect(find.text('Guide Recommendations'), findsOneWidget);
      expect(find.text('Personalized developmental activity plans'), findsOneWidget);

      expect(find.text('Contact Sharing & Consent'), findsOneWidget);
      expect(find.text('Review pending requests and manage permissions'), findsOneWidget);
    });
  });

  group('SpecialistSupportCard States on Parent Home Dashboard', () {
    testWidgets('Renders active guide details, case status, Message Guide, and Recommendations buttons', (tester) async {
      final mockService = MockSpecialistCaseService(
        Stream.value([activeCase]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpecialistSupportCard(
                activeChild: testChild,
                caseService: mockService,
                parentId: 'parent_sanjay_01',
                parentName: 'Sanjay Kumar',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ASSIGNED SPECIALIST'), findsOneWidget);
      expect(find.text('Dr. Priya Sharma'), findsOneWidget);
      expect(find.text('Pediatric Development Guide'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.textContaining('Speech articulation and fine motor'), findsOneWidget);
      expect(find.text('Message Guide'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);
    });

    testWidgets('Renders pending review card when consultation request is pending', (tester) async {
      final mockService = MockSpecialistCaseService(
        Stream.value([pendingCase]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpecialistSupportCard(
                activeChild: testChild,
                caseService: mockService,
                parentId: 'parent_sanjay_01',
                parentName: 'Sanjay Kumar',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('CONSULTATION IN REVIEW'), findsOneWidget);
      expect(find.text('PENDING REVIEW'), findsOneWidget);
      expect(find.textContaining('Anita Desai'), findsOneWidget);
      expect(find.text('View Status'), findsOneWidget);
    });

    testWidgets('Renders discovery card when no active or pending specialist case exists', (tester) async {
      final mockService = MockSpecialistCaseService(
        Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpecialistSupportCard(
                activeChild: testChild,
                caseService: mockService,
                parentId: 'parent_sanjay_01',
                parentName: 'Sanjay Kumar',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SPECIALIST GUIDANCE AVAILABLE'), findsOneWidget);
      expect(find.textContaining('Connect with certified LittleLumin Guides'), findsOneWidget);
      expect(find.text('Connect with a Guide'), findsOneWidget);
    });

    testWidgets('Renders SizedBox.shrink() when activeChild is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpecialistSupportCard(
              activeChild: null,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('ASSIGNED SPECIALIST'), findsNothing);
      expect(find.text('SPECIALIST GUIDANCE AVAILABLE'), findsNothing);
    });
  });

  group('LLGConnectPage Specialist & Support Hub Tabs', () {
    testWidgets('Renders all 5 navigation tabs and header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LLGConnectPage(
            initialChildId: testChild.childId,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Specialist & Support'), findsOneWidget);
      expect(find.text('Overview & Guide'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('Contact Requests'), findsOneWidget);
      expect(find.text('Find Specialists'), findsOneWidget);
      expect(find.text('Session Summaries'), findsOneWidget);
    });

    testWidgets('Supports initialSection navigation directly to recommendations tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LLGConnectPage(
            initialChildId: testChild.childId,
            initialSection: 'recommendations',
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Specialist & Support'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);
    });

    testWidgets('Supports initialSection navigation directly to contact consents tab', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LLGConnectPage(
            initialChildId: testChild.childId,
            initialSection: 'consents',
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Specialist & Support'), findsOneWidget);
      expect(find.text('Contact Requests'), findsOneWidget);
    });
  });

  group('ChatScreen Error & Empty States', () {
    testWidgets('Renders error state with retry button when stream emits error', (tester) async {
      final controller = StreamController<List<MessageModel>>();
      final mockMessaging = MockMessagingService(controller.stream);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            specialistCase: activeCase,
            currentUserId: 'parent_sanjay_01',
            currentUserName: 'Sanjay Kumar',
            currentUserRole: 'parent',
            otherParticipantName: 'Dr. Priya Sharma',
            otherParticipantRole: 'Pediatric Development Guide',
            messagingService: mockMessaging,
          ),
        ),
      );

      // Emit error on stream
      controller.addError('Network connection lost to Firestore');
      await tester.pump();

      expect(find.text('Failed to load messages'), findsOneWidget);
      expect(find.textContaining('Network connection lost'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await controller.close();
    });

    testWidgets('Renders empty conversation state when no messages exist yet', (tester) async {
      final mockMessaging = MockMessagingService(
        Stream.value([]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            specialistCase: activeCase,
            currentUserId: 'parent_sanjay_01',
            currentUserName: 'Sanjay Kumar',
            currentUserRole: 'parent',
            otherParticipantName: 'Dr. Priya Sharma',
            otherParticipantRole: 'Pediatric Development Guide',
            messagingService: mockMessaging,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.textContaining('Send a note to start the conversation'), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
    });

    testWidgets('Renders messages list with correct sender bubble alignment', (tester) async {
      final now = DateTime(2026, 10, 23, 10, 0);
      final messages = [
        MessageModel(
          id: 'm1',
          caseId: activeCase.caseId,
          childId: activeCase.childId,
          senderId: 'llg_priya_01',
          senderName: 'Dr. Priya Sharma',
          senderRole: 'llg',
          recipientId: 'parent_sanjay_01',
          content: 'Hello Sanjay! How did Aarav do with the block stacking exercise?',
          timestamp: now,
          status: MessageStatus.delivered,
        ),
        MessageModel(
          id: 'm2',
          caseId: activeCase.caseId,
          childId: activeCase.childId,
          senderId: 'parent_sanjay_01',
          senderName: 'Sanjay Kumar',
          senderRole: 'parent',
          recipientId: 'llg_priya_01',
          content: 'He did very well, built a 5-block tower without falling!',
          timestamp: now.add(const Duration(minutes: 5)),
          status: MessageStatus.sent,
        ),
      ];

      final mockMessaging = MockMessagingService(
        Stream.value(messages),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            specialistCase: activeCase,
            currentUserId: 'parent_sanjay_01',
            currentUserName: 'Sanjay Kumar',
            currentUserRole: 'parent',
            otherParticipantName: 'Dr. Priya Sharma',
            otherParticipantRole: 'Pediatric Development Guide',
            messagingService: mockMessaging,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hello Sanjay! How did Aarav do with the block stacking exercise?'), findsOneWidget);
      expect(find.text('He did very well, built a 5-block tower without falling!'), findsOneWidget);
    });
  });

  group('Consent & Recommendation Lifecycle Business Rules', () {
    test('enforces DPDP consent status and audit metadata on model update', () {
      final now = DateTime.now();
      final consent = ContactConsentModel(
        id: 'consent_req_01',
        caseId: activeCase.caseId,
        childId: testChild.childId,
        requesterId: 'llg_priya_01',
        requesterName: 'Dr. Priya Sharma',
        requesterRole: 'llg',
        recipientId: 'parent_sanjay_01',
        recipientName: 'Sanjay Kumar',
        recipientRole: 'parent',
        requestedItem: ContactItemType.phone,
        status: ContactConsentStatus.pending,
        purpose: 'Direct voice coordination during difficult milestone sessions',
        requestedAt: now,
      );

      expect(consent.isPending, true);
      expect(consent.isApproved, false);
      expect(consent.sharedContactValue, isNull);

      // Parent accepts request and provides verified phone number
      final approvedConsent = consent.copyWith(
        status: ContactConsentStatus.approved,
        sharedContactValue: '+91 98765 43210',
        respondedAt: now.add(const Duration(minutes: 15)),
      );

      expect(approvedConsent.isPending, false);
      expect(approvedConsent.isApproved, true);
      expect(approvedConsent.sharedContactValue, '+91 98765 43210');
      expect(approvedConsent.permittedContactValue, '+91 98765 43210');

      // Parent declines request
      final declinedConsent = consent.copyWith(
        status: ContactConsentStatus.declined,
        declineOrRevokeReason: 'Prefer all communications inside LittleLumin chat.',
        respondedAt: now.add(const Duration(minutes: 5)),
      );

      expect(declinedConsent.isPending, false);
      expect(declinedConsent.isApproved, false);
      expect(declinedConsent.status, ContactConsentStatus.declined);
      expect(declinedConsent.sharedContactValue, isNull);
      expect(declinedConsent.declineOrRevokeReason, contains('inside LittleLumin chat'));
    });

    test('supports non-blaming recommendation responses with constructive parent feedback', () {
      final now = DateTime.now();
      final rec = RecommendationModel(
        id: 'rec_01',
        caseId: activeCase.caseId,
        childId: testChild.childId,
        childName: testChild.name,
        parentId: 'parent_sanjay_01',
        llgId: 'llg_priya_01',
        llgName: 'Dr. Priya Sharma',
        title: 'Two-Hand Bilateral Ball Rolling',
        rationale: 'Fosters motor symmetry and hand-eye gaze tracking',
        skillDomain: 'motor',
        instructions: ['Roll soft sensory ball back and forth across a low table'],
        materials: ['Soft foam ball'],
        durationMinutes: 10,
        frequency: 'Daily',
        status: RecommendationStatus.in_progress,
        recommendedAt: now,
        createdAt: now,
      );

      expect(rec.status, RecommendationStatus.in_progress);

      // Parent logs completed response
      final completedRec = rec.copyWith(
        status: RecommendationStatus.completed,
        parentResponse: ParentActivityResponse.completed,
        parentFeedback: 'Aarav caught the ball 8 times in a row! Great fun.',
        parentRespondedAt: now.add(const Duration(days: 1)),
      );

      expect(completedRec.status, RecommendationStatus.completed);
      expect(completedRec.parentResponse, ParentActivityResponse.completed);
      expect(completedRec.parentFeedback, contains('8 times in a row'));

      // Parent logs struggling feedback without penalty
      final struggledRec = rec.copyWith(
        parentResponse: ParentActivityResponse.struggled,
        parentFeedback: 'Lost interest quickly, got distracted by other toys.',
        parentRespondedAt: now.add(const Duration(days: 2)),
      );

      expect(struggledRec.parentResponse, ParentActivityResponse.struggled);
      expect(struggledRec.parentFeedback, contains('Lost interest'));
    });
  });
}
