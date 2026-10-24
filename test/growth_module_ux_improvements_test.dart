// test/growth_module_ux_improvements_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/journey_model.dart';
import 'package:littlelumin/models/specialist_case_model.dart';
import 'package:littlelumin/screens/parent/journey_activity_detail_page.dart';
import 'package:littlelumin/screens/parent/journey_view.dart';
import 'package:littlelumin/screens/parent/level_detail_screen.dart';
import 'package:littlelumin/widgets/activity_origin_badge.dart';
import 'package:littlelumin/widgets/specialist_contextual_action.dart';

ActivityModel createTestActivity({
  String? id,
  required String title,
  String? shortDescription,
  required String skillType,
  String difficulty = 'Easy',
  int duration = 10,
  String? origin,
  List<String> tags = const [],
  String createdBy = '',
  List<String> instructions = const ['Have fun exploring together!'],
  List<String> learningGoals = const ['Build foundational strength'],
  List<String> materials = const ['None needed'],
}) {
  return ActivityModel(
    id: id,
    title: title,
    shortDescription: shortDescription,
    skillType: skillType,
    difficulty: difficulty,
    ageGroup: const [3, 4, 5],
    duration: duration,
    origin: origin,
    tags: tags,
    createdBy: createdBy,
    instructions: instructions,
    learningGoals: learningGoals,
    materials: materials,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final testChild = ChildModel(
    childId: 'child_123',
    parentId: 'parent_456',
    name: 'Maya',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Female',
    createdAt: DateTime(2023, 1, 1),
  );

  group('1. Clearly Explain Level Unlock Requirements', () {
    testWidgets('Displays empathetic banner and distinguishes Completed from Mastered when all activities done but 0/6 mastered', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Child completed all 6 activities in Level 1, but scored below 70 in all domains (0/6 Mastered)
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 45.0, isCompleted: false, activitiesDone: 1),
        'language': const DomainProgress(domain: 'language', score: 50.0, isCompleted: false, activitiesDone: 1),
        'motor': const DomainProgress(domain: 'motor', score: 60.0, isCompleted: false, activitiesDone: 1),
        'social': const DomainProgress(domain: 'social', score: 40.0, isCompleted: false, activitiesDone: 1),
        'emotional': const DomainProgress(domain: 'emotional', score: 55.0, isCompleted: false, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 65.0, isCompleted: false, activitiesDone: 1),
      };

      final completed6 = ['act_1_1', 'act_1_2', 'act_1_3', 'act_1_4', 'act_1_5', 'act_1_6'];

      final journey = JourneyProgress(
        childId: testChild.childId,
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: completed6,
        levelProgress: {
          1: LevelProgress(
            completed: [],
            total: 6,
            isUnlocked: true,
            domains: domains,
          ),
          2: LevelProgress(completed: [], total: 6, isUnlocked: false),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JourneyViewScreen(
            activeChild: testChild,
            initialJourneyProgress: journey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Empathetic guidance banner is visible
      expect(find.text('All Activities Completed!'), findsOneWidget);
      // Appears in both empathetic guidance banner and locked Level 2 card
      expect(
        find.textContaining("🌱 Great job completing all your activities! You're making progress. To unlock Level 2, let's practise a few activities again and build your skills. You're getting closer!"),
        findsNWidgets(2),
      );

      // 2. Clearly distinguishes Completed vs Mastered
      expect(find.text('6 Activities Done'), findsOneWidget);
      expect(find.text('0 of 6 Domains'), findsOneWidget);
      expect(find.text('Requires 70%+ domain score'), findsOneWidget);

      // 3. Clear CTA to practice activities needing improvement
      expect(find.text('Practise Activities Needing Improvement'), findsOneWidget);

      // 4. Locked Level 2 card displays empathetic explanation and requirements instead of a discouraging barrier
      expect(find.text('Unlock Requirement: Level 1 Mastery'), findsOneWidget);
      expect(find.text('0 of 6 Mastered'), findsWidgets);
      expect(find.text('Practise Activities to Unlock Level 2'), findsOneWidget);
    });

    testWidgets('LevelDetailScreen displays empathetic banner and indicates practice-needed vs mastered activities', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 85.0, isCompleted: true, activitiesDone: 1),
        'language': const DomainProgress(domain: 'language', score: 50.0, isCompleted: false, activitiesDone: 1),
        'motor': const DomainProgress(domain: 'motor', score: 60.0, isCompleted: false, activitiesDone: 1),
        'social': const DomainProgress(domain: 'social', score: 40.0, isCompleted: false, activitiesDone: 1),
        'emotional': const DomainProgress(domain: 'emotional', score: 55.0, isCompleted: false, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 65.0, isCompleted: false, activitiesDone: 1),
      };

      final List<ActivityModel> activities = [
        createTestActivity(
          id: 'act_1_1',
          title: 'Color Sorter Fun',
          skillType: 'cognitive',
          origin: 'preset',
          tags: ['preset'],
          createdBy: 'system',
        ),
        createTestActivity(
          id: 'act_1_2',
          title: 'Rhyme Time Fun',
          skillType: 'language',
          origin: 'preset',
          tags: ['preset'],
          createdBy: 'system',
        ),
      ];

      final journey = JourneyProgress(
        childId: testChild.childId,
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: ['act_1_1', 'act_1_2', 'act_1_3', 'act_1_4', 'act_1_5', 'act_1_6'],
        levelProgress: {
          1: LevelProgress(
            completed: ['cognitive'],
            total: 6,
            isUnlocked: true,
            domains: domains,
          ),
          2: LevelProgress(completed: [], total: 6, isUnlocked: false),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            activeChild: testChild,
            level: 1,
            initialJourneyProgress: journey,
            initialActivities: activities,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check banner on Overview tab
      expect(find.text('All Activities Completed!'), findsOneWidget);
      // Appears in empathetic banner and dynamic guidance card
      expect(find.textContaining("To unlock Level 2, let's practise a few activities again and build your skills"), findsNWidgets(2));

      // Switch to Activities tab
      await tester.tap(find.text('Activities & History'));
      await tester.pumpAndSettle();

      // Cognitive (score: 85%) is Mastered
      expect(find.text('Completed · Mastered 🏆 (85%)'), findsOneWidget);

      // Language (score: 50%) needs Practice
      expect(find.text('Completed · Practice Recommended (50% / 70% goal)'), findsOneWidget);
    });
  });

  group('2. Contextual Specialist Connection for LLG-Recommended Activities', () {
    final llgActivity = createTestActivity(
      id: 'rec_llg_speech_1',
      title: 'Speech Exploration Play',
      shortDescription: 'Gentle expressive language play recommended by LLG.',
      skillType: 'language',
      duration: 15,
      origin: 'llg_recommended',
      tags: ['llg', 'llg_recommended'],
      createdBy: 'llg',
    );

    final presetActivity = createTestActivity(
      id: 'act_1_1',
      title: 'Pattern Blocks',
      skillType: 'cognitive',
      duration: 10,
      origin: 'preset',
      tags: ['preset'],
      createdBy: 'system',
    );

    final aiActivity = createTestActivity(
      id: 'gen_act_789',
      title: 'Creative Story Safari',
      skillType: 'creative',
      duration: 12,
      origin: 'ai_generated',
      tags: ['ai_generated'],
      createdBy: 'ai',
    );

    testWidgets('Renders "Discuss with Your Specialist" and "View Connected Specialist" when specialist case is active', (tester) async {
      final activeCase = SpecialistCaseModel(
        caseId: 'case_001',
        childId: testChild.childId,
        childName: testChild.name,
        childAgeYears: testChild.age,
        parentId: testChild.parentId,
        parentName: 'Priya Patel',
        specialistId: 'spec_dr_smith',
        specialistName: 'Dr. Sarah Smith',
        status: CaseStatus.active,
        purpose: 'Language enrichment support',
        authorizedDataCategories: const ['milestones', 'growth_analytics'],
        consentedAt: DateTime.now(),
        statusUpdatedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialistContextualAction(
              childId: testChild.childId,
              activity: llgActivity,
              connectedSpecialistCase: activeCase,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Specialist Guidance Available'), findsOneWidget);
      expect(find.textContaining('Dr. Sarah Smith'), findsOneWidget);
      expect(find.text('Discuss with Your Specialist'), findsOneWidget);
      expect(find.text('View Connected Specialist'), findsOneWidget);
    });

    testWidgets('Renders "Connect with a Specialist" when child has no active case connected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialistContextualAction(
              childId: testChild.childId,
              activity: llgActivity,
              currentUserId: 'parent_without_case',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect with a Specialist'), findsOneWidget);
      expect(find.text('Personalized Specialist Guidance'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('Does NOT render specialist connection for preset activities or AI activities', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SpecialistContextualAction(
                  childId: testChild.childId,
                  activity: presetActivity,
                ),
                SpecialistContextualAction(
                  childId: testChild.childId,
                  activity: aiActivity,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Specialist Guidance Available'), findsNothing);
      expect(find.text('Discuss with Your Specialist'), findsNothing);
      expect(find.text('Connect with a Specialist'), findsNothing);
    });
  });

  group('3. Activity Origin Badges', () {
    testWidgets('Displays AI Generated badge for AI activities', (tester) async {
      final act = createTestActivity(
        id: 'gen_act_101',
        title: 'AI Sensory Cloud',
        skillType: 'cognitive',
        origin: 'ai_generated',
        tags: ['ai_generated'],
        createdBy: 'ai',
      );

      expect(act.activityOrigin, equals(ActivityOrigin.aiGenerated));
      expect(act.isAIGenerated, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOriginBadge(activity: act),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Generated'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('Displays Preset Activity badge for preset library activities', (tester) async {
      final act = createTestActivity(
        id: 'act_1_1',
        title: 'Blocks & Shapes',
        skillType: 'motor',
        origin: 'preset',
        tags: ['preset'],
        createdBy: 'system',
      );

      expect(act.activityOrigin, equals(ActivityOrigin.preset));
      expect(act.isPresetActivity, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOriginBadge(activity: act),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preset Activity'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    });

    testWidgets('Displays LLG Recommended badge for LLG activities', (tester) async {
      final act = createTestActivity(
        id: 'rec_social_circle',
        title: 'Circle of Sharing',
        skillType: 'social',
        duration: 15,
        origin: 'llg_recommended',
        tags: ['llg_recommended'],
        createdBy: 'llg',
      );

      expect(act.activityOrigin, equals(ActivityOrigin.llgRecommended));
      expect(act.isLLGRecommended, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOriginBadge(activity: act),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LLG Recommended'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    testWidgets('Gracefully omits badge when metadata is unknown or unverified', (tester) async {
      final act = createTestActivity(
        id: 'custom_123',
        title: 'Unknown Origin Adventure',
        skillType: 'creative',
      );

      expect(act.activityOrigin, equals(ActivityOrigin.unknown));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityOriginBadge(activity: act),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Generated'), findsNothing);
      expect(find.text('Preset Activity'), findsNothing);
      expect(find.text('LLG Recommended'), findsNothing);
    });

    testWidgets('JourneyActivityDetailPage renders ActivityOriginBadge and specialist action for LLG recommendation', (tester) async {
      final llgAct = createTestActivity(
        id: 'rec_act_555',
        title: 'LLG Balance Game',
        shortDescription: 'Motor control balance exercise recommended by LLG.',
        skillType: 'motor',
        duration: 10,
        origin: 'llg_recommended',
        tags: ['llg_recommended'],
        createdBy: 'llg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JourneyActivityDetailPage(
            activityId: llgAct.id!,
            childId: testChild.childId,
            initialActivity: llgAct,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Origin badge is displayed
      expect(find.text('LLG Recommended'), findsOneWidget);

      // Specialist contextual action is displayed
      expect(find.text('Connect with a Specialist'), findsOneWidget);
      expect(find.text('Personalized Specialist Guidance'), findsOneWidget);
    });
  });
}
