import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/screens/auth/forgot_password_page.dart';
import 'package:littlelumin/services/auth_service.dart';

class MockAuthService extends AuthService {
  bool sendResetCalled = false;
  String? capturedEmail;
  bool shouldThrow = false;
  Exception? exceptionToThrow;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    sendResetCalled = true;
    capturedEmail = email;
    if (shouldThrow) {
      throw exceptionToThrow ?? Exception('Network error');
    }
  }
}

void main() {
  void setDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  void setMobileSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetSize(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  group('ForgotPasswordPage Tests', () {
    testWidgets('Renders all initial form elements on desktop', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Elements
      expect(find.byKey(const ValueKey('forgot_password_email_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('send_reset_link_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('back_to_login_btn')), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Password\nRecovery'), findsOneWidget);
    });

    testWidgets('Renders all initial form elements on mobile', (tester) async {
      setMobileSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('forgot_password_email_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('send_reset_link_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('back_to_login_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('forgot_password_back_icon_btn')), findsOneWidget);
      expect(find.text('Reset Password'), findsOneWidget);
    });

    testWidgets('Pre-fills email when initialEmail is provided', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordPage(initialEmail: 'parent@example.com'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('parent@example.com'), findsOneWidget);
    });

    testWidgets('Validation rejects empty email', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      final mockAuth = MockAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(authService: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit with empty field
      await tester.tap(find.byKey(const ValueKey('send_reset_link_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(mockAuth.sendResetCalled, isFalse);
    });

    testWidgets('Validation rejects malformed email', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      final mockAuth = MockAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(authService: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot_password_email_field')),
        'invalid-email-format',
      );
      await tester.tap(find.byKey(const ValueKey('send_reset_link_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Email must contain @'), findsOneWidget);
      expect(mockAuth.sendResetCalled, isFalse);
    });

    testWidgets('Calls AuthService.sendPasswordResetEmail and shows confirmation view on success', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      final mockAuth = MockAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(authService: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot_password_email_field')),
        'parent@littlelumin.com',
      );
      await tester.tap(find.byKey(const ValueKey('send_reset_link_btn')));
      await tester.pumpAndSettle();

      expect(mockAuth.sendResetCalled, isTrue);
      expect(mockAuth.capturedEmail, 'parent@littlelumin.com');

      // Success view appears
      expect(find.text('Check Your Email'), findsOneWidget);
      expect(find.textContaining('parent@littlelumin.com'), findsOneWidget);
      expect(find.textContaining('spam or junk folder'), findsOneWidget);
      expect(find.byKey(const ValueKey('back_to_login_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('resend_reset_link_btn')), findsOneWidget);
    });

    testWidgets('Handles errors gracefully with error snackbar', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      final mockAuth = MockAuthService();
      mockAuth.shouldThrow = true;
      mockAuth.exceptionToThrow = Exception('Network error. Check your internet connection.');

      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(authService: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot_password_email_field')),
        'parent@littlelumin.com',
      );
      await tester.tap(find.byKey(const ValueKey('send_reset_link_btn')));
      await tester.pumpAndSettle();

      expect(mockAuth.sendResetCalled, isTrue);
      // Form remains visible and error SnackBar is displayed
      expect(find.text('Network error. Check your internet connection.'), findsOneWidget);
      expect(find.byKey(const ValueKey('send_reset_link_btn')), findsOneWidget);
    });

    testWidgets('Back to Sign In pops navigation with entered email', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      String? poppedEmail;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                poppedEmail = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordPage(
                      initialEmail: 'returned@example.com',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open page
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Back to Sign In
      await tester.tap(find.byKey(const ValueKey('back_to_login_btn')));
      await tester.pumpAndSettle();

      expect(poppedEmail, 'returned@example.com');
    });

    testWidgets('Tapping Resend on success view resends email without crash', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      final mockAuth = MockAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: ForgotPasswordPage(authService: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('forgot_password_email_field')),
        'resend@littlelumin.com',
      );
      await tester.tap(find.byKey(const ValueKey('send_reset_link_btn')));
      await tester.pumpAndSettle();

      expect(mockAuth.sendResetCalled, isTrue);
      expect(mockAuth.capturedEmail, 'resend@littlelumin.com');
      expect(find.text('Check Your Email'), findsOneWidget);

      // Fast-forward cooldown timer 31 seconds
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      // Reset mock flag to verify second call
      mockAuth.sendResetCalled = false;
      mockAuth.capturedEmail = null;

      // Tap Resend
      expect(find.byKey(const ValueKey('resend_reset_link_btn')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('resend_reset_link_btn')));
      await tester.pumpAndSettle();

      expect(mockAuth.sendResetCalled, isTrue);
      expect(mockAuth.capturedEmail, 'resend@littlelumin.com');
    });
  });
}
