// lib/widgets/journey_card.dart
import 'package:flutter/material.dart';
import '../models/journey_model.dart';
import '../utils/constants.dart';

class JourneyCard extends StatelessWidget {
  final JourneyProgress journeyProgress;
  final VoidCallback onTapContinue;

  const JourneyCard({
    super.key,
    required this.journeyProgress,
    required this.onTapContinue,
  });

  @override
  Widget build(BuildContext context) {
    final level = journeyProgress.currentLevel;
    final levelConfig = JourneyLevelConfig.defaultLevels.firstWhere(
      (l) => l.level == level,
      orElse: () => JourneyLevelConfig.defaultLevels.first,
    );

    final lvlProgress = journeyProgress.currentLevelProgress ?? LevelProgress(completed: []);
    final completedCount = lvlProgress.completed.length;
    final totalCount = lvlProgress.total > 0 ? lvlProgress.total : 6;
    final progressFraction = lvlProgress.progressFraction;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90D9), Color(0xFF357ABD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A90D9).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Your Journey',
                    style: AppTextStyles.heading2.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'LEVEL $level',
                  style: AppTextStyles.small.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Level Title
          Text(
            levelConfig.title,
            style: AppTextStyles.heading1.copyWith(
              color: Colors.white,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Progress Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: AppTextStyles.small.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$completedCount/$totalCount activities completed',
                style: AppTextStyles.small.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Custom Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Continue Journey Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onTapContinue,
              icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primary),
              label: Text(
                'Continue Journey',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
