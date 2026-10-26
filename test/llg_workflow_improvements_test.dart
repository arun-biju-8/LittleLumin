// test/llg_workflow_improvements_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/specialist_case_model.dart';
import 'package:littlelumin/models/recommendation_model.dart';
import 'package:littlelumin/models/specialist_report_model.dart';
import 'package:littlelumin/screens/llg/send_recommendation_page.dart';
import 'package:littlelumin/screens/parent/recommendation_detail_screen.dart';
import 'package:littlelumin/screens/parent/home/widgets/specialist_support_card.dart';
import 'package:littlelumin/services/specialist_case_service.dart';

class MockSpecialistCaseServiceForTest extends SpecialistCaseService {
  final Stream<List<SpecialistCaseModel>> _stream;

  MockSpecialistCaseServiceForTest(this._stream);

  @override
  Stream<List<SpecialistCaseModel>> getParentCasesStream(String parentId, {String? childId}) {
    return _stream;
  }
}

void main() {
  final testChild = ChildModel(
    childId: 'child_101',
    parentId: 'parent_202',
    name: 'Aarav Kumar',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    createdAt: DateTime(2025, 1, 1),
  );

  final activeCase = SpecialistCaseModel(
    caseId: 'case_303',
    parentId: 'parent_202',
    parentName: 'Sunita Kumar',
    childId: 'child_101',
    childName: 'Aarav Kumar',
    childAgeYears: 4,
    specialistId: 'llg_404',
    specialistName: 'Dr. Priya Sharma',
    specialistRole: 'Developmental Specialist',
    purpose: 'Gross and fine motor coordination support',
    status: CaseStatus.active,
    authorizedDataCategories: ['activities', 'milestones', 'skill_scores'],
    consentedAt: DateTime(2026, 1, 1),
    statusUpdatedAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2026, 12, 31),
    consentNoticeVersion: 'v1.0-dpdp',
    createdAt: DateTime(2026, 1, 1),
  );

  final sampleRecommendation = RecommendationModel(
    id: 'rec_505',
    caseId: 'case_303',
    childId: 'child_101',
    childName: 'Aarav Kumar',
    parentId: 'parent_202',
    llgId: 'llg_404',
    llgName: 'Dr. Priya Sharma',
    llgRole: 'Developmental Specialist',
    title: 'Bilateral Balance Beam Walk',
    rationale: 'Enhance vestibular integration and bilateral motor planning.',
    skillDomain: 'motor',
    instructions: [
      'Place colorful painter tape in a straight line on the floor.',
      'Ask the child to place heel-to-toe while keeping arms outstretched like airplane wings.',
      'Celebrate each completed segment without touching outside the tape line.',
    ],
    materials: ['Painter tape', 'Open floor space'],
    durationMinutes: 15,
    frequency: 'Daily',
    safetyGuidance: 'Ensure the floor surface is dry and free of tripping hazards.',
    recommendedAt: DateTime(2026, 10, 20),
    status: RecommendationStatus.recommended,
    createdAt: DateTime(2026, 10, 20),
  );

  group('Task 1: Responsive Layouts and Overflow Prevention', () {
    testWidgets('SpecialistSupportCard renders cleanly without overflow on narrow 320px viewport', (tester) async {
      final controller = StreamController<List<SpecialistCaseModel>>.broadcast();

      await tester.binding.setSurfaceSize(const Size(320, 600));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpecialistSupportCard(
                activeChild: testChild,
                parentId: 'parent_202',
                parentName: 'Sunita Kumar',
                caseService: MockSpecialistCaseServiceForTest(controller.stream),
              ),
            ),
          ),
        ),
      );

      controller.add([activeCase]);
      await tester.pumpAndSettle();

      expect(find.text('Dr. Priya Sharma'), findsOneWidget);
      expect(find.text('Message Guide'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);

      // Verify no overflow error was dispatched
      expect(tester.takeException(), isNull);

      await controller.close();
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('SpecialistSupportCard renders empty state cleanly on narrow viewport', (tester) async {
      final controller = StreamController<List<SpecialistCaseModel>>.broadcast();

      await tester.binding.setSurfaceSize(const Size(320, 600));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpecialistSupportCard(
                activeChild: testChild,
                parentId: 'parent_202',
                parentName: 'Sunita Kumar',
                caseService: MockSpecialistCaseServiceForTest(controller.stream),
              ),
            ),
          ),
        ),
      );

      controller.add([]);
      await tester.pumpAndSettle();

      expect(find.text('Specialist & Support'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await controller.close();
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('Task 2: Specialist Report Model and Parent Association', () {
    test('SpecialistReportModel correctly includes parentId and sharing flags', () {
      final report = SpecialistReportModel(
        id: 'rep_1',
        caseId: 'case_303',
        childId: 'child_101',
        childName: 'Aarav Kumar',
        parentId: 'parent_202',
        specialistId: 'llg_404',
        specialistName: 'Dr. Priya Sharma',
        reportType: ReportType.progress,
        title: 'Comprehensive Milestone Evaluation',
        summary: 'Progress is steady across cognitive and motor domains.',
        domainScores: {'motor': 75.0, 'cognitive': 80.0},
        keyFindings: ['Good balance'],
        strengths: ['Focus'],
        growthAreas: ['Coordination'],
        recommendations: ['Daily tape walk'],
        status: SpecialistReportStatus.finalized,
        generatedAt: DateTime(2026, 10, 20),
        finalizedAt: DateTime(2026, 10, 21),
      );

      final map = report.toMap();
      expect(map['parentId'], 'parent_202');
      expect(map['status'], 'finalized');
      expect(map['isSharedWithParent'], true);
      expect(map['isShared'], true);

      final reconstructed = SpecialistReportModel.fromMap('rep_1', map);
      expect(reconstructed.parentId, 'parent_202');
      expect(reconstructed.isFinalized, isTrue);
      expect(reconstructed.isShared, isTrue);
    });
  });

  group('Task 3: Step-by-Step Instruction Editor in SendRecommendationPage', () {
    testWidgets('SendRecommendationPage renders toggle and defaults to paragraph mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SendRecommendationPage(
              child: testChild,
              specialistCase: activeCase,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step-by-Step Instructions *'), findsOneWidget);
      expect(find.text('Paragraph'), findsOneWidget);
      expect(find.text('Step 1'), findsNothing); // OFF initially
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Toggling Numbered Steps ON exposes dynamic step editor with (+) button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SendRecommendationPage(
              child: testChild,
              specialistCase: activeCase,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Numbered Steps switch
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Now Step 1 should be visible with Numbered Steps label and Add Step button
      expect(find.text('Numbered Steps'), findsOneWidget);
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Add Step'), findsOneWidget);

      // Tap Add Step to dynamically add Step 2
      await tester.tap(find.text('Add Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);

      // Tap Add Step again to add Step 3
      await tester.tap(find.text('Add Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 3'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Removing a step automatically renumbers subsequent steps', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SendRecommendationPage(
              child: testChild,
              specialistCase: activeCase,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to structured steps
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Add Step 2
      await tester.tap(find.text('Add Step'));
      await tester.pumpAndSettle();

      // Delete Step 1 (the first delete_outline icon)
      final removeButtons = find.byIcon(Icons.delete_outline);
      expect(removeButtons, findsNWidgets(2));

      await tester.tap(removeButtons.first);
      await tester.pumpAndSettle();

      // Should now have exactly 1 step labeled 'Step 1'
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsNothing);

      await tester.binding.setSurfaceSize(null);
    });
  });

  group('Task 4: Interactive Parent-Facing Recommendation Detail Screen', () {
    testWidgets('RecommendationDetailScreen displays full activity info and numbered steps', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationDetailScreen(
              recommendation: sampleRecommendation,
              childId: testChild.childId,
              childName: testChild.name,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and domain
      expect(find.text('Bilateral Balance Beam Walk'), findsOneWidget);
      expect(find.text('MOTOR'), findsOneWidget);

      // Check specialist info
      expect(find.textContaining('Dr. Priya Sharma'), findsOneWidget);

      // Check duration & frequency
      expect(find.textContaining('15 Minutes'), findsOneWidget);
      expect(find.textContaining('Daily'), findsOneWidget);

      // Check clinical rationale
      expect(find.text('Enhance vestibular integration and bilateral motor planning.'), findsOneWidget);

      // Check materials
      expect(find.text('Painter tape'), findsOneWidget);
      expect(find.text('Open floor space'), findsOneWidget);

      // Check numbered steps
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
      expect(find.text('Step 3'), findsOneWidget);
      expect(find.text('Place colorful painter tape in a straight line on the floor.'), findsOneWidget);

      // Check safety guidance
      expect(find.text('Ensure the floor surface is dry and free of tripping hazards.'), findsOneWidget);

      // Check bottom action button
      expect(find.text('Submit Child Response & Feedback'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Tapping Submit Child Response button opens interactive feedback sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationDetailScreen(
              recommendation: sampleRecommendation,
              childId: testChild.childId,
              childName: testChild.name,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.text('Submit Child Response & Feedback');
      await tester.scrollUntilVisible(submitBtn, 300);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Bottom sheet contents
      expect(find.text('Record Child Response'), findsOneWidget);
      expect(find.text('1. Activity Completion Outcome *'), findsOneWidget);
      expect(find.text('Completed Successfully'), findsOneWidget);
      expect(find.text('Partially Completed'), findsOneWidget);
      expect(find.text('Struggled / Needed Help'), findsOneWidget);
      expect(find.text('Skipped for Now'), findsOneWidget);
      expect(find.text('Confirm & Save Response'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });

  group('Task 5: LLG Completed Activities & Feedback Inspection', () {
    test('SpecialistCaseModel correctly validates data access permissions', () {
      expect(activeCase.canAccessChildData, isTrue);
      expect(activeCase.isCategoryAuthorized('activities'), isTrue);
      expect(activeCase.isCategoryAuthorized('skill_scores'), isTrue);
      expect(activeCase.isCategoryAuthorized('unauthorized_category'), isFalse);

      final revokedCase = SpecialistCaseModel(
        caseId: 'case_revoked',
        parentId: 'parent_202',
        parentName: 'Sunita Kumar',
        childId: 'child_101',
        childName: 'Aarav Kumar',
        childAgeYears: 4,
        specialistId: 'llg_404',
        specialistName: 'Dr. Priya Sharma',
        purpose: 'Review',
        status: CaseStatus.revoked,
        authorizedDataCategories: ['activities'],
        consentedAt: DateTime(2026, 1, 1),
        statusUpdatedAt: DateTime(2026, 2, 1),
        revokedAt: DateTime(2026, 2, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      expect(revokedCase.canAccessChildData, isFalse);
      expect(revokedCase.isCategoryAuthorized('activities'), isFalse);
    });

    test('RecommendationModel captures parent response, feedback, and review fields', () {
      final respondedRec = sampleRecommendation.copyWith(
        parentResponse: ParentActivityResponse.completed,
        parentFeedback: 'Aarav completed all three balance segments with great enthusiasm!',
        parentRespondedAt: DateTime(2026, 10, 22),
        status: RecommendationStatus.completed,
        llgFeedback: 'Excellent bilateral control and vestibular stability observed.',
        nextSteps: 'Advance to single-leg balance and beam obstacle stepping.',
      );

      expect(respondedRec.hasParentResponded, isTrue);
      expect(respondedRec.status, RecommendationStatus.completed);
      expect(respondedRec.parentResponse, ParentActivityResponse.completed);
      expect(respondedRec.parentFeedback, contains('enthusiasm'));
      expect(respondedRec.llgFeedback, contains('bilateral control'));
      expect(respondedRec.nextSteps, contains('single-leg balance'));

      final map = respondedRec.toMap();
      expect(map['parentResponse'], 'completed');
      expect(map['parentFeedback'], contains('enthusiasm'));
      expect(map['llgFeedback'], contains('bilateral control'));
      expect(map['nextSteps'], contains('single-leg balance'));
    });
  });
}
