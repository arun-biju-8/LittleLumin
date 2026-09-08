// lib/screens/auth/splash_splash.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/logo_widget.dart';
import '../../widgets/background_shapes.dart';
import '../../models/app_state.dart';
import 'login_page.dart';
import '../parent/parent_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  Timer? _timer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 2.5;
        if (_progress >= 100.0) {
          _progress = 100.0;
          _timer?.cancel();
          _checkAuthAndNavigate();
        }
      });
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _timer?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('🟢 User: ${user?.email ?? "null"}');

      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/auth-wrapper');
      } else {
        Navigator.pushReplacementNamed(context, '/landing');
      }
    } catch (e) {
      debugPrint('⚠️ Auth check error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/landing');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5C9CE6),
              Color(0xFF7B8BD1),
              Color(0xFF9B59B6),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background Shapes
            const BackgroundShapes(
              animated: true,
              density: ShapeDensity.normal,
            ),
            
            // Foreground Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        
                        // Logo
                        const LogoWidget(
                          size: LogoSize.xl,
                          animated: true,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Title
                        Text(
                          "LittleLumin",
                          style: GoogleFonts.outfit(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                offset: const Offset(0, 4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 6),
                        
                        // Tagline
                        Text(
                          "Growing Children, Growing Parents",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.2,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Progress Bar
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 280),
                          height: 10,
                          padding: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (_progress / 100.0).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFF1C40F),
                                    Color(0xFFFFE082),
                                    Colors.white,
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66F1C40F),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // Loading Message
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "✦",
                              style: GoogleFonts.inter(
                                color: const Color(0xFFF1C40F),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Preparing your parenting journey...",
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Percentage
                        Text(
                          "${_progress.round()}%",
                          style: GoogleFonts.firaCode(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}