import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/theme/meadow_theme.dart';
import 'package:littlelumin/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  group('Meadow Design System Tests', () {
    test('MeadowColors constants match design palette', () {
      expect(MeadowColors.cream, const Color(0xFFFFFBF5));
      expect(MeadowColors.creamDark, const Color(0xFFF5EFE6));
      expect(MeadowColors.surface, const Color(0xFFFFFFFF));
      expect(MeadowColors.surfaceAlt, const Color(0xFFFAF6EF));

      expect(MeadowColors.primary, const Color(0xFF3D5A3D));
      expect(MeadowColors.primaryLight, const Color(0xFF5A7A5A));
      expect(MeadowColors.primaryDark, const Color(0xFF2A3D2A));
      expect(MeadowColors.primarySurface, const Color(0xFFE8F0E8));

      expect(MeadowColors.sage, const Color(0xFFA8BFA8));
      expect(MeadowColors.sageLight, const Color(0xFFD4E0D4));

      expect(MeadowColors.gold, const Color(0xFFF0B95C));
      expect(MeadowColors.goldLight, const Color(0xFFF8DC9C));
      expect(MeadowColors.goldSurface, const Color(0xFFFDF4E0));

      expect(MeadowColors.cognitive, const Color(0xFF9B7EDE));
      expect(MeadowColors.language, const Color(0xFF6B9FE0));
      expect(MeadowColors.motor, const Color(0xFF5DB88F));
      expect(MeadowColors.social, const Color(0xFFF08E6B));
      expect(MeadowColors.emotional, const Color(0xFFE07A9E));
      expect(MeadowColors.creative, const Color(0xFFE0A854));

      expect(MeadowColors.cognitiveSurface, const Color(0xFFEFE8FC));
      expect(MeadowColors.languageSurface, const Color(0xFFE3EEFB));
      expect(MeadowColors.motorSurface, const Color(0xFFE0F2EA));
      expect(MeadowColors.socialSurface, const Color(0xFFFCE8DF));
      expect(MeadowColors.emotionalSurface, const Color(0xFFFBE4EC));
      expect(MeadowColors.creativeSurface, const Color(0xFFFAEDD6));

      expect(MeadowColors.textPrimary, const Color(0xFF1F2A1F));
      expect(MeadowColors.textSecondary, const Color(0xFF5A6B5A));
      expect(MeadowColors.textTertiary, const Color(0xFF9CAA9C));
      expect(MeadowColors.textInverse, const Color(0xFFFFFFFF));

      expect(MeadowColors.success, const Color(0xFF5DB88F));
      expect(MeadowColors.warning, const Color(0xFFF0B95C));
      expect(MeadowColors.error, const Color(0xFFD9694D));

      expect(MeadowColors.border, const Color(0xFFE8E0D5));
      expect(MeadowColors.borderLight, const Color(0xFFF2EDE5));

      expect(MeadowColors.shadow, const Color(0x14000000));
      expect(MeadowColors.shadowSoft, const Color(0x0A000000));
    });

    test('MeadowTypography generates configured Plus Jakarta Sans styles', () {
      expect(MeadowTypography.display.fontSize, 28);
      expect(MeadowTypography.display.fontWeight, FontWeight.w700);
      expect(MeadowTypography.display.height, 1.2);
      expect(MeadowTypography.display.color, MeadowColors.textPrimary);

      expect(MeadowTypography.h1.fontSize, 24);
      expect(MeadowTypography.h1.fontWeight, FontWeight.w700);
      expect(MeadowTypography.h1.height, 1.25);
      expect(MeadowTypography.h1.color, MeadowColors.textPrimary);

      expect(MeadowTypography.h2.fontSize, 20);
      expect(MeadowTypography.h2.fontWeight, FontWeight.w600);
      expect(MeadowTypography.h2.height, 1.3);

      expect(MeadowTypography.h3.fontSize, 17);
      expect(MeadowTypography.h3.fontWeight, FontWeight.w600);
      expect(MeadowTypography.h3.height, 1.3);

      expect(MeadowTypography.bodyLarge.fontSize, 16);
      expect(MeadowTypography.bodyLarge.fontWeight, FontWeight.w400);
      expect(MeadowTypography.bodyLarge.height, 1.5);

      expect(MeadowTypography.body.fontSize, 14);
      expect(MeadowTypography.body.fontWeight, FontWeight.w400);
      expect(MeadowTypography.body.height, 1.5);

      expect(MeadowTypography.caption.fontSize, 12);
      expect(MeadowTypography.caption.fontWeight, FontWeight.w500);
      expect(MeadowTypography.caption.height, 1.4);

      expect(MeadowTypography.button.fontSize, 15);
      expect(MeadowTypography.button.fontWeight, FontWeight.w600);
      expect(MeadowTypography.button.letterSpacing, 0.2);

      expect(MeadowTypography.label.fontSize, 13);
      expect(MeadowTypography.label.fontWeight, FontWeight.w600);
    });

    test('MeadowSpacing tokens are accurate', () {
      expect(MeadowSpacing.xs, 4);
      expect(MeadowSpacing.sm, 8);
      expect(MeadowSpacing.md, 12);
      expect(MeadowSpacing.lg, 16);
      expect(MeadowSpacing.xl, 20);
      expect(MeadowSpacing.xxl, 24);
      expect(MeadowSpacing.xxxl, 32);
      expect(MeadowSpacing.screenH, 20);
      expect(MeadowSpacing.cardPadding, 16);
      expect(MeadowSpacing.cardGap, 12);
    });

    test('MeadowRadius tokens are accurate', () {
      expect(MeadowRadius.sm, 8);
      expect(MeadowRadius.md, 12);
      expect(MeadowRadius.lg, 16);
      expect(MeadowRadius.xl, 20);
      expect(MeadowRadius.xxl, 24);
      expect(MeadowRadius.pill, 100);
    });

    test('MeadowShadows definitions are accurate', () {
      expect(MeadowShadows.card.length, 1);
      expect(MeadowShadows.card.first.blurRadius, 12);

      expect(MeadowShadows.elevated.length, 1);
      expect(MeadowShadows.elevated.first.blurRadius, 20);

      expect(MeadowShadows.soft.length, 1);
      expect(MeadowShadows.soft.first.blurRadius, 8);
    });

    test('MeadowButtons returns valid ButtonStyles', () {
      final primary = MeadowButtons.primary();
      expect(primary, isA<ButtonStyle>());

      final secondary = MeadowButtons.secondary();
      expect(secondary, isA<ButtonStyle>());

      final gold = MeadowButtons.gold();
      expect(gold, isA<ButtonStyle>());

      final small = MeadowButtons.small();
      expect(small, isA<ButtonStyle>());
    });

    test('MeadowCards returns valid BoxDecorations', () {
      final standard = MeadowCards.standard();
      expect(standard.color, MeadowColors.surface);
      expect(standard.borderRadius, BorderRadius.circular(MeadowRadius.lg));

      final hero = MeadowCards.hero();
      expect(hero.color, MeadowColors.surface);
      expect(hero.borderRadius, BorderRadius.circular(MeadowRadius.xl));

      const testTint = Color(0xFFEFE8FC);
      final tinted = MeadowCards.tinted(testTint);
      expect(tinted.color, testTint);

      final cream = MeadowCards.cream();
      expect(cream.color, MeadowColors.creamDark);
    });

    test('MeadowDomain returns correct domain metadata and handles case sensitivity', () {
      expect(MeadowDomain.colorFor('cognitive'), MeadowColors.cognitive);
      expect(MeadowDomain.colorFor('Language'), MeadowColors.language);
      expect(MeadowDomain.colorFor('MOTOR'), MeadowColors.motor);
      expect(MeadowDomain.colorFor('Social'), MeadowColors.social);
      expect(MeadowDomain.colorFor('emotional'), MeadowColors.emotional);
      expect(MeadowDomain.colorFor('creative'), MeadowColors.creative);
      expect(MeadowDomain.colorFor('unknown'), MeadowColors.primary);

      expect(MeadowDomain.surfaceFor('cognitive'), MeadowColors.cognitiveSurface);
      expect(MeadowDomain.surfaceFor('language'), MeadowColors.languageSurface);
      expect(MeadowDomain.surfaceFor('motor'), MeadowColors.motorSurface);
      expect(MeadowDomain.surfaceFor('social'), MeadowColors.socialSurface);
      expect(MeadowDomain.surfaceFor('emotional'), MeadowColors.emotionalSurface);
      expect(MeadowDomain.surfaceFor('creative'), MeadowColors.creativeSurface);
      expect(MeadowDomain.surfaceFor('unknown'), MeadowColors.primarySurface);

      expect(MeadowDomain.iconFor('cognitive'), Icons.psychology_outlined);
      expect(MeadowDomain.iconFor('language'), Icons.chat_bubble_outlined);
      expect(MeadowDomain.iconFor('motor'), Icons.directions_run_outlined);
      expect(MeadowDomain.iconFor('social'), Icons.people_outlined);
      expect(MeadowDomain.iconFor('emotional'), Icons.favorite_outline);
      expect(MeadowDomain.iconFor('creative'), Icons.palette_outlined);
      expect(MeadowDomain.iconFor('unknown'), Icons.star_outline);

      expect(MeadowDomain.labelFor('cognitive'), 'Cognitive');
      expect(MeadowDomain.labelFor('LANGUAGE'), 'Language');
      expect(MeadowDomain.labelFor('motor'), 'Motor');
      expect(MeadowDomain.labelFor(''), '');
    });

    test('getMeadowTheme constructs a functional ThemeData instance', () {
      final theme = getMeadowTheme();
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, MeadowColors.cream);
      expect(theme.colorScheme.primary, MeadowColors.primary);
      expect(theme.colorScheme.surface, MeadowColors.surface);
      expect(theme.colorScheme.error, MeadowColors.error);
    });
  });
}
