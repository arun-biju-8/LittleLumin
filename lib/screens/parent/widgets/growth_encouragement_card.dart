// lib/screens/parent/widgets/growth_encouragement_card.dart
import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../models/journey_model.dart';
import '../../../services/growth_messaging_service.dart';
import '../../../theme/meadow_theme.dart';

class GrowthEncouragementCard extends StatefulWidget {
  final ChildModel child;
  final JourneyProgress journey;
  final Map<String, dynamic>? recommendation;
  final GrowthMessagingService? messagingService;
  final GrowthMessage? initialMessage;
  final VoidCallback? onActionTap;

  const GrowthEncouragementCard({
    super.key,
    required this.child,
    required this.journey,
    this.recommendation,
    this.messagingService,
    this.initialMessage,
    this.onActionTap,
  });

  @override
  State<GrowthEncouragementCard> createState() => _GrowthEncouragementCardState();
}

class _GrowthEncouragementCardState extends State<GrowthEncouragementCard> {
  late final GrowthMessagingService _service;
  GrowthMessage? _message;
  bool _isLoading = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _service = widget.messagingService ?? GrowthMessagingService();
    if (widget.initialMessage != null) {
      _message = widget.initialMessage;
    } else {
      _fetchMessage();
    }
  }

  @override
  void didUpdateWidget(covariant GrowthEncouragementCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != null && widget.initialMessage != oldWidget.initialMessage) {
      setState(() => _message = widget.initialMessage);
      return;
    }

    // Invalidate and refresh if progression facts changed
    final oldCompleted = oldWidget.journey.completedActivities.length;
    final newCompleted = widget.journey.completedActivities.length;
    final oldMastered = oldWidget.journey.masteredDomainCount;
    final newMastered = widget.journey.masteredDomainCount;
    final oldLevel = oldWidget.journey.currentLevel;
    final newLevel = widget.journey.currentLevel;

    if (oldCompleted != newCompleted || oldMastered != newMastered || oldLevel != newLevel) {
      _fetchMessage(forceRefresh: false);
    }
  }

  Future<void> _fetchMessage({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() => _isRefreshing = true);
    } else if (_message == null) {
      setState(() => _isLoading = true);
    }

    try {
      final msg = await _service.getOrGenerateMessage(
        child: widget.child,
        journey: widget.journey,
        recommendation: widget.recommendation,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _message = msg;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading growth encouragement: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = _message;

    if (_isLoading && msg == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MeadowSpacing.lg),
        decoration: BoxDecoration(
          color: MeadowColors.goldSurface,
          borderRadius: BorderRadius.circular(MeadowRadius.xl),
          border: Border.all(color: MeadowColors.gold.withOpacity(0.4)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: MeadowColors.primary),
            ),
          ),
        ),
      );
    }

    if (msg == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.goldSurface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.gold, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: MeadowColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text('💡', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PARENT GUIDANCE',
                    style: MeadowTypography.caption.copyWith(
                      color: const Color(0xFF8A5A00),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_isRefreshing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: MeadowColors.primary),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 18, color: MeadowColors.textSecondary),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Refresh Message',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _fetchMessage(forceRefresh: true),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.sm),
          Text(
            msg.headline,
            style: MeadowTypography.h3.copyWith(color: MeadowColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            msg.message,
            style: MeadowTypography.body.copyWith(
              color: MeadowColors.textPrimary,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          if (widget.onActionTap != null && msg.suggestedAction.isNotEmpty) ...[
            const SizedBox(height: MeadowSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.onActionTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(msg.suggestedAction),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MeadowColors.primaryDark,
                  side: const BorderSide(color: MeadowColors.gold, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
