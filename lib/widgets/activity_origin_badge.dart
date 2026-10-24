// lib/widgets/activity_origin_badge.dart
import 'package:flutter/material.dart';
import '../models/activity_model.dart';
import '../theme/meadow_theme.dart';

/// Visually consistent origin badge indicating if an activity is:
/// - AI Generated
/// - Preset Activity
/// - LLG Recommended
///
/// Reliably uses activity model metadata without inferring from title/description.
/// Gracefully omits if origin cannot be reliably determined.
class ActivityOriginBadge extends StatelessWidget {
  final ActivityModel? activity;
  final ActivityOrigin? originOverride;
  final bool compact;

  const ActivityOriginBadge({
    super.key,
    this.activity,
    this.originOverride,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOrigin = originOverride ?? activity?.activityOrigin ?? ActivityOrigin.unknown;

    if (effectiveOrigin == ActivityOrigin.unknown) {
      return const SizedBox.shrink();
    }

    final BadgeConfig config;
    switch (effectiveOrigin) {
      case ActivityOrigin.aiGenerated:
        config = const BadgeConfig(
          label: 'AI Generated',
          icon: Icons.auto_awesome_rounded,
          backgroundColor: Color(0xFFF3E8FF), // soft lavender
          borderColor: Color(0xFFD8B4FE),
          textColor: Color(0xFF7E22CE), // rich purple
          iconColor: Color(0xFF9333EA),
          emoji: '✨',
        );
        break;
      case ActivityOrigin.preset:
        config = const BadgeConfig(
          label: 'Preset Activity',
          icon: Icons.menu_book_rounded,
          backgroundColor: Color(0xFFE0F2FE), // soft sky
          borderColor: Color(0xFFBAE6FD),
          textColor: Color(0xFF0369A1), // rich ocean blue
          iconColor: Color(0xFF0284C7),
          emoji: '📚',
        );
        break;
      case ActivityOrigin.llgRecommended:
        config = const BadgeConfig(
          label: 'LLG Recommended',
          icon: Icons.verified_rounded,
          backgroundColor: Color(0xFFFEF3C7), // warm amber/gold
          borderColor: Color(0xFFFDE68A),
          textColor: Color(0xFFB45309), // rich honey/amber
          iconColor: Color(0xFFD97706),
          emoji: '🌟',
        );
        break;
      case ActivityOrigin.unknown:
        return const SizedBox.shrink();
    }

    final double verticalPadding = compact ? 2 : 3;
    final double horizontalPadding = compact ? 6 : 8;
    final double fontSize = compact ? 10 : 11;
    final double iconSize = compact ? 11 : 13;

    return Semantics(
      label: 'Activity origin: ${config.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(MeadowRadius.pill),
          border: Border.all(
            color: config.borderColor,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              config.icon,
              size: iconSize,
              color: config.iconColor,
            ),
            const SizedBox(width: 4),
            Text(
              config.label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: config.textColor,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BadgeConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final String emoji;

  const BadgeConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    required this.emoji,
  });
}
