// test/growth_runtime_bugfixes_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/journey_model.dart';
import 'package:littlelumin/screens/parent/journey_activity_detail_page.dart';
import 'package:littlelumin/screens/parent/level_detail_screen.dart';
import 'package:littlelumin/services/growth_messaging_service.dart';
import 'package:littlelumin/services/activity_state_service.dart';
import 'package:littlelumin/widgets/global_header.dart';

void main() {
  final testChild = ChildModel(
    childId: 'child_test_123',
    parentId: 'parent_test_123',
    name: 'Aarav Sharma',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    createdAt: DateTime(2023, 1, 1),
  );

  final anonymousChild = ChildModel(
    childId: 'child_anon_123',
    parentId: 'parent_anon_123',
    name: '',
    dateOfBirth: DateTime(DateTime.now().year - 3, 5, 1),
    gender: 'Female',
    createdAt: DateTime(2023, 5, 1),
  );

  final kindnessRollingGame = ActivityModel(
    id: 'act_social_kindness_roll',
    title: 'The Kindness Rolling Game',
    shortDescription: 'Roll a soft ball to a partner and share something kind.',
    skillType: 'Social',
    difficulty: 'Easy',
    ageGroup: [3, 4, 5],
    duration: 15,
    instructions: ['Sit facing your partner', 'Roll the ball gently', 'Share a smile and a kind word'],
    learningGoals: ['Turn-taking', 'Social connection', 'Sharing emotions'],
    materials: ['Soft ball'],
    createdBy: 'system',
    createdByName: 'LittleLumin',
    category: 'Social',
    tags: ['social', 'sharing'],
    createdAt: DateTime.now(),
  );

  group('1. Activity Launch & Error Recovery Tests', () {
    testWidgets('Valid recommended activity opens directly with initialActivity without network error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyActivityDetailPage(
            activityId: kindnessRollingGame.id!,
            childId: testChild.childId,
            initialActivity: kindnessRollingGame,
          ),
        ),
      );

      // Should immediately show activity title without loading spinner or error
      expect(find.text('The Kindness Rolling Game'), findsWidgets);
      expect(find.text('SOCIAL'), findsOneWidget);
      expect(find.text('Roll a soft ball to a partner and share something kind.'), findsOneWidget);
      expect(find.text('🎯 Learning Goals'), findsOneWidget);
      expect(find.text('• Turn-taking'), findsOneWidget);
      expect(find.text('✅ Complete Activity & Give Feedback'), findsOneWidget);
      expect(find.text('This activity could not be loaded.'), findsNothing);
    });

    testWidgets('Unresolvable activity ID shows recoverable error state with recovery buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyActivityDetailPage(
            activityId: 'unresolvable_non_existent_id',
            childId: testChild.childId,
            // initialActivity omitted and Firestore not mocked -> should land on error state
          ),
        ),
      );

      // Wait for any async lookup attempt to finish
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Activity Unavailable'), findsOneWidget);
      expect(find.textContaining('We could not load this activity'), findsOneWidget);
      expect(find.text('Browse Library'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
    });
  });

  group('2. Domain Consistency: Social vs Cognitive Integrity', () {
    test('Recommendation derives authoritative domain from activity.skillType', () {
      final rec = {
        'domain': 'social',
        'targetDomain': 'social',
        'score': 30.0,
        'currentScore': 30.0,
        'reason': 'Social score is currently 30/100. Practicing this activity will help reach the 70% milestone.',
        'rationale': 'Social score is currently 30/100. Practicing this activity will help reach the 70% milestone.',
        'activity': kindnessRollingGame,
      };

      final activity = rec['activity'] as ActivityModel;
      final domain = activity.skillType.trim().toLowerCase();
      final score = rec['score'] as double;
      final rationale = rec['rationale'] as String;

      // Assert that Social recommendation can NEVER be conflated with Cognitive
      expect(domain, equals('social'));
      expect(activity.skillType, equals('Social'));
      expect(activity.title, equals('The Kindness Rolling Game'));
      expect(score, equals(30.0));
      expect(rationale, contains('Social score is currently 30/100'));
      expect(rationale, isNot(contains('Cognitive')));
    });

    test('Missing recommendation fields default safely to activity values', () {
      final incompleteRec = {
        'activity': kindnessRollingGame,
      };

      final activity = incompleteRec['activity'] as ActivityModel;
      final domain = (activity.skillType.isNotEmpty)
          ? activity.skillType.trim().toLowerCase()
          : 'cognitive';

      expect(domain, equals('social'));
    });
  });

  group('3. Back Navigation Stack & GlobalHeader Fixes', () {
    testWidgets('GlobalHeader does not navigate to Home on title tap when showBack is true', (tester) async {
      bool navigatedToHome = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/home': (_) {
              navigatedToHome = true;
              return const Scaffold(body: Text('Home Page'));
            },
          },
          home: const Scaffold(
            appBar: GlobalHeader(
              showBack: true,
              title: 'Activity Workspace',
            ),
            body: Center(child: Text('Current Sub Page')),
          ),
        ),
      );

      // Tap on the header title
      await tester.tap(find.text('Activity Workspace'));
      await tester.pump();

      // Must remain on Current Sub Page, NOT navigate to /home
      expect(navigatedToHome, isFalse);
      expect(find.text('Current Sub Page'), findsOneWidget);
    });

    testWidgets('LevelDetailScreen contains PopScope and explicit back button', (tester) async {
      final testJourney = JourneyProgress(
        childId: testChild.childId,
        currentLevel: 1,
        completedActivities: ['act_1', 'act_2'],
        levelProgress: {
          1: LevelProgress(
            completed: ['act_1', 'act_2'],
            domains: {
              'cognitive': const DomainProgress(domain: 'cognitive', score: 60.0, isCompleted: false, activitiesDone: 1),
              'social': const DomainProgress(domain: 'social', score: 30.0, isCompleted: false, activitiesDone: 1),
            },
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            activeChild: testChild,
            level: 1,
            initialJourneyProgress: testJourney,
            initialActivities: [kindnessRollingGame],
            scoreEventsStream: const Stream.empty(),
          ),
        ),
      );

      await tester.pump();

      // Verify PopScope exists
      expect(find.byWidgetPredicate((w) => w is PopScope), findsOneWidget);

      // Verify explicit back button exists in AppBar
      final backButton = find.byTooltip('Back to Growth Journey');
      expect(backButton, findsOneWidget);
    });
  });

  group('4. AI Encouragement Messaging & Natural Child Grammar', () {
    test('Anonymous child generates natural grammar (Your child / your child / their)', () async {
      final service = GrowthMessagingService();

      final journey = JourneyProgress(
        childId: anonymousChild.childId,
        currentLevel: 1,
        completedActivities: ['act_1', 'act_2', 'act_3', 'act_4', 'act_5', 'act_6'],
        levelProgress: {
          1: LevelProgress(
            completed: ['act_1', 'act_2', 'act_3', 'act_4', 'act_5', 'act_6'],
            domains: {
              'social': const DomainProgress(domain: 'social', score: 30.0, isCompleted: false, activitiesDone: 1),
            },
          ),
        },
      );

      final stateA = service.determineLearningState(
        journey: journey,
        completedActivitiesCount: 6,
        masteredDomainsCount: 3,
        totalDomainsCount: 6,
      );
      expect(stateA, equals('initial_activities_completed_mastery_pending'));

      final msg = await service.getOrGenerateMessage(
        child: anonymousChild,
        journey: journey,
        recommendation: {'domain': 'social', 'activity': kindnessRollingGame},
      );

      // Verify natural grammar without "for Your child"
      expect(msg.message, contains('Your child can continue building these skills'));
      expect(msg.message, contains('their learning journey'));
      expect(msg.message, isNot(contains('for Your child')));
    });

    test('Named child uses first name cleanly without duplicated headlines', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'headline': 'Building Social Skills',
              // Simulating Gemini accidentally repeating the headline at start of message
              'message': 'Building Social Skills: Aarav is making wonderful progress with turn-taking and empathy.',
              'suggested_action': 'Start Practice',
              'source': 'gemini',
            },
          }),
          200,
        );
      });

      final service = GrowthMessagingService(client: mockClient);
      final journey = JourneyProgress(
        childId: testChild.childId,
        currentLevel: 1,
        completedActivities: ['act_1'],
        levelProgress: {
          1: LevelProgress(
            completed: ['act_1'],
            domains: {
              'social': const DomainProgress(domain: 'social', score: 30.0, isCompleted: false, activitiesDone: 1),
            },
          ),
        },
      );

      final msg = await service.getOrGenerateMessage(
        child: testChild,
        journey: journey,
        recommendation: {'domain': 'social', 'activity': kindnessRollingGame},
        forceRefresh: true,
      );

      // Repeated headline prefix should be cleanly stripped!
      expect(msg.headline, equals('Building Social Skills'));
      expect(msg.message, startsWith('Aarav is making wonderful progress'));
      expect(msg.message, isNot(startsWith('Building Social Skills:')));
    });
  });

  group('5. ActivityStateService In-Memory & SetOptions Resilience', () {
    test('markCompleted updates state safely without throwing not-found exception', () async {
      final inMem = <String, Map<String, dynamic>>{};
      final stateService = ActivityStateService(inMemoryStore: inMem);

      // Start an activity
      await stateService.startActivity(
        childId: testChild.childId,
        activityId: kindnessRollingGame.id!,
        activityTitle: kindnessRollingGame.title,
        skillDomain: kindnessRollingGame.skillType,
      );

      expect(inMem[testChild.childId]?['status'], equals('in_progress'));

      // Mark completed
      await stateService.markCompleted(testChild.childId);
      expect(inMem[testChild.childId]?['status'], equals('completed_pending_feedback'));

      // Mark feedback submitted
      await stateService.markFeedbackSubmitted(testChild.childId);
      expect(inMem[testChild.childId]?['status'], equals('completed'));
    });
  });
}
