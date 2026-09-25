// lib/widgets/mobile_only_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class MobileOnlyGate extends StatelessWidget {
  final Widget child;
  final String userType; // parent | llg | admin

  const MobileOnlyGate({super.key, required this.child, required this.userType});

  bool get _isParent => userType == 'parent';
  bool get _isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    // LLG and Admin: full web/desktop access allowed
    if (userType == 'llg' || userType == 'admin') return child;

    // Parent on mobile: allowed
    if (_isMobile) return child;

    // Parent on web/desktop: block with install prompt
    if (_isParent) return _buildInstallPrompt(context);

    return child;
  }

  Widget _buildInstallPrompt(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android, size: 64, color: Color(0xFF0EA5E9)),
                ),
                const SizedBox(height: 32),
                const Text(
                  'LittleLumin is Mobile-Only for Parents',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'To give you the best experience and protect your child\'s data,\n'
                  'the parent app is available only on Android and iOS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _buildStoreButton(
                  icon: Icons.android,
                  label: 'Get it on Google Play',
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _buildStoreButton(
                  icon: Icons.apple,
                  label: 'Download on App Store',
                  onTap: () {},
                ),
                const SizedBox(height: 24),
                Text(
                  'Already have an account? Open the app on your phone to sign in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildStoreButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
