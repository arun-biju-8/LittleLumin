// lib/screens/parent/growth_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/child_model.dart';
import '../../models/journey_model.dart';
import '../../theme/meadow_theme.dart';
import '../../widgets/global_header.dart';

class GrowthAnalyticsScreen extends StatefulWidget {
  final ChildModel activeChild;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? skillProfileStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? scoreEventsStream;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? journeyProgressStream;
  final Map<String, dynamic>? initialSkillProfile;
  final List<Map<String, dynamic>>? initialScoreEvents;
  final Map<String, dynamic>? initialJourneyProgress;

  const GrowthAnalyticsScreen({
    super.key,
    required this.activeChild,
    this.skillProfileStream,
    this.scoreEventsStream,
    this.journeyProgressStream,
    this.initialSkillProfile,
    this.initialScoreEvents,
    this.initialJourneyProgress,
  });

  @override
  State<GrowthAnalyticsScreen> createState() => _GrowthAnalyticsScreenState();
}

class _GrowthAnalyticsScreenState extends State<GrowthAnalyticsScreen> {
  String _selectedDomainFilter = 'overall'; // 'overall' or specific domain

  static const List<String> _domains = [
    'cognitive',
    'language',
    'motor',
    'social',
    'emotional',
    'creative',
  ];

  Stream<DocumentSnapshot<Map<String, dynamic>>> _resolveSkillProfileStream() {
    if (widget.skillProfileStream != null) return widget.skillProfileStream!;
    try {
      return FirebaseFirestore.instance
          .collection('skillProfiles')
          .doc(widget.activeChild.childId)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _resolveScoreEventsStream() {
    if (widget.scoreEventsStream != null) return widget.scoreEventsStream!;
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      return FirebaseFirestore.instance
          .collection('scoreEvents')
          .where('childId', isEqualTo: widget.activeChild.childId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .orderBy('createdAt', descending: false)
          .snapshots();
    } catch (_) {
      return const Stream.empty();
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _resolveJourneyProgressStream() {
    if (widget.journeyProgressStream != null) return widget.journeyProgressStream!;
    try {
      return FirebaseFirestore.instance
          .collection('journeyProgress')
          .doc(widget.activeChild.childId)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: GlobalHeader(
        showBack: true,
        title: 'Growth Analytics',
        onBackTap: () => Navigator.pop(context),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _resolveSkillProfileStream(),
        builder: (context, profileSnap) {
          final profileData = profileSnap.data?.data() ?? widget.initialSkillProfile ?? {};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _resolveScoreEventsStream(),
            builder: (context, eventsSnap) {
              final eventDocs = eventsSnap.data?.docs.map((d) => d.data()).toList() ??
                  widget.initialScoreEvents ??
                  [];

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _resolveJourneyProgressStream(),
                builder: (context, journeySnap) {
                  final journeyData = journeySnap.data?.data() ?? widget.initialJourneyProgress ?? {};

                  return _buildContent(
                    profile: profileData,
                    events: eventDocs,
                    journey: journeyData,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> events,
    required Map<String, dynamic> journey,
  }) {
    // 1. Calculate overall score
    double totalScore = 0;
    int domainsWithScores = 0;
    for (final domain in _domains) {
      final s = _getScore(profile, domain);
      if (s > 0) {
        totalScore += s;
        domainsWithScores++;
      }
    }
    final overallScore = domainsWithScores > 0 ? (totalScore / domainsWithScores) : 0.0;

    // 2. Journey level info
    final currentLevel = (journey['currentLevel'] as num?)?.toInt() ?? 1;
    final levelConfig = JourneyLevelConfig.defaultLevels.firstWhere(
      (l) => l.level == currentLevel,
      orElse: () => JourneyLevelConfig.defaultLevels.first,
    );
    final completedActivities = (journey['completedActivities'] as List?)?.length ?? 0;
    final totalSkillsForLevel = levelConfig.domainRequirements.length;

    // 3. Compute 7-day trends per domain
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final Map<String, double> domainDeltas = {};
    for (final domain in _domains) {
      domainDeltas[domain] = 0.0;
    }

    int weeklyActivitiesCount = 0;
    int weeklyTimeMinutes = 0;
    final Set<String> weeklyDomains = {};

    for (final e in events) {
      DateTime? eventDate;
      final createdAt = e['createdAt'];
      if (createdAt is Timestamp) {
        eventDate = createdAt.toDate();
      } else if (createdAt is DateTime) {
        eventDate = createdAt;
      }

      final domain = (e['skillDomain']?.toString() ?? '').toLowerCase();
      final delta = (e['appliedScoreDelta'] as num?)?.toDouble() ?? 0.0;

      if (eventDate != null) {
        if (eventDate.isAfter(sevenDaysAgo)) {
          weeklyActivitiesCount++;
          // Estimate 15 min per activity if timeEstimate not specified
          weeklyTimeMinutes += 15;
          if (domain.isNotEmpty) weeklyDomains.add(domain);
          if (domainDeltas.containsKey(domain)) {
            domainDeltas[domain] = domainDeltas[domain]! + delta;
          }
        }
      } else {
        // If no timestamp (e.g. mock test event), aggregate into delta
        if (domainDeltas.containsKey(domain)) {
          domainDeltas[domain] = domainDeltas[domain]! + delta;
        }
      }
    }

    // Identify most improved and needs attention
    String? mostImprovedDomain;
    double maxPositiveDelta = 0;
    String? needsAttentionDomain;
    double lowestDeltaOrScore = 999;

    for (final d in _domains) {
      final delta = domainDeltas[d] ?? 0;
      final score = _getScore(profile, d);
      if (delta > maxPositiveDelta) {
        maxPositiveDelta = delta;
        mostImprovedDomain = d;
      }
      if (delta < 0 && delta < lowestDeltaOrScore) {
        lowestDeltaOrScore = delta;
        needsAttentionDomain = d;
      } else if (needsAttentionDomain == null && score < 50 && score > 0) {
        needsAttentionDomain = d;
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: MeadowSpacing.screenH,
        vertical: MeadowSpacing.lg,
      ),
      children: [
        // Section 1: Subtitle
        Text(
          "${widget.activeChild.name}'s developmental journey",
          style: MeadowTypography.bodyLarge.copyWith(color: MeadowColors.textSecondary),
        ),
        const SizedBox(height: MeadowSpacing.xl),

        // Section 2: Overall Progress Ring
        _buildOverallProgressCard(
          overallScore: overallScore,
          currentLevel: currentLevel,
          levelName: levelConfig.title,
          completedCount: completedActivities,
          totalSkillsCount: totalSkillsForLevel,
        ),
        const SizedBox(height: MeadowSpacing.xxl),

        // Section 3: Domain Scores Grid
        _buildSectionTitle('DOMAIN SCORES'),
        const SizedBox(height: MeadowSpacing.md),
        _buildDomainGrid(profile, domainDeltas, events),
        const SizedBox(height: MeadowSpacing.xxl),

        // Section 4: Weekly Summary
        _buildSectionTitle('WEEKLY SUMMARY'),
        const SizedBox(height: MeadowSpacing.md),
        _buildWeeklySummaryCard(
          activitiesCount: weeklyActivitiesCount,
          timeMinutes: weeklyTimeMinutes,
          domainsPracticed: weeklyDomains.length,
          mostImproved: mostImprovedDomain,
          needsAttention: needsAttentionDomain,
        ),
        const SizedBox(height: MeadowSpacing.xxl),

        // Section 5: 30-Day Trend Chart
        _buildSectionTitle('30-DAY GROWTH TREND'),
        const SizedBox(height: MeadowSpacing.md),
        _buildTrendChartSection(events, profile),
        const SizedBox(height: MeadowSpacing.xxl),

        // Section 6: Recent Milestones
        _buildSectionTitle('RECENT MILESTONES'),
        const SizedBox(height: MeadowSpacing.md),
        _buildMilestonesSection(events, profile, currentLevel),
        const SizedBox(height: MeadowSpacing.xxxl),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: MeadowTypography.caption.copyWith(
        color: MeadowColors.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  // --- SECTION 2: Overall Progress Ring ---
  Widget _buildOverallProgressCard({
    required double overallScore,
    required int currentLevel,
    required String levelName,
    required int completedCount,
    required int totalSkillsCount,
  }) {
    final scoreInt = overallScore.round();

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.xl),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Row(
        children: [
          // Circular Progress Indicator Ring
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: overallScore > 0 ? (overallScore / 100.0).clamp(0.0, 1.0) : 0.05,
                    strokeWidth: 10,
                    backgroundColor: MeadowColors.primarySurface,
                    valueColor: const AlwaysStoppedAnimation<Color>(MeadowColors.primary),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$scoreInt%',
                      style: MeadowTypography.h1.copyWith(
                        color: MeadowColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      'Growth',
                      style: MeadowTypography.caption.copyWith(
                        color: MeadowColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: MeadowSpacing.xl),

          // Level details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MeadowColors.goldSurface,
                    borderRadius: BorderRadius.circular(MeadowRadius.pill),
                  ),
                  child: Text(
                    'Level $currentLevel · $levelName',
                    style: MeadowTypography.caption.copyWith(
                      color: MeadowColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: MeadowSpacing.sm),
                Text(
                  'Milestone Progress',
                  style: MeadowTypography.h3,
                ),
                const SizedBox(height: 2),
                Text(
                  '$completedCount of $totalSkillsCount skills explored',
                  style: MeadowTypography.body.copyWith(
                    color: MeadowColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 3: Domain Scores Grid ---
  Widget _buildDomainGrid(
    Map<String, dynamic> profile,
    Map<String, double> deltas,
    List<Map<String, dynamic>> events,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: MeadowSpacing.md,
        crossAxisSpacing: MeadowSpacing.md,
        childAspectRatio: 1.15,
      ),
      itemCount: _domains.length,
      itemBuilder: (context, index) {
        final domain = _domains[index];
        final score = _getScore(profile, domain);
        final delta = deltas[domain] ?? 0.0;
        final color = MeadowDomain.colorFor(domain);
        final surfaceColor = MeadowDomain.surfaceFor(domain);
        final icon = MeadowDomain.iconFor(domain);
        final label = MeadowDomain.labelFor(domain);

        // Filter events for this domain to build sparkline spots
        final domainEvents = events.where((e) {
          final d = (e['skillDomain']?.toString() ?? '').toLowerCase();
          return d == domain;
        }).toList();

        final spots = <FlSpot>[];
        if (domainEvents.isNotEmpty) {
          for (int i = 0; i < domainEvents.length; i++) {
            final after = (domainEvents[i]['scoreAfter'] as num?)?.toDouble() ?? score;
            spots.add(FlSpot(i.toDouble(), after));
          }
        } else {
          spots.add(const FlSpot(0, 50));
          spots.add(FlSpot(1, score > 0 ? score : 50));
        }

        // Trend arrow
        String arrow;
        Color trendColor;
        String deltaStr;
        if (delta > 0) {
          arrow = '↑';
          trendColor = MeadowColors.success;
          deltaStr = '+${delta.toStringAsFixed(1)}';
        } else if (delta < 0) {
          arrow = '↓';
          trendColor = MeadowColors.error;
          deltaStr = delta.toStringAsFixed(1);
        } else {
          arrow = '→';
          trendColor = MeadowColors.textTertiary;
          deltaStr = '0.0';
        }

        return Container(
          padding: const EdgeInsets.all(MeadowSpacing.md),
          decoration: BoxDecoration(
            color: MeadowColors.surface,
            borderRadius: BorderRadius.circular(MeadowRadius.lg),
            border: Border.all(color: MeadowColors.borderLight),
            boxShadow: MeadowShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Domain icon + Name
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: MeadowSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: MeadowTypography.label.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Score + Trend
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${score.round()}%',
                    style: MeadowTypography.h2.copyWith(
                      fontWeight: FontWeight.w700,
                      color: MeadowColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: MeadowSpacing.xs),
                  Text(
                    '$arrow $deltaStr',
                    style: MeadowTypography.caption.copyWith(
                      color: trendColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Mini sparkline
              SizedBox(
                height: 22,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.1),
                        ),
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

  // --- SECTION 4: Weekly Summary ---
  Widget _buildWeeklySummaryCard({
    required int activitiesCount,
    required int timeMinutes,
    required int domainsPracticed,
    String? mostImproved,
    String? needsAttention,
  }) {
    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem('Activities', '$activitiesCount', Icons.check_circle_outline),
              _buildStatDivider(),
              _buildStatItem('Time Spent', '${timeMinutes}m', Icons.schedule),
              _buildStatDivider(),
              _buildStatItem('Domains', '$domainsPracticed / 6', Icons.bubble_chart_outlined),
            ],
          ),
          if (mostImproved != null || needsAttention != null) ...[
            const Divider(color: MeadowColors.borderLight, height: MeadowSpacing.xl),
            Row(
              children: [
                if (mostImproved != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Text('🌟 ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Most Improved', style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary)),
                              Text(MeadowDomain.labelFor(mostImproved), style: MeadowTypography.label),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (needsAttention != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Text('🌱 ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Needs Gentle Care', style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary)),
                              Text(MeadowDomain.labelFor(needsAttention), style: MeadowTypography.label),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: MeadowColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: MeadowTypography.h3.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: MeadowColors.borderLight,
    );
  }

  // --- SECTION 5: 30-Day Trend Chart ---
  Widget _buildTrendChartSection(List<Map<String, dynamic>> events, Map<String, dynamic> profile) {
    // Filter chips
    final filterOptions = ['overall', ..._domains];

    // Build spots based on filter
    final spots = <FlSpot>[];
    if (_selectedDomainFilter == 'overall') {
      if (events.isNotEmpty) {
        for (int i = 0; i < events.length; i++) {
          final s = (events[i]['scoreAfter'] as num?)?.toDouble() ?? 50.0;
          spots.add(FlSpot(i.toDouble(), s));
        }
      }
    } else {
      final domainEvents = events.where((e) {
        return (e['skillDomain']?.toString() ?? '').toLowerCase() == _selectedDomainFilter;
      }).toList();
      for (int i = 0; i < domainEvents.length; i++) {
        final s = (domainEvents[i]['scoreAfter'] as num?)?.toDouble() ?? 50.0;
        spots.add(FlSpot(i.toDouble(), s));
      }
    }

    if (spots.isEmpty) {
      final defaultScore = _selectedDomainFilter == 'overall'
          ? 60.0
          : _getScore(profile, _selectedDomainFilter);
      spots.add(FlSpot(0, defaultScore > 0 ? defaultScore : 50));
      spots.add(FlSpot(1, defaultScore > 0 ? defaultScore : 50));
    }

    final activeColor = _selectedDomainFilter == 'overall'
        ? MeadowColors.primary
        : MeadowDomain.colorFor(_selectedDomainFilter);

    return Container(
      padding: const EdgeInsets.all(MeadowSpacing.lg),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filterOptions.map((domain) {
                final isSelected = _selectedDomainFilter == domain;
                final label = domain == 'overall' ? 'Overall' : MeadowDomain.labelFor(domain);

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedDomainFilter = domain);
                    },
                    selectedColor: MeadowColors.primarySurface,
                    backgroundColor: MeadowColors.surfaceAlt,
                    labelStyle: MeadowTypography.caption.copyWith(
                      color: isSelected ? MeadowColors.primary : MeadowColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MeadowRadius.pill),
                      side: BorderSide(
                        color: isSelected ? MeadowColors.primary : MeadowColors.borderLight,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: MeadowSpacing.lg),

          // Chart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: MeadowColors.borderLight,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, _) => Text(
                        '${val.toInt()}',
                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: activeColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: activeColor.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 6: Recent Milestones ---
  Widget _buildMilestonesSection(
    List<Map<String, dynamic>> events,
    Map<String, dynamic> profile,
    int currentLevel,
  ) {
    final milestones = <Widget>[];

    // 1. Level achievement
    milestones.add(_buildMilestoneItem(
      title: 'Reached Level $currentLevel',
      subtitle: 'Progressing steadily on the milestone journey',
      icon: Icons.emoji_events,
      color: MeadowColors.gold,
    ));

    // 2. High score milestones
    for (final domain in _domains) {
      final s = _getScore(profile, domain);
      if (s >= 70) {
        milestones.add(_buildMilestoneItem(
          title: '${MeadowDomain.labelFor(domain)} Milestone: 70%+ Mastery',
          subtitle: 'Strong foundation achieved in this developmental area',
          icon: MeadowDomain.iconFor(domain),
          color: MeadowDomain.colorFor(domain),
        ));
      }
    }

    // 3. Score events crossed
    for (final e in events.reversed.take(3)) {
      final delta = (e['appliedScoreDelta'] as num?)?.toDouble() ?? 0;
      final after = (e['scoreAfter'] as num?)?.toDouble() ?? 0;
      final domain = e['skillDomain']?.toString() ?? 'Learning';

      if (delta > 2.0) {
        milestones.add(_buildMilestoneItem(
          title: '+${delta.toStringAsFixed(1)} leap in ${MeadowDomain.labelFor(domain)}',
          subtitle: 'Reached score of ${after.round()}% after activity practice',
          icon: Icons.trending_up,
          color: MeadowColors.success,
        ));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        children: milestones.isNotEmpty
            ? milestones
            : [
                Padding(
                  padding: const EdgeInsets.all(MeadowSpacing.xl),
                  child: Center(
                    child: Text(
                      'Complete more activities to unlock milestone celebrations!',
                      style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildMilestoneItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: MeadowTypography.label),
      subtitle: Text(
        subtitle,
        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
      ),
    );
  }
}
