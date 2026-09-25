import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParentColors {
  static const primary = Color(0xFF6C4AB6);
  static const primaryLight = Color(0xFF8D72E1);
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6C4AB6), Color(0xFF8D72E1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const accent = Color(0xFFF5B700);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF8F7FC);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B6B80);
  static const textTertiary = Color(0xFF9B9BAE);
}

class ParentTypography {
  static TextStyle display = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: ParentColors.textPrimary,
  );

  static TextStyle title = GoogleFonts.outfit(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: ParentColors.textPrimary,
  );

  static TextStyle cardTitle = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: ParentColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: ParentColors.textPrimary,
  );

  static TextStyle bodyLight = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: ParentColors.textSecondary,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: ParentColors.textSecondary,
  );

  static TextStyle button = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

class ParentShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> elevated = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> gradient = [
    const BoxShadow(
      color: Color(0x266C4AB6),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];
}

class ParentRadius {
  static const card = BorderRadius.all(Radius.circular(20));
  static const button = BorderRadius.all(Radius.circular(14));
  static const chip = BorderRadius.all(Radius.circular(100));
  static const input = BorderRadius.all(Radius.circular(14));
  static const modal = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  );
}

String getGreetingMessage(String name) {
  final hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Good morning, $name 👋';
  } else if (hour < 17) {
    return 'Good afternoon, $name 👋';
  } else {
    return 'Good evening, $name 👋';
  }
}
