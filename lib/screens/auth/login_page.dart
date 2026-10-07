import 'package:flutter/material.dart';
import 'auth_page.dart';

/// Legacy entry point for Login — redirects to the unified animated [AuthPage]
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthPage(initialMode: AuthMode.login);
  }
}
