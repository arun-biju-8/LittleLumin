import 'package:flutter/material.dart';
import '../parent_theme.dart';

class QuickActionsRow extends StatelessWidget {
  final VoidCallback onAIActivity;
  final VoidCallback onAIStory;
  final VoidCallback onAllActivities;

  const QuickActionsRow({
    super.key,
    required this.onAIActivity,
    required this.onAIStory,
    required this.onAllActivities,
  });

  Widget _buildActionTile({
    required BuildContext context,
    required String icon,
    required String label,
    required Color iconBg,
    required VoidCallback onTap,
    required int delayMs,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: ParentRadius.card,
          boxShadow: ParentShadows.card,
          border: Border.all(
            color: ParentColors.surfaceAlt,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: ParentRadius.card,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ParentTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ParentColors.textPrimary,
                      fontSize: 12,
                      height: 1.2,
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
        _buildActionTile(
          context: context,
          icon: '✨',
          label: 'AI Activity',
          iconBg: ParentColors.primary.withOpacity(0.12),
          onTap: onAIActivity,
          delayMs: 0,
        ),
        const SizedBox(width: 12),
        _buildActionTile(
          context: context,
          icon: '📖',
          label: 'AI Story',
          iconBg: ParentColors.accent.withOpacity(0.18),
          onTap: onAIStory,
          delayMs: 100,
        ),
        const SizedBox(width: 12),
        _buildActionTile(
          context: context,
          icon: '📚',
          label: 'All Activities',
          iconBg: const Color(0xFF06B6D4).withOpacity(0.14),
          onTap: onAllActivities,
          delayMs: 200,
        ),
      ],
    );
  }
}
