// test/skill_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/screens/parent/activities/skill_detail_screen.dart';

void main() {
  final childAge4 = ChildModel(
    childId: 'c1',
    parentId: 'p1',
    name: 'Leo',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    createdAt: DateTime.now(),
  );

  final activities = [
    ActivityModel(
      id: 'a1',
      title: 'Cognitive Game 4yo',
      shortDescription: 'For age 4',
      skillType: 'Cognitive',
      difficulty: 'Easy',
      ageGroup: [4],
      duration: 5,
      instructions: ['Step 1'],
      learningGoals: ['Goal 1'],
      materials: [],
      createdAt: DateTime(2023, 1, 1),
    ),
    ActivityModel(
      id: 'a2',
      title: 'Cognitive Game 5yo',
      shortDescription: 'For age 5',
      skillType: 'Cognitive',
      difficulty: 'Hard',
      ageGroup: [5],
      duration: 15,
      instructions: ['Step 1'],
      learningGoals: ['Goal 2'],
      materials: [],
      createdAt: DateTime(2023, 1, 2),
    ),
  ];

  group('SkillDetailScreen Tests', () {
    testWidgets('Age chips render and kid\'s age is highlighted by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SkillDetailScreen(
            skillDomain: 'Cognitive',
            child: childAge4,
            initialActivities: activities,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cognitive'), findsWidgets);
      expect(find.text('3 yrs'), findsOneWidget);
      expect(find.text('4 yrs'), findsOneWidget);
      expect(find.text('5 yrs'), findsOneWidget);
      expect(find.text('6 yrs'), findsOneWidget);

      // Since child is 4, only 'Cognitive Game 4yo' shows up
      expect(find.text('Cognitive Game 4yo'), findsOneWidget);
      expect(find.text('Cognitive Game 5yo'), findsNothing);
    });

    testWidgets('Tapping a different age chip updates results', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SkillDetailScreen(
            skillDomain: 'Cognitive',
            child: childAge4,
            initialActivities: activities,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to 5 yrs
      await tester.tap(find.text('5 yrs'));
      await tester.pumpAndSettle();

      expect(find.text('Cognitive Game 5yo'), findsOneWidget);
      expect(find.text('Cognitive Game 4yo'), findsNothing);
    });

    testWidgets('Grid / List view toggle toggles view', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SkillDetailScreen(
            skillDomain: 'Cognitive',
            child: childAge4,
            initialActivities: activities,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Default is list view
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      // Tap Grid/List toggle button
      await tester.tap(find.byTooltip('Switch to Grid view'));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });
  });
}
