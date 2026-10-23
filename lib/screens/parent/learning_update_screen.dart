// lib/screens/parent/learning_update_screen.dart
import 'package:flutter/material.dart';
import '../../models/child_model.dart';
import '../../models/learning_update_model.dart';
import '../../models/activity_model.dart';
import '../../services/growth_messaging_service.dart';
import '../../theme/meadow_theme.dart';
import '../../widgets/global_header.dart';
import 'app_shell.dart';
import 'journey_activity_detail_page.dart';
import 'journey_view.dart';
import 'activities/activity_library_screen.dart';

class LearningUpdateScreen extends StatefulWidget {
  final LearningUpdateModel update;
  final ChildModel activeChild;
  final bool isReadOnly;
  final GrowthMessagingService? messagingService;

  const LearningUpdateScreen({
    super.key,
    required this.update,
    required this.activeChild,
    this.isReadOnly = false,
    this.messagingService,
  });

  @override
  State<LearningUpdateScreen> createState() => _LearningUpdateScreenState();
}

class _LearningUpdateScreenState extends State<LearningUpdateScreen> {
  late final GrowthMessagingService _messagingService;
  GrowthMessage? _aiMessage;
  bool _isLoadingMessage = false;

  @override
  void initState() {
    super.initState();
    _messagingService = widget.messagingService ?? GrowthMessagingService();
    _loadEncouragement();
  }

  Future<void> _loadEncouragement({bool forceRefresh = false}) async {
    setState(() => _isLoadingMessage = true);
    try {
      final msg = await _messagingService.getOrGenerateLearningUpdateMessage(
        update: widget.update,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _aiMessage = msg;
          _isLoadingMessage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMessage = false);
      }
    }
  }

  void _navigateToGrowth() {
    final shell = context.findAncestorStateOfType<AppShellState>();
    if (shell != null) {
      shell.setTab(1); // Tab 1: Growth
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyViewScreen(activeChild: widget.activeChild),
        ),
      );
    }
  }

  void _navigateToActivities() {
    final shell = context.findAncestorStateOfType<AppShellState>();
    if (shell != null) {
      shell.setTab(0); // Tab 0: Activities
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _openNextActivity(ActivityModel activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JourneyActivityDetailPage(
          activityId: activity.id ?? 'act_next',
          childId: widget.activeChild.childId,
          initialActivity: activity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final domain = update.domain.toLowerCase().trim();
    final domainLabel = MeadowDomain.labelFor(domain);
    final domainColor = MeadowDomain.colorFor(domain);
    final domainSurface = MeadowDomain.surfaceColorFor(domain);

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: GlobalHeader(
        showBack: true,
        title: 'Learning Update 🌱',
        onBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            _navigateToGrowth();
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: MeadowSpacing.screenH,
          vertical: MeadowSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Historical Read-Only Notice
            if (widget.isReadOnly) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: MeadowColors.goldSurface,
                  borderRadius: BorderRadius.circular(MeadowRadius.md),
                  border: Border.all(color: MeadowColors.goldLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 16, color: Color(0xFF8A5A00)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Viewing saved review from ${_formatDate(update.completedAt)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A5A00)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MeadowSpacing.md),
            ],

            // Section A: Success Confirmation Header
            _buildConfirmationHeader(),
            const SizedBox(height: MeadowSpacing.lg),

            // Section B: Activity Summary Card
            _buildActivitySummaryCard(domainLabel, domainColor, domainSurface),
            const SizedBox(height: MeadowSpacing.lg),

            // Section C: Skills and Progress Updated
            _buildProgressUpdateCard(domainLabel, domainColor),
            const SizedBox(height: MeadowSpacing.lg),

            // Section D: Mastery and Level Status
            _buildMasteryStatusCard(domainLabel),
            const SizedBox(height: MeadowSpacing.lg),

            // Section E: AI-Generated Parent Encouragement
            _buildAiEncouragementCard(),
            const SizedBox(height: MeadowSpacing.xl),

            // Section F: Primary Actions
            _buildActionButtons(),
            const SizedBox(height: MeadowSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  // --- Section A: Confirmation Header ---
  Widget _buildConfirmationHeader() {
    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.primary.withOpacity(0.2)),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: MeadowColors.primarySurface,
              shape: BoxShape.circle,
              border: Border.all(color: MeadowColors.primary.withOpacity(0.3), width: 2),
            ),
            child: const Center(
              child: Text('🌱', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: MeadowSpacing.md),
          Text(
            'Learning Update Recorded',
            style: MeadowTypography.h2.copyWith(color: MeadowColors.primaryDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "${widget.update.childName}'s learning progress has been saved safely.",
            style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- Section B: Activity Summary Card ---
  Widget _buildActivitySummaryCard(String domainLabel, Color domainColor, Color domainSurface) {
    final update = widget.update;
    final ratings = update.ratings;

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVITY REVIEWED',
                style: MeadowTypography.caption.copyWith(
                  color: MeadowColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: domainSurface,
                  borderRadius: BorderRadius.circular(MeadowRadius.pill),
                  border: Border.all(color: domainColor.withOpacity(0.4)),
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
            ],
          ),
          const SizedBox(height: MeadowSpacing.sm),
          Text(update.activityTitle, style: MeadowTypography.h2),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MeadowColors.creamDark,
                  borderRadius: BorderRadius.circular(MeadowRadius.sm),
                ),
                child: Text(
                  'Level ${update.level}',
                  style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, size: 14, color: MeadowColors.success),
              const SizedBox(width: 4),
              Text(
                'Assessment Completed',
                style: MeadowTypography.caption.copyWith(color: MeadowColors.success),
              ),
            ],
          ),

          // Qualitative ratings summary
          if (ratings.isNotEmpty) ...[
            const SizedBox(height: MeadowSpacing.md),
            const Divider(color: MeadowColors.borderLight, height: 1),
            const SizedBox(height: MeadowSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (ratings['childResponse'] != null)
                  _buildRatingChip('Mood', ratings['childResponse'].toString()),
                if (ratings['engagement'] != null)
                  _buildRatingChip('Engagement', ratings['engagement'].toString()),
                if (ratings['difficulty'] != null)
                  _buildRatingChip('Pace', ratings['difficulty'].toString()),
                if (ratings['confidence'] != null)
                  _buildRatingChip('Confidence', ratings['confidence'].toString()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.sm),
        border: Border.all(color: MeadowColors.borderLight),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, color: MeadowColors.textSecondary),
      ),
    );
  }

  // --- Section C: Skills & Progress Updated ---
  Widget _buildProgressUpdateCard(String domainLabel, Color domainColor) {
    final update = widget.update;
    final before = update.scoreBefore.round();
    final after = update.scoreAfter.round();
    final delta = update.scoreDelta.round();

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECORDED PROGRESS',
                style: MeadowTypography.caption.copyWith(
                  color: MeadowColors.textTertiary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: delta > 0 ? MeadowColors.success.withOpacity(0.12) : MeadowColors.goldSurface,
                  borderRadius: BorderRadius.circular(MeadowRadius.pill),
                ),
                child: Text(
                  delta > 0 ? '+$delta pts' : (delta == 0 ? 'Steady practice' : '$delta pts'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: delta > 0 ? MeadowColors.success : MeadowColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Before & After comparison
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScoreColumn('Previous Score', '$before / 100', MeadowColors.textSecondary),
              const Icon(Icons.arrow_forward_rounded, color: MeadowColors.textTertiary),
              _buildScoreColumn('Updated Score', '$after / 100', domainColor),
            ],
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Visual Progress Bar towards 70% threshold
          ClipRRect(
            borderRadius: BorderRadius.circular(MeadowRadius.pill),
            child: LinearProgressIndicator(
              value: (after / 100.0).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: MeadowColors.creamDark,
              color: domainColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: MeadowTypography.caption),
              Text('Milestone: 70%', style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold)),
              Text('100%', style: MeadowTypography.caption),
            ],
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Non-clinical educational disclosure
          Text(
            'Note: App scores reflect joyful practice frequency and feedback ratings, not clinical developmental assessments.',
            style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreColumn(String label, String scoreText, Color scoreColor) {
    return Column(
      children: [
        Text(label, style: MeadowTypography.caption),
        const SizedBox(height: 2),
        Text(
          scoreText,
          style: MeadowTypography.h2.copyWith(color: scoreColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // --- Section D: Mastery and Level Status ---
  Widget _buildMasteryStatusCard(String domainLabel) {
    final update = widget.update;

    if (update.levelCompleted) {
      return Container(
        padding: const EdgeInsets.all(MeadowSpacing.lg),
        decoration: BoxDecoration(
          color: MeadowColors.goldSurface,
          borderRadius: BorderRadius.circular(MeadowRadius.xl),
          border: Border.all(color: MeadowColors.gold, width: 1.5),
        ),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${update.level} Mastered! 🌟',
                    style: MeadowTypography.h3.copyWith(fontWeight: FontWeight.bold, color: MeadowColors.primaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'All 6 required domains reached the 70% threshold. Level ${update.nextLevel ?? (update.level + 1)} is now unlocked!',
                    style: MeadowTypography.body.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (update.isMastered) {
      return Container(
        padding: const EdgeInsets.all(MeadowSpacing.lg),
        decoration: BoxDecoration(
          color: MeadowColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(MeadowRadius.xl),
          border: Border.all(color: MeadowColors.success.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$domainLabel Mastery Goal Reached!',
                    style: MeadowTypography.h3.copyWith(fontWeight: FontWeight.bold, color: MeadowColors.primaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This domain has reached 70%+. Continue exploring other domains to unlock Level ${update.level + 1}.',
                    style: MeadowTypography.body.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
      ),
      child: Row(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Level ${update.level} In Progress',
                  style: MeadowTypography.h3.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Playful practice in $domainLabel continues building core confidence toward Level ${update.level + 1}.',
                  style: MeadowTypography.body.copyWith(fontSize: 12.5, color: MeadowColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Section E: AI-Generated Parent Message ---
  Widget _buildAiEncouragementCard() {
    final msg = _aiMessage;

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.goldSurface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.gold, width: 1.2),
        boxShadow: MeadowShadows.card,
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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💡', style: TextStyle(fontSize: 14)),
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
              if (_isLoadingMessage)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MeadowColors.primary),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: MeadowColors.textSecondary),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Refresh Guidance',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _loadEncouragement(forceRefresh: true),
                ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.sm),
          Text(
            msg?.headline ?? 'Learning Progress Recorded 🌱',
            style: MeadowTypography.h3.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            msg?.message ??
                "${widget.update.childName} is doing great exploring new activities. Steady practice builds joyful confidence.",
            style: MeadowTypography.body.copyWith(height: 1.4, fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  // --- Section F: Action Buttons ---
  Widget _buildActionButtons() {
    final nextAct = widget.update.nextActivity;

    return Column(
      children: [
        // 1. Primary Action: View All Growth
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _navigateToGrowth,
            icon: const Icon(Icons.insights_rounded),
            label: const Text('View All Growth', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: MeadowColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
            ),
          ),
        ),
        const SizedBox(height: MeadowSpacing.md),

        // 2. Next Recommended Activity (if available)
        if (nextAct != null) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _openNextActivity(nextAct),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Next: ${nextAct.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                foregroundColor: MeadowColors.primaryDark,
                side: const BorderSide(color: MeadowColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
              ),
            ),
          ),
          const SizedBox(height: MeadowSpacing.md),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                  ),
                );
              },
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explore Activity Library'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MeadowColors.primaryDark,
                side: const BorderSide(color: MeadowColors.borderLight, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.md)),
              ),
            ),
          ),
          const SizedBox(height: MeadowSpacing.md),
        ],

        // 3. Return to Activities
        TextButton(
          onPressed: _navigateToActivities,
          child: const Text(
            'Return to Activities',
            style: TextStyle(color: MeadowColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
