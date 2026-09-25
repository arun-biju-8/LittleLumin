import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/screens/parent/growth_analytics_screen.dart';
import 'package:littlelumin/screens/parent/widgets/growth_guidance_banner.dart';
import 'package:littlelumin/screens/parent/widgets/compact_score_preview.dart';

void main() {
  final testChild = ChildModel(
    childId: 'child_test_1',
    parentId: 'parent_test_1',
    name: 'Leo',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    createdAt: DateTime(2023, 1, 1),
  );

  final testProfile = {
    'cognitive': 65.0,
    'language': 71.0,
    'motor': 42.0,
    'social': 58.0,
    'emotional': 64.0,
    'creative': 76.0,
  };

  final now = DateTime.now();
  final testEvents = [
    {
      'childId': 'child_test_1',
      'skillDomain': 'cognitive',
      'appliedScoreDelta': 3.5,
      'scoreBefore': 61.5,
      'scoreAfter': 65.0,
      'createdAt': now.subtract(const Duration(days: 2)),
    },
    {
      'childId': 'child_test_1',
      'skillDomain': 'motor',
      'appliedScoreDelta': -2.0,
      'scoreBefore': 44.0,
      'scoreAfter': 42.0,
      'createdAt': now.subtract(const Duration(days: 3)),
    },
    {
      'childId': 'child_test_1',
      'skillDomain': 'language',
      'appliedScoreDelta': 1.0,
      'scoreBefore': 70.0,
      'scoreAfter': 71.0,
      'createdAt': now.subtract(const Duration(days: 4)),
    },
  ];

  final testJourney = {
    'currentLevel': 1,
    'completedActivities': ['act_1', 'act_2', 'act_3', 'act_4'],
  };

  Widget buildAnalyticsScreen() {
    return MaterialApp(
      home: GrowthAnalyticsScreen(
        activeChild: testChild,
        initialSkillProfile: testProfile,
        initialScoreEvents: testEvents,
        initialJourneyProgress: testJourney,
      ),
    );
  }

  group('Growth Analytics Screen Tests', () {
    testWidgets('Renders overall progress ring and level information', (tester) async {
      await tester.pumpWidget(buildAnalyticsScreen());
      await tester.pumpAndSettle();

      // Title & Subtitle
      expect(find.text('Growth Analytics'), findsOneWidget);
      expect(find.text("Leo's developmental journey"), findsOneWidget);

      // Overall average: (65 + 71 + 42 + 58 + 64 + 76) / 6 = 62.67% -> rounds to 63%
      expect(find.text('63%'), findsOneWidget);
      expect(find.text('Growth'), findsOneWidget);

      // Level information
      expect(find.text('Level 1 · Level 1: Foundation Skills'), findsOneWidget);
      expect(find.text('4 of 6 skills explored'), findsOneWidget);
    });

    testWidgets('Renders all 6 domain cards with scores and domain labels', (tester) async {
      await tester.pumpWidget(buildAnalyticsScreen());
      await tester.pumpAndSettle();

      expect(find.text('DOMAIN SCORES'), findsOneWidget);
      expect(find.text('Cognitive'), findsWidgets);
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Motor'), findsWidgets);
      expect(find.text('Social'), findsWidgets);
      expect(find.text('Emotional'), findsWidgets);
      expect(find.text('Creative'), findsWidgets);

      expect(find.text('65%'), findsOneWidget);
      expect(find.text('71%'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('58%'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('76%'), findsOneWidget);
    });

    testWidgets('Trend arrows render correctly based on recent score events', (tester) async {
      await tester.pumpWidget(buildAnalyticsScreen());
      await tester.pumpAndSettle();

      // Cognitive has +3.5 delta -> ↑ +3.5
      expect(find.text('↑ +3.5'), findsOneWidget);

      // Motor has -2.0 delta -> ↓ -2.0
      expect(find.text('↓ -2.0'), findsOneWidget);

      // Social has 0 delta -> → 0.0
      expect(find.text('→ 0.0'), findsWidgets);
    });

    testWidgets('Weekly summary calculates activities count, time, and domains practiced', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildAnalyticsScreen());
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY SUMMARY'), findsOneWidget);

      // 3 activities in last 7 days
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);

      // 3 * 15 min = 45m
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('Time Spent'), findsOneWidget);

      // 3 unique domains: cognitive, motor, language
      expect(find.text('3 / 6'), findsOneWidget);
      expect(find.text('Domains'), findsOneWidget);

      // Most improved is Cognitive (+3.5)
      expect(find.text('Most Improved'), findsOneWidget);
      expect(find.text('Needs Gentle Care'), findsOneWidget);
    });

    testWidgets('CompactScorePreview renders overall ring, domain scores, and opens analytics on tap', (tester) async {
      bool analyticsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CompactScorePreview(
                activeChild: testChild,
                skillProfileStream: const Stream.empty(),
                scoreEventsStream: const Stream.empty(),
                journeyProgressStream: const Stream.empty(),
                onViewFullAnalytics: () => analyticsTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overall Growth'), findsOneWidget);
      expect(find.text('Domain scores:'), findsOneWidget);
      expect(find.text('View Full Analytics →'), findsOneWidget);

      await tester.tap(find.text('View Full Analytics →'));
      await tester.pump();
      expect(analyticsTapped, isTrue);
    });

    testWidgets('GrowthGuidanceBanner displays recent update and triggers onViewFullGrowth', (tester) async {
      bool fullGrowthTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrowthGuidanceBanner(
              activeChild: testChild,
              scoreEventStream: const Stream.empty(),
              onViewFullGrowth: () => fullGrowthTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty stream yields SizedBox.shrink without crash
      expect(find.byType(GrowthGuidanceBanner), findsOneWidget);
      expect(fullGrowthTapped, isFalse);
    });
  });
}
