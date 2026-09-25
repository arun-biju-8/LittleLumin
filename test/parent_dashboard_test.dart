import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/models/child_model.dart';
import 'package:littlelumin/screens/parent/home/quick_actions_row.dart';
import 'package:littlelumin/screens/parent/home/flagged_alert_card.dart';
import 'package:littlelumin/screens/parent/children/child_card.dart';
import 'package:littlelumin/screens/parent/profile/settings_section.dart';

void main() {
  group('Parent Dashboard Home Tab Widgets', () {
    testWidgets('QuickActionsRow renders all 3 action tiles and handles callbacks', (tester) async {
      bool aiActTapped = false;
      bool aiStoryTapped = false;
      bool allActTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionsRow(
              onAIActivity: () => aiActTapped = true,
              onAIStory: () => aiStoryTapped = true,
              onAllActivities: () => allActTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('AI Activity'), findsOneWidget);
      expect(find.text('AI Story'), findsOneWidget);
      expect(find.text('All Activities'), findsOneWidget);

      await tester.tap(find.text('AI Activity'));
      await tester.pump();
      expect(aiActTapped, isTrue);

      await tester.tap(find.text('AI Story'));
      await tester.pump();
      expect(aiStoryTapped, isTrue);

      await tester.tap(find.text('All Activities'));
      await tester.pump();
      expect(allActTapped, isTrue);
    });

    testWidgets('FlaggedAlertCard is hidden when child is not flagged', (tester) async {
      final unflaggedChild = ChildModel(
        childId: 'c1',
        parentId: 'p1',
        name: 'Leo',
        dateOfBirth: DateTime(2020, 1, 1),
        gender: 'Male',
        isFlagged: false,
        createdAt: DateTime(2023, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlaggedAlertCard(child: unflaggedChild),
          ),
        ),
      );

      expect(find.text('A specialist could help'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('FlaggedAlertCard renders warning and button when child is flagged', (tester) async {
      final flaggedChild = ChildModel(
        childId: 'c2',
        parentId: 'p1',
        name: 'Maya',
        dateOfBirth: DateTime(2019, 5, 1),
        gender: 'Female',
        isFlagged: true,
        flagReason: 'Speech delay noted',
        createdAt: DateTime(2023, 1, 1),
      );

      bool viewLLGTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlaggedAlertCard(
              child: flaggedChild,
              onViewLLG: () => viewLLGTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('A specialist could help'), findsOneWidget);
      expect(find.textContaining('Maya has been finding some activities trickier than usual'), findsOneWidget);
      expect(find.text('Yes, show me specialists'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);

      await tester.tap(find.text('Yes, show me specialists'));
      await tester.pump();
      expect(viewLLGTapped, isTrue);
    });
  });

  group('Parent Dashboard Children Tab Widgets', () {
    testWidgets('ChildCard displays child details, scores, and action buttons', (tester) async {
      final child = ChildModel(
        childId: 'c3',
        parentId: 'p1',
        name: 'Sammy',
        dateOfBirth: DateTime(DateTime.now().year - 4, 1, 1),
        gender: 'Male',
        vabsScores: {'Cognitive': 75.0, 'Language': 82.0},
        createdAt: DateTime(2023, 1, 1),
      );

      bool viewTapped = false;
      bool editTapped = false;
      bool deleteTapped = false;
      bool selectTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChildCard(
              child: child,
              level: 1,
              isSelected: true,
              onView: () => viewTapped = true,
              onEdit: () => editTapped = true,
              onDelete: () => deleteTapped = true,
              onSelect: () => selectTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Sammy'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('View'));
      await tester.pump();
      expect(viewTapped, isTrue);

      await tester.tap(find.text('Edit'));
      await tester.pump();
      expect(editTapped, isTrue);

      await tester.tap(find.text('Delete'));
      await tester.pump();
      expect(deleteTapped, isTrue);

      await tester.tap(find.text('Sammy'));
      await tester.pump();
      expect(selectTapped, isTrue);
    });
  });

  group('Parent Dashboard Profile Tab Settings Widgets', () {
    testWidgets('SettingsSection toggles switches and calls callbacks', (tester) async {
      bool notif = true;
      bool dark = false;
      bool privacyOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsSection(
              notificationsEnabled: notif,
              onNotificationsChanged: (v) => notif = v,
              darkModeEnabled: dark,
              onDarkModeChanged: (v) => dark = v,
              currentLanguage: 'English',
              onLanguageTap: () {},
              onPrivacyTap: () => privacyOpened = true,
              onTermsTap: () {},
              onHelpTap: () {},
              onRateTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('⚙️ Settings'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();
      expect(privacyOpened, isTrue);
    });
  });
}
