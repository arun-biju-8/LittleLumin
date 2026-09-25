import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/screens/parent/widgets/post_feedback_guidance_sheet.dart';

void main() {
  final testNextActivity = ActivityModel(
    id: 'act_next_1',
    title: 'Gentle Building Blocks',
    shortDescription: 'Stack simple shapes together',
    skillType: 'cognitive',
    difficulty: 'easy',
    ageGroup: [3, 4, 5],
    duration: 10,
    instructions: ['Stack blocks'],
    learningGoals: ['Cognitive shapes'],
    materials: ['Blocks'],
    category: 'Cognitive',
    createdBy: 'system',
    createdByName: 'System',
    createdAt: DateTime.now(),
  );

  group('PostFeedbackGuidanceSheet Tests', () {
    testWidgets('Case A: Positive delta (> 0) renders "Nice work!" and positive delta info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostFeedbackGuidanceSheet(
              childName: 'Leo',
              domain: 'cognitive',
              scoreBefore: 62.0,
              scoreAfter: 65.5,
              delta: 3.5,
              nextActivity: testNextActivity,
            ),
          ),
        ),
      );

      // Verify header and title
      expect(find.text('Nice work!'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);

      // Verify score message
      expect(find.text("Leo's Cognitive score improved from 62 to 65.5 (+3.5)."), findsOneWidget);
      expect(find.text('Great progress! Keep it up.'), findsOneWidget);

      // Verify button
      expect(find.text('Continue with next activity'), findsOneWidget);
      expect(find.text('See growth trends →'), findsNothing);
    });

    testWidgets('Case B: Negative delta (< 0) renders supportive "found that one tricky" message and secondary growth button', (tester) async {
      bool growthTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostFeedbackGuidanceSheet(
              childName: 'Leo',
              domain: 'motor',
              scoreBefore: 50.0,
              scoreAfter: 48.0,
              delta: -2.0,
              nextActivity: testNextActivity,
              onViewGrowth: () => growthTapped = true,
            ),
          ),
        ),
      );

      // Verify title & tone (warm, non-clinical)
      expect(find.text('Leo found that one tricky'), findsOneWidget);
      expect(find.text('💚'), findsOneWidget);

      // Verify score change & supportive body message
      expect(find.text('Motor score: 50 → 48 (-2)'), findsOneWidget);
      expect(find.text("That's okay — every child has tough days. We've prepared a gentler activity to help."), findsOneWidget);

      // Verify primary and secondary action buttons
      expect(find.text('Try easier activity →'), findsOneWidget);
      expect(find.text('See growth trends →'), findsOneWidget);

      await tester.tap(find.text('See growth trends →'));
      await tester.pump();
      expect(growthTapped, isTrue);
    });

    testWidgets('Case C: Zero delta (== 0) renders "Thanks for sharing!" message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const PostFeedbackGuidanceSheet(
              childName: 'Leo',
              domain: 'social',
              scoreBefore: 58.0,
              scoreAfter: 58.0,
              delta: 0.0,
            ),
          ),
        ),
      );

      // Verify title & message
      expect(find.text('Thanks for sharing!'), findsOneWidget);
      expect(find.text('Social score is 58.'), findsOneWidget);
      expect(find.text('Every activity helps — keep going.'), findsOneWidget);

      // Verify button
      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.text('See growth trends →'), findsNothing);
    });

    testWidgets('showPostFeedbackGuidance opens modal bottom sheet and dismisses cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showPostFeedbackGuidance(
                    context,
                    childName: 'Leo',
                    domain: 'language',
                    scoreBefore: 70.0,
                    scoreAfter: 73.0,
                    delta: 3.0,
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nice work!'), findsNothing);

      // Open the sheet
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Nice work!'), findsOneWidget);
      expect(find.text("Leo's Language score improved from 70 to 73 (+3)."), findsOneWidget);

      // Tap Back to Home to dismiss
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('Nice work!'), findsNothing);
    });
  });
}
