// lib/screens/landing_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/constants.dart';
import 'auth/login_page.dart';
import 'auth/signup_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb || MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: isWeb
                ? _buildWebLayout(context)
                : _buildMobileLayout(context),
          ),
        ),
      ),
    );
  }

  // ✅ WEB LAYOUT — Two columns
  Widget _buildWebLayout(BuildContext context) {
    return Row(
      children: [
        // Left Column — Branding
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'LittleLumin',
                style: AppTextStyles.heading1.copyWith(fontSize: 40),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Growing Children, Growing Parents',
                style: AppTextStyles.bodyLight.copyWith(fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'AI-powered parenting guidance for children aged 3-6',
                style: AppTextStyles.small.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
        // Right Column — Buttons
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                  ),
                  child: Text('Get Started', style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: 300,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                  ),
                  child: Text(
                    'Create Account',
                    style: AppTextStyles.button.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: AppTextStyles.bodyLight),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Text(
                      'Log In',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ MOBILE LAYOUT — Single column (existing design)
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_stories,
            size: 50,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'LittleLumin',
          style: AppTextStyles.heading1.copyWith(fontSize: 32),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Growing Children, Growing Parents',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Icons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(Icons.face, Colors.orange),
            const SizedBox(width: AppSpacing.md),
            _buildIcon(Icons.psychology, AppColors.secondary),
            const SizedBox(width: AppSpacing.md),
            _buildIcon(Icons.favorite, AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            _buildIcon(Icons.star, AppColors.accent),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Get Started Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
            ),
            child: Text('Get Started', style: AppTextStyles.button),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Create Account Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
            ),
            child: Text(
              'Create Account',
              style: AppTextStyles.button.copyWith(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Already have account
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ', style: AppTextStyles.bodyLight),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: Text(
                'Log In',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}