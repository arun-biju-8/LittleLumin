// lib/screens/parent/home/widgets/greeting_header.dart
import 'package:flutter/material.dart';
import '../../../../theme/meadow_theme.dart';

class GreetingHeader extends StatelessWidget {
  final String parentName;

  const GreetingHeader({
    super.key,
    required this.parentName,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getTimeGreeting();
    final cleanName = parentName.trim().isNotEmpty ? parentName.trim() : 'Parent';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$greeting, $cleanName 👋',
          style: MeadowTypography.h1.copyWith(
            color: MeadowColors.textPrimary,
          ),
        ),
        const SizedBox(height: MeadowSpacing.xs),
        Text(
          'Small steps today, brighter growth tomorrow.',
          style: MeadowTypography.body.copyWith(
            color: MeadowColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
