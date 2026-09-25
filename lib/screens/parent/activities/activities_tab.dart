// lib/screens/parent/activities/activities_tab.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/activity_model.dart';
import '../../../models/child_model.dart';
import '../../../models/journey_model.dart';
import '../../../services/curated_packs_service.dart';
import '../../../services/journey_service.dart';
import '../../../theme/meadow_theme.dart';
import '../../../widgets/global_header.dart';
import '../activity_view.dart';
import '../ai_activity_generator.dart';
import '../app_shell.dart';
import '../journey_view.dart';
import 'skill_detail_screen.dart';
import 'activity_library_screen.dart';

class ActivitiesTab extends StatefulWidget {
  final ChildModel? activeChild;
  final int initialSubTabIndex;
  final List<String>? initialRecentActivityIds;
  final List<ActivityModel>? initialActivities;
  final Stream<JourneyProgress?>? journeyStream;

  const ActivitiesTab({
    super.key,
    required this.activeChild,
    this.initialSubTabIndex = 0,
    this.initialRecentActivityIds,
    this.initialActivities,
    this.journeyStream,
  });

  static Future<void> recordRecentlyViewed(String activityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('recently_viewed_activities') ?? [];
      list.remove(activityId);
      list.insert(0, activityId);
      if (list.length > 3) {
        list.removeRange(3, list.length);
      }
      await prefs.setStringList('recently_viewed_activities', list);
    } catch (_) {}
  }

  @override
  State<ActivitiesTab> createState() => ActivitiesTabState();
}

class ActivitiesTabState extends State<ActivitiesTab> {
  final ScrollController _scrollController = ScrollController();
  List<String> _recentActivityIds = [];
  late Future<List<ActivityModel>> _activitiesFuture;
  late Future<List<ActivityModel>> _todaysActivitiesFuture;

  @override
  void initState() {
    super.initState();
    _loadRecentActivities();
    _loadAllActivities();
    _loadTodaysActivities();
  }

  @override
  void didUpdateWidget(covariant ActivitiesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild?.childId != widget.activeChild?.childId) {
      _loadRecentActivities();
      _loadTodaysActivities();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void selectSubTab(int index) {
    // Kept for backward compatibility
  }

  Future<void> _loadRecentActivities() async {
    if (widget.initialRecentActivityIds != null) {
      setState(() => _recentActivityIds = widget.initialRecentActivityIds!);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('recently_viewed_activities') ?? [];
      if (mounted) {
        setState(() => _recentActivityIds = list);
      }
    } catch (_) {}
  }

  void _loadAllActivities() {
    if (widget.initialActivities != null) {
      _activitiesFuture = Future.value(widget.initialActivities!);
      return;
    }
    _activitiesFuture = _fetchAllActivities();
  }

  Future<List<ActivityModel>> _fetchAllActivities() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('activities')
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs
          .map((doc) => ActivityModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _loadTodaysActivities() {
    _todaysActivitiesFuture = _fetchTodaysActivities();
  }

  Future<List<ActivityModel>> _fetchTodaysActivities() async {
    if (widget.initialActivities != null && widget.initialActivities!.isNotEmpty) {
      return widget.initialActivities!.take(3).toList();
    }

    final childId = widget.activeChild?.childId;
    final childAge = widget.activeChild?.age ?? 4;
    final List<ActivityModel> results = [];

    if (childId != null && childId.isNotEmpty) {
      try {
        final recSnap = await FirebaseFirestore.instance
            .collection('recommendedActivities')
            .doc(childId)
            .collection('domains')
            .limit(3)
            .get();

        for (final doc in recSnap.docs) {
          final data = doc.data();
          if (data['activityData'] is Map<String, dynamic>) {
            results.add(
              ActivityModel.fromMap(
                doc.id,
                Map<String, dynamic>.from(data['activityData'] as Map),
              ),
            );
          } else if (data.containsKey('title')) {
            results.add(ActivityModel.fromMap(doc.id, data));
          }
        }
      } catch (_) {}
    }

    if (results.length < 3) {
      try {
        final all = await _fetchAllActivities();
        final ageMatching = all.where((a) => a.ageGroup.contains(childAge)).toList();
        final candidates = ageMatching.isNotEmpty ? ageMatching : all;

        for (final c in candidates) {
          if (results.length >= 3) break;
          if (!results.any((r) => r.title.toLowerCase() == c.title.toLowerCase())) {
            results.add(c);
          }
        }
      } catch (_) {}
    }

    return results;
  }

  String _mapIllustration(String title, String domain) {
    final t = title.toLowerCase();
    if (t.contains('nature') || t.contains('hunt') || t.contains('treasure')) {
      return 'assets/illustrations/nature_hunt.webp';
    }
    if (t.contains('color') || t.contains('sort')) {
      return 'assets/illustrations/color_sorting.webp';
    }
    if (t.contains('fort') || t.contains('build')) {
      return 'assets/illustrations/build_fort.webp';
    }
    if (t.contains('story') || t.contains('read') || t.contains('book')) {
      return 'assets/illustrations/story_reading.webp';
    }
    if (t.contains('calm') || t.contains('safari')) {
      return 'assets/illustrations/calm_safari.webp';
    }
    if (t.contains('ocean') || t.contains('breath')) {
      return 'assets/illustrations/ocean_breathing.webp';
    }
    if (t.contains('phonic') || t.contains('sound') || t.contains('word') || t.contains('letter')) {
      return 'assets/illustrations/phonics_fun.webp';
    }
    if (t.contains('music') || t.contains('listen')) {
      return 'assets/illustrations/nature_sounds.webp';
    }

    final d = domain.toLowerCase();
    if (d == 'cognitive') return 'assets/illustrations/nature_hunt.webp';
    if (d == 'motor') return 'assets/illustrations/build_fort.webp';
    if (d == 'language') return 'assets/illustrations/phonics_fun.webp';
    if (d == 'emotional') return 'assets/illustrations/ocean_breathing.webp';
    if (d == 'social') return 'assets/illustrations/calm_safari.webp';

    return 'assets/illustrations/home_hero.webp';
  }

  void _openActivity(ActivityModel activity) {
    ActivitiesTab.recordRecentlyViewed(activity.id ?? activity.title);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityView(
          activity: activity,
          activityId: activity.id,
          childId: widget.activeChild?.childId,
        ),
      ),
    );
  }

  void _openJourney() {
    final shell = context.findAncestorStateOfType<AppShellState>();
    if (shell != null) {
      shell.setTab(1); // Growth
    } else if (widget.activeChild != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JourneyViewScreen(activeChild: widget.activeChild!),
        ),
      );
    }
  }

  void _openSurpriseMe(List<ActivityModel> activities) {
    if (activities.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AIActivityGeneratorScreen(
            child: widget.activeChild,
            initialTabIndex: 0,
          ),
        ),
      );
      return;
    }
    final random = Random();
    final chosen = activities[random.nextInt(activities.length)];
    _openActivity(chosen);
  }

  void _showAllThreeActivitiesModal(List<ActivityModel> activities) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MeadowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: MeadowColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Today\'s 3 Activities', style: MeadowTypography.h2),
              const SizedBox(height: 12),
              ...activities.map((a) {
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(MeadowRadius.sm),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.asset(
                          _mapIllustration(a.title, a.skillType),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: MeadowColors.primarySurface,
                            child: const Icon(Icons.palette_outlined, color: MeadowColors.primary),
                          ),
                        ),
                      ),
                    ),
                    title: Text(a.title, style: MeadowTypography.h3),
                    subtitle: Text(
                      '${a.skillType} · ${a.duration} min · ${a.difficulty}',
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MeadowColors.primary,
                        foregroundColor: MeadowColors.textInverse,
                        elevation: 0,
                        minimumSize: const Size(60, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openActivity(a);
                      },
                      child: const Text('Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Jump Back In Section
  Widget _buildJumpBackInSection(List<ActivityModel> allActivities) {
    if (_recentActivityIds.isEmpty) return const SizedBox.shrink();

    final recentActivities = allActivities.where((a) {
      return _recentActivityIds.contains(a.id) || _recentActivityIds.contains(a.title);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'JUMP BACK IN',
              style: MeadowTypography.caption.copyWith(
                color: MeadowColors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                  ),
                );
              },
              child: Text(
                'View all',
                style: MeadowTypography.caption.copyWith(
                  color: MeadowColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (recentActivities.isNotEmpty)
                ...recentActivities.map((a) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: MeadowColors.surface,
                      side: const BorderSide(color: MeadowColors.borderLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.pill)),
                      label: Text(
                        a.title,
                        style: MeadowTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: MeadowColors.textPrimary,
                        ),
                      ),
                      onPressed: () => _openActivity(a),
                    ),
                  );
                })
              else
                ..._recentActivityIds.map((id) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: MeadowColors.surface,
                      side: const BorderSide(color: MeadowColors.borderLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.pill)),
                      label: Text(
                        id,
                        style: MeadowTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: MeadowColors.textPrimary,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: MeadowSpacing.xl),
      ],
    );
  }

  // 2. Continue Your Journey Card
  Widget _buildJourneyCard() {
    final childId = widget.activeChild?.childId ?? '';

    Stream<JourneyProgress?> resolveStream() {
      if (widget.journeyStream != null) return widget.journeyStream!;
      if (childId.isEmpty) return const Stream.empty();
      try {
        return JourneyService().getJourneyProgress(childId);
      } catch (_) {
        return const Stream.empty();
      }
    }

    return StreamBuilder<JourneyProgress?>(
      stream: resolveStream(),
      builder: (context, snapshot) {
        final journey = snapshot.data;
        final level = journey?.currentLevel ?? 1;
        final completedSkills = journey?.currentLevelProgress?.completed.length ?? 3;
        final totalSkills = journey?.currentLevelProgress?.total ?? 6;

        const allDomains = ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'];
        String nextFocus = 'Cognitive';
        if (journey != null && journey.currentLevelProgress != null) {
          for (final d in allDomains) {
            if (!journey.currentLevelProgress!.completed.contains(d)) {
              nextFocus = d;
              break;
            }
          }
        }

        return Container(
          width: double.infinity,
          decoration: MeadowCards.hero(),
          padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'CONTINUE YOUR JOURNEY',
                    style: MeadowTypography.caption.copyWith(
                      color: MeadowColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Level $level · Foundation',
                style: MeadowTypography.h2,
              ),
              const SizedBox(height: 4),
              Text(
                '$completedSkills of $totalSkills skills explored',
                style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Next focus: ',
                    style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                  ),
                  Text(
                    nextFocus,
                    style: MeadowTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MeadowDomain.colorFor(nextFocus),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: MeadowButtons.primary(),
                  onPressed: _openJourney,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue Journey →',
                        style: MeadowTypography.button.copyWith(color: MeadowColors.textInverse),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Today's Activities Card
  Widget _buildTodaysActivitiesCard() {
    return FutureBuilder<List<ActivityModel>>(
      future: _todaysActivitiesFuture,
      builder: (context, snapshot) {
        final activities = snapshot.data ?? [];
        if (activities.isEmpty) return const SizedBox.shrink();

        final first = activities.first;
        final illustration = _mapIllustration(first.title, first.skillType);
        final kidName = widget.activeChild?.name ?? 'Kid';

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
                      const Text('📋', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        'TODAY\'S ACTIVITIES',
                        style: MeadowTypography.caption.copyWith(
                          color: MeadowColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${activities.length} picked for $kidName',
                    style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Illustration
              ClipRRect(
                borderRadius: BorderRadius.circular(MeadowRadius.md),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    illustration,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: MeadowColors.sageLight,
                      child: const Icon(Icons.auto_awesome, color: MeadowColors.primary, size: 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title + metadata
              Text(first.title, style: MeadowTypography.h2),
              const SizedBox(height: 4),
              Text(
                '${MeadowDomain.labelFor(first.skillType)} · ${first.duration} min · ${first.difficulty}',
                style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),

              // Action buttons row: [ Start First → ] [ See All 3 ]
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: MeadowButtons.primary().copyWith(
                        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                      ),
                      onPressed: () => _openActivity(first),
                      child: const Text('Start First →', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MeadowColors.primary,
                      side: const BorderSide(color: MeadowColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _showAllThreeActivitiesModal(activities),
                    child: Text('See All ${activities.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. Quick Start Row
  Widget _buildQuickStartRow(List<ActivityModel> allActivities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK START',
          style: MeadowTypography.caption.copyWith(
            color: MeadowColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Create with AI
            Expanded(
              child: _buildQuickTile(
                icon: '✨',
                iconBg: MeadowColors.goldSurface,
                title: 'Create with AI',
                onTap: () {
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
              ),
            ),
            const SizedBox(width: 10),

            // Story
            Expanded(
              child: _buildQuickTile(
                icon: '📖',
                iconBg: MeadowColors.languageSurface,
                title: 'Story',
                onTap: () {
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
              ),
            ),
            const SizedBox(width: 10),

            // Surprise Me
            Expanded(
              child: _buildQuickTile(
                icon: '🎲',
                iconBg: MeadowColors.motorSurface,
                title: 'Surprise Me',
                onTap: () => _openSurpriseMe(allActivities),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickTile({
    required String icon,
    required Color iconBg,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: MeadowCards.standard(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MeadowRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: MeadowTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: MeadowColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 5. Browse By Skill Section
  Widget _buildBrowseBySkillSection(List<ActivityModel> allActivities) {
    const skills = [
      {'name': 'Cognitive', 'icon': '🧠'},
      {'name': 'Language', 'icon': '💬'},
      {'name': 'Motor', 'icon': '🏃'},
      {'name': 'Social', 'icon': '🤝'},
      {'name': 'Emotional', 'icon': '❤️'},
      {'name': 'Creative', 'icon': '🎨'},
    ];

    int countForSkill(String skill) {
      final s = skill.toLowerCase();
      final count = allActivities.where((a) => a.skillType.toLowerCase() == s).length;
      return count > 0 ? count : 25; // Graceful default if unseeded
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BROWSE BY SKILL',
          style: MeadowTypography.caption.copyWith(
            color: MeadowColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: MeadowCards.standard(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: skills.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final name = s['name']!;
              final icon = s['icon']!;
              final count = countForSkill(name);

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Text(icon, style: const TextStyle(fontSize: 22)),
                    title: Text(name, style: MeadowTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count activities',
                          style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: MeadowColors.textTertiary, size: 20),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SkillDetailScreen(
                            skillDomain: name,
                            child: widget.activeChild,
                          ),
                        ),
                      );
                    },
                  ),
                  if (idx < skills.length - 1)
                    const Divider(height: 1, indent: 56, color: MeadowColors.borderLight),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      ],
    );
  }

  // 6. Curated Packs Section
  Widget _buildCuratedPacksSection(List<ActivityModel> allActivities) {
    final packEntries = CuratedPacksService.packs.entries.toList();

    int countForPack(Map<String, dynamic> pack) {
      final filter = pack['filter'] as Map<String, dynamic>;
      if (allActivities.isEmpty) return 10;
      var list = allActivities;
      if (filter.containsKey('maxDuration')) {
        final maxDur = filter['maxDuration'] as int;
        list = list.where((a) => a.duration <= maxDur).toList();
      }
      if (filter.containsKey('skillTypes')) {
        final types = (filter['skillTypes'] as List).map((t) => t.toString().toLowerCase()).toList();
        list = list.where((a) => types.contains(a.skillType.toLowerCase())).toList();
      }
      return list.isNotEmpty ? list.length : 8;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CURATED PACKS',
          style: MeadowTypography.caption.copyWith(
            color: MeadowColors.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: MeadowCards.standard(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: packEntries.asMap().entries.map((entry) {
              final idx = entry.key;
              final packId = entry.value.key;
              final pack = entry.value.value;
              final count = countForPack(pack);

              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Text(pack['emoji'] as String, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      pack['name'] as String,
                      style: MeadowTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      pack['description'] as String,
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                    ),
                    trailing: Text(
                      '$count',
                      style: MeadowTypography.bodyLarge.copyWith(
                        color: MeadowColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SkillDetailScreen(
                            packId: packId,
                            packName: pack['name'] as String,
                            child: widget.activeChild,
                          ),
                        ),
                      );
                    },
                  ),
                  if (idx < packEntries.length - 1)
                    const Divider(height: 1, indent: 56, color: MeadowColors.borderLight),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      ],
    );
  }

  // 7. All Activities Section
  Widget _buildAllActivitiesSection(List<ActivityModel> allActivities) {
    final count = allActivities.isNotEmpty ? allActivities.length : 112;

    return Container(
      width: double.infinity,
      decoration: MeadowCards.tinted(MeadowColors.primarySurface),
      padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'ALL ACTIVITIES ($count)',
                style: MeadowTypography.caption.copyWith(
                  color: MeadowColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Browse the full library',
            style: MeadowTypography.h2,
          ),
          const SizedBox(height: 4),
          Text(
            'Filter by skills, age, materials, and learning goals across all developmental milestones.',
            style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: MeadowButtons.primary(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityLibraryScreen(child: widget.activeChild),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Open Library →',
                    style: MeadowTypography.button.copyWith(color: MeadowColors.textInverse),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kidName = widget.activeChild?.name ?? 'your child';

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: const GlobalHeader(showBack: false),
      body: FutureBuilder<List<ActivityModel>>(
        future: _activitiesFuture,
        builder: (context, snapshot) {
          final allActivities = snapshot.data ?? [];

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: MeadowSpacing.screenH,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text('Activities', style: MeadowTypography.display),
                const SizedBox(height: MeadowSpacing.xs),
                Text(
                  'What would you like to do with $kidName today?',
                  style: MeadowTypography.bodyLarge.copyWith(color: MeadowColors.textSecondary),
                ),
                const SizedBox(height: MeadowSpacing.xl),

                // 1. Jump Back In
                _buildJumpBackInSection(allActivities),

                // 2. Continue Your Journey
                _buildJourneyCard(),
                const SizedBox(height: MeadowSpacing.xl),

                // 3. Today's Activities
                _buildTodaysActivitiesCard(),
                const SizedBox(height: MeadowSpacing.xl),

                // 4. Quick Start
                _buildQuickStartRow(allActivities),
                const SizedBox(height: MeadowSpacing.xl),

                // 5. Browse By Skill
                _buildBrowseBySkillSection(allActivities),
                const SizedBox(height: MeadowSpacing.xl),

                // 6. Curated Packs
                _buildCuratedPacksSection(allActivities),
                const SizedBox(height: MeadowSpacing.xl),

                // 7. All Activities
                _buildAllActivitiesSection(allActivities),
                const SizedBox(height: MeadowSpacing.xxxl),
              ],
            ),
          );
        },
      ),
    );
  }
}
