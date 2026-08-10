// lib/screens/auth/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:littlelumin/models/app_state.dart';  // ✅ ShapeDensity from here
import '../../widgets/logo_widget.dart';
import '../../widgets/background_shapes.dart';

// ============================================
// SPLASH SCREEN WRAPPER (Stateful)
// ============================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 1.0;
        print('🔵 Progress: $_progress%');  // Debug
        if (_progress >= 100.0) {
          _timer?.cancel();
          _navigateToLanding();
        }
      });
    });
  }

  void _navigateToLanding() {
    print('🟢 Navigating to Landing');
    Navigator.pushReplacementNamed(context, '/landing');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreenWidget(
      progress: _progress,
      onComplete: _navigateToLanding,
    );
  }
}

// ============================================
// SPLASH SCREEN WIDGET (UI)
// ============================================

class SplashScreenWidget extends StatefulWidget {
  final double progress;
  final bool isLoading;
  final VoidCallback? onComplete;
  final bool animated;
  final ShapeDensity shapeDensity;  // ✅ Type from app_state.dart

  const SplashScreenWidget({
    super.key,
    required this.progress,
    this.isLoading = true,
    this.onComplete,
    this.animated = true,
    this.shapeDensity = ShapeDensity.normal,
  });

  @override
  State<SplashScreenWidget> createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  Timer? _completeTimer;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _checkCompletion();
  }

  @override
  void didUpdateWidget(SplashScreenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress) {
      _checkCompletion();
    }
  }

  void _checkCompletion() {
    if (widget.progress >= 100.0 && widget.onComplete != null) {
      _completeTimer?.cancel();
      _completeTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted && widget.onComplete != null) {
          widget.onComplete!();
        }
      });
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _completeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // ✅ Background Floating Shapes
          BackgroundShapes(
            animated: widget.animated,
            density: widget.shapeDensity,  // ✅ FIXED: was widget.ShapeDensity
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
                      // Top Status Pill
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val,
                            child: Transform.translate(
                              offset: Offset(0, -10 * (1 - val)),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14.0, vertical: 6.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30.0),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1C40F),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x99F1C40F),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                              
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Center Stage (Logo + Title + Tagline)
                      LogoWidget(
                        size: LogoSize.xl,
                        animated: widget.animated,
                      ),
                      const SizedBox(height: 16),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1 - val)),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
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
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1 - val)),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          "Growing Children, Growing Parents",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.95),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bottom Loading Bar Section
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (context, val, child) {
                          return Opacity(
                            opacity: val,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - val)),
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: (widget.progress / 100.0).clamp(0.0, 1.0),
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
                                RotationTransition(
                                  turns: _spinController,
                                  child: Text(
                                    "✦",
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFF1C40F),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
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

                            // Percentage Ticker
                            Text(
                              "${widget.progress.round()}%",
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ REMOVED duplicate ShapeDensity enum from here