// lib/screens/desktop_redirect_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DesktopRedirectPage extends StatelessWidget {
  const DesktopRedirectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 600;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4A90D9),
              Color(0xFF7B8BD1),
              Color(0xFF9B59B6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_stories,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'LittleLumin',
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 48 : 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Download the Mobile App',
                    style: GoogleFonts.inter(
                      fontSize: isDesktop ? 24 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          size: 48,
                          color: AppTheme.amberGold,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Parent Dashboard is available on Mobile',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'To access the full parent experience with screen-free activities, guided play, and progress tracking, please use the mobile app.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // QR Code Placeholder
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '📱',
                              style: TextStyle(fontSize: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan to Download',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Store Buttons (Placeholder)
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStoreButton(
                        'Google Play',
                        Icons.play_arrow_rounded,
                        Colors.green,
                      ),
                      _buildStoreButton(
                        'App Store',
                        Icons.apple_rounded,
                        Colors.grey[800]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // LLG/Admin Login Link
                  TextButton(
                    onPressed: () {
                      // Navigate to LLG/Admin Login
                      Navigator.pushNamed(context, '/login');
                    },
                    child: Text(
                      'Are you an LLG or Admin? Click here to login.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreButton(String label, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () {
        // Open store links
      },
      icon: Icon(icon, color: color, size: 24),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: Colors.white.withOpacity(0.4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
      ),
    );
  }
}