// lib/screens/parent/home/home_tab.dart
import 'package:flutter/material.dart';
import '../../../models/child_model.dart';
import '../../../widgets/global_header.dart';
import '../../../services/reminder_service.dart';
import '../../../services/activity_state_service.dart';
import '../../../theme/meadow_theme.dart';
import '../feedback_form.dart';
import '../ai_activity_generator.dart';
import '../growth_analytics_screen.dart';
import '../widgets/growth_guidance_banner.dart';
import '../app_shell.dart';
import 'active_activity_banner.dart';
import 'flagged_alert_card.dart';
import 'widgets/greeting_header.dart';
import 'widgets/child_switcher_card.dart';
import 'widgets/todays_plan_card.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/growth_snapshot_card.dart';
import 'widgets/todays_insight_card.dart';
import 'widgets/recent_activity_card.dart';

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

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToGrowth() {
    final shell = context.findAncestorStateOfType<AppShellState>();
    if (shell != null) {
      shell.setTab(1);
    } else {
      widget.onContinueJourney();
    }
  }

  Widget _buildReminderCard(BuildContext context) {
    if (_reminderMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: MeadowSpacing.md),
      padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
      decoration: BoxDecoration(
        color: MeadowColors.languageSurface,
        borderRadius: BorderRadius.circular(MeadowRadius.lg),
        border: Border.all(color: MeadowColors.language.withOpacity(0.4), width: 1.2),
        boxShadow: MeadowShadows.soft,
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
                  color: Colors.white,
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
                      style: MeadowTypography.caption.copyWith(
                        color: MeadowColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reminderMessage!,
                      style: MeadowTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: MeadowColors.textPrimary,
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
                  style: MeadowTypography.caption.copyWith(
                    color: MeadowColors.textSecondary,
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
                  backgroundColor: MeadowColors.primary,
                  foregroundColor: MeadowColors.textInverse,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MeadowRadius.md),
                  ),
                ),
                child: const Text('Complete Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.screenH),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: MeadowCards.standard(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: MeadowColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('👶', style: TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to LittleLumin!',
                textAlign: TextAlign.center,
                style: MeadowTypography.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'Add your child\'s profile to unlock personalized skill journeys, daily activities, and developmental tracking.',
                textAlign: TextAlign.center,
                style: MeadowTypography.body.copyWith(
                  color: MeadowColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onAddChild,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Add Your First Child',
                    style: MeadowTypography.button.copyWith(color: MeadowColors.textInverse),
                  ),
                  style: MeadowButtons.primary(),
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
      backgroundColor: MeadowColors.cream,
      appBar: GlobalHeader(
        showBack: false,
        scrollController: _scrollController,
        onBellTap: widget.onNotificationsTap,
        onAvatarTap: widget.onSettingsTap,
      ),
      body: widget.activeChild == null
          ? _buildEmptyState(context)
          : RefreshIndicator(
              color: MeadowColors.primary,
              backgroundColor: MeadowColors.surface,
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: MeadowSpacing.screenH,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Smart reminder if triggered
                    _buildReminderCard(context),

                    // Prominent Activity In Progress banner (if active)
                    ActiveActivityBanner(
                      childId: widget.activeChild!.childId,
                    ),

                    // Post-feedback guidance (if recent activity feedback)
                    GrowthGuidanceBanner(
                      activeChild: widget.activeChild!,
                      onViewFullGrowth: _navigateToGrowth,
                    ),

                    // 1. Greeting Section
                    GreetingHeader(parentName: widget.parentName),
                    const SizedBox(height: MeadowSpacing.lg),

                    // 2. Child Switcher Card
                    ChildSwitcherCard(
                      child: widget.activeChild!,
                      children: widget.children,
                      onChildSelected: widget.onChildSelected,
                      onAddChild: widget.onAddChild,
                    ),
                    const SizedBox(height: MeadowSpacing.lg),

                    // 3. Today's Plan Hero Card
                    TodaysPlanCard(
                      child: widget.activeChild!,
                      onAIActivity: widget.onAIActivity,
                      onContinueJourney: _navigateToGrowth,
                    ),
                    const SizedBox(height: MeadowSpacing.lg),

                    // 4. Quick Actions Row (3 tiles)
                    QuickActionsRow(
                      onAIActivity: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AIActivityGeneratorScreen(
                              child: widget.activeChild,
                              initialTabIndex: 0,
                            ),
                          ),
                        );
                      },
                      onAIStory: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AIActivityGeneratorScreen(
                              child: widget.activeChild,
                              initialTabIndex: 1,
                            ),
                          ),
                        );
                      },
                      onAllActivities: widget.onAllActivities,
                    ),
                    const SizedBox(height: MeadowSpacing.lg),

                    // 5. Growth Snapshot Card
                    GrowthSnapshotCard(
                      child: widget.activeChild!,
                      onViewGrowth: _navigateToGrowth,
                    ),
                    const SizedBox(height: MeadowSpacing.lg),

                    // 6. Today's Insight Card
                    const TodaysInsightCard(),
                    const SizedBox(height: MeadowSpacing.lg),

                    // 7. Recent Activity Card
                    RecentActivityCard(
                      child: widget.activeChild!,
                      onViewHistory: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GrowthAnalyticsScreen(
                              activeChild: widget.activeChild!,
                            ),
                          ),
                        );
                      },
                    ),

                    // 8. Support / Flagged Alert Card (if flagged)
                    if (widget.activeChild!.isFlagged) ...[
                      const SizedBox(height: MeadowSpacing.lg),
                      FlaggedAlertCard(child: widget.activeChild!),
                    ],

                    const SizedBox(height: MeadowSpacing.xxxl),
                  ],
                ),
              ),
            ),
    );
  }
}
