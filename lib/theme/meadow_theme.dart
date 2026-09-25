import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MeadowColors {
  // Backgrounds
  static const Color cream = Color(0xFFFFFBF5);
  static const Color creamDark = Color(0xFFF5EFE6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFFAF6EF);

  // Primary — Forest Green
  static const Color primary = Color(0xFF3D5A3D);
  static const Color primaryLight = Color(0xFF5A7A5A);
  static const Color primaryDark = Color(0xFF2A3D2A);
  static const Color primarySurface = Color(0xFFE8F0E8);

  // Sage
  static const Color sage = Color(0xFFA8BFA8);
  static const Color sageLight = Color(0xFFD4E0D4);

  // Gold
  static const Color gold = Color(0xFFF0B95C);
  static const Color goldLight = Color(0xFFF8DC9C);
  static const Color goldSurface = Color(0xFFFDF4E0);

  // Domain accents
  static const Color cognitive = Color(0xFF9B7EDE);
  static const Color language = Color(0xFF6B9FE0);
  static const Color motor = Color(0xFF5DB88F);
  static const Color social = Color(0xFFF08E6B);
  static const Color emotional = Color(0xFFE07A9E);
  static const Color creative = Color(0xFFE0A854);

  // Domain surface tints
  static const Color cognitiveSurface = Color(0xFFEFE8FC);
  static const Color languageSurface = Color(0xFFE3EEFB);
  static const Color motorSurface = Color(0xFFE0F2EA);
  static const Color socialSurface = Color(0xFFFCE8DF);
  static const Color emotionalSurface = Color(0xFFFBE4EC);
  static const Color creativeSurface = Color(0xFFFAEDD6);

  // Text
  static const Color textPrimary = Color(0xFF1F2A1F);
  static const Color textSecondary = Color(0xFF5A6B5A);
  static const Color textTertiary = Color(0xFF9CAA9C);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF5DB88F);
  static const Color warning = Color(0xFFF0B95C);
  static const Color error = Color(0xFFD9694D);

  // Borders
  static const Color border = Color(0xFFE8E0D5);
  static const Color borderLight = Color(0xFFF2EDE5);

  // Shadows
  static const Color shadow = Color(0x14000000);
  static const Color shadowSoft = Color(0x0A000000);
}

class MeadowTypography {
  static TextStyle display = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: MeadowColors.textPrimary,
  );

  static TextStyle h1 = GoogleFonts.plusJakartaSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: MeadowColors.textPrimary,
  );

  static TextStyle h2 = GoogleFonts.plusJakartaSans(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: MeadowColors.textPrimary,
  );

  static TextStyle h3 = GoogleFonts.plusJakartaSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: MeadowColors.textPrimary,
  );

  static TextStyle bodyLarge = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: MeadowColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: MeadowColors.textPrimary,
  );

  static TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: MeadowColors.textPrimary,
  );

  static TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: MeadowColors.textPrimary,
  );

  static TextStyle label = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: MeadowColors.textPrimary,
  );
}

class MeadowSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double screenH = 20;
  static const double cardPadding = 16;
  static const double cardGap = 12;
}

class MeadowRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 100;
}

class MeadowShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 1)),
  ];
}

class MeadowButtons {
  static ButtonStyle primary() {
    return ElevatedButton.styleFrom(
      backgroundColor: MeadowColors.primary,
      foregroundColor: MeadowColors.textInverse,
      minimumSize: const Size(0, 56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: MeadowTypography.button,
      elevation: 0,
    );
  }

  static ButtonStyle secondary() {
    return OutlinedButton.styleFrom(
      backgroundColor: MeadowColors.surface,
      foregroundColor: MeadowColors.primary,
      side: const BorderSide(color: MeadowColors.primary, width: 1.5),
      minimumSize: const Size(0, 56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: MeadowTypography.button,
      elevation: 0,
    );
  }

  static ButtonStyle gold() {
    return ElevatedButton.styleFrom(
      backgroundColor: MeadowColors.gold,
      foregroundColor: MeadowColors.textPrimary,
      minimumSize: const Size(0, 56),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: MeadowTypography.button,
      elevation: 0,
    );
  }

  static ButtonStyle small() {
    return ElevatedButton.styleFrom(
      backgroundColor: MeadowColors.primary,
      foregroundColor: MeadowColors.textInverse,
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: MeadowTypography.button,
      elevation: 0,
    );
  }
}

class MeadowCards {
  static BoxDecoration standard() {
    return BoxDecoration(
      color: MeadowColors.surface,
      borderRadius: BorderRadius.circular(MeadowRadius.lg),
      border: Border.all(color: MeadowColors.borderLight, width: 1),
      boxShadow: MeadowShadows.card,
    );
  }

  static BoxDecoration hero() {
    return BoxDecoration(
      color: MeadowColors.surface,
      borderRadius: BorderRadius.circular(MeadowRadius.xl),
      border: Border.all(color: MeadowColors.borderLight, width: 1),
      boxShadow: MeadowShadows.elevated,
    );
  }

  static BoxDecoration tinted(Color tint) {
    return BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(MeadowRadius.lg),
      boxShadow: MeadowShadows.soft,
    );
  }

  static BoxDecoration cream() {
    return BoxDecoration(
      color: MeadowColors.creamDark,
      borderRadius: BorderRadius.circular(MeadowRadius.lg),
      boxShadow: MeadowShadows.soft,
    );
  }
}

class MeadowDomain {
  static Color colorFor(String domain) {
    switch (domain.trim().toLowerCase()) {
      case 'cognitive':
        return MeadowColors.cognitive;
      case 'language':
        return MeadowColors.language;
      case 'motor':
        return MeadowColors.motor;
      case 'social':
        return MeadowColors.social;
      case 'emotional':
        return MeadowColors.emotional;
      case 'creative':
        return MeadowColors.creative;
      default:
        return MeadowColors.primary;
    }
  }

  static Color surfaceFor(String domain) {
    switch (domain.trim().toLowerCase()) {
      case 'cognitive':
        return MeadowColors.cognitiveSurface;
      case 'language':
        return MeadowColors.languageSurface;
      case 'motor':
        return MeadowColors.motorSurface;
      case 'social':
        return MeadowColors.socialSurface;
      case 'emotional':
        return MeadowColors.emotionalSurface;
      case 'creative':
        return MeadowColors.creativeSurface;
      default:
        return MeadowColors.primarySurface;
    }
  }

  static IconData iconFor(String domain) {
    switch (domain.trim().toLowerCase()) {
      case 'cognitive':
        return Icons.psychology_outlined;
      case 'language':
        return Icons.chat_bubble_outlined;
      case 'motor':
        return Icons.directions_run_outlined;
      case 'social':
        return Icons.people_outlined;
      case 'emotional':
        return Icons.favorite_outline;
      case 'creative':
        return Icons.palette_outlined;
      default:
        return Icons.star_outline;
    }
  }

  static String labelFor(String domain) {
    final clean = domain.trim();
    if (clean.isEmpty) return '';
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }
}
