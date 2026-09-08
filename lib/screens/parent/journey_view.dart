// lib/screens/parent/journey_view.dart
import 'package:flutter/material.dart';
import '../../models/child_model.dart';
import '../../models/journey_model.dart';
import '../../models/activity_model.dart';
import '../../services/journey_service.dart';
import '../../utils/constants.dart';
import '../../widgets/journey_dialogs.dart';
import 'activity_view.dart';
import 'feedback_form.dart';

class JourneyViewScreen extends StatefulWidget {
  final ChildModel activeChild;

  const JourneyViewScreen({
    super.key,
    required this.activeChild,
  });

  @override
  State<JourneyViewScreen> createState() => _JourneyViewScreenState();
}

class _JourneyViewScreenState extends State<JourneyViewScreen> {
  final JourneyService _journeyService = JourneyService();
  bool _isInitializing = true;
  JourneyProgress? _journeyProgress;

  @override
  void initState() {
    super.initState();
    _initJourney();
  }

  Future<void> _initJourney() async {
    setState(() => _isInitializing = true);
    try {
      final journey = await _journeyService.getOrInitializeJourney(
        widget.activeChild.childId,
        age: widget.activeChild.age,
      );
      if (mounted) {
        setState(() {
          _journeyProgress = journey;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing journey: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _handleActivityTap({
    required BuildContext context,
    required JourneyProgress journey,
    required ActivityModel activity,
    required int level,
    required bool isUnlocked,
  }) async {
    if (!isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 Level $level is locked! Complete Level ${level - 1} first to unlock.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final active = journey.activeActivity;

    // SCENARIO A: No active activity or tapping current active activity
    if (active == null || active.activityId == activity.id) {
      await _journeyService.startActivity(
        childId: widget.activeChild.childId,
        activityId: activity.id!,
        activityTitle: activity.title,
        level: level,
      );

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityView(
            activity: activity,
            childId: widget.activeChild.childId,
          ),
        ),
      );
      return;
    }

    // SCENARIO C: Active activity is marked completed but feedback is pending
    if (active.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📝 Please submit feedback for your active activity to continue!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackForm(
            childId: widget.activeChild.childId,
            activityId: active.activityId,
            activityTitle: active.activityTitle,
          ),
        ),
      );
      return;
    }

    // SCENARIO B: Has active activity in progress, trying to start a DIFFERENT activity
    if (active.isInProgress && active.activityId != activity.id) {
      final choice = await JourneyDialogs.showActiveActivityWarningDialog(
        context: context,
        activeActivityTitle: active.activityTitle,
      );

      if (choice == 'complete') {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeedbackForm(
              childId: widget.activeChild.childId,
              activityId: active.activityId,
              activityTitle: active.activityTitle,
            ),
          ),
        );
      } else if (choice == 'discard') {
        await _journeyService.discardActiveActivity(widget.activeChild.childId);
        await _journeyService.startActivity(
          childId: widget.activeChild.childId,
          activityId: activity.id!,
          activityTitle: activity.title,
          level: level,
        );

        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActivityView(
              activity: activity,
              childId: widget.activeChild.childId,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Activity Journey', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<JourneyProgress?>(
              stream: _journeyService.getJourneyProgress(widget.activeChild.childId),
              builder: (context, snapshot) {
                final journey = snapshot.data ?? _journeyProgress;

                if (journey == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Overview Banner
                      _buildJourneyHeaderBanner(journey),
                      const SizedBox(height: AppSpacing.lg),

                      // Level Sections (Level 1 to Level 4)
                      ...JourneyLevelConfig.defaultLevels.map((lvlConfig) {
                        return _buildLevelSection(context, journey, lvlConfig);
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildJourneyHeaderBanner(JourneyProgress journey) {
    final currentLevelConfig = JourneyLevelConfig.defaultLevels.firstWhere(
      (l) => l.level == journey.currentLevel,
      orElse: () => JourneyLevelConfig.defaultLevels.first,
    );

    final lvlProg = journey.currentLevelProgress ?? LevelProgress(completed: []);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF6C5CE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.activeChild.name}\'s Skill Path',
                      style: AppTextStyles.heading1.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Structured level-by-level skill development',
                      style: AppTextStyles.small.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT LEVEL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentLevelConfig.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${lvlProg.completed.length}/${lvlProg.total} Done',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSection(
    BuildContext context,
    JourneyProgress journey,
    JourneyLevelConfig lvlConfig,
  ) {
    final int level = lvlConfig.level;
    final bool isUnlocked = journey.isLevelUnlocked(level);
    final lvlProg = journey.levelProgress[level] ?? LevelProgress(completed: []);
    final isCurrentLevel = journey.currentLevel == level;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: isCurrentLevel
              ? AppColors.primary
              : isUnlocked
                  ? AppColors.border
                  : Colors.grey.shade300,
          width: isCurrentLevel ? 2.0 : 1.0,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level Title Header Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? (isCurrentLevel ? AppColors.primary.withOpacity(0.08) : Colors.grey.shade50)
                  : Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppBorderRadius.medium),
                topRight: Radius.circular(AppBorderRadius.medium),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isUnlocked ? (lvlProg.isCompleted ? Icons.verified : Icons.lock_open) : Icons.lock,
                  color: isUnlocked ? (lvlProg.isCompleted ? AppColors.success : AppColors.primary) : Colors.grey.shade500,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            lvlConfig.title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? AppColors.textDark : Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                          if (isCurrentLevel) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUnlocked
                            ? lvlConfig.description
                            : 'Complete Level ${level - 1} to unlock this level',
                        style: AppTextStyles.small.copyWith(
                          color: isUnlocked ? AppColors.textLight : Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  Text(
                    '${lvlProg.completed.length}/${lvlProg.total}',
                    style: AppTextStyles.small.copyWith(
                      fontWeight: FontWeight.bold,
                      color: lvlProg.isCompleted ? AppColors.success : AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Activities List for Level
          FutureBuilder<List<ActivityModel>>(
            future: _journeyService.getActivitiesForLevel(lvlProg.activityIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    isUnlocked ? 'Activities loading...' : '🔒 Locked',
                    style: AppTextStyles.small.copyWith(color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  final isCompleted = journey.isActivityCompleted(activity.id ?? '');
                  final isActive = journey.activeActivity?.activityId == activity.id &&
                      journey.activeActivity?.isInProgress == true;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success.withOpacity(0.15)
                            : isActive
                                ? Colors.orange.withOpacity(0.15)
                                : isUnlocked
                                    ? AppColors.primary.withOpacity(0.1)
                                    : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isCompleted
                              ? '✅'
                              : isActive
                                  ? '⏳'
                                  : isUnlocked
                                      ? '🔓'
                                      : '🔒',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isUnlocked ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            activity.skillType,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isUnlocked ? AppColors.primary : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activity.title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: isCompleted || isActive ? FontWeight.bold : FontWeight.w500,
                              color: isUnlocked ? AppColors.textDark : Colors.grey.shade600,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isCompleted
                          ? 'Completed 🎉'
                          : isActive
                              ? 'IN PROGRESS — Tap to view'
                              : '${activity.duration} min • ${activity.difficulty}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted
                            ? AppColors.success
                            : isActive
                                ? Colors.orange.shade800
                                : AppColors.textLight,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: isUnlocked ? AppColors.textLight : Colors.grey.shade400,
                    ),
                    onTap: () {
                      _handleActivityTap(
                        context: context,
                        journey: journey,
                        activity: activity,
                        level: level,
                        isUnlocked: isUnlocked,
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
