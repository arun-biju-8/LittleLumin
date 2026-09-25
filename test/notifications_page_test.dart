import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/screens/parent/notifications_page.dart';

void main() {
  group('NotificationsPage Widget Tests', () {
    testWidgets('Renders empty state when user is not logged in / no notifications', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotificationsPage(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    });

    testWidgets('Back button pops the screen', (tester) async {
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onPopPage: (route, result) {
              popped = true;
              return route.didPop(result);
            },
            pages: const [
              MaterialPage(child: Scaffold(body: Text('Home Screen'))),
              MaterialPage(child: NotificationsPage()),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
    });
  });
}
