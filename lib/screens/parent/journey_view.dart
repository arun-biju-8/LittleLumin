// lib/screens/parent/journey_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child_model.dart';
import '../../models/journey_model.dart';
import '../../models/activity_model.dart';
import '../../services/journey_service.dart';
import '../../services/ai_generation_service.dart';
import '../../theme/meadow_theme.dart';
import '../../utils/constants.dart';
import 'journey_activity_detail_page.dart';
import 'activities/activity_library_screen.dart';
import 'level_detail_screen.dart';
import '../../services/growth_messaging_service.dart';
import 'widgets/growth_encouragement_card.dart';
import '../../widgets/activity_origin_badge.dart';
import '../../widgets/specialist_contextual_action.dart';

class JourneyViewScreen extends StatefulWidget {
  final ChildModel activeChild;
  final String? title;
  final List<Widget>? headerWidgets;
  final JourneyProgress? initialJourneyProgress;
  final JourneyService? journeyService;
  final GrowthMessagingService? growthMessagingService;
  final GrowthMessage? initialGrowthMessage;

  const JourneyViewScreen({
    super.key,
    required this.activeChild,
    this.title,
    this.headerWidgets,
    this.initialJourneyProgress,
    this.journeyService,
    this.growthMessagingService,
    this.initialGrowthMessage,
  });

  @override
  State<JourneyViewScreen> createState() => _JourneyViewScreenState();
}

class _JourneyViewScreenState extends State<JourneyViewScreen> {
  late final JourneyService _journeyService = widget.journeyService ?? JourneyService();
  final AIGenerationService _aiGenService = AIGenerationService();

  bool _isInitializing = true;
  bool _isGeneratingAI = false;
  JourneyProgress? _journeyProgress;
  Map<String, dynamic>? _recommendedPractice;
  final ScrollController _scrollController = ScrollController();

  static const List<Map<String, dynamic>> _domainConfigs = [
    {
      'key': 'cognitive',
      'label': 'Cognitive',
      'icon': '🧩',
      'color': MeadowColors.cognitive,
      'surface': MeadowColors.cognitiveSurface,
      'description': 'Thinking, reasoning, problem solving, and memory skills.',
    },
    {
      'key': 'language',
      'label': 'Language',
      'icon': '🗣️',
      'color': MeadowColors.language,
      'surface': MeadowColors.languageSurface,
      'description': 'Vocabulary, expression, listening, and storytelling comprehension.',
    },
    {
      'key': 'motor',
      'label': 'Motor',
      'icon': '🏃',
      'color': MeadowColors.motor,
      'surface': MeadowColors.motorSurface,
      'description': 'Gross and fine motor coordination, balance, and physical agility.',
    },
    {
      'key': 'social',
      'label': 'Social',
      'icon': '🤝',
      'color': MeadowColors.social,
      'surface': MeadowColors.socialSurface,
      'description': 'Interaction, sharing, empathy, and collaborative play with others.',
    },
    {
      'key': 'emotional',
      'label': 'Emotional',
      'icon': '💛',
      'color': MeadowColors.emotional,
      'surface': MeadowColors.emotionalSurface,
      'description': 'Self-regulation, emotional awareness, and confidence building.',
    },
    {
      'key': 'creative',
      'label': 'Creative',
      'icon': '🎨',
      'color': MeadowColors.creative,
      'surface': MeadowColors.creativeSurface,
      'description': 'Imagination, artistic expression, music, and exploratory play.',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialJourneyProgress != null) {
      _journeyProgress = widget.initialJourneyProgress;
      _isInitializing = false;
    } else {
      _initJourney();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initJourney() async {
    if (widget.initialJourneyProgress != null) {
      if (mounted) {
        setState(() {
          _journeyProgress = widget.initialJourneyProgress;
          _isInitializing = false;
        });
      }
      return;
    }

    setState(() => _isInitializing = true);
    try {
      final journey = await _journeyService.getOrInitializeJourney(
        widget.activeChild.childId,
        age: widget.activeChild.age,
      );

      final rec = await _journeyService.getRecommendedPracticeActivity(
        childId: widget.activeChild.childId,
        childAge: widget.activeChild.age,
        level: journey.currentLevel,
      );

      if (mounted) {
        setState(() {
          _journeyProgress = journey;
          _recommendedPractice = rec;
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

  bool _isNavigating = false;

  Future<void> _handleActivityTap({
    required BuildContext context,
    required JourneyProgress journey,
    required ActivityModel activity,
    required int level,
    required bool isUnlocked,
  }) async {
    if (_isNavigating) return;

    if (!isUnlocked) {
      _showLockedLevelGuidance(context, level, journey);
      return;
    }

    final actId = (activity.id != null && activity.id!.isNotEmpty)
        ? activity.id!
        : 'act_${activity.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final safeActivity = (activity.id == null || activity.id!.isEmpty)
        ? activity.copyWith(id: actId)
        : activity;

    setState(() => _isNavigating = true);

    try {
      // Record starting activity in background without blocking UI navigation
      _journeyService.startActivity(
        childId: widget.activeChild.childId,
        activityId: actId,
        activityTitle: safeActivity.title,
        level: level,
      ).catchError((e) {
        debugPrint('Note: starting activity logged with error: $e');
        return false;
      });

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyActivityDetailPage(
            activityId: actId,
            childId: widget.activeChild.childId,
            initialActivity: safeActivity,
            onActivityCompleted: () {
              _initJourney();
            },
          ),
        ),
      );

      if (mounted) {
        _initJourney();
      }
    } catch (e) {
      debugPrint('Error navigating to activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open this activity: $e. You can explore the library.'),
            action: SnackBarAction(
              label: 'Library',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ActivityLibraryScreen(child: widget.activeChild)),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  void _showLockedLevelGuidance(BuildContext context, int level, JourneyProgress journey) {
    final curLevel = journey.currentLevel;
    final masteredCount = journey.masteredDomainCount;
    final pendingDomains = journey.pendingDomainKeys;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_clock_rounded, color: AppColors.warning, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Level $level is Locked', style: MeadowTypography.h2),
                        Text('Mastery required in Level $curLevel', style: MeadowTypography.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your child has mastered $masteredCount of 6 domains in Level $curLevel. Each domain requires a 70% mastery score before unlocking Level $level.',
                style: MeadowTypography.bodyLarge.copyWith(color: MeadowColors.textSecondary),
              ),
              if (pendingDomains.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Remaining domains to practice:', style: MeadowTypography.label),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: pendingDomains.map((d) {
                    final cfg = _domainConfigs.firstWhere(
                      (c) => c['key'] == d,
                      orElse: () => {'label': d, 'icon': '🎯'},
                    );
                    return Chip(
                      avatar: Text(cfg['icon'] ?? '🎯'),
                      label: Text(cfg['label'] ?? d),
                      backgroundColor: MeadowColors.creamDark,
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _scrollToRecommendations();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continue Learning in Level 1'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeadowColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollToRecommendations() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        320.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _generateAndStartAIActivity(String domainKey) async {
    if (_isGeneratingAI) return;
    setState(() => _isGeneratingAI = true);

    try {
      final act = await _aiGenService.generateActivity(
        skillDomain: domainKey,
        difficulty: 'Easy',
        ageYears: widget.activeChild.age,
        childName: widget.activeChild.name,
      );

      // Save generated activity to Firestore activities collection
      final docRef = await FirebaseFirestore.instance.collection('activities').add(act.toMap());
      final activityId = docRef.id;

      if (!mounted) return;
      setState(() => _isGeneratingAI = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyActivityDetailPage(
            activityId: activityId,
            childId: widget.activeChild.childId,
            initialActivity: act,
            onActivityCompleted: () => _initJourney(),
          ),
        ),
      ).then((_) => _initJourney());
    } catch (e) {
      debugPrint('Error generating AI practice activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate activity right now: $e. You can choose one from the library!'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAI = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: AppBar(
        title: Text(widget.title ?? 'Growth Journey', style: MeadowTypography.h2),
        backgroundColor: MeadowColors.surface,
        foregroundColor: MeadowColors.textPrimary,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Progress',
            onPressed: _initJourney,
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator(color: MeadowColors.primary))
          : RefreshIndicator(
              color: MeadowColors.primary,
              onRefresh: _initJourney,
              child: StreamBuilder<JourneyProgress?>(
                stream: widget.initialJourneyProgress != null
                    ? Stream.value(widget.initialJourneyProgress)
                    : _journeyService.getJourneyProgress(widget.activeChild.childId),
                builder: (context, snapshot) {
                  final journey = snapshot.data ?? _journeyProgress;

                  if (journey == null) {
                    return const Center(child: CircularProgressIndicator(color: MeadowColors.primary));
                  }

                  return SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Widgets (Banner & Score Preview from GrowthTab)
                        if (widget.headerWidgets != null) ...widget.headerWidgets!,

                        // Section F: Celebration Banner if Level 1 is fully Mastered
                        if (journey.isLevelUnlocked(2) && journey.currentLevel >= 2)
                          _buildLevelCompleteCelebration(journey),

                        // Section A: Level Progress Card
                        _buildLevelProgressCard(journey),
                        const SizedBox(height: AppSpacing.lg),

                        // Empathetic Banner when all activities completed but mastery pending
                        if (journey.completedActivities.length >= 6 &&
                            (!journey.isLevelUnlocked(2) || !(journey.currentLevelProgress?.isCompleted ?? false))) ...[
                          _buildAllActivitiesCompletedMasteryPendingBanner(journey),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // AI-Powered Personalized Encouragement Guidance Card
                        GrowthEncouragementCard(
                          child: widget.activeChild,
                          journey: journey,
                          recommendation: _recommendedPractice,
                          messagingService: widget.growthMessagingService,
                          initialMessage: widget.initialGrowthMessage,
                          onActionTap: () {
                            if (_isNavigating) return;
                            final recAct = _recommendedPractice?['activity'] as ActivityModel?;
                            if (recAct != null) {
                              _handleActivityTap(
                                context: context,
                                journey: journey,
                                activity: recAct,
                                level: journey.currentLevel,
                                isUnlocked: true,
                              );
                            } else if (journey.isLevelUnlocked(2) && journey.currentLevel >= 2) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LevelDetailScreen(
                                    activeChild: widget.activeChild,
                                    level: 2,
                                  ),
                                ),
                              ).then((_) => _initJourney());
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LevelDetailScreen(
                                    activeChild: widget.activeChild,
                                    level: journey.currentLevel,
                                  ),
                                ),
                              ).then((_) => _initJourney());
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Section C: Next-Step Practice Recommendation (if Level 1 not yet mastered)
                        if (!journey.isLevelUnlocked(2) || journey.currentLevel == 1)
                          _buildNextStepRecommendation(journey),

                        const SizedBox(height: AppSpacing.lg),

                        // Section B: Six Developmental Domains
                        _buildDomainsSection(journey),
                        const SizedBox(height: AppSpacing.xl),

                        // Section D & E: Level Sections (Level 1 to Level 4)
                        ...JourneyLevelConfig.defaultLevels.map((lvlConfig) {
                          return _buildLevelSection(context, journey, lvlConfig);
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  // =========================================================================
  // SECTION A: LEVEL PROGRESS CARD
  // =========================================================================

  Widget _buildLevelProgressCard(JourneyProgress journey) {
    final currentLevelConfig = JourneyLevelConfig.defaultLevels.firstWhere(
      (l) => l.level == journey.currentLevel,
      orElse: () => JourneyLevelConfig.defaultLevels.first,
    );

    final lvlProg = journey.currentLevelProgress ?? LevelProgress(completed: []);
    final masteredCount = lvlProg.masteredDomainCount;
    final totalDomains = lvlProg.totalDomains;
    final progressFraction = lvlProg.progressFraction;
    final progressPercent = lvlProg.progressPercent;

    final completedActivitiesCount = journey.completedActivities.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MeadowColors.primary, Color(0xFF2E462E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        boxShadow: const [
          BoxShadow(
            color: MeadowColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🗺️', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.activeChild.name}\'s Learning Journey',
                      style: MeadowTypography.h2.copyWith(color: Colors.white),
                    ),
                    Text(
                      currentLevelConfig.title,
                      style: MeadowTypography.caption.copyWith(color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: lvlProg.isCompleted ? MeadowColors.gold : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  lvlProg.isCompleted ? 'MASTERED 🏆' : 'IN PROGRESS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: lvlProg.isCompleted ? MeadowColors.primaryDark : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Separate Activity Completion from Domain Mastery
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'ACTIVITIES DONE',
                  value: '$completedActivitiesCount Completed',
                  caption: 'Learning through play',
                ),
              ),
              Container(width: 1, height: 42, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: 'DOMAINS MASTERED',
                  value: '$masteredCount of $totalDomains',
                  caption: '70%+ mastery required',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Domain Mastery Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level Progression ($masteredCount/$totalDomains Domains Mastered)',
                    style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$progressPercent%',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressFraction,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(MeadowColors.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: MeadowColors.goldLight, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lvlProg.isCompleted
                        ? 'All 6 domains mastered! Level 2 is unlocked.'
                        : 'To unlock Level 2, your child must achieve 70% mastery across all 6 core domains.',
                    style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllActivitiesCompletedMasteryPendingBanner(JourneyProgress journey) {
    final curLevel = journey.currentLevel;
    final nextLevel = curLevel + 1;
    final lvlProg = journey.currentLevelProgress ?? LevelProgress(completed: []);
    final masteredCount = lvlProg.masteredDomainCount;
    final totalDomains = lvlProg.totalDomains;
    final pendingDomains = journey.pendingDomainKeys;
    final completedCount = journey.completedActivities.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MeadowColors.creamDark,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: MeadowColors.gold, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: MeadowColors.shadowSoft,
            blurRadius: 8,
            offset: Offset(0, 2),
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
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: MeadowColors.goldSurface,
                  shape: BoxShape.circle,
                ),
                child: const Text('🌱', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Activities Completed!',
                      style: MeadowTypography.h3.copyWith(color: MeadowColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🌱 Great job completing all your activities! You\'re making progress. To unlock Level $nextLevel, let\'s practise a few activities again and build your skills. You\'re getting closer!',
                      style: MeadowTypography.body.copyWith(
                        color: MeadowColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: MeadowColors.border),
          const SizedBox(height: AppSpacing.sm),
          // Distinction between Completed and Mastered
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MeadowColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: MeadowColors.success),
                          const SizedBox(width: 4),
                          Text('COMPLETED', style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$completedCount Activities Done',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: MeadowColors.textPrimary),
                      ),
                      Text('Completed learning exercises', style: MeadowTypography.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MeadowColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, size: 14, color: MeadowColors.gold),
                          const SizedBox(width: 4),
                          Text('MASTERED', style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$masteredCount of $totalDomains Domains',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: MeadowColors.textPrimary),
                      ),
                      Text('Requires 70%+ domain score', style: MeadowTypography.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (pendingDomains.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Focus on these domains for additional practice to reach 70%:',
              style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pendingDomains.map((d) {
                final cfg = _domainConfigs.firstWhere(
                  (c) => c['key'] == d,
                  orElse: () => {'label': d, 'icon': '🎯'},
                );
                final dp = lvlProg.domains[d];
                final score = dp?.score.round() ?? 0;
                return Chip(
                  avatar: Text(cfg['icon'] ?? '🎯', style: const TextStyle(fontSize: 12)),
                  label: Text('${cfg['label'] ?? d} ($score% / 70%)', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _scrollToRecommendations(),
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Practise Activities Needing Improvement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MeadowColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required String caption}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.75),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          caption,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  // =========================================================================
  // SECTION B: SIX DEVELOPMENTAL DOMAINS
  // =========================================================================

  Widget _buildDomainsSection(JourneyProgress journey) {
    final domains = journey.currentLevelDomains;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Developmental Domains', style: MeadowTypography.h2),
                  Text('Tap any domain to view skills & targeted practice', style: MeadowTypography.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MeadowColors.sageLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Goal: 70% Mastery',
                style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _domainConfigs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final config = _domainConfigs[index];
            final key = config['key'] as String;
            final domainProg = domains[key] ??
                DomainProgress(domain: key, score: 0.0, isCompleted: false, activitiesDone: 0);

            return _buildDomainCard(config, domainProg);
          },
        ),
      ],
    );
  }

  Widget _buildDomainCard(Map<String, dynamic> config, DomainProgress prog) {
    final Color domainColor = config['color'] as Color;
    final Color domainSurface = config['surface'] as Color;
    final isMastered = prog.isMastered;
    final score = prog.score;
    final scoreFraction = (score / 100.0).clamp(0.0, 1.0);

    Color badgeColor;
    Color badgeTextColor;
    String badgeText;

    if (isMastered) {
      badgeColor = MeadowColors.success.withOpacity(0.18);
      badgeTextColor = MeadowColors.primaryDark;
      badgeText = 'Mastered 🟢';
    } else if (prog.activitiesDone > 0 && score < 70) {
      badgeColor = MeadowColors.goldSurface;
      badgeTextColor = const Color(0xFFB37400);
      badgeText = 'Practice 🟡';
    } else if (score > 0 || prog.activitiesDone > 0) {
      badgeColor = domainSurface;
      badgeTextColor = domainColor;
      badgeText = 'In Progress 🔵';
    } else {
      badgeColor = Colors.grey.shade200;
      badgeTextColor = Colors.grey.shade600;
      badgeText = 'Not Started';
    }

    return InkWell(
      onTap: () => _showDomainDetailSheet(config, prog),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMastered ? MeadowColors.success.withOpacity(0.5) : MeadowColors.border,
            width: isMastered ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: MeadowColors.shadowSoft,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(config['icon'] as String, style: const TextStyle(fontSize: 22)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config['label'] as String,
                  style: MeadowTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${prog.activitiesDone} activities done',
                  style: MeadowTypography.caption.copyWith(fontSize: 10),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Score: ${score.round()}/100',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: domainColor),
                    ),
                    Text(
                      isMastered ? 'Goal Met ✅' : 'Need 70%',
                      style: TextStyle(
                        fontSize: 9,
                        color: isMastered ? MeadowColors.success : MeadowColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: scoreFraction,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isMastered ? MeadowColors.success : domainColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDomainDetailSheet(Map<String, dynamic> config, DomainProgress prog) {
    final key = config['key'] as String;
    final label = config['label'] as String;
    final icon = config['icon'] as String;
    final isMastered = prog.isMastered;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (config['surface'] as Color),
                      shape: BoxShape.circle,
                    ),
                    child: Text(icon, style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$label Domain', style: MeadowTypography.h2),
                        Text(config['description'] as String, style: MeadowTypography.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MeadowColors.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MeadowColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Mastery Score', style: MeadowTypography.body),
                        Text(
                          '${prog.score.round()} / 100',
                          style: MeadowTypography.h3.copyWith(
                            color: isMastered ? MeadowColors.success : (config['color'] as Color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (prog.score / 100.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMastered ? MeadowColors.success : (config['color'] as Color),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status: ${prog.status}', style: MeadowTypography.caption),
                        Text('Threshold: 70%', style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Browse Library'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _generateAndStartAIActivity(key);
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate AI Activity'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeadowColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // SECTION C: CLEAR NEXT-STEP RECOMMENDATION
  // =========================================================================

  Widget _buildNextStepRecommendation(JourneyProgress journey) {
    final rec = _recommendedPractice;
    final activity = rec?['activity'] as ActivityModel?;
    // Authoritative domain: use activity.skillType if available, ensuring 100% domain alignment
    final domain = (activity != null && activity.skillType.isNotEmpty)
        ? activity.skillType.trim().toLowerCase()
        : (rec?['domain'] ?? rec?['targetDomain'] ?? 'cognitive').toString().trim().toLowerCase();
    final reason = rec?['reason']?.toString() ?? rec?['rationale']?.toString() ??
        'Targeted practice in this domain will reinforce skills toward reaching the 70% threshold.';

    final domainConfig = _domainConfigs.firstWhere(
      (c) => c['key'].toString().toLowerCase() == domain.toLowerCase(),
      orElse: () => _domainConfigs.first,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MeadowColors.goldSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('🌟', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recommended Next Practice', style: MeadowTypography.h3),
                    Text(
                      'Every child learns at their own pace. Let\'s practise together!',
                      style: MeadowTypography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            reason,
            style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          if (activity != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (domainConfig['surface'] as Color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(domainConfig['icon'] as String, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activity.title,
                                style: MeadowTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ActivityOriginBadge(activity: activity, compact: true),
                          ],
                        ),
                        Text(
                          '${activity.duration} min • ${activity.difficulty} • ${domainConfig['label']}',
                          style: MeadowTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Specialist support for LLG-recommended practice
            SpecialistContextualAction(
              childId: widget.activeChild.childId,
              activity: activity,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: activity != null
                      ? () => _handleActivityTap(
                            context: context,
                            journey: journey,
                            activity: activity,
                            level: journey.currentLevel,
                            isUnlocked: true,
                          )
                      : () => _generateAndStartAIActivity(domain),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(activity != null ? 'Start Practice' : 'Generate Activity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeadowColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Explore Library'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.auto_awesome, color: MeadowColors.primary),
                tooltip: 'Generate AI Activity for this domain',
                onPressed: () => _generateAndStartAIActivity(domain),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION F: LEVEL UNLOCKED CELEBRATION
  // =========================================================================

  Widget _buildLevelCompleteCelebration(JourneyProgress journey) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MeadowColors.goldSurface,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
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
                Text('Level 1 Mastered! 🎉', style: MeadowTypography.h3),
                Text(
                  'Your child reached 70% in all 6 domains. Level 2 is unlocked!',
                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECTION D & E: LEVEL SECTIONS & LEVEL 2 LOCKED STATE
  // =========================================================================

  Widget _buildLevelSection(
    BuildContext context,
    JourneyProgress journey,
    JourneyLevelConfig lvlConfig,
  ) {
    final int level = lvlConfig.level;
    final bool isUnlocked = journey.isLevelUnlocked(level);
    final lvlProg = journey.levelProgress[level] ?? LevelProgress(completed: []);
    final isCurrentLevel = journey.currentLevel == level;

    // Redesigned Level 2 Locked Card
    if (!isUnlocked) {
      return _buildLockedLevelCard(context, lvlConfig, journey);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: isCurrentLevel ? MeadowColors.primary : MeadowColors.border,
          width: isCurrentLevel ? 2.0 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: MeadowColors.shadowSoft,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level Title Header Bar (Tappable to open Workspace)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LevelDetailScreen(
                    activeChild: widget.activeChild,
                    level: level,
                    journeyService: _journeyService,
                  ),
                ),
              ).then((_) => _initJourney());
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppBorderRadius.medium),
              topRight: Radius.circular(AppBorderRadius.medium),
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isCurrentLevel ? MeadowColors.primarySurface : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppBorderRadius.medium),
                  topRight: Radius.circular(AppBorderRadius.medium),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    lvlProg.isCompleted ? Icons.verified : Icons.lock_open_rounded,
                    color: lvlProg.isCompleted ? MeadowColors.success : MeadowColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                lvlConfig.title,
                                style: MeadowTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrentLevel) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MeadowColors.primary,
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
                          lvlConfig.description,
                          style: MeadowTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${lvlProg.masteredDomainCount}/6 Mastered',
                        style: MeadowTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: lvlProg.isCompleted ? MeadowColors.success : MeadowColors.primary,
                        ),
                      ),
                      if (level == 1 && journey.completedActivities.length >= 6 && !lvlProg.isCompleted)
                        Text(
                          '6/6 Completed · Practice needed',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: MeadowColors.textTertiary),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: MeadowColors.border),

          // Activities List for Level
          FutureBuilder<List<ActivityModel>>(
            future: lvlProg.activityIds.isNotEmpty
                ? _journeyService.getActivitiesForLevel(lvlProg.activityIds)
                : (widget.initialJourneyProgress != null
                    ? Future.value(<ActivityModel>[])
                    : _journeyService.getActivitiesForLevelConfig(lvlConfig, age: widget.activeChild.age)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator(color: MeadowColors.primary)),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Activities ready to load',
                    style: MeadowTypography.caption,
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: MeadowColors.borderLight),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  final isCompleted = journey.isActivityCompleted(activity.id ?? '');
                  final isActive = journey.activeActivity?.activityId == activity.id &&
                      journey.activeActivity?.isInProgress == true;
                  final domainKey = activity.skillType.toLowerCase();
                  final dp = lvlProg.domains[domainKey];
                  final isDomainMastered = (dp?.isMastered ?? false) || (dp != null && dp.score >= 70.0);
                  final domainScore = dp?.score.round() ?? 0;

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? (isDomainMastered
                                ? MeadowColors.success.withOpacity(0.15)
                                : Colors.amber.withOpacity(0.2))
                            : isActive
                                ? Colors.orange.withOpacity(0.15)
                                : MeadowColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          isCompleted
                              ? (isDomainMastered ? '✅' : '🔄')
                              : isActive
                                  ? '⏳'
                                  : '🔓',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MeadowColors.primarySurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            activity.skillType,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: MeadowColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ActivityOriginBadge(activity: activity, compact: true),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            activity.title,
                            style: MeadowTypography.bodyLarge.copyWith(
                              fontWeight: isCompleted || isActive ? FontWeight.bold : FontWeight.w500,
                              color: isCompleted ? MeadowColors.textSecondary : MeadowColors.textPrimary,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      isCompleted
                          ? (isDomainMastered
                              ? 'Completed · Mastered 🏆 ($domainScore%) · Tap to replay'
                              : 'Completed · Practice Recommended ($domainScore% / 70% goal) · Tap to practise')
                          : isActive
                              ? 'In progress · Tap to resume'
                              : '${activity.duration} min • ${activity.difficulty}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted
                            ? (isDomainMastered ? MeadowColors.success : const Color(0xFFB37400))
                            : isActive
                                ? Colors.orange.shade800
                                : MeadowColors.textSecondary,
                        fontWeight: (isActive || (isCompleted && !isDomainMastered)) ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: MeadowColors.textTertiary,
                    ),
                    onTap: () {
                      _handleActivityTap(
                        context: context,
                        journey: journey,
                        activity: activity,
                        level: level,
                        isUnlocked: true,
                      );
                    },
                  ),
                );
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LevelDetailScreen(
                        activeChild: widget.activeChild,
                        level: level,
                        journeyService: _journeyService,
                      ),
                    ),
                  ).then((_) => _initJourney());
                },
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text('Open Level $level Learning Workspace →'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MeadowColors.primary,
                  side: const BorderSide(color: MeadowColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Redesigned Locked Level Card that informs and guides rather than blocking
  Widget _buildLockedLevelCard(
    BuildContext context,
    JourneyLevelConfig lvlConfig,
    JourneyProgress journey,
  ) {
    final masteredCount = journey.masteredDomainCount;
    final pendingKeys = journey.pendingDomainKeys;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lvlConfig.title,
                      style: MeadowTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      lvlConfig.description,
                      style: MeadowTypography.caption.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MeadowColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MeadowColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Unlock Requirement: Level ${lvlConfig.level - 1} Mastery',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$masteredCount of 6 Mastered',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: MeadowColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  journey.completedActivities.length >= 6
                      ? '🌱 Great job completing all your activities! You\'re making progress. To unlock Level ${lvlConfig.level}, let\'s practise a few activities again and build your skills. You\'re getting closer!'
                      : 'Your child is making progress! Reach 70% mastery in each core domain to unlock Level ${lvlConfig.level}.',
                  style: MeadowTypography.caption.copyWith(
                    color: journey.completedActivities.length >= 6 ? MeadowColors.textPrimary : MeadowColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (pendingKeys.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: pendingKeys.map((k) {
                      final dp = journey.currentLevelDomains[k];
                      final score = dp?.score.round() ?? 0;
                      return Chip(
                        label: Text(
                          '${k[0].toUpperCase()}${k.substring(1)} ($score% / 70%)',
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (journey.completedActivities.length >= 6) {
                  _scrollToRecommendations();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LevelDetailScreen(
                        activeChild: widget.activeChild,
                        level: journey.currentLevel,
                        initialJourneyProgress: journey,
                      ),
                    ),
                  ).then((_) => _initJourney());
                }
              },
              icon: Icon(
                journey.completedActivities.length >= 6
                    ? Icons.play_circle_outline_rounded
                    : Icons.school_outlined,
                size: 18,
              ),
              label: Text(
                journey.completedActivities.length >= 6
                    ? 'Practise Activities to Unlock Level ${lvlConfig.level}'
                    : 'Continue Learning in Level ${journey.currentLevel}',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: MeadowColors.primary,
                side: const BorderSide(color: MeadowColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
