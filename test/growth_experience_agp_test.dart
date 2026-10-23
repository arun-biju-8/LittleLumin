// test/growth_experience_agp_test.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/journey_model.dart';
import 'package:littlelumin/screens/parent/activities/activities_tab.dart';
import 'package:littlelumin/screens/parent/home/journey_card.dart';
import 'package:littlelumin/screens/parent/journey_view.dart';
import 'package:littlelumin/screens/parent/level_detail_screen.dart';
import 'package:littlelumin/screens/parent/widgets/growth_encouragement_card.dart';
import 'package:littlelumin/services/growth_messaging_service.dart';

void main() {
  setUp(() {
    GrowthMessagingService.clearCache();
  });

  tearDown(() {
    GrowthMessagingService.clearCache();
  });

  final childA = ChildModel(
    childId: 'child_a',
    parentId: 'parent_1',
    name: 'Maya Patel',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Female',
    createdAt: DateTime(2023, 1, 1),
  );

  final childB = ChildModel(
    childId: 'child_b',
    parentId: 'parent_1',
    name: 'Liam Chen',
    dateOfBirth: DateTime(DateTime.now().year - 5, 2, 1),
    gender: 'Male',
    createdAt: DateTime(2023, 2, 1),
  );

  group('1. Metric Definitions & Progression Integrity', () {
    test('Authoritative metrics distinguish completed activities from mastered domains', () {
      // Child completed 13 activities, but only 3 of 6 domains have reached 70% threshold
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true, activitiesDone: 3),
        'language': const DomainProgress(domain: 'language', score: 45.0, isCompleted: false, activitiesDone: 2),
        'motor': const DomainProgress(domain: 'motor', score: 80.0, isCompleted: true, activitiesDone: 4),
        'social': const DomainProgress(domain: 'social', score: 55.0, isCompleted: false, activitiesDone: 2),
        'emotional': const DomainProgress(domain: 'emotional', score: 72.0, isCompleted: true, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 60.0, isCompleted: false, activitiesDone: 1),
      };

      final completed13 = List.generate(13, (i) => 'act_${i + 1}');

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: completed13,
        levelProgress: {
          1: LevelProgress(
            completed: ['cognitive', 'motor', 'emotional'],
            total: 6,
            isUnlocked: true,
            domains: domains,
          ),
          2: LevelProgress(completed: [], total: 6, isUnlocked: false),
        },
      );

      // Activities completed count is 13
      expect(journey.completedActivities.length, equals(13));

      // Mastered domains count is 3, total domains is 6
      expect(journey.masteredDomainCount, equals(3));
      expect(journey.currentLevelProgress?.totalDomains, equals(6));

      // Level 1 mastery requires ALL 6 domains >= 70%
      expect(journey.currentLevelProgress?.isCompleted, isFalse);
      expect(journey.isLevelUnlocked(2), isFalse);

      // Domain status accurately distinguishes states without assuming failure
      expect(domains['cognitive']!.status, equals('Mastered'));
      expect(domains['language']!.status, equals('Practice Recommended'));
      expect(domains['social']!.status, equals('Practice Recommended'));
    });

    test('Unassessed and pending domains do not silently treat missing data as zero failure', () {
      final unassessedDomains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 0.0, isCompleted: false, activitiesDone: 0),
        'language': const DomainProgress(domain: 'language', score: 0.0, isCompleted: false, activitiesDone: 0),
      };

      expect(unassessedDomains['cognitive']!.status, equals('Not Started'));
      expect(unassessedDomains['cognitive']!.isMastered, isFalse);
    });

    test('All 6 domains must reach 70% threshold before Level 2 unlocks', () {
      // 5 of 6 domains at 100%, but 6th domain is 69%
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 100.0, isCompleted: true),
        'language': const DomainProgress(domain: 'language', score: 100.0, isCompleted: true),
        'motor': const DomainProgress(domain: 'motor', score: 100.0, isCompleted: true),
        'social': const DomainProgress(domain: 'social', score: 100.0, isCompleted: true),
        'emotional': const DomainProgress(domain: 'emotional', score: 100.0, isCompleted: true),
        'creative': const DomainProgress(domain: 'creative', score: 69.9, isCompleted: false),
      };

      final level1 = LevelProgress(
        completed: ['cognitive', 'language', 'motor', 'social', 'emotional'],
        total: 6,
        isUnlocked: true,
        domains: domains,
      );

      expect(level1.masteredDomainCount, equals(5));
      expect(level1.isCompleted, isFalse);
    });
  });

  group('2. AI Encouragement Engine & State Determination', () {
    final service = GrowthMessagingService();

    test('State A: Initial activities completed but mastery in progress', () {
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true, activitiesDone: 2),
        'language': const DomainProgress(domain: 'language', score: 50.0, isCompleted: false, activitiesDone: 1),
        'motor': const DomainProgress(domain: 'motor', score: 72.0, isCompleted: true, activitiesDone: 2),
        'social': const DomainProgress(domain: 'social', score: 45.0, isCompleted: false, activitiesDone: 1),
        'emotional': const DomainProgress(domain: 'emotional', score: 60.0, isCompleted: false, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 55.0, isCompleted: false, activitiesDone: 1),
      };

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: ['act1', 'act2', 'act3', 'act4', 'act5', 'act6'],
        levelProgress: {
          1: LevelProgress(completed: ['cognitive', 'motor'], total: 6, isUnlocked: true, domains: domains),
        },
      );

      final state = service.determineLearningState(
        journey: journey,
        completedActivitiesCount: 6,
        masteredDomainsCount: 2,
        totalDomainsCount: 6,
      );

      expect(state, equals('initial_activities_completed_mastery_pending'));

      // Check fallback copy for State A
      final msg = service.getOrGenerateMessage(
        child: childA,
        journey: journey,
      );

      expect(
        msg,
        completion(predicate<GrowthMessage>((m) {
          return m.headline.contains('Learning in progress') &&
              m.message.contains('first set of activities is complete') &&
              m.suggestedAction == 'Continue Learning';
        })),
      );
    });

    test('State B: Domain needs more practice', () {
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true, activitiesDone: 2),
        'language': const DomainProgress(domain: 'language', score: 40.0, isCompleted: false, activitiesDone: 1),
      };

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: ['act1', 'act2'],
        levelProgress: {
          1: LevelProgress(completed: ['cognitive'], total: 6, isUnlocked: true, domains: domains),
        },
      );

      final state = service.determineLearningState(
        journey: journey,
        completedActivitiesCount: 2,
        masteredDomainsCount: 1,
        totalDomainsCount: 6,
      );

      expect(state, equals('domain_practice_needed'));
    });

    test('State E: Level mastery achieved across all 6 domains', () {
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true),
        'language': const DomainProgress(domain: 'language', score: 72.0, isCompleted: true),
        'motor': const DomainProgress(domain: 'motor', score: 80.0, isCompleted: true),
        'social': const DomainProgress(domain: 'social', score: 70.0, isCompleted: true),
        'emotional': const DomainProgress(domain: 'emotional', score: 78.0, isCompleted: true),
        'creative': const DomainProgress(domain: 'creative', score: 85.0, isCompleted: true),
      };

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        unlockedLevels: [1, 2],
        completedActivities: ['act1', 'act2', 'act3', 'act4', 'act5', 'act6'],
        levelProgress: {
          1: LevelProgress(
            completed: ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative'],
            total: 6,
            isUnlocked: true,
            domains: domains,
          ),
          2: LevelProgress(completed: [], total: 6, isUnlocked: true),
        },
      );

      final state = service.determineLearningState(
        journey: journey,
        completedActivitiesCount: 6,
        masteredDomainsCount: 6,
        totalDomainsCount: 6,
      );

      expect(state, equals('level_mastered'));
    });
  });

  group('3. Caching, Invalidation, Segregation & Deduplication', () {
    test('Messages for different children are completely segregated in cache', () async {
      int serverCalls = 0;
      final mockClient = MockClient((request) async {
        serverCalls++;
        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final childName = reqBody['child_name'];
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'headline': 'Progress for $childName',
              'message': 'Encouraging message specifically for $childName.',
              'suggested_action': 'Explore',
              'source': 'gemini',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GrowthMessagingService(client: mockClient);

      final journeyA = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      final journeyB = JourneyProgress(
        childId: 'child_b',
        currentLevel: 1,
        completedActivities: ['act1', 'act2'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      final msgA = await service.getOrGenerateMessage(child: childA, journey: journeyA);
      final msgB = await service.getOrGenerateMessage(child: childB, journey: journeyB);

      expect(serverCalls, equals(2));
      expect(msgA.headline, contains('Maya'));
      expect(msgB.headline, contains('Liam'));
      expect(msgA.headline, isNot(equals(msgB.headline)));
    });

    test('Repeated calls with identical progression state reuse cached message without network calls', () async {
      int serverCalls = 0;
      final mockClient = MockClient((request) async {
        serverCalls++;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'headline': 'Consistent Message',
              'message': 'Child is doing wonderfully.',
              'suggested_action': 'Keep Going',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GrowthMessagingService(client: mockClient);

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      // Call 1 -> Network
      final msg1 = await service.getOrGenerateMessage(child: childA, journey: journey);
      expect(serverCalls, equals(1));

      // Call 2 & 3 -> Cache
      final msg2 = await service.getOrGenerateMessage(child: childA, journey: journey);
      final msg3 = await service.getOrGenerateMessage(child: childA, journey: journey);

      expect(serverCalls, equals(1));
      expect(msg2.headline, equals(msg1.headline));
      expect(msg3.headline, equals(msg1.headline));
    });

    test('Meaningful progress changes invalidate stale messaging and trigger fresh generation', () async {
      int serverCalls = 0;
      final mockClient = MockClient((request) async {
        serverCalls++;
        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final count = reqBody['completed_activities_count'];
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'headline': 'Completed $count Activities',
              'message': 'Keep up the practice!',
              'suggested_action': 'Next Activity',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GrowthMessagingService(client: mockClient);

      final journeyInitial = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      final msg1 = await service.getOrGenerateMessage(child: childA, journey: journeyInitial);
      expect(serverCalls, equals(1));
      expect(msg1.headline, equals('Completed 1 Activities'));

      // Child completes another activity!
      final journeyUpdated = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1', 'act2'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      final msg2 = await service.getOrGenerateMessage(child: childA, journey: journeyUpdated);
      expect(serverCalls, equals(2));
      expect(msg2.headline, equals('Completed 2 Activities'));
    });

    test('Concurrent requests for the same child are deduplicated to a single HTTP request', () async {
      int serverCalls = 0;
      final mockClient = MockClient((request) async {
        serverCalls++;
        await Future.delayed(const Duration(milliseconds: 20));
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'headline': 'Shared Future',
              'message': 'Concurrent calls are deduplicated.',
              'suggested_action': 'Start',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GrowthMessagingService(client: mockClient);

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      // Launch 3 concurrent requests simultaneously
      final futures = [
        service.getOrGenerateMessage(child: childA, journey: journey),
        service.getOrGenerateMessage(child: childA, journey: journey),
        service.getOrGenerateMessage(child: childA, journey: journey),
      ];

      final results = await Future.wait(futures);

      expect(serverCalls, equals(1)); // Only ONE network call!
      expect(results[0].headline, equals('Shared Future'));
      expect(results[1].headline, equals('Shared Future'));
      expect(results[2].headline, equals('Shared Future'));
    });

    test('Graceful fallback when AI backend fails or times out', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Service unavailable'}),
          503,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GrowthMessagingService(client: mockClient);

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1', 'act2', 'act3', 'act4', 'act5', 'act6'],
        levelProgress: {1: LevelProgress(completed: ['cognitive'], total: 6)},
      );

      // Does not throw! Returns clean fallback message
      final msg = await service.getOrGenerateMessage(child: childA, journey: journey);
      expect(msg.isFallback, isTrue);
      expect(msg.headline, contains('Learning in progress'));
      expect(msg.suggestedAction, equals('Continue Learning'));
    });

    test('Non-identifying privacy: payload does not contain full name, email, or credentials', () async {
      Map<String, dynamic>? capturedPayload;
      final mockClient = MockClient((request) async {
        capturedPayload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'headline': 'Private Message',
              'message': 'Clean and safe.',
              'suggested_action': 'Continue',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GrowthMessagingService(client: mockClient);

      final fullNamedChild = ChildModel(
        childId: 'c_secret_123',
        parentId: 'p_private_456',
        name: 'Maya S. Patel-Wellington',
        dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
        gender: 'Female',
        createdAt: DateTime(2023, 1, 1),
      );

      final journey = JourneyProgress(
        childId: fullNamedChild.childId,
        currentLevel: 1,
        completedActivities: ['act1'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      await service.getOrGenerateMessage(child: fullNamedChild, journey: journey);

      expect(capturedPayload, isNotNull);
      // Only first name transmitted, never full surname or email/tokens
      expect(capturedPayload!['child_name'], equals('Maya'));
      expect(capturedPayload!.containsKey('email'), isFalse);
      expect(capturedPayload!.containsKey('token'), isFalse);
      expect(capturedPayload!.containsKey('password'), isFalse);
    });
  });

  group('4. UI Widget & Label Accuracy Verification', () {
    testWidgets('ActivitiesTab displays accurate activities completed and domains mastered', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true, activitiesDone: 2),
        'language': const DomainProgress(domain: 'language', score: 45.0, isCompleted: false, activitiesDone: 1),
        'motor': const DomainProgress(domain: 'motor', score: 80.0, isCompleted: true, activitiesDone: 3),
        'social': const DomainProgress(domain: 'social', score: 50.0, isCompleted: false, activitiesDone: 1),
        'emotional': const DomainProgress(domain: 'emotional', score: 60.0, isCompleted: false, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 78.0, isCompleted: true, activitiesDone: 2),
      };

      // 13 activities completed!
      final completed13 = List.generate(13, (i) => 'act_$i');

      final journey13 = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: completed13,
        levelProgress: {
          1: LevelProgress(completed: ['cognitive', 'motor', 'creative'], total: 6, isUnlocked: true, domains: domains),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivitiesTab(
              activeChild: childA,
              journeyStream: Stream.value(journey13),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure NO misleading label like '13 of 6 skills explored'
      expect(find.text('13 of 6 skills explored'), findsNothing);
      expect(find.textContaining('skills explored'), findsNothing);

      // Verifies accurate metric label
      expect(
        find.text('13 activities completed · 3 of 6 domains mastered'),
        findsOneWidget,
      );
    });

    testWidgets('JourneyCard renders accurate domains mastered and completed activity count', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true, activitiesDone: 2),
        'language': const DomainProgress(domain: 'language', score: 45.0, isCompleted: false, activitiesDone: 1),
        'motor': const DomainProgress(domain: 'motor', score: 80.0, isCompleted: true, activitiesDone: 3),
        'social': const DomainProgress(domain: 'social', score: 50.0, isCompleted: false, activitiesDone: 1),
        'emotional': const DomainProgress(domain: 'emotional', score: 60.0, isCompleted: false, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 78.0, isCompleted: true, activitiesDone: 2),
      };

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: ['act1', 'act2', 'act3', 'act4', 'act5'],
        levelProgress: {
          1: LevelProgress(completed: ['cognitive', 'motor', 'creative'], total: 6, isUnlocked: true, domains: domains),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneyCard(
              child: childA,
              journeyStream: Stream.value(journey),
              onContinueJourney: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Does not render conflated skills label
      expect(find.textContaining('/6 skills'), findsNothing);

      // Renders accurate domains mastered and completed activity count
      expect(find.text('Level 1 · 3/6 domains mastered'), findsOneWidget);
      expect(find.text('5 activities completed (70% domain mastery goal)'), findsOneWidget);
    });

    testWidgets('GrowthEncouragementCard renders headline, encouragement copy, and action button', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool actionTapped = false;
      final initialMsg = GrowthMessage(
        headline: 'Level 1 · Learning in progress',
        message: 'The first set of activities is complete — a lovely milestone! Maya can continue building these skills through more practice.',
        suggestedAction: 'Continue Learning',
        source: 'gemini',
        stateFingerprint: 'fp123',
        generatedAt: DateTime(2026, 1, 1),
      );

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1', 'act2', 'act3', 'act4', 'act5', 'act6'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrowthEncouragementCard(
              child: childA,
              journey: journey,
              initialMessage: initialMsg,
              onActionTap: () {
                actionTapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PARENT GUIDANCE'), findsOneWidget);
      expect(find.text('Level 1 · Learning in progress'), findsOneWidget);
      expect(
        find.text('The first set of activities is complete — a lovely milestone! Maya can continue building these skills through more practice.'),
        findsOneWidget,
      );
      expect(find.text('Continue Learning'), findsOneWidget);

      await tester.tap(find.text('Continue Learning'));
      await tester.pumpAndSettle();
      expect(actionTapped, isTrue);
    });

    testWidgets('JourneyViewScreen integrates GrowthEncouragementCard seamlessly', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialMsg = GrowthMessage(
        headline: 'Level 1 · Learning in progress',
        message: 'Every child develops at their own rhythm. Maya is doing great with foundational skills.',
        suggestedAction: 'Continue Learning',
        source: 'gemini',
        stateFingerprint: 'fp_journey_view',
        generatedAt: DateTime.now(),
      );

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1', 'act2', 'act3', 'act4', 'act5', 'act6'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: JourneyViewScreen(
            activeChild: childA,
            initialJourneyProgress: journey,
            initialGrowthMessage: initialMsg,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GrowthEncouragementCard), findsOneWidget);
      expect(find.text('PARENT GUIDANCE'), findsOneWidget);
      expect(find.text('Level 1 · Learning in progress'), findsWidgets);
      expect(
        find.text('Every child develops at their own rhythm. Maya is doing great with foundational skills.'),
        findsOneWidget,
      );
    });

    testWidgets('LevelDetailScreen integrates GrowthEncouragementCard in overview tab', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialMsg = GrowthMessage(
        headline: 'Level 1 · Learning in progress',
        message: 'The initial activity set is finished. Continued play and practice builds mastery.',
        suggestedAction: 'Practice Next Skill',
        source: 'gemini',
        stateFingerprint: 'fp_level_detail',
        generatedAt: DateTime.now(),
      );

      final journey = JourneyProgress(
        childId: 'child_a',
        currentLevel: 1,
        completedActivities: ['act1', 'act2', 'act3'],
        levelProgress: {1: LevelProgress(completed: [], total: 6)},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            activeChild: childA,
            level: 1,
            initialJourneyProgress: journey,
            initialGrowthMessage: initialMsg,
            scoreEventsStream: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GrowthEncouragementCard), findsOneWidget);
      expect(find.text('PARENT GUIDANCE'), findsOneWidget);
      expect(
        find.text('The initial activity set is finished. Continued play and practice builds mastery.'),
        findsOneWidget,
      );
      expect(find.text('Practice Next Skill'), findsOneWidget);
    });
  });
}
