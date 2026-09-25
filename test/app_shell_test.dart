import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/screens/parent/app_shell.dart';
import 'package:littlelumin/screens/parent/tabs/growth_tab.dart';
import 'package:littlelumin/screens/parent/tabs/stories_tab.dart';
import 'package:littlelumin/screens/parent/tabs/more_tab.dart';
import 'package:littlelumin/theme/meadow_theme.dart';

void main() {
  final testChild = ChildModel(
    childId: 'c_test_1',
    parentId: 'p_test_1',
    name: 'Leo',
    dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
    gender: 'Male',
    createdAt: DateTime(2023, 1, 1),
  );

  Widget buildTestShell({int initialTab = 0}) {
    return MaterialApp(
      home: AppShell(
        initialTab: initialTab,
        activeChild: testChild,
        children: [testChild],
        parentName: 'Test Parent',
        tabViews: [
          const Scaffold(body: Center(child: Text('Home Content'))),
          const GrowthTab(activeChild: null),
          const Scaffold(body: Center(child: Text('Activities Content'))),
          StoriesTab(activeChild: testChild, storiesStream: const Stream.empty()),
          MoreTab(children: [testChild], activeChild: testChild),
        ],
      ),
    );
  }

  group('AppShell 5-Tab Meadow Navigation Tests', () {
    testWidgets('Renders all 5 tabs in bottom navigation with correct labels', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pump();

      // Verify all 5 tab labels exist in bottom navigation bar
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Growth'), findsWidgets);
      expect(find.text('Activities'), findsWidgets);
      expect(find.text('Stories'), findsWidgets);
      expect(find.text('More'), findsWidgets);

      // Verify tabs exist in the widget tree (offstage tabs in IndexedStack)
      expect(find.text('Home Content'), findsOneWidget);
      expect(find.byType(GrowthTab, skipOffstage: false), findsOneWidget);
      expect(find.byType(StoriesTab, skipOffstage: false), findsOneWidget);
      expect(find.byType(MoreTab, skipOffstage: false), findsOneWidget);
    });

    testWidgets('Initial tab is Home and selected tab uses Meadow primary color', (tester) async {
      await tester.pumpWidget(buildTestShell(initialTab: 0));
      await tester.pump();

      final appShellFinder = find.byType(AppShell);
      expect(appShellFinder, findsOneWidget);
      final state = tester.state<AppShellState>(appShellFinder);
      expect(state.currentIndex, 0);

      // Selected Home tab label has Meadow primary color
      final homeText = tester.widget<Text>(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Home'),
      ));
      expect(homeText.style?.color, MeadowColors.primary);

      // Unselected More tab label has Meadow textTertiary color
      final moreText = tester.widget<Text>(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('More'),
      ));
      expect(moreText.style?.color, MeadowColors.textTertiary);
    });

    testWidgets('Tapping Growth switches active tab to GrowthTab', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pump();

      // Tap on Growth tab in bottom nav
      await tester.tap(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Growth'),
      ));
      await tester.pump();

      final state = tester.state<AppShellState>(find.byType(AppShell));
      expect(state.currentIndex, 1);

      // GrowthTab is now active
      expect(find.text('Growth Journey'), findsOneWidget);

      final growthText = tester.widget<Text>(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Growth'),
      ));
      expect(growthText.style?.color, MeadowColors.primary);
    });

    testWidgets('Tapping Stories switches active tab to StoriesTab', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pump();

      // Tap on Stories tab in bottom nav
      await tester.tap(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Stories'),
      ));
      await tester.pump();

      final state = tester.state<AppShellState>(find.byType(AppShell));
      expect(state.currentIndex, 3);

      expect(find.text('Create a Story'), findsOneWidget);
      expect(find.text('My Saved Stories'), findsOneWidget);
    });

    testWidgets('Tapping More switches active tab to MoreTab', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pump();

      // Tap on More tab in bottom nav
      await tester.tap(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('More'),
      ));
      await tester.pump();

      final state = tester.state<AppShellState>(find.byType(AppShell));
      expect(state.currentIndex, 4);

      expect(find.text('FAMILY'), findsOneWidget);
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Parent Journal'), findsOneWidget);
      expect(find.text('LITTLELUMIN'), findsOneWidget);
      expect(find.text('Expert Support'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Log Out'), 100);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('State is preserved in IndexedStack when switching tabs', (tester) async {
      await tester.pumpWidget(buildTestShell());
      await tester.pump();

      // Start on Home (0)
      final state = tester.state<AppShellState>(find.byType(AppShell));
      expect(state.currentIndex, 0);
      expect(find.text('Home Content'), findsOneWidget);

      // Switch to More (4)
      await tester.tap(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('More'),
      ));
      await tester.pump();
      expect(state.currentIndex, 4);
      expect(find.text('FAMILY'), findsOneWidget);

      // Switch back to Home (0)
      await tester.tap(find.descendant(
        of: find.byType(InkWell),
        matching: find.text('Home'),
      ));
      await tester.pump();
      expect(state.currentIndex, 0);

      // Home Content is still intact
      expect(find.text('Home Content'), findsOneWidget);
    });
  });
}
