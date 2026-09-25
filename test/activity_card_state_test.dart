import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/widgets/activity_card.dart';

void main() {
  group('ActivityCard State Machine Tests', () {
    test('resolveButtonState returns start when no active activity', () {
      final state = ActivityCard.resolveButtonState(
        activityId: 'act_1',
        activeActivity: null,
      );
      expect(state, ActivityButtonState.start);
      expect(ActivityCard.getButtonLabel(state), 'Start Activity');
    });

    test('resolveButtonState returns continueActivity when in_progress', () {
      final state = ActivityCard.resolveButtonState(
        activityId: 'act_1',
        activeActivity: {
          'activityId': 'act_1',
          'status': 'in_progress',
        },
      );
      expect(state, ActivityButtonState.continueActivity);
      expect(ActivityCard.getButtonLabel(state), 'Continue Activity');
    });

    test('resolveButtonState returns submitFeedback when completed_pending_feedback', () {
      final state = ActivityCard.resolveButtonState(
        activityId: 'act_1',
        activeActivity: {
          'activityId': 'act_1',
          'status': 'completed_pending_feedback',
        },
      );
      expect(state, ActivityButtonState.submitFeedback);
      expect(ActivityCard.getButtonLabel(state), 'Submit Feedback');
    });

    test('resolveButtonState returns view when completed in active doc', () {
      final state = ActivityCard.resolveButtonState(
        activityId: 'act_1',
        activeActivity: {
          'activityId': 'act_1',
          'status': 'completed',
        },
      );
      expect(state, ActivityButtonState.view);
      expect(ActivityCard.getButtonLabel(state), 'View');
    });

    test('resolveButtonState returns view when marked completed in journey', () {
      final state = ActivityCard.resolveButtonState(
        activityId: 'act_1',
        activeActivity: null,
        isCompletedInJourney: true,
      );
      expect(state, ActivityButtonState.view);
      expect(ActivityCard.getButtonLabel(state), 'View');
    });

    test('resolveButtonState returns start for different activity ID even if another is active', () {
      final state = ActivityCard.resolveButtonState(
        activityId: 'act_2',
        activeActivity: {
          'activityId': 'act_1',
          'status': 'in_progress',
        },
      );
      expect(state, ActivityButtonState.start);
    });

    testWidgets('ActivityCard renders button with action state', (tester) async {
      final activity = ActivityModel(
        id: 'act_1',
        title: 'Building Blocks',
        skillType: 'motor',
        difficulty: 'Easy',
        ageGroup: [3, 4, 5],
        duration: 15,
        shortDescription: 'Stack colorful blocks together.',
        instructions: ['Stack blocks'],
        learningGoals: ['Motor coordination'],
        materials: ['Blocks'],
        createdAt: DateTime.now(),
      );

      bool buttonTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityCard(
              activity: activity,
              buttonState: ActivityButtonState.continueActivity,
              onActionButtonTap: () => buttonTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Building Blocks'), findsOneWidget);
      expect(find.text('Continue Activity'), findsOneWidget);

      await tester.tap(find.text('Continue Activity'));
      expect(buttonTapped, isTrue);
    });
  });
}
