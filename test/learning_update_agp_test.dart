// test/learning_update_agp_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/learning_update_model.dart';
import 'package:littlelumin/screens/parent/learning_update_screen.dart';
import 'package:littlelumin/screens/parent/widgets/latest_learning_update_card.dart';
import 'package:littlelumin/services/growth_messaging_service.dart';
import 'package:littlelumin/services/journey_service.dart';

void main() {
  final testChild = ChildModel(
    childId: 'child_aarav_1',
    parentId: 'parent_1',
    name: 'Aarav',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    createdAt: DateTime(2023, 1, 1),
  );

  final secondChild = ChildModel(
    childId: 'child_meera_2',
    parentId: 'parent_1',
    name: 'Meera',
    dateOfBirth: DateTime(DateTime.now().year - 2, 6, 1),
    gender: 'Female',
    createdAt: DateTime(2024, 6, 1),
  );

  final nextActivity = ActivityModel(
    id: 'act_social_turn_taking',
    title: 'Turn-Taking Tower',
    shortDescription: 'Build a block tower taking turns gently.',
    skillType: 'Social',
    difficulty: 'Easy',
    ageGroup: [3, 4, 5],
    duration: 10,
    instructions: ['Place a block', 'Invite partner to place next block'],
    learningGoals: ['Patience', 'Cooperation'],
    materials: ['Building blocks'],
    createdBy: 'system',
    createdByName: 'LittleLumin',
    category: 'Social',
    tags: ['social', 'blocks'],
    createdAt: DateTime(2023, 1, 1),
  );

  group('1. LearningUpdateModel Serialization & Integrity', () {
    test('toMap and fromMap preserve all fields faithfully', () {
      final date = DateTime(2026, 10, 22, 10, 30);
      final model = LearningUpdateModel(
        childId: 'child_aarav_1',
        childName: 'Aarav',
        activityId: 'act_rolling_game',
        activityTitle: 'The Kindness Rolling Game',
        domain: 'social',
        level: 1,
        skill: 'empathy',
        scoreBefore: 30.0,
        scoreAfter: 32.0,
        scoreDelta: 2.0,
        isMastered: false,
        levelCompleted: false,
        ratings: {'childResponse': 'loved', 'engagement': 'high'},
        completedAt: date,
        aiHeadline: 'Great Progress in Social! 🌱',
        aiMessage: 'Aarav is building wonderful empathy.',
        nextActivity: nextActivity,
      );

      final map = model.toMap();
      expect(map['childId'], equals('child_aarav_1'));
      expect(map['activityTitle'], equals('The Kindness Rolling Game'));
      expect(map['domain'], equals('social'));
      expect(map['scoreBefore'], equals(30.0));
      expect(map['scoreAfter'], equals(32.0));
      expect(map['scoreDelta'], equals(2.0));
      expect(map['ratings']['childResponse'], equals('loved'));
      expect(map['nextActivity']['title'], equals('Turn-Taking Tower'));

      final restored = LearningUpdateModel.fromMap(map);
      expect(restored.childId, equals(model.childId));
      expect(restored.activityTitle, equals(model.activityTitle));
      expect(restored.domain, equals(model.domain));
      expect(restored.scoreBefore, equals(model.scoreBefore));
      expect(restored.scoreAfter, equals(model.scoreAfter));
      expect(restored.scoreDelta, equals(model.scoreDelta));
      expect(restored.ratings['childResponse'], equals('loved'));
      expect(restored.nextActivity?.title, equals('Turn-Taking Tower'));
    });
  });

  group('2. LearningUpdateScreen UI & Progress Display', () {
    testWidgets('Displays activity summary, scores, and positive delta (+2 pts)', (tester) async {
      final update = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_rolling_game',
        activityTitle: 'The Kindness Rolling Game',
        domain: 'social',
        level: 1,
        scoreBefore: 30.0,
        scoreAfter: 32.0,
        scoreDelta: 2.0,
        isMastered: false,
        levelCompleted: false,
        ratings: {'childResponse': 'loved', 'engagement': 'high'},
        completedAt: DateTime.now(),
        nextActivity: nextActivity,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LearningUpdateScreen(
            update: update,
            activeChild: testChild,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header Confirmation
      expect(find.text('Learning Update Recorded'), findsOneWidget);
      expect(find.text("Aarav's learning progress has been saved safely."), findsOneWidget);

      // Verify Activity Title and Domain
      expect(find.text('The Kindness Rolling Game'), findsOneWidget);
      expect(find.text('Social'), findsWidgets);
      expect(find.text('Level 1'), findsWidgets);

      // Verify Recorded Progress scores
      expect(find.text('30 / 100'), findsOneWidget);
      expect(find.text('32 / 100'), findsOneWidget);
      expect(find.text('+2 pts'), findsOneWidget);

      // Verify Qualitative Ratings
      expect(find.text('Mood: loved'), findsOneWidget);
      expect(find.text('Engagement: high'), findsOneWidget);

      // Verify Primary Action Buttons
      expect(find.text('View All Growth'), findsOneWidget);
      expect(find.text('Next: Turn-Taking Tower'), findsOneWidget);
      expect(find.text('Return to Activities'), findsOneWidget);
    });

    testWidgets('Unchanged score (+0 pts) explains steady practice without fabricating improvement', (tester) async {
      final update = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_rolling_game',
        activityTitle: 'The Kindness Rolling Game',
        domain: 'social',
        level: 1,
        scoreBefore: 30.0,
        scoreAfter: 30.0,
        scoreDelta: 0.0,
        isMastered: false,
        levelCompleted: false,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LearningUpdateScreen(
            update: update,
            activeChild: testChild,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check steady practice label
      expect(find.text('Steady practice'), findsOneWidget);
      expect(find.text('30 / 100'), findsNWidgets(2)); // before and after are both 30
    });

    testWidgets('Celebrates Level 1 complete and Level 2 unlocked when all 6 domains reach 70%', (tester) async {
      final update = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_final_mastery',
        activityTitle: 'Creative Rhythm Dance',
        domain: 'creative',
        level: 1,
        scoreBefore: 68.0,
        scoreAfter: 72.0,
        scoreDelta: 4.0,
        isMastered: true,
        levelCompleted: true,
        nextLevel: 2,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LearningUpdateScreen(
            update: update,
            activeChild: testChild,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Level 1 Mastered! 🌟'), findsOneWidget);
      expect(find.textContaining('Level 2 is now unlocked!'), findsOneWidget);
    });

    testWidgets('Read-only mode indicates saved review without allowing resubmission', (tester) async {
      final update = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_past',
        activityTitle: 'Past Sorting Activity',
        domain: 'cognitive',
        level: 1,
        scoreBefore: 40.0,
        scoreAfter: 42.0,
        scoreDelta: 2.0,
        completedAt: DateTime(2026, 10, 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LearningUpdateScreen(
            update: update,
            activeChild: testChild,
            isReadOnly: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Viewing saved review from 20/10/2026'), findsOneWidget);
    });

    testWidgets('Uses tailored AI messaging with safe fallback when network is unavailable', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = GrowthMessagingService(client: mockClient);

      final update = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_social_kindness',
        activityTitle: 'The Kindness Rolling Game',
        domain: 'social',
        level: 1,
        scoreBefore: 30.0,
        scoreAfter: 32.0,
        scoreDelta: 2.0,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LearningUpdateScreen(
            update: update,
            activeChild: testChild,
            messagingService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify safe fallback is displayed cleanly
      expect(find.text('Growing in Social! 🌱'), findsOneWidget);
      expect(find.textContaining('Aarav had a wonderful learning session with "The Kindness Rolling Game"'), findsOneWidget);
    });
  });

  group('3. LatestLearningUpdateCard & Persistence', () {
    testWidgets('Renders update card when a valid update exists for child', (tester) async {
      final update = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_rolling_game',
        activityTitle: 'The Kindness Rolling Game',
        domain: 'social',
        level: 1,
        scoreBefore: 30.0,
        scoreAfter: 32.0,
        scoreDelta: 2.0,
        completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LatestLearningUpdateCard(
              child: testChild,
              initialUpdate: update,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LATEST LEARNING UPDATE'), findsOneWidget);
      expect(find.text('The Kindness Rolling Game'), findsOneWidget);
      expect(find.text('View Last Learning Update'), findsOneWidget);
    });

    testWidgets('Does not display card when child has no previous update', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LatestLearningUpdateCard(
              child: testChild,
              initialUpdate: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LATEST LEARNING UPDATE'), findsNothing);
      expect(find.text('View Last Learning Update'), findsNothing);
    });

    testWidgets('Switching children never exposes another child’s update', (tester) async {
      final updateChild1 = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_rolling_game',
        activityTitle: 'The Kindness Rolling Game',
        domain: 'social',
        level: 1,
        scoreBefore: 30.0,
        scoreAfter: 32.0,
        scoreDelta: 2.0,
        completedAt: DateTime.now(),
      );

      // Render for child 1
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LatestLearningUpdateCard(
              child: testChild,
              initialUpdate: updateChild1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('The Kindness Rolling Game'), findsOneWidget);

      // Switch to child 2 (who has no update)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LatestLearningUpdateCard(
              child: secondChild,
              initialUpdate: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Must not display child 1's activity for child 2
      expect(find.text('The Kindness Rolling Game'), findsNothing);
      expect(find.text('LATEST LEARNING UPDATE'), findsNothing);
    });

    test('JourneyService persists and retrieves child-isolated updates', () async {
      final service = JourneyService();
      JourneyService.clearLatestUpdateCache();

      final update = LearningUpdateModel(
        childId: testChild.childId,
        childName: testChild.name,
        activityId: 'act_test',
        activityTitle: 'Shape Sorting Fun',
        domain: 'cognitive',
        level: 1,
        scoreBefore: 20.0,
        scoreAfter: 24.0,
        scoreDelta: 4.0,
        completedAt: DateTime.now(),
      );

      await service.saveLatestLearningUpdate(testChild.childId, update);

      // Verify child 1 has update
      final retrieved1 = await service.getLatestLearningUpdate(testChild.childId);
      expect(retrieved1, isNotNull);
      expect(retrieved1!.activityTitle, equals('Shape Sorting Fun'));

      // Verify child 2 does not see child 1's update
      final retrieved2 = await service.getLatestLearningUpdate(secondChild.childId);
      expect(retrieved2, isNull);
    });
  });
}
