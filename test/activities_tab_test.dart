// test/activities_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/activity_model.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/screens/parent/activities/activities_tab.dart';
import 'package:littlelumin/screens/parent/activities/activity_library_screen.dart';

void main() {
  final testChild = ChildModel(
    childId: 'c1',
    parentId: 'p1',
    name: 'Leo',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    createdAt: DateTime(2023, 1, 1),
  );

  final sampleActivities = [
    ActivityModel(
      id: 'act1',
      title: 'Nature Treasure Hunt',
      shortDescription: 'Explore nature outdoors',
      skillType: 'Cognitive',
      difficulty: 'Easy',
      ageGroup: [4],
      duration: 10,
      instructions: ['Step 1'],
      learningGoals: ['Explore nature'],
      materials: ['Basket'],
      createdAt: DateTime.now(),
    ),
    ActivityModel(
      id: 'act2',
      title: 'Sound Safari',
      shortDescription: 'Listen to animals',
      skillType: 'Language',
      difficulty: 'Medium',
      ageGroup: [4],
      duration: 5,
      instructions: ['Step 1'],
      learningGoals: ['Listening'],
      materials: [],
      createdAt: DateTime.now(),
    ),
    ActivityModel(
      id: 'act3',
      title: 'Fort Builder',
      shortDescription: 'Build with cushions',
      skillType: 'Motor',
      difficulty: 'Easy',
      ageGroup: [4],
      duration: 15,
      instructions: ['Step 1'],
      learningGoals: ['Motor coordination'],
      materials: ['Cushions'],
      createdAt: DateTime.now(),
    ),
  ];

  group('ActivitiesTab Tests', () {
    testWidgets('Renders all main sections and header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActivitiesTab(
            activeChild: testChild,
            initialActivities: sampleActivities,
            initialRecentActivityIds: const ['Nature Treasure Hunt'],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('What would you like to do with Leo today?'), findsOneWidget);

      // 1. Jump Back In (since recent exists)
      expect(find.text('JUMP BACK IN'), findsOneWidget);

      // 2. Continue Your Journey
      expect(find.text('CONTINUE YOUR JOURNEY'), findsOneWidget);
      expect(find.text('Continue Journey →'), findsOneWidget);

      // 3. Today's Activities
      expect(find.text('TODAY\'S ACTIVITIES'), findsOneWidget);
      expect(find.text('Start First →'), findsOneWidget);
      expect(find.text('See All 3'), findsOneWidget);

      // 4. Quick Start
      expect(find.text('QUICK START'), findsOneWidget);
      expect(find.text('Create with AI'), findsOneWidget);
      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Surprise Me'), findsOneWidget);

      // 5. Browse by Skill
      expect(find.text('BROWSE BY SKILL'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Cognitive'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Language'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Motor'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Social'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Emotional'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Creative'), findsOneWidget);

      // 6. Curated Packs
      expect(find.text('CURATED PACKS'), findsOneWidget);
      expect(find.text('5-Minute Activities'), findsOneWidget);
      expect(find.text('Bedtime Wind-Down'), findsOneWidget);
      expect(find.text('Rainy Day Fun'), findsOneWidget);
      expect(find.text('School Prep'), findsOneWidget);
      expect(find.text('Calming Activities'), findsOneWidget);

      // 7. All Activities
      expect(find.textContaining('ALL ACTIVITIES'), findsOneWidget);
      expect(find.text('Open Library →'), findsOneWidget);
    });

    testWidgets('Jump Back In is hidden when no recent activity exists', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActivitiesTab(
            activeChild: testChild,
            initialActivities: sampleActivities,
            initialRecentActivityIds: const [],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('JUMP BACK IN'), findsNothing);
    });

    testWidgets('"Open Library" navigates to ActivityLibraryScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActivitiesTab(
            activeChild: testChild,
            initialActivities: sampleActivities,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to Open Library button
      final openLibraryFinder = find.text('Open Library →');
      await tester.scrollUntilVisible(openLibraryFinder, 300);
      await tester.pumpAndSettle();

      await tester.tap(openLibraryFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ActivityLibraryScreen), findsOneWidget);
    });
  });
}
