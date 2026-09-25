import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/screens/parent/home/active_activity_banner.dart';
import 'package:littlelumin/services/activity_state_service.dart';

void main() {
  group('ActiveActivityBanner Widget Tests', () {
    late Map<String, Map<String, dynamic>> inMemoryStore;
    late ActivityStateService service;

    setUp(() {
      inMemoryStore = {};
      service = ActivityStateService(inMemoryStore: inMemoryStore);
    });

    testWidgets('Renders nothing when no active activity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveActivityBanner(
              childId: 'c1',
              service: service,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('ACTIVITY IN PROGRESS'), findsNothing);
      expect(find.text('Complete Now'), findsNothing);
    });

    testWidgets('Renders in-progress banner with details and handles Complete Now', (tester) async {
      final now = DateTime.now();
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Memory Match Game',
        'skillDomain': 'cognitive',
        'status': 'in_progress',
        'startedAt': now.subtract(const Duration(minutes: 15)),
        'lastReminderAt': null,
        'reminderCount': 0,
      };

      bool completeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveActivityBanner(
              childId: 'c1',
              service: service,
              onCompleteNow: () => completeTapped = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('ACTIVITY IN PROGRESS'), findsOneWidget);
      expect(find.text('"Memory Match Game"'), findsOneWidget);
      expect(find.text('Skill Domain: Cognitive'), findsOneWidget);
      expect(find.text('Complete Now'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Complete Now'));
      expect(completeTapped, isTrue);
    });

    testWidgets('Renders feedback pending badge when status is completed_pending_feedback', (tester) async {
      final now = DateTime.now();
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Finger Painting',
        'skillDomain': 'creative',
        'status': 'completed_pending_feedback',
        'startedAt': now.subtract(const Duration(hours: 1)),
        'completedAt': now.subtract(const Duration(minutes: 10)),
        'lastReminderAt': null,
        'reminderCount': 0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveActivityBanner(
              childId: 'c1',
              service: service,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('FEEDBACK PENDING'), findsOneWidget);
      expect(find.text('"Finger Painting"'), findsOneWidget);
    });

    testWidgets('Discard button shows confirmation dialog and removes activity', (tester) async {
      final now = DateTime.now();
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Story Time',
        'skillDomain': 'language',
        'status': 'in_progress',
        'startedAt': now.subtract(const Duration(minutes: 5)),
        'lastReminderAt': null,
        'reminderCount': 0,
      };

      bool discardCallbackFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActiveActivityBanner(
              childId: 'c1',
              service: service,
              onDiscard: () => discardCallbackFired = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('"Story Time"'), findsOneWidget);

      // Tap the discard button on banner
      await tester.tap(find.widgetWithText(OutlinedButton, 'Discard'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Discard Activity?'), findsOneWidget);

      // Tap 'Discard' in dialog (the elevated button)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Discard'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(discardCallbackFired, isTrue);
      expect(inMemoryStore.containsKey('c1'), isFalse);
    });
  });
}
