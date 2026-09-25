import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/screens/parent/activities/tabs/journey_tab.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/widgets/activity_card.dart';

void main() {
  group('JourneyTab ErrorCard & EmptyCard Widget Tests', () {
    testWidgets('ErrorCard displays error message and triggers onRetry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorCard(
              message: 'Could not load activities. Please try again.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Failed to Load Activities'), findsOneWidget);
      expect(find.text('Could not load activities. Please try again.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('EmptyCard displays empty message and triggers onAction', (tester) async {
      bool actionTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyCard(
              message: 'No activities yet for this level.',
              action: 'Create with AI',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No activities yet for this level.'), findsOneWidget);
      expect(find.text('Create with AI'), findsOneWidget);

      await tester.tap(find.text('Create with AI'));
      await tester.pump();
      expect(actionTriggered, isTrue);
    });

    testWidgets('ActivityCard handles lowercase difficulty values correctly', (tester) async {
      final easyActivity = ActivityModel(
        id: 'easy_1',
        title: 'Easy Fun Task',
        skillType: 'social',
        difficulty: 'easy',
        ageGroup: [4],
        duration: 10,
        instructions: ['Instruction 1'],
        learningGoals: ['Goal 1'],
        materials: ['Material 1'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityCard(
              activity: easyActivity,
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('Easy Fun Task'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
    });
  });
}
