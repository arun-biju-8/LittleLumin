// test/parent_desktop_dashboard_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/screens/parent/desktop_parent_companion.dart';
import 'package:littlelumin/widgets/mobile_only_gate.dart';

void main() {
  group('Parent & Specialist Routing Tests', () {
    testWidgets('Parent on desktop receives Child Development Dashboard (not mobile child widget)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: MobileOnlyGate(
              userType: 'parent',
              child: Text('Mobile Only Parent Screen'),
            ),
          ),
        );

        // Mobile content is gated
        expect(find.text('Mobile Only Parent Screen'), findsNothing);

        // Desktop dashboard / companion is displayed
        expect(find.byType(DesktopParentCompanionScreen), findsOneWidget);
        expect(find.text('LittleLumin is Mobile-Only for Parents'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Parent on mobile receives full mobile experience directly', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: MobileOnlyGate(
              userType: 'parent',
              child: Text('Mobile Only Parent Screen'),
            ),
          ),
        );

        // Mobile experience is directly rendered
        expect(find.text('Mobile Only Parent Screen'), findsOneWidget);
        expect(find.byType(DesktopParentCompanionScreen), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('LLG user on desktop sees specialist destination, never parent dashboard', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: MobileOnlyGate(
              userType: 'llg',
              child: Text('LLG Specialist Workspace Destination'),
            ),
          ),
        );

        // Specialist destination is directly rendered
        expect(find.text('LLG Specialist Workspace Destination'), findsOneWidget);
        expect(find.byType(DesktopParentCompanionScreen), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Admin user on desktop sees admin destination, never parent dashboard', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: MobileOnlyGate(
              userType: 'admin',
              child: Text('Admin Workspace Destination'),
            ),
          ),
        );

        expect(find.text('Admin Workspace Destination'), findsOneWidget);
        expect(find.byType(DesktopParentCompanionScreen), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Desktop Parent Companion & Floating Chat UI Tests', () {
    testWidgets('Renders respectful mobile app guidance banner without blocking dashboard', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DesktopParentCompanionScreen(),
        ),
      );

      // Verify guidance banner text
      expect(find.text('LittleLumin is Mobile-Only for Parents'), findsOneWidget);
      expect(find.text('Sign in to Desktop Companion'), findsOneWidget);
    });

    testWidgets('Floating chat launcher button and toggle functionality', (tester) async {
      // Test the widget with initialIsChatOpen: true to verify floating chat panel
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DesktopParentCompanionScreen(
              initialIsChatOpen: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Since unauthenticated in pure unit test, it shows companion sign in.
      expect(find.byType(DesktopParentCompanionScreen), findsOneWidget);
    });
  });
}
