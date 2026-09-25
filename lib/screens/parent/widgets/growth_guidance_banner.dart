// lib/screens/parent/widgets/growth_guidance_banner.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/child_model.dart';
import '../../../theme/meadow_theme.dart';
import '../growth_analytics_screen.dart';

class GrowthGuidanceBanner extends StatefulWidget {
  final ChildModel activeChild;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? scoreEventStream;
  final VoidCallback? onViewFullGrowth;

  const GrowthGuidanceBanner({
    super.key,
    required this.activeChild,
    this.scoreEventStream,
    this.onViewFullGrowth,
  });

  @override
  State<GrowthGuidanceBanner> createState() => _GrowthGuidanceBannerState();
}

class _GrowthGuidanceBannerState extends State<GrowthGuidanceBanner> {
  static final Set<String> _dismissedEventIds = {};
  bool _manuallyDismissed = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _resolveStream() {
    if (widget.scoreEventStream != null) return widget.scoreEventStream!;
    try {
      return FirebaseFirestore.instance
          .collection('scoreEvents')
          .where('childId', isEqualTo: widget.activeChild.childId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  String _formatNum(num? n) {
    if (n == null) return '0';
    final d = n.toDouble();
    if (d.truncateToDouble() == d) {
      return d.toInt().toString();
    }
    return d.toStringAsFixed(1);
  }

  void _openAnalytics() {
    if (widget.onViewFullGrowth != null) {
      widget.onViewFullGrowth!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrowthAnalyticsScreen(activeChild: widget.activeChild),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_manuallyDismissed) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _resolveStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        if (_dismissedEventIds.contains(doc.id)) {
          return const SizedBox.shrink();
        }

        final data = doc.data();

        // 7 days expiration check
        final timestamp = data['createdAt'];
        if (timestamp is Timestamp) {
          final createdDate = timestamp.toDate();
          if (DateTime.now().difference(createdDate).inDays > 7) {
            return const SizedBox.shrink();
          }
        }

        final domain = data['skillDomain']?.toString() ?? 'Learning';
        final domainLabel = MeadowDomain.labelFor(domain);
        final scoreBefore = data['scoreBefore'] as num? ?? 0;
        final scoreAfter = data['scoreAfter'] as num? ?? 0;
        final delta = data['appliedScoreDelta'] as num? ?? (scoreAfter - scoreBefore);

        final beforeStr = _formatNum(scoreBefore);
        final afterStr = _formatNum(scoreAfter);
        final deltaVal = delta.toDouble();
        final deltaStr = deltaVal > 0 ? '+${_formatNum(deltaVal)}' : _formatNum(deltaVal);

        String message;
        if (deltaVal > 0) {
          message = '$domainLabel improved from $beforeStr to $afterStr\n($deltaStr this week)';
        } else if (deltaVal < 0) {
          message = '$domainLabel updated from $beforeStr to $afterStr\n($deltaStr this week)';
        } else {
          message = '$domainLabel score is steady at $afterStr';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: MeadowSpacing.md),
          padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
          decoration: BoxDecoration(
            color: MeadowColors.surface,
            borderRadius: BorderRadius.circular(MeadowRadius.lg),
            border: Border.all(color: MeadowColors.borderLight),
            boxShadow: MeadowShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: "💚 Recent update for Leo" + Dismiss X button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text('💚', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: MeadowSpacing.xs),
                  Expanded(
                    child: Text(
                      'Recent update for ${widget.activeChild.name}',
                      style: MeadowTypography.label.copyWith(
                        color: MeadowColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _dismissedEventIds.add(doc.id);
                      setState(() {
                        _manuallyDismissed = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(MeadowRadius.pill),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: MeadowColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MeadowSpacing.sm),

              // Detail message
              Text(
                message,
                style: MeadowTypography.body.copyWith(
                  color: MeadowColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: MeadowSpacing.sm),

              // Button "See full growth →"
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _openAnalytics,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See full growth',
                        style: MeadowTypography.button.copyWith(
                          fontSize: 13,
                          color: MeadowColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: MeadowColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
