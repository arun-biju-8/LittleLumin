// lib/screens/llg_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constants.dart';
import '../auth/login_page.dart';

class LLGDashboard extends StatelessWidget {
  const LLGDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('LLG Dashboard', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.textDark),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, size: 80, color: AppColors.secondary),
              SizedBox(height: AppSpacing.md),
              Text(
                'Welcome, ${user?.displayName ?? 'LLG'}!',
                style: AppTextStyles.heading1,
              ),
              SizedBox(height: AppSpacing.sm),
              Text(
                'You are logged in as a Little Lumin Guide.',
                style: AppTextStyles.bodyLight,
              ),
              SizedBox(height: AppSpacing.lg),
              Text(
                '🚀 Guide Dashboard coming soon!',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}