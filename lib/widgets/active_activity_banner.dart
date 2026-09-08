// lib/widgets/active_activity_banner.dart
import 'package:flutter/material.dart';
import '../models/journey_model.dart';
import '../utils/constants.dart';

class ActiveActivityBanner extends StatelessWidget {
  final ActiveActivityState activeActivity;
  final VoidCallback onTapComplete;

  const ActiveActivityBanner({
    super.key,
    required this.activeActivity,
    required this.onTapComplete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFeedbackPending = activeActivity.isCompleted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isFeedbackPending ? Colors.amber.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: isFeedbackPending ? Colors.amber.shade400 : Colors.orange.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isFeedbackPending ? Colors.amber.shade100 : Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFeedbackPending ? Icons.rate_review_rounded : Icons.timer_outlined,
              color: isFeedbackPending ? Colors.amber.shade900 : Colors.orange.shade800,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isFeedbackPending ? Colors.amber.shade700 : Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFeedbackPending ? 'FEEDBACK REQUIRED' : 'IN PROGRESS',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Level ${activeActivity.level}',
                      style: AppTextStyles.small.copyWith(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activeActivity.activityTitle,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Complete Button
          ElevatedButton(
            onPressed: onTapComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: isFeedbackPending ? Colors.amber.shade700 : Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isFeedbackPending ? 'Submit Feedback' : 'Complete',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
