import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/child_model.dart';
import '../../../../models/journey_model.dart';
import '../../../../models/activity_model.dart';
import '../../../../services/journey_service.dart';
import '../../../../services/activity_state_service.dart';
import '../../../../widgets/activity_card.dart';
import '../../journey_activity_detail_page.dart';
import '../../feedback_form.dart';
import '../../ai_activity_generator.dart';
import '../../parent_theme.dart';

class JourneyTab extends StatefulWidget {
  final ChildModel? activeChild;

  const JourneyTab({
    super.key,
    required this.activeChild,
  });

  @override
  State<JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<JourneyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final JourneyService _journeyService = JourneyService();
  bool _isInitializing = true;
  JourneyProgress? _journeyProgress;
  int _selectedLevel = 1;
  Future<List<ActivityModel>>? _activitiesFuture;

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<List<ActivityModel>> _fetchActivities(String domain, String difficulty) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('skillType', isEqualTo: domain.toLowerCase().trim())
          .where('difficulty', isEqualTo: difficulty.toLowerCase().trim())
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No activities found for $domain / $difficulty');
        return [];
      }

      return snapshot.docs
          .map((doc) => ActivityModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching activities: $e');
      rethrow; // Let UI show error state instead of infinite loading
    }
  }

  Future<List<ActivityModel>> _fetchActivitiesForLevel(int level, [List<String>? activityIds]) async {
    try {
      if (activityIds != null && activityIds.isNotEmpty) {
        final explicit = await _journeyService.getActivitiesForLevel(activityIds);
        if (explicit.isNotEmpty) return explicit;
      }

      final config = JourneyLevelConfig.defaultLevels.firstWhere(
        (l) => l.level == level,
        orElse: () => JourneyLevelConfig.defaultLevels.first,
      );

      final diff = config.difficulty.toLowerCase().trim() == 'complex'
          ? 'hard'
          : config.difficulty.toLowerCase().trim();

      final List<ActivityModel> activities = [];
      final childAge = widget.activeChild?.age;

      for (final domain in config.domainRequirements) {
        try {
          final domainActivities = await _fetchActivities(domain, diff);
          if (domainActivities.isNotEmpty) {
            final matched = childAge != null
                ? domainActivities.where((a) => a.ageGroup.contains(childAge)).toList()
                : domainActivities;
            activities.add(matched.isNotEmpty ? matched.first : domainActivities.first);
          } else {
            // Fallback for this domain if specific difficulty not found
            final fallback = await _fetchActivities(domain, 'medium');
            if (fallback.isNotEmpty) {
              activities.add(fallback.first);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching domain $domain: $e');
        }
      }

      if (activities.isEmpty) {
        // Direct query fallback for level
        final snapshot = await FirebaseFirestore.instance
            .collection('activities')
            .where('difficulty', isEqualTo: diff)
            .where('isActive', isEqualTo: true)
            .limit(6)
            .get();

        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs
              .map((doc) => ActivityModel.fromMap(doc.id, doc.data()))
              .toList();
        }
      }

      return activities;
    } catch (e) {
      debugPrint('❌ Error fetching activities for level $level: $e');
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _initJourney();
  }

  @override
  void didUpdateWidget(covariant JourneyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild?.childId != widget.activeChild?.childId) {
      _initJourney();
    }
  }

  Future<void> _initJourney() async {
    if (widget.activeChild == null) {
      setState(() => _isInitializing = false);
      return;
    }

    setState(() => _isInitializing = true);
    try {
      final journey = await _journeyService.getOrInitializeJourney(
        widget.activeChild!.childId,
        age: widget.activeChild!.age,
      );
      if (mounted) {
        final currentLvl = journey.currentLevel;
        final lvlProg = journey.levelProgress[currentLvl] ?? LevelProgress(completed: []);
        setState(() {
          _journeyProgress = journey;
          _selectedLevel = currentLvl;
          _isInitializing = false;
          _activitiesFuture = _fetchActivitiesForLevel(currentLvl, lvlProg.activityIds);
        });
      }
    } catch (e) {
      debugPrint('Error initializing journey: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _handleActivityTap({
    required BuildContext context,
    required JourneyProgress journey,
    required ActivityModel activity,
    required int level,
    required bool isUnlocked,
    required ActivityButtonState buttonState,
  }) async {
    if (!isUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 Level $level is locked! Complete Level ${level - 1} first to unlock.'),
          backgroundColor: ParentColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (activity.id == null || widget.activeChild == null) return;

    if (buttonState == ActivityButtonState.start) {
      await ActivityStateService().startActivity(
        childId: widget.activeChild!.childId,
        activityId: activity.id!,
        activityTitle: activity.title,
        skillDomain: activity.skillType,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyActivityDetailPage(
            activityId: activity.id!,
            childId: widget.activeChild!.childId,
            onActivityCompleted: () {
              _initJourney();
            },
          ),
        ),
      );
    } else if (buttonState == ActivityButtonState.continueActivity ||
        buttonState == ActivityButtonState.view) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyActivityDetailPage(
            activityId: activity.id!,
            childId: widget.activeChild!.childId,
            onActivityCompleted: () {
              _initJourney();
            },
          ),
        ),
      );
    } else if (buttonState == ActivityButtonState.submitFeedback) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeedbackForm(
            childId: widget.activeChild!.childId,
            activityId: activity.id!,
            activityTitle: activity.title,
          ),
        ),
      ).then((_) {
        _initJourney();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.activeChild == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: ParentColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('🗺️', style: TextStyle(fontSize: 38)),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -6, duration: 1600.ms),
              const SizedBox(height: 16),
              Text(
                'No Child Selected',
                style: ParentTypography.title,
              ),
              const SizedBox(height: 6),
              Text(
                'Please select or add a child to view their developmental skill path.',
                textAlign: TextAlign.center,
                style: ParentTypography.bodyLight,
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<JourneyProgress?>(
      stream: _journeyService.getJourneyProgress(widget.activeChild!.childId),
      builder: (context, snapshot) {
        final journey = snapshot.data ?? _journeyProgress;
        if (journey == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedConfig = JourneyLevelConfig.defaultLevels.firstWhere(
          (l) => l.level == _selectedLevel,
          orElse: () => JourneyLevelConfig.defaultLevels.first,
        );

        final isLevelUnlocked = journey.isLevelUnlocked(_selectedLevel);
        final lvlProg = journey.levelProgress[_selectedLevel] ?? LevelProgress(completed: []);
        _activitiesFuture ??= _fetchActivitiesForLevel(_selectedLevel, lvlProg.activityIds);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Summary Card with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ParentColors.primaryGradient,
                  borderRadius: ParentRadius.card,
                  boxShadow: ParentShadows.gradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('🗺️', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.activeChild!.name}\'s Skill Path',
                                style: ParentTypography.cardTitle.copyWith(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Structured level-by-level milestone growth',
                                style: ParentTypography.caption.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withOpacity(0.2), height: 1),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Milestone: Level ${journey.currentLevel}',
                          style: ParentTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: ParentRadius.chip,
                          ),
                          child: Text(
                            '${lvlProg.completed.length}/${lvlProg.total} Completed',
                            style: ParentTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Level Selector Pill Chips
              Text(
                'Select Level',
                style: ParentTypography.cardTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: JourneyLevelConfig.defaultLevels.map((lvl) {
                    final isUnlocked = journey.isLevelUnlocked(lvl.level);
                    final isSelected = _selectedLevel == lvl.level;

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        avatar: Icon(
                          isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : (isUnlocked ? ParentColors.primary : ParentColors.textTertiary),
                        ),
                        label: Text('Level ${lvl.level}'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedLevel = lvl.level;
                              final lvlProg = journey.levelProgress[_selectedLevel] ?? LevelProgress(completed: []);
                              _activitiesFuture = _fetchActivitiesForLevel(_selectedLevel, lvlProg.activityIds);
                            });
                          }
                        },
                        selectedColor: ParentColors.primary,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: ParentRadius.chip,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isUnlocked ? ParentColors.textPrimary : ParentColors.textTertiary),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Selected Level Overview Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: ParentRadius.card,
                  border: Border.all(
                    color: isLevelUnlocked
                        ? ParentColors.primary.withOpacity(0.15)
                        : ParentColors.surfaceAlt,
                    width: 1.2,
                  ),
                  boxShadow: ParentShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedConfig.title,
                          style: ParentTypography.cardTitle.copyWith(fontSize: 16),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLevelUnlocked
                                ? (lvlProg.isCompleted
                                    ? ParentColors.success.withOpacity(0.12)
                                    : ParentColors.primary.withOpacity(0.1))
                                : ParentColors.surfaceAlt,
                            borderRadius: ParentRadius.chip,
                          ),
                          child: Text(
                            isLevelUnlocked
                                ? (lvlProg.isCompleted ? 'COMPLETED 🏆' : 'UNLOCKED')
                                : 'LOCKED 🔒',
                            style: ParentTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isLevelUnlocked
                                  ? (lvlProg.isCompleted
                                      ? ParentColors.success
                                      : ParentColors.primary)
                                  : ParentColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedConfig.description,
                      style: ParentTypography.caption,
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: ParentRadius.chip,
                      child: LinearProgressIndicator(
                        value: lvlProg.progressFraction,
                        minHeight: 8,
                        backgroundColor: ParentColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          lvlProg.isCompleted ? ParentColors.success : ParentColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 6 Skill Domains Activities
              Text(
                'Skill Domain Activities',
                style: ParentTypography.cardTitle.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<ActivityModel>>(
                future: _activitiesFuture,
                builder: (context, actSnapshot) {
                  if (!isLevelUnlocked) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: ParentRadius.card,
                        border: Border.all(color: ParentColors.surfaceAlt),
                        boxShadow: ParentShadows.card,
                      ),
                      child: Center(
                        child: Text(
                          '🔒 Unlock Level $_selectedLevel by completing Level ${_selectedLevel - 1}',
                          style: ParentTypography.bodyLight,
                        ),
                      ),
                    );
                  }

                  if (actSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (actSnapshot.hasError) {
                    return ErrorCard(
                      message: 'Could not load activities. Please try again.',
                      onRetry: () {
                        setState(() {
                          _activitiesFuture = _fetchActivitiesForLevel(_selectedLevel, lvlProg.activityIds);
                        });
                      },
                    );
                  }

                  final activities = actSnapshot.data ?? [];
                  if (activities.isEmpty) {
                    return EmptyCard(
                      message: 'No activities yet for this level.',
                      action: 'Create with AI',
                      onAction: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AIActivityGeneratorScreen(
                              child: widget.activeChild,
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: ActivityStateService().watchActiveActivity(widget.activeChild!.childId),
                    builder: (context, activeSnapshot) {
                      final activeData = activeSnapshot.data?.data();

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activities.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          final isCompleted = journey.isActivityCompleted(activity.id ?? '');
                          final buttonState = ActivityCard.resolveButtonState(
                            activityId: activity.id,
                            activeActivity: activeData,
                            isCompletedInJourney: isCompleted,
                          );

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: ParentRadius.card,
                              border: Border.all(
                                color: isCompleted
                                    ? ParentColors.success.withOpacity(0.3)
                                    : ParentColors.surfaceAlt,
                                width: 1.2,
                              ),
                              boxShadow: ParentShadows.card,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? ParentColors.success.withOpacity(0.12)
                                      : (isLevelUnlocked
                                          ? ParentColors.primary.withOpacity(0.1)
                                          : ParentColors.surfaceAlt),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  isCompleted
                                      ? Icons.check_circle_rounded
                                      : (isLevelUnlocked
                                          ? Icons.play_arrow_rounded
                                          : Icons.lock_outline_rounded),
                                  color: isCompleted
                                      ? ParentColors.success
                                      : (isLevelUnlocked
                                          ? ParentColors.primary
                                          : ParentColors.textTertiary),
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                activity.title,
                                style: ParentTypography.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isLevelUnlocked
                                      ? ParentColors.textPrimary
                                      : ParentColors.textTertiary,
                                ),
                              ),
                              subtitle: Text(
                                '${_capitalize(activity.skillType)} · ${activity.duration} min',
                                style: ParentTypography.caption,
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _handleActivityTap(
                                  context: context,
                                  journey: journey,
                                  activity: activity,
                                  level: _selectedLevel,
                                  isUnlocked: isLevelUnlocked,
                                  buttonState: buttonState,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ActivityCard.getButtonColor(buttonState),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: ParentRadius.chip,
                                  ),
                                ),
                                child: Text(
                                  ActivityCard.getButtonLabel(buttonState),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms)
                              .slideY(begin: 0.05, end: 0, duration: 300.ms);
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ParentRadius.card,
        border: Border.all(color: ParentColors.error.withOpacity(0.3)),
        boxShadow: ParentShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ParentColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: ParentColors.error,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to Load Activities',
            style: ParentTypography.cardTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ParentTypography.caption.copyWith(color: ParentColors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ParentColors.primary,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: ParentRadius.chip),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const EmptyCard({
    super.key,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ParentRadius.card,
        border: Border.all(color: ParentColors.surfaceAlt),
        boxShadow: ParentShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ParentColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('✨', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ParentTypography.bodyLight,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(action!),
              style: ElevatedButton.styleFrom(
                backgroundColor: ParentColors.primary,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: ParentRadius.chip),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
