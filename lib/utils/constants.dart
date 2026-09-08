// lib/utils/constants.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF4A90D9);
  static const secondary = Color(0xFF9B59B6);
  static const accent = Color(0xFFF1C40F);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFFF6B81);
  static const error = Color(0xFFE74C3C);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF5F7FA);
  static const textDark = Color(0xFF2C3E50);
  static const textLight = Color(0xFF7F8C8D);
  static const border = Color(0xFFE0E0E0);
}

class AppTextStyles {
  static TextStyle heading1 = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static TextStyle heading2 = GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static TextStyle body = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textDark,
  );

  static TextStyle bodyLight = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
  );

  static TextStyle button = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );

  static TextStyle small = GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
  );
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppBorderRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const xlarge = 24.0;
}