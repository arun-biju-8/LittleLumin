// test/specialist_child_profile_and_case_management_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/specialist_case_model.dart';
import 'package:littlelumin/models/specialist_report_model.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/widgets/activity_origin_badge.dart';
import 'package:littlelumin/screens/llg/child_profile_page.dart';

void main() {
  final now = DateTime(2026, 10, 24);

  final testChild = ChildModel(
    childId: 'child_aarav_99',
    parentId: 'parent_sanjay_99',
    name: 'Aarav Kumar',
    dateOfBirth: DateTime(2022, 5, 10),
    gender: 'Male',
    createdAt: now.subtract(const Duration(days: 300)),
  );

  final activeCase = SpecialistCaseModel(
    caseId: 'case_aarav_spec_01',
    parentId: 'parent_sanjay_99',
    parentName: 'Sanjay Kumar',
    childId: 'child_aarav_99',
    childName: 'Aarav Kumar',
    childAgeYears: 4,
    specialistId: 'spec_priya_01',
    specialistName: 'Dr. Priya Sharma',
    purpose: 'Speech & Language Articulation Guidance',
    authorizedDataCategories: ['skill_scores', 'activity_history', 'observations'],
    consentNoticeVersion: 'v1.0-dpdp',
    consentedAt: now.subtract(const Duration(days: 10)),
    status: CaseStatus.active,
    statusUpdatedAt: now.subtract(const Duration(days: 10)),
    acceptedAt: now.subtract(const Duration(days: 10)),
    expiresAt: now.add(const Duration(days: 80)),
    createdAt: now.subtract(const Duration(days: 10)),
  );

  final revokedCase = SpecialistCaseModel(
    caseId: 'case_aarav_revoked_02',
    parentId: 'parent_sanjay_99',
    parentName: 'Sanjay Kumar',
    childId: 'child_aarav_99',
    childName: 'Aarav Kumar',
    childAgeYears: 4,
    specialistId: 'spec_priya_01',
    specialistName: 'Dr. Priya Sharma',
    purpose: 'Sensory Integration',
    authorizedDataCategories: ['skill_scores'],
    consentNoticeVersion: 'v1.0-dpdp',
    consentedAt: now.subtract(const Duration(days: 40)),
    status: CaseStatus.revoked,
    statusUpdatedAt: now.subtract(const Duration(days: 5)),
    revokedAt: now.subtract(const Duration(days: 5)),
    revocationReason: 'Parent withdrew consent under DPDP guidelines',
    createdAt: now.subtract(const Duration(days: 40)),
  );

  group('1. SpecialistReportModel Unit Tests', () {
    test('Correctly serializes and deserializes AI assessment report data', () {
      final report = SpecialistReportModel(
        id: 'rep_101',
        caseId: 'case_aarav_spec_01',
        childId: 'child_aarav_99',
        childName: 'Aarav Kumar',
        specialistId: 'spec_priya_01',
        specialistName: 'Dr. Priya Sharma',
        title: 'Comprehensive Developmental Assessment - Aarav Kumar',
        summary: 'Aarav demonstrates strong cognitive and creative abilities, with emerging speech articulation.',
        domainScores: {
          'cognitive': 78.5,
          'language': 64.0,
          'motor': 72.0,
          'social': 68.0,
          'emotional': 75.0,
          'creative': 82.0,
        },
        keyFindings: [
          'Mastered cognitive and creative early milestones.',
          'Language articulation benefits from bilateral rhythm exercises.',
        ],
        strengths: ['Creative: 82.0%', 'Cognitive: 78.5%'],
        growthAreas: ['Language: 64.0% (Emerging)'],
        recommendations: [
          'Daily 15-minute rhyming storytelling.',
          'Bilateral clapping and phonetic games.',
        ],
        status: SpecialistReportStatus.draft,
        generatedAt: now,
        specialistNotes: 'Follow-up review in 2 weeks.',
      );

      final map = report.toMap();
      expect(map['caseId'], equals('case_aarav_spec_01'));
      expect(map['childName'], equals('Aarav Kumar'));
      expect(map['status'], equals('draft'));
      expect(report.isDraft, isTrue);
      expect(report.isFinalized, isFalse);
      expect(report.isShared, isFalse);

      final fromMap = SpecialistReportModel.fromMap('rep_101', map);
      expect(fromMap.id, equals('rep_101'));
      expect(fromMap.domainScores['creative'], equals(82.0));
      expect(fromMap.strengths.length, equals(2));
      expect(fromMap.recommendations.length, equals(2));

      final shared = fromMap.copyWith(
        status: SpecialistReportStatus.shared,
        sharedAt: now.add(const Duration(hours: 1)),
      );
      expect(shared.isShared, isTrue);
      expect(shared.status, equals(SpecialistReportStatus.shared));
    });
  });

  group('2. ChildProfilePage Dedicated Workspace Widget Tests', () {
    testWidgets('Renders child header workspace, parent info, and DPDP consent indicator', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1280, 900);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() => tester.binding.window.clearPhysicalSizeTestValue());

      await tester.pumpWidget(
        MaterialApp(
          home: ChildProfilePage(
            caseModel: activeCase,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Child Information
      expect(find.text('Aarav Kumar'), findsWidgets);
      expect(find.textContaining('Child Profile & Clinical Workspace'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);

      // Verify Parent Information
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Sanjay Kumar'), findsOneWidget);

      // Verify DPDP Consent Metadata
      expect(find.text('DPDP Notice'), findsOneWidget);
      expect(find.text('v1.0-dpdp'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Speech & Language Articulation Guidance'), findsOneWidget);
    });

    testWidgets('Displays all 8 dedicated tabs and allows navigation between them', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1280, 900);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() => tester.binding.window.clearPhysicalSizeTestValue());

      await tester.pumpWidget(
        MaterialApp(
          home: ChildProfilePage(
            caseModel: activeCase,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 8 tabs are visible
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Concerns'), findsOneWidget);
      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // Switch to Activities tab
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(find.text('Activities & Developmental History'), findsOneWidget);
      expect(find.text('Assign Activity'), findsOneWidget);

      // Switch to Feedback tab
      await tester.tap(find.text('Feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Parent Feedback History'), findsOneWidget);

      // Switch to Reports tab
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.text('AI-Generated Developmental Reports'), findsOneWidget);
      expect(find.text('Generate New AI Report'), findsOneWidget);

      // Switch to Concerns tab
      await tester.tap(find.text('Concerns'));
      await tester.pumpAndSettle();
      expect(find.text('Developmental Concerns & Observations'), findsOneWidget);
      expect(find.text('Add Clinical Note'), findsOneWidget);

      // Switch to Recommendations tab
      await tester.tap(find.text('Recommendations'));
      await tester.pumpAndSettle();
      expect(find.text('LLG Guidance Recommendations'), findsOneWidget);
      expect(find.text('New Recommendation'), findsOneWidget);

      // Switch to Actions tab
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Specialist Clinical & Operational Actions'), findsOneWidget);
      expect(find.text('Direct Secure Messaging'), findsOneWidget);
      expect(find.text('Record Consultation Summary'), findsOneWidget);

      // Switch to History tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Case Activity & Chronological History'), findsOneWidget);
    });

    testWidgets('Displays Activity Origin Badges visually separate from scores and completion', (tester) async {
      final aiActivity = ActivityModel(
        id: 'act_ai_01',
        title: 'AI Bilateral Rhythm Play',
        skillType: 'motor',
        difficulty: 'Medium',
        shortDescription: 'Dynamic AI generated activity',
        ageGroup: [4],
        duration: 15,
        instructions: ['Step 1'],
        learningGoals: ['Goal 1'],
        materials: ['Mat'],
        origin: 'ai_generated',
        createdBy: 'ai',
        createdAt: now,
      );

      final presetActivity = ActivityModel(
        id: 'preset_act_02',
        title: 'Storybook Pointing',
        skillType: 'language',
        difficulty: 'Medium',
        shortDescription: 'Core preset activity',
        ageGroup: [4],
        duration: 15,
        instructions: ['Step 1'],
        learningGoals: ['Goal 1'],
        materials: ['Book'],
        isPreset: true,
        createdBy: 'system',
        createdAt: now,
      );

      final llgActivity = ActivityModel(
        id: 'rec_act_03',
        title: 'Sensory Texture Scooping',
        skillType: 'sensory',
        difficulty: 'Medium',
        shortDescription: 'LLG Specialist assigned',
        ageGroup: [4],
        duration: 15,
        instructions: ['Step 1'],
        learningGoals: ['Goal 1'],
        materials: ['Sand'],
        origin: 'llg_recommended',
        createdBy: 'spec_priya_01',
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ActivityOriginBadge(activity: aiActivity),
                ActivityOriginBadge(activity: presetActivity),
                ActivityOriginBadge(activity: llgActivity),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Generated'), findsOneWidget);
      expect(find.text('Preset Activity'), findsOneWidget);
      expect(find.text('LLG Recommended'), findsOneWidget);
    });

    testWidgets('Enforces DPDP restrictions and renders revoked notice when consent is revoked', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1280, 900);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() => tester.binding.window.clearPhysicalSizeTestValue());

      await tester.pumpWidget(
        MaterialApp(
          home: ChildProfilePage(
            caseModel: revokedCase,
            initialChild: testChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Revoked Status & Warning Banner
      expect(find.text('REVOKED'), findsOneWidget);
      expect(find.textContaining('Parent revoked consultation consent'), findsOneWidget);
    });
  });
}
