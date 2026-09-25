// test/activity_library_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/screens/parent/activities/activity_library_screen.dart';

void main() {
  final activities = [
    ActivityModel(
      id: 'a1',
      title: 'Animal Nature Safari',
      shortDescription: 'Outdoor animal game',
      skillType: 'Cognitive',
      difficulty: 'Easy',
      ageGroup: [3, 4],
      duration: 10,
      instructions: ['Step 1'],
      learningGoals: ['Explore nature'],
      materials: [],
      createdAt: DateTime.now(),
    ),
    ActivityModel(
      id: 'a2',
      title: 'Color Rhyme Story',
      shortDescription: 'Word play with rhymes',
      skillType: 'Language',
      difficulty: 'Medium',
      ageGroup: [5],
      duration: 8,
      instructions: ['Step 1'],
      learningGoals: ['Phonics'],
      materials: [],
      createdAt: DateTime.now(),
    ),
  ];

  group('ActivityLibraryScreen Tests', () {
    testWidgets('Search filters activities live by title and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityLibraryScreen(
            initialActivities: activities,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2 results'), findsOneWidget);
      expect(find.text('Animal Nature Safari'), findsOneWidget);
      expect(find.text('Color Rhyme Story'), findsOneWidget);

      // Search 'Rhyme'
      await tester.enterText(find.byType(TextField), 'Rhyme');
      await tester.pumpAndSettle();

      expect(find.text('1 result'), findsOneWidget);
      expect(find.text('Color Rhyme Story'), findsOneWidget);
      expect(find.text('Animal Nature Safari'), findsNothing);
    });

    testWidgets('Filter dropdown selection adds removable active filter chip and updates count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityLibraryScreen(
            initialActivities: activities,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Skill' dropdown button
      await tester.tap(find.text('Skill'));
      await tester.pumpAndSettle();

      // Select 'Language'
      await tester.tap(find.widgetWithText(ListTile, 'Language'));
      await tester.pumpAndSettle();

      // Removable chip 'Language' appears and result count updates to 1
      expect(find.text('Language'), findsAtLeastNWidgets(1));
      expect(find.text('1 result'), findsOneWidget);
      expect(find.text('Color Rhyme Story'), findsOneWidget);
      expect(find.text('Animal Nature Safari'), findsNothing);

      // Tap 'Clear all'
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('2 results'), findsOneWidget);
      expect(find.text('Animal Nature Safari'), findsOneWidget);
    });
  });
}
