// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:littlelumin/theme/meadow_theme.dart';

ThemeData getMeadowTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: MeadowColors.cream,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: MeadowColors.primary,
      onPrimary: MeadowColors.textInverse,
      primaryContainer: MeadowColors.primarySurface,
      onPrimaryContainer: MeadowColors.primaryDark,
      secondary: MeadowColors.sage,
      onSecondary: MeadowColors.textPrimary,
      secondaryContainer: MeadowColors.sageLight,
      onSecondaryContainer: MeadowColors.primaryDark,
      tertiary: MeadowColors.gold,
      onTertiary: MeadowColors.textPrimary,
      tertiaryContainer: MeadowColors.goldSurface,
      onTertiaryContainer: MeadowColors.textPrimary,
      error: MeadowColors.error,
      onError: MeadowColors.textInverse,
      surface: MeadowColors.surface,
      onSurface: MeadowColors.textPrimary,
    ),
    textTheme: TextTheme(
      displayLarge: MeadowTypography.display,
      headlineLarge: MeadowTypography.h1,
      headlineMedium: MeadowTypography.h2,
      headlineSmall: MeadowTypography.h3,
      bodyLarge: MeadowTypography.bodyLarge,
      bodyMedium: MeadowTypography.body,
      bodySmall: MeadowTypography.caption,
      labelLarge: MeadowTypography.button,
      labelMedium: MeadowTypography.label,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: MeadowButtons.primary(),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: MeadowButtons.secondary(),
    ),
    cardTheme: CardThemeData(
      color: MeadowColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MeadowRadius.lg),
        side: const BorderSide(color: MeadowColors.borderLight, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: MeadowColors.cream,
      foregroundColor: MeadowColors.textPrimary,
      elevation: 0,
      centerTitle: true,
    ),
  );
}

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
