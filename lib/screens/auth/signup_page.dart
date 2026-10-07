import 'package:flutter/material.dart';
import 'auth_page.dart';

/// Legacy entry point for SignUp — redirects to the unified animated [AuthPage]
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthPage(initialMode: AuthMode.signup);
  }
}