// lib/screens/parent/home/widgets/quick_actions_row.dart
import 'package:flutter/material.dart';
import '../../../../theme/meadow_theme.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onAIActivity;
  final VoidCallback onAIStory;
  final VoidCallback onAllActivities;
  final String? labelActivity;
  final String? labelStory;
  final String? labelLibrary;

  const QuickActionsRow({
    super.key,
    required this.onAIActivity,
    required this.onAIStory,
    required this.onAllActivities,
    this.labelActivity,
    this.labelStory,
    this.labelLibrary,
  });

  Widget _buildTile({
    required BuildContext context,
    required String icon,
    required String label,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Container(
        decoration: MeadowCards.standard(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(MeadowRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MeadowTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MeadowColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildTile(
          context: context,
          icon: '✨',
          label: labelActivity ?? 'Create with AI',
          iconBg: MeadowColors.goldSurface,
          onTap: onAIActivity,
        ),
        const SizedBox(width: 10),
        _buildTile(
          context: context,
          icon: '📖',
          label: labelStory ?? 'Read a Story',
          iconBg: MeadowColors.languageSurface,
          onTap: onAIStory,
        ),
        const SizedBox(width: 10),
        _buildTile(
          context: context,
          icon: '🧩',
          label: labelLibrary ?? 'Activity Library',
          iconBg: MeadowColors.motorSurface,
          onTap: onAllActivities,
        ),
      ],
    );
  }
}
