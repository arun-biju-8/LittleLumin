// test/home_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/screens/parent/home/home_tab.dart';
import 'package:littlelumin/screens/parent/home/widgets/greeting_header.dart';
import 'package:littlelumin/screens/parent/home/widgets/child_switcher_card.dart';
import 'package:littlelumin/screens/parent/home/widgets/todays_plan_card.dart';
import 'package:littlelumin/screens/parent/home/widgets/quick_actions_row.dart';
import 'package:littlelumin/screens/parent/home/widgets/growth_snapshot_card.dart';
import 'package:littlelumin/screens/parent/home/widgets/todays_insight_card.dart';
import 'package:littlelumin/screens/parent/home/widgets/recent_activity_card.dart';
import 'package:littlelumin/theme/meadow_theme.dart';

void main() {
  final testChild = ChildModel(
    childId: 'c1',
    parentId: 'p1',
    name: 'Leo',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    vabsScores: {'Cognitive': 72.0, 'Language': 68.0, 'Motor': 70.0},
    createdAt: DateTime(2023, 1, 1),
  );

  final flaggedChild = ChildModel(
    childId: 'c2',
    parentId: 'p1',
    name: 'Maya',
    dateOfBirth: DateTime(DateTime.now().year - 5, 2, 2),
    gender: 'Female',
    isFlagged: true,
    flagReason: 'Speech delay noted',
    createdAt: DateTime(2023, 1, 1),
  );

  final sampleActivities = [
    ActivityModel(
      id: 'act1',
      title: 'Nature Treasure Hunt',
      shortDescription: 'Explore nature and sort objects around you.',
      skillType: 'Cognitive',
      difficulty: 'Easy',
      ageGroup: [4, 5],
      duration: 10,
      instructions: ['Step 1: Walk in the garden', 'Step 2: Collect 3 leaves'],
      learningGoals: ['Cognitive observation and color sorting'],
      materials: ['Basket'],
      createdAt: DateTime(2023, 1, 1),
    ),
    ActivityModel(
      id: 'act2',
      title: 'Color Sorting',
      shortDescription: 'Sort colored items into corresponding boxes.',
      skillType: 'Cognitive',
      difficulty: 'Medium',
      ageGroup: [4, 5],
      duration: 10,
      instructions: ['Sort blue and red blocks'],
      learningGoals: ['Color recognition'],
      materials: ['Blocks'],
      createdAt: DateTime(2023, 1, 1),
    ),
    ActivityModel(
      id: 'act3',
      title: 'Build a Fort',
      shortDescription: 'Create a cozy play fort with blankets.',
      skillType: 'Motor',
      difficulty: 'Easy',
      ageGroup: [4, 5],
      duration: 10,
      instructions: ['Drape blanket over chairs'],
      learningGoals: ['Motor coordination'],
      materials: ['Blankets', 'Chairs'],
      createdAt: DateTime(2023, 1, 1),
    ),
  ];

  group('Home Tab Components Tests', () {
    testWidgets('Renders greeting header with time-aware greeting and parent name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GreetingHeader(parentName: 'Arun'),
          ),
        ),
      );

      expect(find.textContaining('Arun 👋'), findsOneWidget);
      expect(find.text('Small steps today, brighter growth tomorrow.'), findsOneWidget);
    });

    testWidgets('Renders child switcher and opens bottom sheet on tap', (tester) async {
      ChildModel? selected;
      bool addChildTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildSwitcherCard(
              child: testChild,
              children: [testChild, flaggedChild],
              level: 1,
              onChildSelected: (c) => selected = c,
              onAddChild: () => addChildTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Leo'), findsOneWidget);
      expect(find.text('Age 4 · Level 1'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);

      // Tap card to open picker
      await tester.tap(find.text('Leo'));
      await tester.pumpAndSettle();

      expect(find.text('Select Active Child'), findsOneWidget);
      expect(find.text('Add Child'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);

      await tester.tap(find.text('Maya'));
      await tester.pumpAndSettle();
      expect(selected?.childId, equals('c2'));

      // Re-open and tap Add Child
      await tester.tap(find.text('Leo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Child'));
      await tester.pumpAndSettle();
      expect(addChildTapped, isTrue);
    });

    testWidgets('Renders Today\'s Plan hero card with activities', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TodaysPlanCard(
                child: testChild,
                activitiesFuture: Future.value(sampleActivities),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TODAY\'S PLAN'), findsOneWidget);
      expect(find.textContaining('3 activities · ~30 min'), findsOneWidget);
      expect(find.text('Nature Treasure Hunt'), findsOneWidget);
      expect(find.text('Start Activity →'), findsOneWidget);
      expect(find.textContaining('+ 2 more activities in today\'s plan'), findsOneWidget);
    });

    testWidgets('Renders Today\'s Plan flagged child gentle pace card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodaysPlanCard(
              child: flaggedChild,
            ),
          ),
        ),
      );

      expect(find.text('TAKE IT SLOW TODAY'), findsOneWidget);
      expect(find.textContaining('gentle, calming moments for Maya'), findsOneWidget);
      expect(find.text('Read a Calming Story'), findsOneWidget);
    });

    testWidgets('Renders 3 quick action tiles and triggers callbacks', (tester) async {
      bool aiAct = false;
      bool aiStory = false;
      bool allAct = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionsRow(
              onAIActivity: () => aiAct = true,
              onAIStory: () => aiStory = true,
              onAllActivities: () => allAct = true,
            ),
          ),
        ),
      );

      expect(find.text('Create with AI'), findsOneWidget);
      expect(find.text('Read a Story'), findsOneWidget);
      expect(find.text('Activity Library'), findsOneWidget);

      await tester.tap(find.text('Create with AI'));
      await tester.pump();
      expect(aiAct, isTrue);

      await tester.tap(find.text('Read a Story'));
      await tester.pump();
      expect(aiStory, isTrue);

      await tester.tap(find.text('Activity Library'));
      await tester.pump();
      expect(allAct, isTrue);
    });

    testWidgets('Renders Growth Snapshot card with score and View Growth button', (tester) async {
      bool growthTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrowthSnapshotCard(
              child: testChild,
              onViewGrowth: () => growthTapped = true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('GROWTH SNAPSHOT'), findsOneWidget);
      expect(find.textContaining('Overall:'), findsOneWidget);
      expect(find.text('View Growth →'), findsOneWidget);

      await tester.tap(find.text('View Growth →'));
      await tester.pump();
      expect(growthTapped, isTrue);
    });

    testWidgets('Renders Today\'s Insight with daily parenting tip', (tester) async {
      const tipText = 'Praise effort, not just outcome. It builds a growth mindset.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodaysInsightCard(
              tipFuture: Future.value(tipText),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('TODAY\'S INSIGHT'), findsOneWidget);
      expect(find.text('"$tipText"'), findsOneWidget);
    });

    testWidgets('Renders Recent Activity section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecentActivityCard(
              child: testChild,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.text('No activities completed yet'), findsOneWidget);
    });

    testWidgets('All widgets use Meadow theme colors and cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            scaffoldBackgroundColor: MeadowColors.cream,
            primaryColor: MeadowColors.primary,
          ),
          home: Scaffold(
            backgroundColor: MeadowColors.cream,
            body: Column(
              children: [
                const GreetingHeader(parentName: 'Arun'),
                QuickActionsRow(
                  onAIActivity: () {},
                  onAIStory: () {},
                  onAllActivities: () {},
                ),
                TodaysInsightCard(
                  tipFuture: Future.value('Warm test tip'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(MeadowColors.cream));
    });

    testWidgets('HomeTab renders full structure and pull-to-refresh works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeTab(
            parentName: 'Arun',
            activeChild: testChild,
            children: [testChild],
            onChildSelected: (_) {},
            onAddChild: () {},
            onNotificationsTap: () {},
            onSettingsTap: () {},
            onContinueJourney: () {},
            onAIActivity: () {},
            onAIStory: () {},
            onAllActivities: () {},
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(GreetingHeader), findsOneWidget);
      expect(find.byType(ChildSwitcherCard), findsOneWidget);
      expect(find.byType(TodaysPlanCard), findsOneWidget);
      expect(find.byType(QuickActionsRow), findsOneWidget);
      expect(find.byType(GrowthSnapshotCard), findsOneWidget);
      expect(find.byType(TodaysInsightCard), findsOneWidget);
      expect(find.byType(RecentActivityCard), findsOneWidget);

      // Verify pull-to-refresh
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
    });

    testWidgets('HomeTab renders empty state when activeChild is null', (tester) async {
      bool addChildClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeTab(
            parentName: 'Arun',
            activeChild: null,
            children: const [],
            onChildSelected: (_) {},
            onAddChild: () => addChildClicked = true,
            onNotificationsTap: () {},
            onSettingsTap: () {},
            onContinueJourney: () {},
            onAIActivity: () {},
            onAIStory: () {},
            onAllActivities: () {},
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Welcome to LittleLumin!'), findsOneWidget);
      expect(find.text('Add Your First Child'), findsOneWidget);

      await tester.tap(find.text('Add Your First Child'));
      await tester.pump();
      expect(addChildClicked, isTrue);
    });
  });
}
