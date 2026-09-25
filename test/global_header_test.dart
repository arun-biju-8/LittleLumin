import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/widgets/global_header.dart';

void main() {
  group('GlobalHeader Widget Tests', () {
    testWidgets('Renders logo + name and bell + avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: GlobalHeader(),
            body: Center(child: Text('Content')),
          ),
        ),
      );

      expect(find.text('LittleLumin'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      // Back button should not be present
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('Back button shows when showBack = true and triggers callback', (tester) async {
      bool backTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: GlobalHeader(
              showBack: true,
              onBackTap: () => backTapped = true,
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      final backFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(backFinder, findsOneWidget);

      await tester.tap(backFinder);
      await tester.pump();
      expect(backTapped, isTrue);
    });

    testWidgets('Bell tap and Avatar tap trigger callbacks', (tester) async {
      bool bellTapped = false;
      bool avatarTapped = false;
      bool logoTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: GlobalHeader(
              onBellTap: () => bellTapped = true,
              onAvatarTap: () => avatarTapped = true,
              onLogoTap: () => logoTapped = true,
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pump();
      expect(bellTapped, isTrue);

      await tester.tap(find.text('P'));
      await tester.pump();
      expect(avatarTapped, isTrue);

      await tester.tap(find.text('LittleLumin'));
      await tester.pump();
      expect(logoTapped, isTrue);
    });

    testWidgets('Scroll transition works', (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: GlobalHeader(scrollController: scrollController),
            body: ListView.builder(
              controller: scrollController,
              itemCount: 50,
              itemBuilder: (_, i) => SizedBox(height: 50, child: Text('Item $i')),
            ),
          ),
        ),
      );

      // Initially at offset 0: AnimatedContainer has transparent color
      final headerFinder = find.byKey(const ValueKey('global_header_container'));
      final initialContainer = tester.widget<AnimatedContainer>(headerFinder);
      final initialDecoration = initialContainer.decoration as BoxDecoration?;
      expect(initialDecoration?.color, Colors.transparent);

      // Scroll down by 50px (> 20px)
      scrollController.jumpTo(50.0);
      await tester.pumpAndSettle();

      final scrolledContainer = tester.widget<AnimatedContainer>(headerFinder);
      final scrolledDecoration = scrolledContainer.decoration as BoxDecoration?;
      expect(scrolledDecoration?.color, Colors.white);
      expect(scrolledDecoration?.boxShadow, isNotEmpty);
    });
  });
}
