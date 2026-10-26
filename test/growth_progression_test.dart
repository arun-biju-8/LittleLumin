import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/models/journey_model.dart';
import 'package:littlelumin/screens/parent/journey_view.dart';
import 'package:littlelumin/screens/parent/level_detail_screen.dart';
import 'package:littlelumin/services/journey_service.dart';

void main() {
  group('Phase 2 & 6: DomainProgress and Mastery Rules', () {
    test('1. DomainProgress correctly identifies mastery at 70% threshold', () {
      const below = DomainProgress(domain: 'cognitive', score: 68.5, isCompleted: false, activitiesDone: 3);
      expect(below.isMastered, isFalse);
      expect(below.status, equals('Practice Recommended'));

      const atThreshold = DomainProgress(domain: 'cognitive', score: 70.0, isCompleted: false, activitiesDone: 3);
      expect(atThreshold.isMastered, isTrue);
      expect(atThreshold.status, equals('Mastered'));

      const above = DomainProgress(domain: 'cognitive', score: 85.0, isCompleted: true, activitiesDone: 4);
      expect(above.isMastered, isTrue);
      expect(above.status, equals('Mastered'));

      const notStarted = DomainProgress(domain: 'motor', score: 0.0, isCompleted: false, activitiesDone: 0);
      expect(notStarted.isMastered, isFalse);
      expect(notStarted.status, equals('Not Started'));

      const inProgress = DomainProgress(domain: 'motor', score: 35.0, isCompleted: false, activitiesDone: 0);
      expect(inProgress.isMastered, isFalse);
      expect(inProgress.status, equals('In Progress'));
    });

    test('2. Completing an activity does not automatically imply domain mastery', () {
      // Child completed 6 activities, but domain scores are below 70
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 25.0, isCompleted: false, activitiesDone: 1),
        'language': const DomainProgress(domain: 'language', score: 30.0, isCompleted: false, activitiesDone: 1),
        'motor': const DomainProgress(domain: 'motor', score: 20.0, isCompleted: false, activitiesDone: 1),
        'social': const DomainProgress(domain: 'social', score: 45.0, isCompleted: false, activitiesDone: 1),
        'emotional': const DomainProgress(domain: 'emotional', score: 35.0, isCompleted: false, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 28.0, isCompleted: false, activitiesDone: 1),
      };

      final level1 = LevelProgress(
        completed: ['act_1', 'act_2', 'act_3', 'act_4', 'act_5', 'act_6'],
        total: 6,
        isUnlocked: true,
        domains: domains,
      );

      // Mastery must NOT be granted just because 6 activities were completed!
      expect(level1.masteredDomainCount, equals(0));
      expect(level1.isCompleted, isFalse);
      expect(level1.progressPercent, equals(0));
    });

    test('3. Meeting 70% threshold across all 6 domains satisfies Level 1 mastery', () {
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 72.0, isCompleted: true, activitiesDone: 3),
        'language': const DomainProgress(domain: 'language', score: 70.0, isCompleted: true, activitiesDone: 2),
        'motor': const DomainProgress(domain: 'motor', score: 85.0, isCompleted: true, activitiesDone: 4),
        'social': const DomainProgress(domain: 'social', score: 78.0, isCompleted: true, activitiesDone: 3),
        'emotional': const DomainProgress(domain: 'emotional', score: 71.0, isCompleted: true, activitiesDone: 2),
        'creative': const DomainProgress(domain: 'creative', score: 90.0, isCompleted: true, activitiesDone: 5),
      };

      final level1 = LevelProgress(
        completed: ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative'],
        total: 6,
        isUnlocked: true,
        domains: domains,
      );

      expect(level1.masteredDomainCount, equals(6));
      expect(level1.isCompleted, isTrue);
      expect(level1.progressPercent, equals(100));
    });

    test('4. Level 2 remains locked when visible activities are done but mastery is incomplete', () {
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true, activitiesDone: 2),
        'language': const DomainProgress(domain: 'language', score: 45.0, isCompleted: false, activitiesDone: 1),
        'motor': const DomainProgress(domain: 'motor', score: 72.0, isCompleted: true, activitiesDone: 2),
        'social': const DomainProgress(domain: 'social', score: 50.0, isCompleted: false, activitiesDone: 1),
        'emotional': const DomainProgress(domain: 'emotional', score: 60.0, isCompleted: false, activitiesDone: 1),
        'creative': const DomainProgress(domain: 'creative', score: 78.0, isCompleted: true, activitiesDone: 2),
      };

      final journey = JourneyProgress(
        childId: 'child_123',
        currentLevel: 1,
        unlockedLevels: [1],
        completedActivities: ['act_1', 'act_2', 'act_3', 'act_4', 'act_5', 'act_6'],
        levelProgress: {
          1: LevelProgress(
            completed: ['cognitive', 'motor', 'creative'],
            total: 6,
            isUnlocked: true,
            domains: domains,
          ),
          2: LevelProgress(completed: [], total: 6, isUnlocked: false),
        },
      );

      // Level 1 is unlocked, but Level 2 must remain LOCKED
      expect(journey.isLevelUnlocked(1), isTrue);
      expect(journey.isLevelUnlocked(2), isFalse);
      expect(journey.masteredDomainCount, equals(3));

      // Correctly identifies remaining pending domains needing practice
      final pending = journey.pendingDomainKeys;
      expect(pending, containsAll(['language', 'social', 'emotional']));
      expect(pending, isNot(contains('cognitive')));

      // Correctly finds lowest-scoring pending domain for targeted recommendations
      final lowest = journey.lowestScoringPendingDomain;
      expect(lowest, isNotNull);
      expect(lowest!.domain, equals('language'));
      expect(lowest.score, equals(45.0));
    });

    test('5. Satisfying all progression requirements unlocks Level 2', () {
      final domains = {
        'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true),
        'language': const DomainProgress(domain: 'language', score: 72.0, isCompleted: true),
        'motor': const DomainProgress(domain: 'motor', score: 70.0, isCompleted: true),
        'social': const DomainProgress(domain: 'social', score: 80.0, isCompleted: true),
        'emotional': const DomainProgress(domain: 'emotional', score: 78.0, isCompleted: true),
        'creative': const DomainProgress(domain: 'creative', score: 82.0, isCompleted: true),
      };

      final journey = JourneyProgress(
        childId: 'child_123',
        currentLevel: 2,
        unlockedLevels: [1, 2],
        completedActivities: ['act_1', 'act_2', 'act_3', 'act_4', 'act_5', 'act_6'],
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

      expect(journey.isLevelUnlocked(1), isTrue);
      expect(journey.isLevelUnlocked(2), isTrue);
      expect(journey.levelProgress[1]!.isCompleted, isTrue);
      expect(journey.levelProgress[1]!.masteredDomainCount, equals(6));
    });

    test('6. Missing assessment data does not cause incorrect unlocking or misleading progress', () {
      final journey = JourneyProgress.fromMap('child_new', {
        'currentLevel': 1,
        'unlockedLevels': [1],
        'levels': {
          '1': {
            'domains': {},
            'isCompleted': false,
          }
        },
        'completedActivities': [],
      });

      expect(journey.isLevelUnlocked(1), isTrue);
      expect(journey.isLevelUnlocked(2), isFalse);
      expect(journey.masteredDomainCount, equals(0));
      expect(journey.pendingDomainKeys.length, equals(6));
    });

    test('7. Progress persists across app restarts (fromMap/toMap serialization round-trip)', () {
      final rawFirestoreMap = {
        'childId': 'child_test',
        'currentLevel': 1,
        'unlockedLevels': [1],
        'levels': {
          '1': {
            'domains': {
              'cognitive': {'score': 74.0, 'completed': true, 'activitiesDone': 3},
              'language': {'score': 45.0, 'completed': false, 'activitiesDone': 1},
              'motor': {'score': 80.0, 'completed': true, 'activitiesDone': 4},
              'social': {'score': 55.0, 'completed': false, 'activitiesDone': 2},
              'emotional': {'score': 62.0, 'completed': false, 'activitiesDone': 2},
              'creative': {'score': 71.0, 'completed': true, 'activitiesDone': 3},
            },
            'isCompleted': false,
          }
        },
        'completedActivities': ['act_1', 'act_2', 'act_3'],
      };

      // 1. Parse from Firestore data
      final parsed = JourneyProgress.fromMap('child_test', rawFirestoreMap);
      expect(parsed.masteredDomainCount, equals(3));
      expect(parsed.isLevelUnlocked(2), isFalse);
      expect(parsed.currentLevelDomains['cognitive']?.isMastered, isTrue);
      expect(parsed.currentLevelDomains['language']?.isMastered, isFalse);
      expect(parsed.currentLevelDomains['language']?.score, equals(45.0));

      // 2. Serialize to Map
      final serialized = parsed.toMap();
      expect(serialized['currentLevel'], equals(1));
      expect(serialized['unlockedLevels'], equals([1]));
      expect(serialized['completedActivities'], equals(['act_1', 'act_2', 'act_3']));

      // 3. Re-parse from serialized Map
      final reloaded = JourneyProgress.fromMap('child_test', serialized);
      expect(reloaded.currentLevel, equals(1));
      expect(reloaded.isLevelUnlocked(1), isTrue);
      expect(reloaded.isLevelUnlocked(2), isFalse);
    });

    test('8. JourneyService PASSING_SCORE constant is strictly 70', () {
      expect(JourneyService.PASSING_SCORE, equals(70));
    });
  });

  group('Phase 3 & 6: Growth Screen UI & Widget Tests', () {
    final testChild = ChildModel(
      childId: 'child_widget_test',
      parentId: 'parent_1',
      name: 'Maya',
      dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
      gender: 'Female',
      createdAt: DateTime(2023, 1, 1),
    );

    final domains = {
      'cognitive': const DomainProgress(domain: 'cognitive', score: 75.0, isCompleted: true, activitiesDone: 2),
      'language': const DomainProgress(domain: 'language', score: 45.0, isCompleted: false, activitiesDone: 1),
      'motor': const DomainProgress(domain: 'motor', score: 72.0, isCompleted: true, activitiesDone: 2),
      'social': const DomainProgress(domain: 'social', score: 50.0, isCompleted: false, activitiesDone: 1),
      'emotional': const DomainProgress(domain: 'emotional', score: 60.0, isCompleted: false, activitiesDone: 1),
      'creative': const DomainProgress(domain: 'creative', score: 78.0, isCompleted: true, activitiesDone: 2),
    };

    final testJourney = JourneyProgress(
      childId: 'child_widget_test',
      currentLevel: 1,
      unlockedLevels: [1],
      completedActivities: ['act_1', 'act_2', 'act_3', 'act_4', 'act_5', 'act_6'],
      levelProgress: {
        1: LevelProgress(
          completed: ['cognitive', 'motor', 'creative'],
          total: 6,
          isUnlocked: true,
          domains: domains,
        ),
        2: LevelProgress(completed: [], total: 6, isUnlocked: false),
      },
    );

    testWidgets('JourneyViewScreen renders Level Progress Card without conflating completion and mastery', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: JourneyViewScreen(
            activeChild: testChild,
            initialJourneyProgress: testJourney,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Child name & level
      expect(find.text("Maya's Learning Journey"), findsOneWidget);
      expect(find.text('Level 1: Foundation Skills'), findsWidgets);

      // Distinct metrics
      expect(find.text('ACTIVITIES DONE'), findsOneWidget);
      expect(find.text('6 Completed'), findsOneWidget);

      expect(find.text('DOMAINS MASTERED'), findsOneWidget);
      expect(find.text('3 of 6'), findsOneWidget);

      // Clear requirement explanation
      expect(
        find.text('To unlock Level 2, your child must achieve 70% mastery across all 6 core domains.'),
        findsOneWidget,
      );
    });

    testWidgets('JourneyViewScreen renders all 6 developmental domain cards with status chips', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: JourneyViewScreen(
            activeChild: testChild,
            initialJourneyProgress: testJourney,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Developmental Domains'), findsOneWidget);

      // All 6 domains rendered
      expect(find.text('Cognitive'), findsWidgets);
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Motor'), findsWidgets);
      expect(find.text('Social'), findsWidgets);
      expect(find.text('Emotional'), findsWidgets);
      expect(find.text('Creative'), findsWidgets);

      // Status badges
      expect(find.text('Mastered 🟢'), findsNWidgets(3)); // Cognitive, Motor, Creative
      expect(find.text('Practice 🟡'), findsNWidgets(3)); // Language, Social, Emotional
    });

    testWidgets('JourneyViewScreen renders locked Level 2 card with clear guidance and continue action', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: JourneyViewScreen(
            activeChild: testChild,
            initialJourneyProgress: testJourney,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock Requirement: Level 1 Mastery'), findsOneWidget);
      expect(find.text('3 of 6 Mastered'), findsWidgets);
      expect(find.text('Practise Activities to Unlock Level 2'), findsWidgets);
    });

    testWidgets('LevelDetailScreen renders overview, all 6 domains, and progression checklist', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            activeChild: testChild,
            level: 1,
            initialJourneyProgress: testJourney,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header title
      expect(find.text('Level 1 Workspace'), findsOneWidget);

      // Level overview card
      expect(find.text('Level 1: Foundation Skills'), findsOneWidget);
      expect(find.text('6 Completed'), findsOneWidget);
      expect(find.text('3 of 6 Mastered'), findsWidgets);
      expect(
        find.text('Unlock Requirement: Achieve 70% mastery in all 6 core domains (3 of 6 achieved).'),
        findsOneWidget,
      );

      // Six developmental domains
      expect(find.text('SIX DEVELOPMENTAL DOMAINS'), findsOneWidget);
      expect(find.text('Cognitive'), findsWidgets);
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Motor Skills'), findsWidgets);
      expect(find.text('Social'), findsWidgets);
      expect(find.text('Emotional'), findsWidgets);
      expect(find.text('Creative'), findsWidgets);

      // Mastery status chips
      expect(find.text('Mastered 🏆'), findsNWidgets(3));
      expect(find.text('In Progress'), findsNWidgets(3));

      // Level Advancement Checklist
      expect(find.text('LEVEL ADVANCEMENT CHECKLIST'), findsOneWidget);
      expect(find.text('3 of 6 Met'), findsOneWidget);
    });

    final testActivity1 = ActivityModel(
      id: 'act_1',
      title: 'Building Blocks Tower',
      skillType: 'Motor',
      difficulty: 'Easy',
      ageGroup: [3, 4, 5],
      duration: 15,
      instructions: ['Stack the blocks'],
      learningGoals: ['Hand-eye coordination'],
      materials: ['Blocks'],
      createdBy: 'system',
      createdByName: 'LittleLumin',
      category: 'motor',
      tags: ['motor'],
      createdAt: DateTime.now(),
    );

    testWidgets('LevelDetailScreen renders overview, all 6 domains, and progression checklist', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            activeChild: testChild,
            level: 1,
            initialJourneyProgress: testJourney,
            scoreEventsStream: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header title
      expect(find.text('Level 1 Workspace'), findsOneWidget);

      // Level overview card
      expect(find.text('Level 1: Foundation Skills'), findsOneWidget);
      expect(find.text('6 Completed'), findsOneWidget);
      expect(find.text('3 of 6 Mastered'), findsWidgets);
      expect(
        find.text('Unlock Requirement: Achieve 70% mastery in all 6 core domains (3 of 6 achieved).'),
        findsOneWidget,
      );

      // Six developmental domains
      expect(find.text('SIX DEVELOPMENTAL DOMAINS'), findsOneWidget);
      expect(find.text('Cognitive'), findsWidgets);
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Motor Skills'), findsWidgets);
      expect(find.text('Social'), findsWidgets);
      expect(find.text('Emotional'), findsWidgets);
      expect(find.text('Creative'), findsWidgets);

      // Mastery status chips
      expect(find.text('Mastered 🏆'), findsNWidgets(3));
      expect(find.text('In Progress'), findsNWidgets(3));

      // Level Advancement Checklist
      expect(find.text('LEVEL ADVANCEMENT CHECKLIST'), findsOneWidget);
      expect(find.text('3 of 6 Met'), findsOneWidget);
    });

    testWidgets('LevelDetailScreen Activities Tab renders completed activity without strikethrough styling', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LevelDetailScreen(
            activeChild: testChild,
            level: 1,
            initialJourneyProgress: testJourney,
            initialActivities: [testActivity1],
            scoreEventsStream: const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Tab 2: Activities & History
      await tester.tap(find.text('Activities & History'));
      await tester.pumpAndSettle();

      // Verify guidance banner on completed activities
      expect(
        find.text('Completed activities can always be revisited. Mastery is demonstrated through ongoing practice assessments.'),
        findsOneWidget,
      );
      expect(find.text('LEVEL 1 ACTIVITIES'), findsOneWidget);

      // Verify completed activity title and status
      expect(find.text('Building Blocks Tower'), findsOneWidget);
      expect(find.text('Completed · Tap to replay'), findsOneWidget);

      // CRITICAL: Ensure NO strikethrough (TextDecoration.lineThrough) styling
      final textWidget = tester.widget<Text>(find.text('Building Blocks Tower'));
      expect(textWidget.style?.decoration, isNot(TextDecoration.lineThrough));
    });
  });
}
