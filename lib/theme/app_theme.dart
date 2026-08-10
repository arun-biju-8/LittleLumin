import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color skyBlue = Color(0xFF4A90D9);
  static const Color periwinkle = Color(0xFF6A78D1);
  static const Color purple = Color(0xFF9B59B6);
  static const Color amberGold = Color(0xFFF1C40F);
  static const Color lightAmber = Color(0xFFFFE57F);
  static const Color darkAmber = Color(0xFFE2B70D);
  static const Color slateBg = Color(0xFF0F172A);
  static const Color darkSlate = Color(0xFF020617);
  static const Color slateBorder = Color(0xFF334155);

  // Background Gradient
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF4A90D9),
      Color(0xFF6A78D1),
      Color(0xFF9B59B6),
    ],
  );

  // Glass Card Decoration
  static BoxDecoration glassBox({
    double opacity = 0.12,
    double borderOpacity = 0.22,
    double borderRadius = 24.0,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: 1.0,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
    );
  }

  // Text Theme
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: darkSlate,
      colorScheme: const ColorScheme.dark(
        primary: amberGold,
        secondary: skyBlue,
        surface: slateBg,
      ),
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
    );
  }
}
