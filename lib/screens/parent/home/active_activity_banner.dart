import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../services/activity_state_service.dart';
import '../parent_theme.dart';
import '../feedback_form.dart';

class ActiveActivityBanner extends StatefulWidget {
  final String childId;
  final VoidCallback? onCompleteNow;
  final VoidCallback? onDiscard;
  final ActivityStateService? service;

  const ActiveActivityBanner({
    super.key,
    required this.childId,
    this.onCompleteNow,
    this.onDiscard,
    this.service,
  });

  @override
  State<ActiveActivityBanner> createState() => _ActiveActivityBannerState();
}

class _ActiveActivityBannerState extends State<ActiveActivityBanner> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant ActiveActivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.childId != oldWidget.childId || widget.service != oldWidget.service) {
      _initStream();
    }
  }

  void _initStream() {
    if (widget.childId.isNotEmpty) {
      _stream = (widget.service ?? ActivityStateService()).watchActiveActivity(widget.childId);
    } else {
      _stream = null;
    }
  }

  String _formatElapsed(DateTime startedAt) {
    final diff = DateTime.now().difference(startedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _confirmDiscard(BuildContext context, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
        title: Text('Discard Activity?', style: ParentTypography.cardTitle),
        content: Text(
          'Are you sure you want to discard "$title"? Current progress will be removed.',
          style: ParentTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentColors.error,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await (widget.service ?? ActivityStateService()).discardActivity(widget.childId);
      widget.onDiscard?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity discarded'),
            backgroundColor: ParentColors.warning,
          ),
        );
      }
    }
  }

  void _handleComplete(BuildContext context, String activityId, String title) {
    if (widget.onCompleteNow != null) {
      widget.onCompleteNow!();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedbackForm(
          childId: widget.childId,
          activityId: activityId,
          activityTitle: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.childId.isEmpty || _stream == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data()!;
        final status = data['status'] as String? ?? 'in_progress';
        if (status == 'completed') {
          return const SizedBox.shrink();
        }

        final activityId = data['activityId'] as String? ?? '';
        final activityTitle = data['activityTitle'] as String? ?? 'Activity';
        final rawDomain = data['skillDomain'] as String? ?? 'Development';
        final skillDomain = rawDomain.isNotEmpty
            ? '${rawDomain[0].toUpperCase()}${rawDomain.substring(1)}'
            : 'Development';

        final startedAtRaw = data['startedAt'];
        DateTime startedAt = DateTime.now();
        if (startedAtRaw is Timestamp) {
          startedAt = startedAtRaw.toDate();
        } else if (startedAtRaw is DateTime) {
          startedAt = startedAtRaw;
        } else if (startedAtRaw is String) {
          startedAt = DateTime.tryParse(startedAtRaw) ?? DateTime.now();
        }

        final timeAgo = _formatElapsed(startedAt);
        final isFeedbackPending = status == 'completed_pending_feedback';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isFeedbackPending ? const Color(0xFFFFF7ED) : const Color(0xFFFFFBEB),
            borderRadius: ParentRadius.card,
            border: Border.all(
              color: isFeedbackPending ? const Color(0xFFFDBA74) : const Color(0xFFFCD34D),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isFeedbackPending
                              ? const Color(0xFFEA580C)
                              : const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isFeedbackPending ? '📝' : '⏳',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isFeedbackPending
                                  ? 'FEEDBACK PENDING'
                                  : 'ACTIVITY IN PROGRESS',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Started $timeAgo',
                    style: ParentTypography.caption.copyWith(
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title and Domain
              Text(
                '"$activityTitle"',
                style: ParentTypography.cardTitle.copyWith(
                  fontSize: 17,
                  color: const Color(0xFF78350F),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Skill Domain: $skillDomain',
                style: ParentTypography.caption.copyWith(
                  color: const Color(0xFF92400E),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleComplete(context, activityId, activityTitle),
                      icon: Icon(
                        isFeedbackPending
                            ? Icons.rate_review_rounded
                            : Icons.check_circle_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isFeedbackPending ? 'Submit Feedback' : 'Complete Now',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFeedbackPending
                            ? const Color(0xFFEA580C)
                            : const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: const RoundedRectangleBorder(
                          borderRadius: ParentRadius.button,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDiscard(context, activityTitle),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text(
                      'Discard',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB45309),
                      side: const BorderSide(color: Color(0xFFFCD34D), width: 1.2),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: const RoundedRectangleBorder(
                        borderRadius: ParentRadius.button,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.05, end: 0, duration: 300.ms);
      },
    );
  }
}
