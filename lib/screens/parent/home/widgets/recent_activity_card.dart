// lib/screens/parent/home/widgets/recent_activity_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/child_model.dart';
import '../../../../theme/meadow_theme.dart';
import '../../growth_analytics_screen.dart';

class RecentActivityCard extends StatelessWidget {
  final ChildModel child;
  final VoidCallback? onViewHistory;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? scoreEventsStream;

  const RecentActivityCard({
    super.key,
    required this.child,
    this.onViewHistory,
    this.scoreEventsStream,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> _resolveStream() {
    if (scoreEventsStream != null) return scoreEventsStream!;
    try {
      return FirebaseFirestore.instance
          .collection('scoreEvents')
          .where('childId', isEqualTo: child.childId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      if (diff.inMinutes < 2) return 'Just now';
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24 && now.day == date.day) {
      return 'Today';
    }
    if (diff.inDays <= 1 || (diff.inHours < 48 && now.day - date.day == 1)) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return '${(diff.inDays / 7).floor()}w ago';
  }

  void _handleViewHistory(BuildContext context) {
    if (onViewHistory != null) {
      onViewHistory!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrowthAnalyticsScreen(activeChild: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _resolveStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            decoration: MeadowCards.standard(),
            padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: MeadowColors.creamDark,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: MeadowColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RECENT ACTIVITY',
                      style: MeadowTypography.caption.copyWith(
                        color: MeadowColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'No activities completed yet',
                  style: MeadowTypography.h3,
                ),
                const SizedBox(height: 4),
                Text(
                  'Completed daily plans and playful activities will appear here.',
                  style: MeadowTypography.body.copyWith(
                    color: MeadowColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final data = docs.first.data();
        final title = (data['activityTitle'] ?? data['title'] ?? 'Play Session').toString();
        final domain = (data['skillDomain'] ?? data['domain'] ?? 'Cognitive').toString();
        final duration = (data['durationMinutes'] ?? data['duration'] ?? 10).toString();

        DateTime? createdAt;
        final ts = data['createdAt'];
        if (ts is Timestamp) {
          createdAt = ts.toDate();
        } else if (ts is String) {
          createdAt = DateTime.tryParse(ts);
        }

        final relativeTime = _formatRelativeTime(createdAt);
        final domainLabel = MeadowDomain.labelFor(domain);
        final domainColor = MeadowDomain.colorFor(domain);

        return Container(
          width: double.infinity,
          decoration: MeadowCards.standard(),
          child: Padding(
            padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: MeadowColors.motorSurface,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: MeadowColors.motor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'RECENT ACTIVITY',
                          style: MeadowTypography.caption.copyWith(
                            color: MeadowColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      relativeTime,
                      style: MeadowTypography.caption.copyWith(
                        color: MeadowColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  title,
                  style: MeadowTypography.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Subtitle metadata: Domain · Duration · Relative time
                Row(
                  children: [
                    Text(
                      domainLabel,
                      style: MeadowTypography.caption.copyWith(
                        color: domainColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ' · $duration min · $relativeTime',
                      style: MeadowTypography.caption.copyWith(
                        color: MeadowColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // View History button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _handleViewHistory(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View History →',
                          style: MeadowTypography.button.copyWith(
                            color: MeadowColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
