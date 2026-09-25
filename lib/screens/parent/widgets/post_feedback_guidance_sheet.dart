// lib/screens/parent/widgets/post_feedback_guidance_sheet.dart
import 'package:flutter/material.dart';
import '../../../models/activity_model.dart';
import '../../../theme/meadow_theme.dart';

Future<String?> showPostFeedbackGuidance(
  BuildContext context, {
  required String childName,
  required String domain,
  required double scoreBefore,
  required double scoreAfter,
  required double delta,
  ActivityModel? nextActivity,
  VoidCallback? onNextActivity,
  VoidCallback? onViewGrowth,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => PostFeedbackGuidanceSheet(
      childName: childName,
      domain: domain,
      scoreBefore: scoreBefore,
      scoreAfter: scoreAfter,
      delta: delta,
      nextActivity: nextActivity,
      onNextActivity: onNextActivity,
      onViewGrowth: onViewGrowth,
    ),
  );
}

class PostFeedbackGuidanceSheet extends StatelessWidget {
  final String childName;
  final String domain;
  final double scoreBefore;
  final double scoreAfter;
  final double delta;
  final ActivityModel? nextActivity;
  final VoidCallback? onNextActivity;
  final VoidCallback? onViewGrowth;

  const PostFeedbackGuidanceSheet({
    super.key,
    required this.childName,
    required this.domain,
    required this.scoreBefore,
    required this.scoreAfter,
    required this.delta,
    this.nextActivity,
    this.onNextActivity,
    this.onViewGrowth,
  });

  String _formatNum(double n) {
    if (n.truncateToDouble() == n) {
      return n.toInt().toString();
    }
    return n.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final domainLabel = MeadowDomain.labelFor(domain);
    final beforeStr = _formatNum(scoreBefore);
    final afterStr = _formatNum(scoreAfter);
    final deltaStr = delta > 0 ? '+${_formatNum(delta)}' : _formatNum(delta);

    final isPositive = delta > 0;
    final isNegative = delta < 0;

    String emoji;
    String title;
    String scoreLine;
    String bodyMessage;
    String primaryButtonLabel;
    bool showSecondaryButton = false;

    if (isPositive) {
      // Case A: Score improved
      emoji = '🎉';
      title = 'Nice work!';
      scoreLine = "$childName's $domainLabel score improved from $beforeStr to $afterStr ($deltaStr).";
      bodyMessage = 'Great progress! Keep it up.';
      primaryButtonLabel = nextActivity != null
          ? 'Continue with next activity'
          : 'Back to Home';
    } else if (isNegative) {
      // Case B: Score dropped
      emoji = '💚';
      title = '$childName found that one tricky';
      scoreLine = '$domainLabel score: $beforeStr → $afterStr ($deltaStr)';
      bodyMessage = "That's okay — every child has tough days. We've prepared a gentler activity to help.";
      primaryButtonLabel = nextActivity != null
          ? 'Try easier activity →'
          : 'Continue';
      showSecondaryButton = true;
    } else {
      // Case C: No change
      emoji = '💚';
      title = 'Thanks for sharing!';
      scoreLine = '$domainLabel score is $beforeStr.';
      bodyMessage = 'Every activity helps — keep going.';
      primaryButtonLabel = nextActivity != null
          ? 'Continue with next activity'
          : 'Back to Home';
    }

    return Container(
      decoration: const BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xxl)),
        boxShadow: MeadowShadows.elevated,
      ),
      padding: EdgeInsets.fromLTRB(
        MeadowSpacing.xl,
        MeadowSpacing.md,
        MeadowSpacing.xl,
        MediaQuery.of(context).viewInsets.bottom + MeadowSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: MeadowColors.border,
                borderRadius: BorderRadius.circular(MeadowRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: MeadowSpacing.lg),

          // Header with Emoji & Title
          Row(
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: MeadowSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: MeadowTypography.h2.copyWith(
                    color: MeadowColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Score highlight box
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MeadowSpacing.lg,
              vertical: MeadowSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isPositive
                  ? MeadowColors.primarySurface
                  : (isNegative ? MeadowColors.goldSurface : MeadowColors.surfaceAlt),
              borderRadius: BorderRadius.circular(MeadowRadius.md),
              border: Border.all(
                color: isPositive
                    ? MeadowColors.primary.withOpacity(0.2)
                    : (isNegative ? MeadowColors.gold.withOpacity(0.4) : MeadowColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  MeadowDomain.iconFor(domain),
                  size: 20,
                  color: MeadowDomain.colorFor(domain),
                ),
                const SizedBox(width: MeadowSpacing.sm),
                Expanded(
                  child: Text(
                    scoreLine,
                    style: MeadowTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: MeadowColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Warm message
          Text(
            bodyMessage,
            style: MeadowTypography.bodyLarge.copyWith(
              color: MeadowColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: MeadowSpacing.xl),

          // Primary Button
          ElevatedButton(
            style: MeadowButtons.primary(),
            onPressed: () {
              Navigator.pop(context, 'primary');
              onNextActivity?.call();
            },
            child: Text(primaryButtonLabel),
          ),

          // Optional Secondary Button (for Case B)
          if (showSecondaryButton) ...[
            const SizedBox(height: MeadowSpacing.sm),
            OutlinedButton(
              style: MeadowButtons.secondary(),
              onPressed: () {
                Navigator.pop(context, 'growth');
                onViewGrowth?.call();
              },
              child: const Text('See growth trends →'),
            ),
          ],
        ],
      ),
    );
  }
}
