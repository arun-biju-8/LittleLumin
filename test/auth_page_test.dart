import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:littlelumin/screens/auth/auth_page.dart';
import 'package:littlelumin/screens/auth/login_page.dart';
import 'package:littlelumin/screens/auth/signup_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  group('AuthPage Comprehensive Tests', () {
    testWidgets('Renders in login mode by default with email and password fields', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Login form elements
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('login_password_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('remember_me_checkbox')), findsOneWidget);
      expect(find.byKey(const ValueKey('login_submit_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('google_sign_in_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('toggle_to_signup_btn')), findsOneWidget);

      // Signup fields should NOT be visible initially
      expect(find.byKey(const ValueKey('signup_name_field')), findsNothing);
      expect(find.byKey(const ValueKey('signup_phone_field')), findsNothing);
    });

    testWidgets('Tapping "Sign Up" toggles to signup mode with all signup fields', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign Up toggle
      await tester.ensureVisible(find.byKey(const ValueKey('toggle_to_signup_btn')));
      await tester.tap(find.byKey(const ValueKey('toggle_to_signup_btn')));
      await tester.pumpAndSettle();

      // Verify signup form is now visible
      expect(find.byKey(const ValueKey('signup_name_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_email_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_phone_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_password_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_confirm_password_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('terms_checkbox')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_submit_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('google_sign_in_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('toggle_to_login_btn')), findsOneWidget);

      // Login fields are now hidden
      expect(find.byKey(const ValueKey('login_email_field')), findsNothing);
    });

    testWidgets('Tapping "Sign In" toggles back to login mode', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(initialMode: AuthMode.signup),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('signup_name_field')), findsOneWidget);

      // Tap toggle back to Sign In
      await tester.ensureVisible(find.byKey(const ValueKey('toggle_to_login_btn')));
      await tester.tap(find.byKey(const ValueKey('toggle_to_login_btn')));
      await tester.pumpAndSettle();

      // Login form is back
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('login_password_field')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_name_field')), findsNothing);
    });

    testWidgets('Validation triggers correctly on empty login submission', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit without typing
      await tester.ensureVisible(find.byKey(const ValueKey('login_submit_btn')));
      await tester.tap(find.byKey(const ValueKey('login_submit_btn')));
      await tester.pumpAndSettle();

      // Validators.email and Validators.loginPassword should display error texts
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Validation triggers correctly on empty signup submission', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(initialMode: AuthMode.signup),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit without typing
      await tester.ensureVisible(find.byKey(const ValueKey('signup_submit_btn')));
      await tester.tap(find.byKey(const ValueKey('signup_submit_btn')));
      await tester.pumpAndSettle();

      // Validators messages
      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Mobile layout (< 800px) renders compact brand header and form', (tester) async {
      setMobileSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile brand header title
      expect(find.text('LittleLumin'), findsOneWidget);
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);

      // Toggle to signup on mobile
      await tester.ensureVisible(find.byKey(const ValueKey('toggle_to_signup_btn')));
      await tester.tap(find.byKey(const ValueKey('toggle_to_signup_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Join LittleLumin'), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_name_field')), findsOneWidget);
    });

    testWidgets('Legacy LoginPage redirects to AuthPage in login mode', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byKey(const ValueKey('login_email_field')), findsOneWidget);
    });

    testWidgets('Legacy SignUpPage redirects to AuthPage in signup mode', (tester) async {
      setDesktopSize(tester);
      addTearDown(() => resetSize(tester));

      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_name_field')), findsOneWidget);
    });
  });
}
