// lib/screens/parent/widgets/latest_learning_update_card.dart
import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../models/learning_update_model.dart';
import '../../../services/journey_service.dart';
import '../../../theme/meadow_theme.dart';
import '../learning_update_screen.dart';

class LatestLearningUpdateCard extends StatefulWidget {
  final ChildModel child;
  final JourneyService? journeyService;
  final LearningUpdateModel? initialUpdate;

  const LatestLearningUpdateCard({
    super.key,
    required this.child,
    this.journeyService,
    this.initialUpdate,
  });

  @override
  State<LatestLearningUpdateCard> createState() => _LatestLearningUpdateCardState();
}

class _LatestLearningUpdateCardState extends State<LatestLearningUpdateCard> {
  late final JourneyService _journeyService;
  LearningUpdateModel? _update;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _journeyService = widget.journeyService ?? JourneyService();
    if (widget.initialUpdate != null) {
      _update = widget.initialUpdate;
    } else {
      _fetchLatestUpdate();
    }
  }

  @override
  void didUpdateWidget(covariant LatestLearningUpdateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child.childId != oldWidget.child.childId) {
      setState(() => _update = null);
      _fetchLatestUpdate();
    } else if (widget.initialUpdate != null && widget.initialUpdate != oldWidget.initialUpdate) {
      setState(() => _update = widget.initialUpdate);
    }
  }

  Future<void> _fetchLatestUpdate() async {
    final childId = widget.child.childId;
    if (childId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final update = await _journeyService.getLatestLearningUpdate(childId);
      if (mounted && widget.child.childId == childId) {
        setState(() {
          _update = update;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openLearningUpdate(LearningUpdateModel update) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LearningUpdateScreen(
          update: update,
          activeChild: widget.child,
          isReadOnly: true,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m <= 1 ? 'Just now' : '$m mins ago';
    } else if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1 ? '1 hour ago' : '$h hours ago';
    } else if (diff.inDays < 7) {
      final d = diff.inDays;
      return d == 1 ? 'Yesterday' : '$d days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _update == null) {
      return const SizedBox.shrink();
    }

    final update = _update;
    if (update == null || update.childId != widget.child.childId) {
      return const SizedBox.shrink();
    }

    final domainLabel = MeadowDomain.labelFor(update.domain);
    final domainColor = MeadowDomain.colorFor(update.domain);
    final delta = update.scoreDelta.round();
    final deltaText = delta > 0 ? '+$delta pts' : (delta == 0 ? 'Steady practice' : '$delta pts');

    return Container(
      width: double.infinity,
      decoration: MeadowCards.standard(),
      padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'LATEST LEARNING UPDATE',
                    style: MeadowTypography.caption.copyWith(
                      color: MeadowColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Text(
                _formatTimestamp(update.completedAt),
                style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.sm),
          Text(
            update.activityTitle,
            style: MeadowTypography.h3.copyWith(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: domainColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(MeadowRadius.pill),
                ),
                child: Text(
                  domainLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: domainColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  $deltaText  •  ${update.scoreAfter.round()}/100',
                style: MeadowTypography.caption.copyWith(
                  color: MeadowColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openLearningUpdate(update),
              icon: const Icon(Icons.history_edu_rounded, size: 16),
              label: const Text('View Last Learning Update'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MeadowColors.primaryDark,
                side: const BorderSide(color: MeadowColors.primary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
