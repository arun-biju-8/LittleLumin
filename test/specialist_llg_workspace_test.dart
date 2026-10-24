// test/specialist_llg_workspace_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:littlelumin/models/specialist_report_model.dart';
import 'package:littlelumin/models/specialist_case_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/services/report_pdf_service.dart';
import 'package:littlelumin/widgets/specialist_messaging_panel.dart';
import 'package:littlelumin/screens/llg/report_preview_dialog.dart';
import 'package:littlelumin/screens/llg/report_center_page.dart';

void main() {
  final now = DateTime(2026, 10, 24);

  final testChild = ChildModel(
    childId: 'child_diya_101',
    parentId: 'parent_meera_101',
    name: 'Diya Patel',
    dateOfBirth: DateTime(2021, 3, 15),
    gender: 'Female',
    createdAt: now.subtract(const Duration(days: 400)),
  );

  final testCase = SpecialistCaseModel(
    caseId: 'case_diya_spec_01',
    parentId: 'parent_meera_101',
    parentName: 'Meera Patel',
    childId: 'child_diya_101',
    childName: 'Diya Patel',
    childAgeYears: 5,
    specialistId: 'spec_ananya_01',
    specialistName: 'Dr. Ananya Roy',
    purpose: 'Fine Motor & Sensory Regulation Guidance',
    authorizedDataCategories: ['skill_scores', 'activity_history', 'observations'],
    consentNoticeVersion: 'v1.0-dpdp',
    consentedAt: now.subtract(const Duration(days: 20)),
    status: CaseStatus.active,
    statusUpdatedAt: now.subtract(const Duration(days: 20)),
    acceptedAt: now.subtract(const Duration(days: 20)),
    expiresAt: now.add(const Duration(days: 70)),
    createdAt: now.subtract(const Duration(days: 20)),
  );

  final revokedCase = SpecialistCaseModel(
    caseId: 'case_diya_revoked_02',
    parentId: 'parent_meera_101',
    parentName: 'Meera Patel',
    childId: 'child_diya_101',
    childName: 'Diya Patel',
    childAgeYears: 5,
    specialistId: 'spec_ananya_01',
    specialistName: 'Dr. Ananya Roy',
    purpose: 'Sensory Observation',
    authorizedDataCategories: ['skill_scores'],
    consentNoticeVersion: 'v1.0-dpdp',
    consentedAt: now.subtract(const Duration(days: 60)),
    status: CaseStatus.revoked,
    statusUpdatedAt: now.subtract(const Duration(days: 2)),
    revokedAt: now.subtract(const Duration(days: 2)),
    revocationReason: 'Parent withdrew consent under DPDP guidelines',
    createdAt: now.subtract(const Duration(days: 60)),
  );

  group('1. SpecialistReportModel & 5 Report Types Tests', () {
    test('Verifies all 5 ReportType enums have correct display names and descriptions', () {
      expect(ReportType.progress.displayName, equals('Child Development Progress Report'));
      expect(ReportType.activityPerformance.displayName, equals('Activity Performance Report'));
      expect(ReportType.parentEngagement.displayName, equals('Parent Engagement Report'));
      expect(ReportType.clinicalObservation.displayName, equals('Specialist Clinical & Observation Report'));
      expect(ReportType.caseSummary.displayName, equals('Consolidated Case Summary Report'));

      expect(ReportType.progress.shortName, equals('Progress'));
      expect(ReportType.clinicalObservation.shortName, equals('Clinical Notes'));
    });

    test('Serializes and deserializes comprehensive report model with period and module metadata', () {
      final report = SpecialistReportModel(
        id: 'rep_diya_202',
        caseId: testCase.caseId,
        childId: testCase.childId,
        childName: testCase.childName,
        specialistId: testCase.specialistId,
        specialistName: testCase.specialistName,
        title: 'Child Development Progress Report - Diya Patel',
        summary: 'Diya shows steady progress in fine motor precision and bilaterial coordination.',
        reportType: ReportType.progress,
        periodStartDate: now.subtract(const Duration(days: 30)),
        periodEndDate: now,
        periodLabel: 'Last 30 Days (Oct 2026)',
        domainScores: {
          'cognitive': 82.0,
          'language': 75.0,
          'motor': 68.5,
          'social': 79.0,
          'emotional': 84.0,
          'creative': 88.0,
        },
        includedSections: ['Domain Scores', 'Activities', 'Parent Feedback', 'Care Plan Recommendations'],
        dataSources: ['Skill Profiles Ledger', 'Specialist Observation Notes'],
        keyFindings: ['Significant pencil grasp stabilization.', 'Self-regulation routine established.'],
        strengths: ['Creative: 88.0%', 'Emotional: 84.0%'],
        growthAreas: ['Motor: 68.5% (Targeted for intervention)'],
        recommendations: ['Playdough squeeze and finger pinch exercises daily.', '10 min calming sensory breaks.'],
        status: SpecialistReportStatus.finalized,
        generatedAt: now,
      );

      final map = report.toMap();
      expect(map['reportType'], equals('progress'));
      expect(map['periodLabel'], equals('Last 30 Days (Oct 2026)'));
      expect(map['includedSections'], contains('Domain Scores'));
      expect(map['dataSources'], contains('Skill Profiles Ledger'));

      final reconstructed = SpecialistReportModel.fromMap('rep_diya_202', map);
      expect(reconstructed.reportType, equals(ReportType.progress));
      expect(reconstructed.periodLabel, equals('Last 30 Days (Oct 2026)'));
      expect(reconstructed.domainScores['motor'], equals(68.5));
      expect(reconstructed.status, equals(SpecialistReportStatus.finalized));
    });
  });

  group('2. ReportPdfService Print-Ready PDF Generation Tests', () {
    test('Generates valid multi-page print-ready PDF bytes with LittleLumin branding', () async {
      final report = SpecialistReportModel(
        id: 'rep_pdf_test_303',
        caseId: testCase.caseId,
        childId: testCase.childId,
        childName: testCase.childName,
        specialistId: testCase.specialistId,
        specialistName: testCase.specialistName,
        title: 'Child Development Progress Report - Diya Patel',
        summary: 'Executive summary synthesized from verified activity milestones and clinical observations.',
        reportType: ReportType.progress,
        periodStartDate: now.subtract(const Duration(days: 30)),
        periodEndDate: now,
        periodLabel: 'Last 30 Days',
        domainScores: {
          'cognitive': 80.0,
          'language': 70.0,
          'motor': 65.0,
          'social': 75.0,
          'emotional': 80.0,
          'creative': 85.0,
        },
        activityRecords: [
          {'activityTitle': 'Finger Pinch Grasp', 'skillDomain': 'motor', 'appliedScoreDelta': 4.5, 'scoreAfter': 65.0},
          {'activityTitle': 'Story Sequence Cards', 'skillDomain': 'cognitive', 'appliedScoreDelta': 3.0, 'scoreAfter': 80.0},
        ],
        observationRecords: [
          {'observation': 'Demonstrates focused attention during two-handed manipulation tasks.', 'severity': 'mild'},
        ],
        keyFindings: ['Motor milestones advancing on trajectory.'],
        strengths: ['High creativity and expressive communication.'],
        growthAreas: ['Fine motor finger isolation needs continued daily practice.'],
        recommendations: ['Daily finger tracing and bead threading.'],
        specialistNotes: 'Diya is highly motivated by tactile feedback toys.',
        status: SpecialistReportStatus.finalized,
        generatedAt: now,
      );

      final Uint8List pdfBytes = await ReportPdfService.generateReportPdf(
        report: report,
        child: testChild,
        caseModel: testCase,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      // Standard PDF magic header check
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });

  group('3. SpecialistMessagingPanel Slide-in Workspace Widget Tests', () {
    testWidgets('Panel is hidden when isOpen is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialistMessagingPanel(
              isOpen: false,
              onClose: () {},
              initialCase: testCase,
            ),
          ),
        ),
      );

      expect(find.text('Direct Messages'), findsNothing);
      expect(find.text('Consultation Chat'), findsNothing);
    });

    testWidgets('Panel renders sliding container, header, and preselected consultation chat when isOpen is true', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialistMessagingPanel(
              isOpen: true,
              onClose: () {},
              initialCase: testCase,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consultation Chat'), findsOneWidget);
      expect(find.textContaining('Diya Patel'), findsWidgets);
      expect(find.text('Meera Patel'), findsOneWidget);
      expect(find.textContaining('DPDP Notice'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Quick replies template sheet opens and populates message input without auto-sending', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialistMessagingPanel(
              isOpen: true,
              onClose: () {},
              initialCase: testCase,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Quick Replies button
      final templatesBtn = find.byIcon(Icons.bolt_outlined);
      expect(templatesBtn, findsOneWidget);
      await tester.tap(templatesBtn);
      await tester.pumpAndSettle();

      // Check that professional templates are rendered
      expect(find.text('Activity Follow-up'), findsOneWidget);
      expect(find.text('Request Observations'), findsOneWidget);
      expect(find.text('Progress Milestone Update'), findsOneWidget);
      expect(find.text('Schedule Consultation'), findsOneWidget);

      // Select 'Progress Milestone Update' template
      await tester.tap(find.text('Progress Milestone Update'));
      await tester.pumpAndSettle();

      // Verify that the template populated the textfield and did NOT auto-send
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, contains('positive milestone update'));
    });

    testWidgets('Enforces DPDP consent and blocks sending when case consent is revoked', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialistMessagingPanel(
              isOpen: true,
              onClose: () {},
              initialCase: revokedCase,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active parental consent required under DPDP to message.'), findsOneWidget);
      expect(find.text('Consent paused'), findsOneWidget);
    });
  });

  group('4. ReportPreviewDialog & ReportCenterPage Integration Widget Tests', () {
    testWidgets('ReportPreviewDialog renders comprehensive report details and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleReport = SpecialistReportModel(
        id: 'rep_sample_404',
        caseId: testCase.caseId,
        childId: testCase.childId,
        childName: testCase.childName,
        specialistId: testCase.specialistId,
        specialistName: testCase.specialistName,
        title: 'Developmental Progress Assessment',
        summary: 'Diya has achieved noticeable milestones in social engagement and motor planning.',
        reportType: ReportType.progress,
        domainScores: {'motor': 72.0, 'cognitive': 85.0},
        keyFindings: ['Motor milestones advancing on trajectory.'],
        strengths: ['Cognitive: 85.0%'],
        growthAreas: ['Motor coordination'],
        recommendations: ['Daily finger grasp exercises.'],
        status: SpecialistReportStatus.finalized,
        generatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportPreviewDialog(
              report: sampleReport,
              caseModel: testCase,
              child: testChild,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Developmental Progress Assessment'), findsOneWidget);
      expect(find.text('Executive Clinical Summary'), findsOneWidget);
      expect(find.text('Export Print-Ready PDF'), findsOneWidget);
      expect(find.text('Share with Parent'), findsOneWidget);
    });

    testWidgets('ReportCenterPage renders filter controls and report generation trigger', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportCenterPage(
              initialCase: testCase,
              initialChild: testChild,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Specialist Report Center'), findsOneWidget);
      expect(find.text('Generate New Report'), findsOneWidget);
      expect(find.text('All Reports'), findsOneWidget);
    });
  });
}
