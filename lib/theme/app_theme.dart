// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Color Tokens
  static const Color slateBg = Color(0xFF1E293B);
  static const Color darkSlate = Color(0xFF0F172A);
  static const Color amberGold = Color(0xFFFFB703);
  static const Color lightAmber = Color(0xFFFDE68A);
  static const Color accentTeal = Color(0xFF14B8A6);

  // Main Background Gradient
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
      Color(0xFF334155),
    ],
  );

  // Glassmorphism Box Decoration Helper
  static BoxDecoration glassBox({
    Color? color,
    double borderRadius = 24,
    Border? border,
    double opacity = 0.08,
    double? borderOpacity,
  }) {
    final bAlpha = borderOpacity ?? (opacity * 1.5 > 1.0 ? 1.0 : opacity * 1.5);
    return BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: border ?? Border.all(color: Colors.white.withValues(alpha: bAlpha)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
