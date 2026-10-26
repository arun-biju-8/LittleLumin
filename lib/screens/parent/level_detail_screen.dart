import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/activity_model.dart';
import '../../models/child_model.dart';
import '../../models/journey_model.dart';
import '../../services/journey_service.dart';
import '../../services/ai_generation_service.dart';
import '../../theme/meadow_theme.dart';
import 'journey_activity_detail_page.dart';
import 'activities/activity_library_screen.dart';
import '../../services/growth_messaging_service.dart';
import 'widgets/growth_encouragement_card.dart';
import '../../widgets/activity_origin_badge.dart';
import '../../widgets/specialist_contextual_action.dart';

class LevelDetailScreen extends StatefulWidget {
  final ChildModel activeChild;
  final int level;
  final JourneyProgress? initialJourneyProgress;
  final List<ActivityModel>? initialActivities;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? scoreEventsStream;
  final JourneyService? journeyService;
  final GrowthMessagingService? growthMessagingService;
  final GrowthMessage? initialGrowthMessage;

  const LevelDetailScreen({
    super.key,
    required this.activeChild,
    this.level = 1,
    this.initialJourneyProgress,
    this.initialActivities,
    this.scoreEventsStream,
    this.journeyService,
    this.growthMessagingService,
    this.initialGrowthMessage,
  });

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> with SingleTickerProviderStateMixin {
  late final JourneyService _journeyService;
  final AIGenerationService _aiGenService = AIGenerationService();
  JourneyProgress? _journeyProgress;
  Map<String, dynamic>? _recommendation;
  bool _isLoading = true;
  bool _isGeneratingAI = false;
  late TabController _tabController;

  static const List<Map<String, String>> _domainMeta = [
    {'key': 'cognitive', 'label': 'Cognitive', 'icon': '🧩'},
    {'key': 'language', 'label': 'Language', 'icon': '🗣️'},
    {'key': 'motor', 'label': 'Motor Skills', 'icon': '🏃'},
    {'key': 'social', 'label': 'Social', 'icon': '👥'},
    {'key': 'emotional', 'label': 'Emotional', 'icon': '❤️'},
    {'key': 'creative', 'label': 'Creative', 'icon': '🎨'},
  ];

  @override
  void initState() {
    super.initState();
    _journeyService = widget.journeyService ?? JourneyService();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialJourneyProgress != null) {
      _journeyProgress = widget.initialJourneyProgress;
      _isLoading = false;
      _resolveRecommendation(_journeyProgress!).then((rec) {
        if (mounted) setState(() => _recommendation = rec);
      });
    } else {
      _initData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.initialJourneyProgress != null) {
        _journeyProgress = widget.initialJourneyProgress;
      } else {
        _journeyProgress = await _journeyService.syncJourneyWithSkillProfile(widget.activeChild.childId);
      }
      if (_journeyProgress != null) {
        _recommendation = await _resolveRecommendation(_journeyProgress!);
      }
    } catch (e) {
      debugPrint('Error loading level journey: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  JourneyLevelConfig get _levelConfig {
    return JourneyLevelConfig.defaultLevels.firstWhere(
      (l) => l.level == widget.level,
      orElse: () => JourneyLevelConfig.defaultLevels.first,
    );
  }

  Future<Map<String, dynamic>?> _resolveRecommendation(JourneyProgress journey) async {
    try {
      final rec = await _journeyService.getRecommendedPracticeActivity(
        childId: widget.activeChild.childId,
        level: widget.level,
        childAge: widget.activeChild.age,
      );
      if (rec != null) {
        final act = rec['activity'] as ActivityModel?;
        // Ground truth: Use activity.skillType if available, ensuring perfect domain alignment
        final rawDomain = (act != null && act.skillType.isNotEmpty)
            ? act.skillType
            : (rec['domain'] ?? rec['targetDomain'] ?? 'cognitive');
        final domain = rawDomain.toString().trim().toLowerCase();
        final score = ((rec['score'] ?? rec['currentScore'] ?? journey.currentLevelDomains[domain]?.score ?? 0.0) as num).toDouble();
        final rationale = (rec['reason'] ?? rec['rationale'] ??
            'Recommended to build core mastery in ${MeadowDomain.labelFor(domain)}.').toString();
        return {
          'domain': domain,
          'targetDomain': domain,
          'score': score,
          'currentScore': score,
          'isMastered': journey.currentLevelDomains[domain]?.isMastered ?? false,
          'rationale': rationale,
          'reason': rationale,
          'activity': act,
        };
      }
    } catch (e) {
      debugPrint('Fallback recommendation: $e');
    }

    final lowest = journey.lowestScoringPendingDomain;
    final domain = (lowest?.domain ?? 'cognitive').toLowerCase();
    final score = lowest?.score ?? 0.0;
    final rationale = 'Recommended because ${MeadowDomain.labelFor(domain)} is currently at ${score.round()}%, below the 70% threshold.';
    final defaultAct = ActivityModel(
      id: 'rec_${domain}_default',
      title: 'Fun with ${MeadowDomain.labelFor(domain)}',
      shortDescription: 'Build core developmental strength in ${MeadowDomain.labelFor(domain)}.',
      skillType: MeadowDomain.labelFor(domain),
      difficulty: 'Easy',
      ageGroup: [3, 4, 5],
      duration: 15,
      instructions: ['Engage in guided play to build mastery.'],
      learningGoals: ['Reach 70% threshold in ${MeadowDomain.labelFor(domain)}'],
      materials: ['Everyday objects'],
      createdBy: 'system',
      createdByName: 'LittleLumin',
      category: domain,
      tags: [domain, 'practice'],
      createdAt: DateTime.now(),
    );

    return {
      'domain': domain,
      'targetDomain': domain,
      'score': score,
      'currentScore': score,
      'isMastered': lowest?.isMastered ?? false,
      'rationale': rationale,
      'reason': rationale,
      'activity': defaultAct,
    };
  }

  Future<List<ActivityModel>> _resolveLevelActivities(LevelProgress lvlProg) async {
    if (widget.initialActivities != null) return widget.initialActivities!;
    if (lvlProg.activityIds.isNotEmpty) {
      try {
        return await _journeyService.getActivitiesForLevel(lvlProg.activityIds);
      } catch (_) {
        return [];
      }
    }
    try {
      return await _journeyService.getActivitiesForLevelConfig(_levelConfig, age: widget.activeChild.age);
    } catch (_) {
      return [];
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _resolveScoreEventsStream() {
    if (widget.scoreEventsStream != null) return widget.scoreEventsStream!;
    try {
      return FirebaseFirestore.instance
          .collection('scoreEvents')
          .where('childId', isEqualTo: widget.activeChild.childId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  bool _isNavigating = false;

  Future<void> _handleStartActivity(ActivityModel activity) async {
    if (_isNavigating) return;

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
        level: widget.level,
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
            onActivityCompleted: _initData,
          ),
        ),
      );

      if (mounted) {
        _initData();
      }
    } catch (e) {
      debugPrint('Error starting activity: $e');
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Future<void> _generateAndStartAIActivity(String domain) async {
    if (_isGeneratingAI) return;
    setState(() => _isGeneratingAI = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Generating custom ${MeadowDomain.labelFor(domain)} practice...'),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: MeadowColors.primary,
        ),
      );

      final act = await _aiGenService.generateActivity(
        skillDomain: domain,
        difficulty: widget.level == 1 ? 'easy' : 'medium',
        ageYears: widget.activeChild.age,
        childName: widget.activeChild.name,
      );

      final docRef = await FirebaseFirestore.instance.collection('activities').add(act.toMap());
      final activityId = docRef.id;

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() => _isGeneratingAI = false);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyActivityDetailPage(
            activityId: activityId,
            childId: widget.activeChild.childId,
            initialActivity: act,
            onActivityCompleted: _initData,
          ),
        ),
      );

      _initData();
    } catch (e) {
      debugPrint('Error generating targeted AI activity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => _isGeneratingAI = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate right now ($e). Choose an activity from the library!'),
            backgroundColor: MeadowColors.warning,
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
    final journey = _journeyProgress ?? widget.initialJourneyProgress;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: MeadowColors.cream,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to Growth Journey',
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          title: Text(
            'Level ${widget.level} Workspace',
            style: MeadowTypography.h2,
          ),
          backgroundColor: MeadowColors.surface,
          foregroundColor: MeadowColors.textPrimary,
          elevation: 0.5,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Level Data',
              onPressed: _initData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: MeadowColors.primary,
            unselectedLabelColor: MeadowColors.textSecondary,
            indicatorColor: MeadowColors.primary,
            indicatorWeight: 3,
            labelStyle: MeadowTypography.label.copyWith(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Overview & Goals'),
              Tab(icon: Icon(Icons.list_alt_rounded, size: 20), text: 'Activities & History'),
            ],
          ),
        ),
        body: _isLoading && journey == null
            ? const Center(child: CircularProgressIndicator(color: MeadowColors.primary))
            : journey == null
                ? _buildEmptyState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(journey),
                      _buildActivitiesTab(journey),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeadowSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, size: 56, color: MeadowColors.textTertiary),
            const SizedBox(height: MeadowSpacing.md),
            Text('No Level Data Available', style: MeadowTypography.h2),
            const SizedBox(height: MeadowSpacing.xs),
            Text(
              'We could not load progress for Level ${widget.level}. Please check your connection or try again.',
              textAlign: TextAlign.center,
              style: MeadowTypography.bodyLarge.copyWith(color: MeadowColors.textSecondary),
            ),
            const SizedBox(height: MeadowSpacing.lg),
            ElevatedButton(
              onPressed: _initData,
              style: MeadowButtons.primary(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: OVERVIEW & GOALS
  // =========================================================================

  Widget _buildOverviewTab(JourneyProgress journey) {
    return RefreshIndicator(
      color: MeadowColors.primary,
      onRefresh: _initData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MeadowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Level Overview Hero Card
            _buildLevelOverviewCard(journey),
            const SizedBox(height: MeadowSpacing.lg),

            if (journey.completedActivities.length >= 6 &&
                (!journey.isLevelUnlocked(widget.level + 1) ||
                 !(journey.levelProgress[widget.level]?.isCompleted ?? false))) ...[
              _buildAllActivitiesCompletedMasteryPendingBanner(journey),
              const SizedBox(height: MeadowSpacing.lg),
            ],

            // AI-Powered Personalized Encouragement Guidance Card
            GrowthEncouragementCard(
              child: widget.activeChild,
              journey: journey,
              recommendation: _recommendation,
              messagingService: widget.growthMessagingService,
              initialMessage: widget.initialGrowthMessage,
              onActionTap: () {
                final recAct = _recommendation?['activity'] as ActivityModel?;
                if (recAct != null) {
                  _handleStartActivity(recAct);
                } else {
                  _tabController.animateTo(1);
                }
              },
            ),
            const SizedBox(height: MeadowSpacing.lg),

            // 2. Next Learning Action (Featured Practice)
            _buildNextLearningActionCard(journey),
            const SizedBox(height: MeadowSpacing.xl),

            // 3. Six Developmental Domains Deep Dive
            _buildDomainsSection(journey),
            const SizedBox(height: MeadowSpacing.xl),

            // 4. Level Progression & Advancement Checklist
            _buildLevelProgressionChecklist(journey),
            const SizedBox(height: MeadowSpacing.xxl),
          ],
        ),
      ),
    );
  }

  // --- 1. Level Overview Card ---
  Widget _buildLevelOverviewCard(JourneyProgress journey) {
    final lvlProg = journey.levelProgress[widget.level] ?? LevelProgress(completed: []);
    final totalDomains = _domainMeta.length;
    final masteredCount = lvlProg.masteredDomainCount;
    final completedActivitiesCount = journey.completedActivities.length;
    final isMastered = lvlProg.isCompleted;

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isMastered
              ? [MeadowColors.goldSurface, Colors.white]
              : [MeadowColors.primaryDark, MeadowColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMastered ? MeadowColors.gold.withOpacity(0.2) : Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  isMastered ? '🏆' : '🌱',
                  style: const TextStyle(fontSize: 26),
                ),
              ),
              const SizedBox(width: MeadowSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _levelConfig.title,
                      style: MeadowTypography.h2.copyWith(
                        color: isMastered ? MeadowColors.textPrimary : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _levelConfig.description,
                      style: MeadowTypography.caption.copyWith(
                        color: isMastered ? MeadowColors.textSecondary : Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isMastered ? MeadowColors.gold : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(MeadowRadius.pill),
                ),
                child: Text(
                  isMastered ? 'MASTERED 🏆' : 'IN PROGRESS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isMastered ? MeadowColors.primaryDark : Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.lg),
          Divider(
            color: isMastered ? MeadowColors.borderLight : Colors.white24,
            height: 1,
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Core Metrics: Completed Activities vs. Domains Mastered
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVITIES COMPLETED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isMastered ? MeadowColors.textTertiary : Colors.white70,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedActivitiesCount Completed',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isMastered ? MeadowColors.textPrimary : Colors.white,
                      ),
                    ),
                    Text(
                      'Unique learning attempts',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMastered ? MeadowColors.textSecondary : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isMastered ? MeadowColors.borderLight : Colors.white24,
              ),
              const SizedBox(width: MeadowSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DOMAINS MASTERED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isMastered ? MeadowColors.textTertiary : Colors.white70,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$masteredCount of $totalDomains Mastered',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isMastered ? MeadowColors.textPrimary : Colors.white,
                      ),
                    ),
                    Text(
                      'Requires 70%+ score',
                      style: TextStyle(
                        fontSize: 10,
                        color: isMastered ? MeadowColors.textSecondary : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.md),

          // Unlock Requirement Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isMastered ? Colors.white : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(MeadowRadius.md),
              border: Border.all(
                color: isMastered ? MeadowColors.goldLight : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isMastered ? Icons.check_circle : Icons.lock_outline,
                  color: isMastered ? MeadowColors.success : MeadowColors.goldLight,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isMastered
                        ? 'All 6 domains mastered! Level ${widget.level + 1} is now unlocked.'
                        : 'Unlock Requirement: Achieve 70% mastery in all 6 core domains ($masteredCount of 6 achieved).',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isMastered ? MeadowColors.textPrimary : Colors.white,
                    ),
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
    final curLevel = widget.level;
    final nextLevel = curLevel + 1;
    final lvlProg = journey.levelProgress[widget.level] ?? LevelProgress(completed: []);
    final masteredCount = lvlProg.masteredDomainCount;
    final totalDomains = _domainMeta.length;
    final pendingKeys = journey.pendingDomainKeys;
    final completedCount = journey.completedActivities.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.creamDark,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.gold, width: 1.5),
        boxShadow: MeadowShadows.card,
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
          const SizedBox(height: MeadowSpacing.md),
          const Divider(height: 1, color: MeadowColors.border),
          const SizedBox(height: MeadowSpacing.sm),
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
                      Text('Finished all exercises', style: MeadowTypography.caption.copyWith(fontSize: 10)),
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
                      Text('Requires 70%+ score', style: MeadowTypography.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (pendingKeys.isNotEmpty) ...[
            const SizedBox(height: MeadowSpacing.sm),
            Text(
              'Focus on these domains for additional practice to reach 70%:',
              style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: pendingKeys.map((k) {
                final dp = lvlProg.domains[k];
                final score = dp?.score.round() ?? 0;
                return Chip(
                  label: Text('${MeadowDomain.labelFor(k)} ($score% / 70%)', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: MeadowSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _tabController.animateTo(1);
              },
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

  // --- 2. Next Learning Action ---
  Widget _buildNextLearningActionCard(JourneyProgress journey) {
    final rec = _recommendation;
    if (rec == null) {
      if (_isLoading) {
        return Container(
          height: 140,
          padding: const EdgeInsets.all(MeadowSpacing.lg),
          decoration: BoxDecoration(
            color: MeadowColors.surface,
            borderRadius: BorderRadius.circular(MeadowRadius.xl),
            border: Border.all(color: MeadowColors.borderLight),
          ),
          child: const Center(child: CircularProgressIndicator(color: MeadowColors.primary)),
        );
      }
      return const SizedBox.shrink();
    }

    final activity = rec['activity'] as ActivityModel?;
    // Authoritative domain: align with activity.skillType if available
    final domain = (activity != null && activity.skillType.isNotEmpty)
        ? activity.skillType.trim().toLowerCase()
        : (rec['domain'] ?? rec['targetDomain'] ?? 'cognitive').toString().trim().toLowerCase();
    final score = ((rec['score'] ?? rec['currentScore'] ?? journey.currentLevelDomains[domain]?.score ?? 0.0) as num).toDouble();
    final rationale = (rec['reason'] ?? rec['rationale'] ??
        'Recommended to build core mastery in ${MeadowDomain.labelFor(domain)}.').toString();
    final isMastered = rec['isMastered'] == true;

    final domainLabel = MeadowDomain.labelFor(domain);
    final domainColor = MeadowDomain.colorFor(domain);

        return Container(
          padding: const EdgeInsets.all(MeadowSpacing.xl),
          decoration: BoxDecoration(
            color: MeadowColors.surface,
            borderRadius: BorderRadius.circular(MeadowRadius.xl),
            border: Border.all(color: MeadowColors.primary.withOpacity(0.3), width: 1.5),
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
                        decoration: BoxDecoration(
                          color: MeadowColors.primarySurface,
                          borderRadius: BorderRadius.circular(MeadowRadius.sm),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: MeadowColors.primary, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text('RECOMMENDED PRACTICE', style: MeadowTypography.label),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: domainColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(MeadowRadius.pill),
                    ),
                    child: Text(
                      '$domainLabel · ${score.round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: domainColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MeadowSpacing.md),

              if (activity != null) ...[
                Row(
                  children: [
                    Expanded(child: Text(activity.title, style: MeadowTypography.h2)),
                    const SizedBox(width: 8),
                    ActivityOriginBadge(activity: activity, compact: true),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity.shortDescription ?? 'Guided developmental practice for $domainLabel.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                ),
                const SizedBox(height: MeadowSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: MeadowColors.textTertiary),
                    const SizedBox(width: 4),
                    Text('${activity.duration} min', style: MeadowTypography.caption),
                    const SizedBox(width: 12),
                    const Icon(Icons.bar_chart_outlined, size: 14, color: MeadowColors.textTertiary),
                    const SizedBox(width: 4),
                    Text(activity.difficulty, style: MeadowTypography.caption),
                  ],
                ),
              ] else ...[
                Text('Practice in $domainLabel', style: MeadowTypography.h2),
                const SizedBox(height: 4),
                Text(
                  'Select an activity from the library or generate a new tailored exercise below.',
                  style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                ),
              ],
              const SizedBox(height: MeadowSpacing.md),

              // Rationale Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isMastered ? MeadowColors.success.withOpacity(0.15) : MeadowColors.goldSurface,
                  borderRadius: BorderRadius.circular(MeadowRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      isMastered ? Icons.verified : Icons.lightbulb_outline,
                      size: 16,
                      color: isMastered ? MeadowColors.success : const Color(0xFFC48E2E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rationale,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMastered ? MeadowColors.primaryDark : MeadowColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (activity != null) ...[
                const SizedBox(height: MeadowSpacing.md),
                SpecialistContextualAction(
                  childId: widget.activeChild.childId,
                  activity: activity,
                ),
              ],
              const SizedBox(height: MeadowSpacing.lg),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: activity != null
                          ? () => _handleStartActivity(activity)
                          : () => _generateAndStartAIActivity(domain),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(activity != null ? 'Start Activity' : 'Generate Practice'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeadowColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MeadowRadius.md),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MeadowColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: MeadowColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(MeadowRadius.md),
                        ),
                      ),
                      child: const Text('Library'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isGeneratingAI
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: MeadowColors.primary),
                          )
                        : const Icon(Icons.auto_awesome, color: MeadowColors.primary),
                    tooltip: 'Generate AI Activity for $domainLabel',
                    onPressed: _isGeneratingAI ? null : () => _generateAndStartAIActivity(domain),
                  ),
                ],
              ),
            ],
          ),
        );
  }

  // --- 3. Six Developmental Domains ---
  Widget _buildDomainsSection(JourneyProgress journey) {
    final lvlProg = journey.levelProgress[widget.level] ?? LevelProgress(completed: []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SIX DEVELOPMENTAL DOMAINS', style: MeadowTypography.label),
            Text(
              'Goal: 70% in each',
              style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: MeadowSpacing.md),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _domainMeta.length,
          separatorBuilder: (context, index) => const SizedBox(height: MeadowSpacing.sm),
          itemBuilder: (context, index) {
            final meta = _domainMeta[index];
            final key = meta['key']!;
            final dp = lvlProg.domains[key] ??
                DomainProgress(domain: key, score: 0.0, isCompleted: false, activitiesDone: 0);
            final score = dp.score;
            final isMastered = dp.isMastered;
            final isAssessed = score > 0;
            final color = MeadowDomain.colorFor(key);

            return Container(
              padding: const EdgeInsets.all(MeadowSpacing.md),
              decoration: BoxDecoration(
                color: MeadowColors.surface,
                borderRadius: BorderRadius.circular(MeadowRadius.lg),
                border: Border.all(
                  color: isMastered ? MeadowColors.success.withOpacity(0.4) : MeadowColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(meta['icon'] ?? '🎯', style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: MeadowSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              meta['label']!,
                              style: MeadowTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isMastered
                                    ? MeadowColors.success.withOpacity(0.15)
                                    : isAssessed
                                        ? MeadowColors.primarySurface
                                        : MeadowColors.creamDark,
                                borderRadius: BorderRadius.circular(MeadowRadius.pill),
                              ),
                              child: Text(
                                isMastered
                                    ? 'Mastered 🏆'
                                    : isAssessed
                                        ? 'In Progress'
                                        : 'Not Started',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isMastered
                                      ? MeadowColors.success
                                      : isAssessed
                                          ? MeadowColors.primary
                                          : MeadowColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (score / 100.0).clamp(0.0, 1.0),
                                  minHeight: 6,
                                  backgroundColor: MeadowColors.creamDark,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isMastered ? MeadowColors.success : color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isAssessed ? '${score.round()}% / 70%' : 'Pending',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMastered ? MeadowColors.success : MeadowColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MeadowSpacing.sm),
                  OutlinedButton(
                    onPressed: () => _generateAndStartAIActivity(key),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      side: BorderSide(color: color.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.sm)),
                    ),
                    child: Text('Practice', style: TextStyle(fontSize: 11, color: color)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- 4. Level Progression Checklist ---
  Widget _buildLevelProgressionChecklist(JourneyProgress journey) {
    final lvlProg = journey.levelProgress[widget.level] ?? LevelProgress(completed: []);
    final totalDomains = _domainMeta.length;
    final masteredCount = lvlProg.masteredDomainCount;

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.xl),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LEVEL ADVANCEMENT CHECKLIST', style: MeadowTypography.label),
              Text(
                '$masteredCount of $totalDomains Met',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: MeadowColors.primary),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.xs),
          Text(
            'To unlock Level ${widget.level + 1}, satisfy the 70% threshold across each domain below:',
            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: MeadowSpacing.md),
          const Divider(height: 1, color: MeadowColors.borderLight),
          const SizedBox(height: MeadowSpacing.md),
          ..._domainMeta.map((meta) {
            final key = meta['key']!;
            final dp = lvlProg.domains[key];
            final score = dp?.score ?? 0.0;
            final isMastered = (dp?.isMastered ?? false) || score >= 70.0;
            final pointsRemaining = (70.0 - score).clamp(0.0, 70.0).round();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isMastered ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: isMastered ? MeadowColors.success : MeadowColors.textTertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meta['label']!,
                      style: MeadowTypography.body.copyWith(
                        fontWeight: isMastered ? FontWeight.bold : FontWeight.normal,
                        color: isMastered ? MeadowColors.textPrimary : MeadowColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    isMastered
                        ? 'Mastered (${score.round()}%)'
                        : score > 0
                            ? '${score.round()}% ($pointsRemaining pts needed)'
                            : 'Assessment pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isMastered ? FontWeight.bold : FontWeight.w500,
                      color: isMastered ? MeadowColors.success : MeadowColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: ACTIVITIES & HISTORY
  // =========================================================================

  Widget _buildActivitiesTab(JourneyProgress journey) {
    final lvlProg = journey.levelProgress[widget.level] ?? LevelProgress(completed: []);

    return RefreshIndicator(
      color: MeadowColors.primary,
      onRefresh: _initData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MeadowSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Guidance Header
            Container(
              padding: const EdgeInsets.all(MeadowSpacing.md),
              decoration: BoxDecoration(
                color: MeadowColors.surface,
                borderRadius: BorderRadius.circular(MeadowRadius.lg),
                border: Border.all(color: MeadowColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: MeadowColors.primary, size: 20),
                  const SizedBox(width: MeadowSpacing.sm),
                  Expanded(
                    child: Text(
                      'Completed activities can always be revisited. Mastery is demonstrated through ongoing practice assessments.',
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MeadowSpacing.lg),

            // Level Activities List (NO STRIKETHROUGH)
            Text('LEVEL ${widget.level} ACTIVITIES', style: MeadowTypography.label),
            const SizedBox(height: MeadowSpacing.sm),

            FutureBuilder<List<ActivityModel>>(
              future: _resolveLevelActivities(lvlProg),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator(color: MeadowColors.primary)),
                  );
                }

                final activities = snapshot.data ?? [];
                if (activities.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(MeadowSpacing.xl),
                    decoration: BoxDecoration(
                      color: MeadowColors.surface,
                      borderRadius: BorderRadius.circular(MeadowRadius.lg),
                      border: Border.all(color: MeadowColors.borderLight),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.playlist_add_check, size: 36, color: MeadowColors.textTertiary),
                          const SizedBox(height: MeadowSpacing.sm),
                          Text('Activities Ready to Load', style: MeadowTypography.h3),
                          const SizedBox(height: 4),
                          Text(
                            'Explore the activity library to find tailored Level ${widget.level} exercises.',
                            style: MeadowTypography.caption,
                          ),
                          const SizedBox(height: MeadowSpacing.md),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                                ),
                              );
                            },
                            style: MeadowButtons.primary(),
                            child: const Text('Explore Library'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => const SizedBox(height: MeadowSpacing.sm),
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
                      color: MeadowColors.surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MeadowRadius.lg),
                        side: BorderSide(
                          color: isActive
                              ? Colors.orange.shade300
                              : isCompleted
                                  ? (isDomainMastered ? MeadowColors.success.withOpacity(0.3) : Colors.amber.shade300)
                                  : MeadowColors.borderLight,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 40,
                          height: 40,
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
                                      : '🎯',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        // NO STRIKETHROUGH STYLING:
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MeadowDomain.colorFor(activity.skillType).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                activity.skillType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: MeadowDomain.colorFor(activity.skillType),
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
                                  fontWeight: FontWeight.w600,
                                  color: MeadowColors.textPrimary,
                                  // Explicitly NO line-through
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? (isDomainMastered
                                          ? MeadowColors.success.withOpacity(0.15)
                                          : Colors.amber.withOpacity(0.2))
                                      : isActive
                                          ? Colors.orange.withOpacity(0.15)
                                          : MeadowColors.creamDark,
                                  borderRadius: BorderRadius.circular(MeadowRadius.pill),
                                ),
                                child: Text(
                                  isCompleted
                                      ? (isDomainMastered
                                          ? 'Completed · Mastered 🏆 ($domainScore%)'
                                          : 'Completed · Practice Recommended ($domainScore% / 70% goal)')
                                      : isActive
                                          ? 'In Progress · Tap to resume'
                                          : 'Ready to start',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isCompleted
                                        ? (isDomainMastered ? MeadowColors.success : const Color(0xFFB37400))
                                        : isActive
                                            ? Colors.orange.shade800
                                            : MeadowColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (isCompleted)
                                Text(
                                  'Completed · Tap to replay',
                                  style: MeadowTypography.caption.copyWith(
                                    color: MeadowColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              Text(
                                '${activity.duration} min · ${activity.difficulty}',
                                style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: MeadowColors.textTertiary),
                        onTap: () => _handleStartActivity(activity),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: MeadowSpacing.xxl),

            // Recent Assessment Events & Attempts Stream
            Text('RECENT LEARNING ASSESSMENTS', style: MeadowTypography.label),
            const SizedBox(height: MeadowSpacing.sm),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _resolveScoreEventsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: MeadowColors.primary));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(MeadowSpacing.lg),
                    decoration: BoxDecoration(
                      color: MeadowColors.surface,
                      borderRadius: BorderRadius.circular(MeadowRadius.lg),
                      border: Border.all(color: MeadowColors.borderLight),
                    ),
                    child: Center(
                      child: Text(
                        'No previous assessment records found yet for this child.',
                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final domain = data['skillDomain']?.toString() ?? 'development';
                    final delta = (data['appliedScoreDelta'] as num?)?.toDouble() ?? 0.0;
                    final reason = data['reason']?.toString() ?? 'Activity practice';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: MeadowColors.surface,
                        borderRadius: BorderRadius.circular(MeadowRadius.md),
                        border: Border.all(color: MeadowColors.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reason,
                                  style: MeadowTypography.body.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  MeadowDomain.labelFor(domain),
                                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: delta >= 0
                                  ? MeadowColors.success.withOpacity(0.15)
                                  : MeadowColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(MeadowRadius.pill),
                            ),
                            child: Text(
                              delta >= 0 ? '+${delta.toStringAsFixed(1)} pts' : '${delta.toStringAsFixed(1)} pts',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: delta >= 0 ? MeadowColors.success : MeadowColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: MeadowSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}
