// lib/screens/parent/home/widgets/todays_plan_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/activity_model.dart';
import '../../../../models/child_model.dart';
import '../../../../services/activity_state_service.dart';
import '../../../../theme/meadow_theme.dart';
import '../../activity_view.dart';
import '../../ai_activity_generator.dart';

class TodaysPlanCard extends StatefulWidget {
  final ChildModel child;
  final VoidCallback? onAIActivity;
  final VoidCallback? onContinueJourney;
  final Future<List<ActivityModel>>? activitiesFuture;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? activeActivityStream;

  const TodaysPlanCard({
    super.key,
    required this.child,
    this.onAIActivity,
    this.onContinueJourney,
    this.activitiesFuture,
    this.activeActivityStream,
  });

  @override
  State<TodaysPlanCard> createState() => _TodaysPlanCardState();
}

class _TodaysPlanCardState extends State<TodaysPlanCard> {
  late Future<List<ActivityModel>> _future;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void didUpdateWidget(covariant TodaysPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.childId != widget.child.childId ||
        oldWidget.activitiesFuture != widget.activitiesFuture) {
      _loadActivities();
    }
  }

  void _loadActivities() {
    if (widget.activitiesFuture != null) {
      _future = widget.activitiesFuture!;
      return;
    }
    _future = _fetchPlanActivities();
  }

  Future<List<ActivityModel>> _fetchPlanActivities() async {
    final List<ActivityModel> results = [];
    final childId = widget.child.childId;
    final childAge = widget.child.age;

    try {
      // 1. Check recommendedActivities/{childId}/domains/*
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

      // 2. If fewer than 3, fall back to preset activities
      if (results.length < 3) {
        final presetSnap = await FirebaseFirestore.instance
            .collection('activities')
            .where('isPreset', isEqualTo: true)
            .where('isActive', isEqualTo: true)
            .limit(10)
            .get();

        final presets = presetSnap.docs
            .map((doc) => ActivityModel.fromMap(doc.id, doc.data()))
            .toList();

        // Sort / filter for child's age group if matching
        final ageMatching = presets.where((a) => a.ageGroup.contains(childAge)).toList();
        final candidatePresets = ageMatching.isNotEmpty ? ageMatching : presets;

        for (final p in candidatePresets) {
          if (results.length >= 3) break;
          // Avoid duplicates by title
          final alreadyPresent = results.any(
            (r) => r.title.trim().toLowerCase() == p.title.trim().toLowerCase(),
          );
          if (!alreadyPresent) {
            results.add(p);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching today\'s plan: $e');
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

    // Domain fallback mapping
    final d = domain.toLowerCase();
    if (d == 'cognitive') return 'assets/illustrations/nature_hunt.webp';
    if (d == 'motor') return 'assets/illustrations/build_fort.webp';
    if (d == 'language') return 'assets/illustrations/phonics_fun.webp';
    if (d == 'emotional') return 'assets/illustrations/ocean_breathing.webp';
    if (d == 'social') return 'assets/illustrations/calm_safari.webp';

    return 'assets/illustrations/home_hero.webp';
  }

  Widget _buildFlaggedCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MeadowColors.emotionalSurface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.emotional.withOpacity(0.35)),
        boxShadow: MeadowShadows.soft,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌿', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'TAKE IT SLOW TODAY',
                style: MeadowTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: MeadowColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'We\'ve prepared gentle, calming moments for ${widget.child.name}. There\'s no rush today — focus on connection and comfort.',
            style: MeadowTypography.body.copyWith(
              color: MeadowColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AIActivityGeneratorScreen(
                    child: widget.child,
                    initialTabIndex: 1, // story mode
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MeadowColors.surface,
              foregroundColor: MeadowColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MeadowRadius.md),
                side: BorderSide(color: MeadowColors.emotional.withOpacity(0.4)),
              ),
            ),
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Read a Calming Story'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: MeadowCards.standard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'TODAY\'S PLAN',
                style: MeadowTypography.caption.copyWith(
                  color: MeadowColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No activities scheduled yet',
            style: MeadowTypography.h3,
          ),
          const SizedBox(height: 6),
          Text(
            'Generate a personalized playful activity tailored to ${widget.child.name} in seconds.',
            style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.onAIActivity != null) {
                widget.onAIActivity!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AIActivityGeneratorScreen(
                      child: widget.child,
                      initialTabIndex: 0,
                    ),
                  ),
                );
              }
            },
            style: MeadowButtons.primary(),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Create one with AI'),
          ),
        ],
      ),
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _resolveActiveStream() {
    if (widget.activeActivityStream != null) return widget.activeActivityStream!;
    try {
      return ActivityStateService().watchActiveActivity(widget.child.childId);
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Flagged child priority check
    if (widget.child.isFlagged) {
      return _buildFlaggedCard();
    }

    final activeStream = _resolveActiveStream();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: activeStream,
      builder: (context, activeSnapshot) {
        final activeData = activeSnapshot.data?.data();
        final hasActive = activeData != null && activeData['activityId'] != null;

        return FutureBuilder<List<ActivityModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 220,
                decoration: MeadowCards.standard(),
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: MeadowColors.primary),
              );
            }

            final activities = snapshot.data ?? [];
            if (activities.isEmpty) {
              return _buildEmptyState();
            }

            final first = activities.first;
            final totalMinutes = activities.fold<int>(0, (acc, a) => acc + a.duration);
            final illustration = _mapIllustration(first.title, first.skillType);
            final remainingCount = activities.length - 1;

            final domainColor = MeadowDomain.colorFor(first.skillType);
            final domainSurface = MeadowDomain.surfaceFor(first.skillType);
            final domainLabel = MeadowDomain.labelFor(first.skillType);

            return Container(
              width: double.infinity,
              decoration: MeadowCards.hero(),
              child: Padding(
                padding: const EdgeInsets.all(MeadowSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: 📋 TODAY'S PLAN · 3 activities · ~30 min
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Text('📋', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              'TODAY\'S PLAN',
                              style: MeadowTypography.caption.copyWith(
                                color: MeadowColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${activities.length} activities · ~$totalMinutes min',
                          style: MeadowTypography.caption.copyWith(
                            color: MeadowColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Illustration hero image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(MeadowRadius.md),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(
                          illustration,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: MeadowColors.sageLight,
                            child: const Center(
                              child: Icon(
                                Icons.auto_awesome,
                                size: 48,
                                color: MeadowColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Activity title
                    Text(
                      first.title,
                      style: MeadowTypography.h2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Metadata row: Domain badge · Duration · Difficulty
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: domainSurface,
                            borderRadius: BorderRadius.circular(MeadowRadius.sm),
                          ),
                          child: Text(
                            domainLabel,
                            style: MeadowTypography.caption.copyWith(
                              color: domainColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· ${first.duration} min · ${first.difficulty}',
                          style: MeadowTypography.caption.copyWith(
                            color: MeadowColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      first.shortDescription != null && first.shortDescription!.isNotEmpty
                          ? first.shortDescription!
                          : (first.learningGoals.isNotEmpty
                              ? first.learningGoals.first
                              : 'Explore, sort, and learn through playful guided moments.'),
                      style: MeadowTypography.body.copyWith(
                        color: MeadowColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),

                    // Primary Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActivityView(
                                activity: first,
                                activityId: first.id,
                                childId: widget.child.childId,
                              ),
                            ),
                          );
                        },
                        style: MeadowButtons.primary(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              hasActive ? 'Continue Activity →' : 'Start Activity →',
                              style: MeadowTypography.button.copyWith(
                                color: MeadowColors.textInverse,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Remaining activities indicator
                    if (remainingCount > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: MeadowColors.creamDark,
                          borderRadius: BorderRadius.circular(MeadowRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.checklist_rounded,
                              size: 16,
                              color: MeadowColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '+ $remainingCount more ${remainingCount == 1 ? 'activity' : 'activities'} in today\'s plan',
                                style: MeadowTypography.caption.copyWith(
                                  color: MeadowColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: MeadowColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
