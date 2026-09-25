import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/child_model.dart';
import '../../../theme/meadow_theme.dart';
import '../journey_view.dart';
import '../widgets/growth_guidance_banner.dart';
import '../widgets/compact_score_preview.dart';

class GrowthTab extends StatelessWidget {
  final ChildModel? activeChild;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? skillProfileStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? scoreEventsStream;
  final VoidCallback? onViewFullAnalytics;

  const GrowthTab({
    super.key,
    this.activeChild,
    this.skillProfileStream,
    this.scoreEventsStream,
    this.onViewFullAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    if (activeChild == null) {
      return Scaffold(
        backgroundColor: MeadowColors.cream,
        appBar: AppBar(
          title: Text('Growth', style: MeadowTypography.h2),
          backgroundColor: MeadowColors.surface,
          foregroundColor: MeadowColors.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(MeadowSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(MeadowSpacing.lg),
                  decoration: const BoxDecoration(
                    color: MeadowColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.trending_up_outlined,
                    size: 48,
                    color: MeadowColors.primary,
                  ),
                ),
                const SizedBox(height: MeadowSpacing.lg),
                Text('Growth Journey', style: MeadowTypography.h2),
                const SizedBox(height: MeadowSpacing.xs),
                Text(
                  'Select or add a child to track their milestone growth and activities.',
                  textAlign: TextAlign.center,
                  style: MeadowTypography.bodyLarge.copyWith(
                    color: MeadowColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return JourneyViewScreen(
      activeChild: activeChild!,
      title: 'Growth',
      headerWidgets: [
        GrowthGuidanceBanner(
          activeChild: activeChild!,
          scoreEventStream: scoreEventsStream,
          onViewFullGrowth: onViewFullAnalytics,
        ),
        CompactScorePreview(
          activeChild: activeChild!,
          skillProfileStream: skillProfileStream,
          scoreEventsStream: scoreEventsStream,
          onViewFullAnalytics: onViewFullAnalytics,
        ),
      ],
    );
  }
}
