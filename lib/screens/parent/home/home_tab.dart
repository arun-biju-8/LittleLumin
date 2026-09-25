import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/child_model.dart';
import '../../../widgets/global_header.dart';
import '../../../services/reminder_service.dart';
import '../../../services/activity_state_service.dart';
import '../feedback_form.dart';
import '../parent_theme.dart';
import 'child_selector_card.dart';
import 'journey_card.dart';
import 'quick_actions_row.dart';
import 'tip_card.dart';
import 'flagged_alert_card.dart';
import 'active_activity_banner.dart';

class HomeTab extends StatefulWidget {
  final String parentName;
  final ChildModel? activeChild;
  final List<ChildModel> children;
  final ValueChanged<ChildModel> onChildSelected;
  final VoidCallback onAddChild;
  final VoidCallback onNotificationsTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onContinueJourney;
  final VoidCallback onAIActivity;
  final VoidCallback onAIStory;
  final VoidCallback onAllActivities;

  const HomeTab({
    super.key,
    required this.parentName,
    required this.activeChild,
    required this.children,
    required this.onChildSelected,
    required this.onAddChild,
    required this.onNotificationsTap,
    required this.onSettingsTap,
    required this.onContinueJourney,
    required this.onAIActivity,
    required this.onAIStory,
    required this.onAllActivities,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();
  final ReminderService _reminderService = ReminderService();
  final ActivityStateService _stateService = ActivityStateService();

  String? _reminderMessage;
  bool _checkedReminderForCurrentSession = false;

  @override
  void initState() {
    super.initState();
    _checkReminder();
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild?.childId != widget.activeChild?.childId) {
      _checkedReminderForCurrentSession = false;
      _checkReminder();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkReminder() async {
    if (_checkedReminderForCurrentSession || widget.activeChild == null) return;
    _checkedReminderForCurrentSession = true;

    try {
      final message = await _reminderService.checkReminder(
        widget.activeChild!.childId,
        widget.activeChild!.name,
      );

      if (message != null && mounted) {
        setState(() {
          _reminderMessage = message;
        });
        await _stateService.recordReminder(widget.activeChild!.childId);
      }
    } catch (e) {
      debugPrint('Error checking reminder: $e');
    }
  }

  Widget _buildReminderCard(BuildContext context) {
    if (_reminderMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: ParentRadius.card,
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const Text('🔔', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Friendly Reminder',
                      style: ParentTypography.caption.copyWith(
                        color: const Color(0xFF1D4ED8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reminderMessage!,
                      style: ParentTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _reminderMessage = null),
                child: Text(
                  'Dismiss',
                  style: ParentTypography.caption.copyWith(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final active = await _stateService.getActiveActivity(widget.activeChild!.childId);
                  if (!context.mounted) return;
                  if (active != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FeedbackForm(
                          childId: widget.activeChild!.childId,
                          activityId: active['activityId'],
                          activityTitle: active['activityTitle'],
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
                ),
                child: const Text('Complete Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.05, end: 0, duration: 300.ms);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: ParentRadius.card,
            boxShadow: ParentShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: ParentColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('👶', style: TextStyle(fontSize: 40)),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -6, duration: 1800.ms, curve: Curves.easeInOut),
              const SizedBox(height: 20),
              Text(
                'Welcome to LittleLumin!',
                textAlign: TextAlign.center,
                style: ParentTypography.title,
              ),
              const SizedBox(height: 8),
              Text(
                'Add your child\'s profile to unlock personalized skill journeys, daily activities, and developmental tracking.',
                textAlign: TextAlign.center,
                style: ParentTypography.bodyLight,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onAddChild,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Add Your First Child',
                    style: ParentTypography.button.copyWith(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParentColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: ParentRadius.button,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParentColors.surfaceAlt,
      appBar: GlobalHeader(
        showBack: false,
        scrollController: _scrollController,
        onBellTap: widget.onNotificationsTap,
        onAvatarTap: widget.onSettingsTap,
      ),
      body: widget.activeChild == null
          ? _buildEmptyState(context)
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Smart reminder if triggered
                  _buildReminderCard(context),

                  // Prominent Activity In Progress banner
                  ActiveActivityBanner(
                    childId: widget.activeChild!.childId,
                  ),

                  ChildSelectorCard(
                    child: widget.activeChild!,
                    children: widget.children,
                    onChildSelected: widget.onChildSelected,
                    onAddChild: widget.onAddChild,
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.05, end: 0, duration: 300.ms),
                  const SizedBox(height: 16),
                  JourneyCard(
                    child: widget.activeChild!,
                    onContinueJourney: widget.onContinueJourney,
                  )
                      .animate()
                      .fadeIn(delay: 80.ms, duration: 350.ms)
                      .slideY(begin: 0.05, end: 0, duration: 350.ms),
                  const SizedBox(height: 16),
                  QuickActionsRow(
                    onAIActivity: widget.onAIActivity,
                    onAIStory: widget.onAIStory,
                    onAllActivities: widget.onAllActivities,
                  ),
                  const SizedBox(height: 16),
                  const TipCard()
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 350.ms)
                      .slideY(begin: 0.05, end: 0, duration: 350.ms),
                  if (widget.activeChild!.isFlagged) ...[
                    const SizedBox(height: 16),
                    FlaggedAlertCard(child: widget.activeChild!)
                        .animate()
                        .fadeIn(delay: 280.ms, duration: 350.ms)
                        .slideY(begin: 0.05, end: 0, duration: 350.ms),
                  ],
                ],
              ),
            ),
    );
  }
}
