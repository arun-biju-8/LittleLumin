// lib/screens/parent/widgets/compact_score_preview.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/child_model.dart';
import '../../../models/journey_model.dart';
import '../../../theme/meadow_theme.dart';
import '../growth_analytics_screen.dart';

class CompactScorePreview extends StatelessWidget {
  final ChildModel activeChild;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? skillProfileStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? scoreEventsStream;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? journeyProgressStream;
  final VoidCallback? onViewFullAnalytics;

  const CompactScorePreview({
    super.key,
    required this.activeChild,
    this.skillProfileStream,
    this.scoreEventsStream,
    this.journeyProgressStream,
    this.onViewFullAnalytics,
  });

  static const List<String> _domains = [
    'cognitive',
    'language',
    'motor',
    'social',
    'emotional',
    'creative',
  ];

  Stream<DocumentSnapshot<Map<String, dynamic>>> _resolveSkillProfileStream() {
    if (skillProfileStream != null) return skillProfileStream!;
    try {
      return FirebaseFirestore.instance
          .collection('skillProfiles')
          .doc(activeChild.childId)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _resolveScoreEventsStream() {
    if (scoreEventsStream != null) return scoreEventsStream!;
    try {
      return FirebaseFirestore.instance
          .collection('scoreEvents')
          .where('childId', isEqualTo: activeChild.childId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _resolveJourneyProgressStream() {
    if (journeyProgressStream != null) return journeyProgressStream!;
    try {
      return FirebaseFirestore.instance
          .collection('journeyProgress')
          .doc(activeChild.childId)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  double _getScore(Map<String, dynamic> profile, String domain) {
    final lower = domain.toLowerCase();
    final capitalized = domain[0].toUpperCase() + domain.substring(1).toLowerCase();
    final val = profile[lower] ?? profile[capitalized] ?? profile[domain];
    if (val is num) return val.toDouble();
    return 0.0;
  }

  void _openAnalytics(BuildContext context) {
    if (onViewFullAnalytics != null) {
      onViewFullAnalytics!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GrowthAnalyticsScreen(activeChild: activeChild),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _resolveSkillProfileStream(),
      builder: (context, profileSnap) {
        final profile = profileSnap.data?.data() ?? {};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _resolveScoreEventsStream(),
          builder: (context, eventsSnap) {
            final events = eventsSnap.data?.docs.map((d) => d.data()).toList() ?? [];

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _resolveJourneyProgressStream(),
              builder: (context, journeySnap) {
                final journey = journeySnap.data?.data() ?? {};
                return _buildCard(context, profile, events, journey);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> profile,
    List<Map<String, dynamic>> events,
    Map<String, dynamic> journey,
  ) {
    // 1. Calculate overall score
    double totalScore = 0;
    int domainCount = 0;
    for (final d in _domains) {
      final s = _getScore(profile, d);
      if (s > 0) {
        totalScore += s;
        domainCount++;
      }
    }
    final overallScore = domainCount > 0 ? (totalScore / domainCount) : 0.0;
    final scoreInt = overallScore.round();

    // 2. Journey level info
    final currentLevel = (journey['currentLevel'] as num?)?.toInt() ?? 1;
    final levelConfig = JourneyLevelConfig.defaultLevels.firstWhere(
      (l) => l.level == currentLevel,
      orElse: () => JourneyLevelConfig.defaultLevels.first,
    );
    final completedCount = (journey['completedActivities'] as List?)?.length ?? 0;
    final totalSkillsCount = levelConfig.domainRequirements.length;

    // 3. Calculate 7-day trend per domain
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final Map<String, double> domainDeltas = {};
    for (final d in _domains) {
      domainDeltas[d] = 0.0;
    }

    for (final e in events) {
      final domain = (e['skillDomain']?.toString() ?? '').toLowerCase();
      final delta = (e['appliedScoreDelta'] as num?)?.toDouble() ?? 0.0;
      final createdAt = e['createdAt'];
      if (createdAt is Timestamp) {
        if (createdAt.toDate().isAfter(sevenDaysAgo)) {
          if (domainDeltas.containsKey(domain)) {
            domainDeltas[domain] = domainDeltas[domain]! + delta;
          }
        }
      } else {
        if (domainDeltas.containsKey(domain)) {
          domainDeltas[domain] = domainDeltas[domain]! + delta;
        }
      }
    }

    // Top 4 domains (prioritize domains with highest activity or top scores)
    final topDomains = _domains.take(4).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: MeadowSpacing.lg),
      padding: const EdgeInsets.all(MeadowSpacing.xl),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: 📊 Overall Growth
          Row(
            children: [
              const Text('📊 ', style: TextStyle(fontSize: 18)),
              Text('Overall Growth', style: MeadowTypography.h2),
            ],
          ),
          const SizedBox(height: MeadowSpacing.lg),

          // Ring Chart + Level Information
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: overallScore > 0 ? (overallScore / 100.0).clamp(0.0, 1.0) : 0.05,
                        strokeWidth: 8,
                        backgroundColor: MeadowColors.primarySurface,
                        valueColor: const AlwaysStoppedAnimation<Color>(MeadowColors.primary),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$scoreInt%',
                      style: MeadowTypography.h2.copyWith(
                        color: MeadowColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MeadowSpacing.lg),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $currentLevel · ${levelConfig.title}',
                      style: MeadowTypography.label.copyWith(
                        color: MeadowColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$completedCount of $totalSkillsCount skills explored',
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MeadowSpacing.lg),

          const Divider(color: MeadowColors.borderLight, height: 1),
          const SizedBox(height: MeadowSpacing.md),

          // Domain Scores (Top 4)
          Text(
            'Domain scores:',
            style: MeadowTypography.caption.copyWith(
              color: MeadowColors.textTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: MeadowSpacing.xs),

          ...topDomains.map((domain) {
            final score = _getScore(profile, domain);
            final delta = domainDeltas[domain] ?? 0.0;
            final label = MeadowDomain.labelFor(domain);
            final icon = MeadowDomain.iconFor(domain);
            final color = MeadowDomain.colorFor(domain);

            String arrow = '→';
            Color arrowColor = MeadowColors.textTertiary;
            if (delta > 0) {
              arrow = '↑';
              arrowColor = MeadowColors.success;
            } else if (delta < 0) {
              arrow = '↓';
              arrowColor = MeadowColors.error;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: MeadowSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: MeadowTypography.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${score.round()}%',
                    style: MeadowTypography.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: MeadowColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: MeadowSpacing.sm),
                  Text(
                    arrow,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: arrowColor,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: MeadowSpacing.lg),

          // Button: View Full Analytics →
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: MeadowButtons.secondary().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
              ),
              onPressed: () => _openAnalytics(context),
              child: const Text('View Full Analytics →'),
            ),
          ),
        ],
      ),
    );
  }
}
