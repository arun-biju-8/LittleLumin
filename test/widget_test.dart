import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/widgets/mobile_only_gate.dart';

void main() {
  group('MobileOnlyGate Widget Tests', () {
    testWidgets('LLG users always see the destination child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MobileOnlyGate(
            userType: 'llg',
            child: Text('LLG Specialist Portal Content'),
          ),
        ),
      );

      expect(find.text('LLG Specialist Portal Content'), findsOneWidget);
    });

    testWidgets('Admin users always see the destination child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MobileOnlyGate(
            userType: 'admin',
            child: Text('Admin Portal Content'),
          ),
        ),
      );

      expect(find.text('Admin Portal Content'), findsOneWidget);
    });

    testWidgets('Parent user on desktop test environment sees mobile-only gate', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: MobileOnlyGate(
              userType: 'parent',
              child: Text('Parent Private Home Content'),
            ),
          ),
        );

        // In Flutter test desktop environment (Windows/Linux/macOS), parents should be blocked
        expect(find.text('LittleLumin is Mobile-Only for Parents'), findsOneWidget);
        expect(find.text('Parent Private Home Content'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
