// lib/screens/parent/desktop_parent_companion.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/child_model.dart';
import '../../models/recommendation_model.dart';
import '../../models/specialist_case_model.dart';
import '../../models/consultation_summary_model.dart';
import '../../models/message_model.dart';
import '../../models/journey_model.dart';
import '../../services/child_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/score_ledger_service.dart';
import '../../services/specialist_case_service.dart';
import '../../services/consultation_summary_service.dart';
import '../../services/messaging_service.dart';
import '../../services/journey_service.dart';
import '../../theme/meadow_theme.dart';
import '../auth/login_page.dart';
import 'notifications_page.dart';

/// Primary Desktop Parent Child Development Dashboard & Web Portal
/// Aliased as [DesktopParentCompanionScreen] for backwards compatibility with existing routes.
typedef DesktopParentDashboard = DesktopParentCompanionScreen;

class DesktopParentCompanionScreen extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final MessagingService? messagingService;
  final SpecialistCaseService? specialistCaseService;
  final String? initialChildId;
  final bool initialIsChatOpen;

  const DesktopParentCompanionScreen({
    super.key,
    this.auth,
    this.firestore,
    this.messagingService,
    this.specialistCaseService,
    this.initialChildId,
    this.initialIsChatOpen = false,
  });

  @override
  State<DesktopParentCompanionScreen> createState() => _DesktopParentCompanionScreenState();
}

class _DesktopParentCompanionScreenState extends State<DesktopParentCompanionScreen> {
  FirebaseAuth? get _auth {
    try {
      return widget.auth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return widget.firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  late final MessagingService _messagingService = widget.messagingService ?? MessagingService();
  late final SpecialistCaseService _caseService = widget.specialistCaseService ?? SpecialistCaseService();
  final ScoreLedgerService _scoreService = ScoreLedgerService();
  final JourneyService _journeyService = JourneyService();

  User? get _currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? _selectedChildId;
  bool _isChatOpen = false;
  String _chartDomainFilter = 'all'; // 'all' or domain name
  String _activeNav = 'growth'; // 'growth', 'milestones', 'history', 'llg'

  final GlobalKey _growthSectionKey = GlobalKey();
  final GlobalKey _milestonesSectionKey = GlobalKey();
  final GlobalKey _historySectionKey = GlobalKey();
  final GlobalKey _llgSectionKey = GlobalKey();

  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();
  bool _isSendingMessage = false;

  static const List<String> _domains = [
    'cognitive',
    'language',
    'motor',
    'social',
    'emotional',
    'creative',
  ];

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.initialChildId;
    _isChatOpen = widget.initialIsChatOpen;
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(String navId, GlobalKey key) {
    setState(() => _activeNav = navId);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    // Unauthenticated State (handles test environments & signed-out view)
    if (user == null) {
      return Scaffold(
        backgroundColor: MeadowColors.cream,
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: MeadowColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_android, size: 64, color: MeadowColors.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'LittleLumin is Mobile-Only for Parents',
                      textAlign: TextAlign.center,
                      style: MeadowTypography.h1,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'LittleLumin\'s complete parent experience is designed for our mobile app. You can use this desktop companion to review your child\'s available profile and growth information. For the full experience, please install LittleLumin on your phone.',
                      textAlign: TextAlign.center,
                      style: MeadowTypography.body.copyWith(
                        color: MeadowColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStoreBadge(Icons.android, 'Google Play', 'Coming soon'),
                        const SizedBox(width: 8),
                        _buildStoreBadge(Icons.apple, 'App Store', 'Coming soon'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (r) => false,
                        );
                      },
                      style: MeadowButtons.primary(),
                      child: const Text('Sign in to Desktop Companion'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      body: StreamBuilder<List<ChildModel>>(
        stream: ChildService().getChildren(),
        builder: (context, childSnap) {
          final children = childSnap.data ?? [];
          if (children.isEmpty && childSnap.connectionState != ConnectionState.waiting) {
            return _buildNoChildrenDashboard(user);
          }

          if (children.isNotEmpty) {
            _selectedChildId ??= children.first.childId;
          }

          final activeChild = children.firstWhere(
            (c) => c.childId == _selectedChildId,
            orElse: () => children.isNotEmpty
                ? children.first
                : ChildModel(
                    childId: 'default',
                    name: 'Your Child',
                    dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 4)),
                    gender: 'Child',
                    parentId: user.uid,
                    createdAt: DateTime.now(),
                  ),
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1050;

              return Stack(
                children: [
                  // Full Website Content View
                  Column(
                    children: [
                      // 1. Horizontal Desktop Website Header
                      _buildDesktopWebHeader(user, activeChild, children, isDesktop),

                      // 2. Main Scrollable Workspace
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _mainScrollController,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 36 : 20,
                            vertical: 24,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1480),
                              child: isDesktop
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Primary Main Column (~67% width)
                                        Expanded(
                                          flex: 67,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Overview KPI Cards
                                              _buildOverviewCards(activeChild),
                                              const SizedBox(height: 28),

                                              // Chart Workspace (Key: growth)
                                              Container(
                                                key: _growthSectionKey,
                                                child: _buildDevelopmentalPerformanceSection(activeChild),
                                              ),
                                              const SizedBox(height: 28),

                                              // Domain Scores Summary Grid
                                              _buildDomainScoresSection(activeChild),
                                              const SizedBox(height: 28),

                                              // Milestones Workspace (Key: milestones)
                                              Container(
                                                key: _milestonesSectionKey,
                                                child: _buildMilestonesSection(activeChild),
                                              ),
                                              const SizedBox(height: 28),

                                              // Activity History Timeline (Key: history)
                                              Container(
                                                key: _historySectionKey,
                                                child: _buildActivityHistorySection(activeChild),
                                              ),
                                              const SizedBox(height: 100),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 28),

                                        // Supporting Intelligence Column (~33% width)
                                        Expanded(
                                          flex: 33,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Mobile App Companion Card
                                              _buildMobileAppSidebarCard(),
                                              const SizedBox(height: 24),

                                              // Assigned Guide Status Card (Key: llg)
                                              Container(
                                                key: _llgSectionKey,
                                                child: _buildGuideCaseCard(activeChild, user),
                                              ),
                                              const SizedBox(height: 24),

                                              // Recommendations Feed
                                              _buildRecommendationsSidePanel(activeChild),
                                              const SizedBox(height: 24),

                                              // Consultation Summaries
                                              _buildConsultationsSidePanel(activeChild),
                                              const SizedBox(height: 100),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildMobileAppNoticeBanner(),
                                        const SizedBox(height: 20),
                                        _buildOverviewCards(activeChild),
                                        const SizedBox(height: 24),
                                        Container(
                                          key: _growthSectionKey,
                                          child: _buildDevelopmentalPerformanceSection(activeChild),
                                        ),
                                        const SizedBox(height: 24),
                                        _buildDomainScoresSection(activeChild),
                                        const SizedBox(height: 24),
                                        Container(
                                          key: _milestonesSectionKey,
                                          child: _buildMilestonesSection(activeChild),
                                        ),
                                        const SizedBox(height: 24),
                                        Container(
                                          key: _historySectionKey,
                                          child: _buildActivityHistorySection(activeChild),
                                        ),
                                        const SizedBox(height: 24),
                                        Container(
                                          key: _llgSectionKey,
                                          child: _buildGuideCaseCard(activeChild, user),
                                        ),
                                        const SizedBox(height: 24),
                                        _buildRecommendationsSidePanel(activeChild),
                                        const SizedBox(height: 24),
                                        _buildConsultationsSidePanel(activeChild),
                                        const SizedBox(height: 100),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Floating Secure Chat Panel (when open)
                  if (_isChatOpen)
                    Positioned(
                      bottom: 24,
                      right: 28,
                      child: _buildFloatingChatPanel(activeChild, user),
                    ),

                  // Floating Secure Chat Launcher Button (when closed)
                  if (!_isChatOpen)
                    Positioned(
                      bottom: 24,
                      right: 28,
                      child: _buildFloatingChatLauncher(activeChild, user),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // =========================================================================
  // HORIZONTAL TOP NAVIGATION WEBSITE HEADER
  // =========================================================================
  Widget _buildDesktopWebHeader(
    User user,
    ChildModel activeChild,
    List<ChildModel> children,
    bool isDesktop,
  ) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        border: const Border(bottom: BorderSide(color: MeadowColors.borderLight, width: 1.2)),
        boxShadow: MeadowShadows.soft,
      ),
      child: Row(
        children: [
          // LittleLumin Branding Logo
          InkWell(
            onTap: () => _scrollToSection('growth', _growthSectionKey),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MeadowColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.eco_rounded, color: MeadowColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'LittleLumin',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: MeadowColors.primaryDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MeadowColors.primarySurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PORTAL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: MeadowColors.primary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Child Growth & Development',
                      style: MeadowTypography.caption.copyWith(fontSize: 10, color: MeadowColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isDesktop) ...[
            const SizedBox(width: 28),
            Container(width: 1, height: 28, color: MeadowColors.borderLight),
            const SizedBox(width: 20),

            // Horizontal Navigation Links
            _buildNavTab(
              id: 'growth',
              label: 'Child Growth',
              icon: Icons.show_chart_rounded,
              keyRef: _growthSectionKey,
            ),
            const SizedBox(width: 8),
            _buildNavTab(
              id: 'milestones',
              label: 'Milestones',
              icon: Icons.flag_outlined,
              keyRef: _milestonesSectionKey,
            ),
            const SizedBox(width: 8),
            _buildNavTab(
              id: 'history',
              label: 'Activity History',
              icon: Icons.history_edu_outlined,
              keyRef: _historySectionKey,
            ),
            const SizedBox(width: 8),
            _buildNavTab(
              id: 'llg',
              label: 'LLG Recommendations',
              icon: Icons.lightbulb_outline,
              keyRef: _llgSectionKey,
            ),
          ],

          const Spacer(),

          // Selected Child Switcher Pill
          if (children.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: MeadowColors.creamDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MeadowColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: MeadowColors.primary,
                    child: Text(
                      activeChild.name.isNotEmpty ? activeChild.name[0].toUpperCase() : 'C',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activeChild.name,
                        style: MeadowTypography.label.copyWith(fontSize: 12),
                      ),
                      Text(
                        '${activeChild.ageDisplay} • ${activeChild.gender}',
                        style: MeadowTypography.caption.copyWith(fontSize: 9, color: MeadowColors.textSecondary),
                      ),
                    ],
                  ),
                  if (children.length > 1) ...[
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedChildId,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: MeadowColors.textSecondary),
                        items: children.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.childId,
                            child: Text(
                              '${c.name} (${c.ageYears} yrs)',
                              style: MeadowTypography.body.copyWith(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            setState(() => _selectedChildId = newId);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
          ],

          // Notifications Button
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: MeadowColors.textSecondary, size: 22),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          const SizedBox(width: 8),

          // User Menu & Sign Out
          PopupMenuButton<String>(
            tooltip: 'Account Menu',
            onSelected: (val) async {
              if (val == 'logout') {
                await _auth?.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (r) => false,
                  );
                }
              }
            },
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName ?? 'Parent Account', style: MeadowTypography.label),
                    Text(user.email ?? '', style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: MeadowColors.error),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: MeadowColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: MeadowColors.sageLight,
                  child: Text(
                    user.displayName?.isNotEmpty == true ? user.displayName![0].toUpperCase() : 'P',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: MeadowColors.primaryDark,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  Text(
                    user.displayName ?? 'Parent',
                    style: MeadowTypography.label.copyWith(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: MeadowColors.textSecondary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required String id,
    required String label,
    required IconData icon,
    required GlobalKey keyRef,
  }) {
    final isSelected = _activeNav == id;
    return InkWell(
      onTap: () => _scrollToSection(id, keyRef),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MeadowColors.primarySurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? MeadowColors.primary : MeadowColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? MeadowColors.primary : MeadowColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // OVERVIEW STATS ROW (Genuine Historical Progress)
  // =========================================================================
  Widget _buildOverviewCards(ChildModel activeChild) {
    return FutureBuilder<JourneyProgress>(
      future: _journeyService.getOrInitializeJourney(activeChild.childId, age: activeChild.ageYears),
      builder: (context, journeySnap) {
        final journey = journeySnap.data;
        final currentLevel = journey?.currentLevel ?? 1;
        final completedCount = journey?.completedActivities.length ?? 0;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore != null
              ? _firestore!.collection('skillProfiles').doc(activeChild.childId).snapshots()
              : const Stream.empty(),
          builder: (context, profileSnap) {
            final profile = profileSnap.data?.data() ?? {};
            double scoreSum = 0;
            int scoredDomains = 0;
            for (final d in _domains) {
              final val = profile[d];
              if (val is num && val > 0) {
                scoreSum += val.toDouble();
                scoredDomains++;
              }
            }
            final avgScore = scoredDomains > 0 ? (scoreSum / scoredDomains) : 0.0;

            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _scoreService.getScoreHistory(childId: activeChild.childId),
              builder: (context, historySnap) {
                final history = historySnap.data ?? [];
                double recentChange = 0;
                String latestMilestone = 'Baseline Evaluation';
                if (history.isNotEmpty) {
                  latestMilestone = history.first['activityTitle'] ?? 'Baseline Evaluation';
                  for (final ev in history.take(5)) {
                    final delta = ev['appliedScoreDelta'];
                    if (delta is num) recentChange += delta.toDouble();
                  }
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth < 600
                        ? constraints.maxWidth
                        : (constraints.maxWidth < 950
                            ? (constraints.maxWidth - 16) / 2
                            : (constraints.maxWidth - 48) / 4);

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _buildKPICard(
                            title: 'DEVELOPMENTAL LEVEL',
                            value: 'Level $currentLevel',
                            subtitle: _getLevelTitle(currentLevel),
                            icon: Icons.military_tech_outlined,
                            accentColor: MeadowColors.gold,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildKPICard(
                            title: 'OVERALL PROGRESS',
                            value: scoredDomains > 0 ? '${avgScore.toStringAsFixed(1)}%' : 'Pending',
                            subtitle: recentChange > 0
                                ? '+${recentChange.toStringAsFixed(1)} pts recent trend'
                                : (scoredDomains > 0 ? 'Baseline established' : 'Awaiting first evaluation'),
                            icon: Icons.trending_up,
                            accentColor: MeadowColors.primary,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildKPICard(
                            title: 'ACTIVITIES COMPLETED',
                            value: '$completedCount Done',
                            subtitle: '$scoredDomains of 6 domains active',
                            icon: Icons.task_alt_outlined,
                            accentColor: MeadowColors.motor,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _buildKPICard(
                            title: 'LATEST MILESTONE',
                            value: latestMilestone,
                            subtitle: history.isNotEmpty
                                ? DateFormat.yMMMd().format((history.first['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now())
                                : 'Initial baseline',
                            icon: Icons.emoji_events_outlined,
                            accentColor: MeadowColors.creative,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _getLevelTitle(int level) {
    switch (level) {
      case 1:
        return 'Foundation Skills';
      case 2:
        return 'Building Skills';
      case 3:
        return 'Advanced Skills';
      case 4:
        return 'Mastery Challenges';
      default:
        return 'Foundation Skills';
    }
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: MeadowColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: MeadowColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PROMINENT DEVELOPMENTAL PROGRESS CHART WORKSPACE
  // =========================================================================
  Widget _buildDevelopmentalPerformanceSection(ChildModel activeChild) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Domain Filter Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Developmental Progress & Growth Trends', style: MeadowTypography.h2),
                    const SizedBox(height: 4),
                    Text(
                      '30-day interactive developmental trajectory synthesized from immutable score ledger records',
                      style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Domain Filter Selector Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildChartFilterChip('all', 'All Domains'),
                  ..._domains.map((d) => _buildChartFilterChip(d, MeadowDomain.labelFor(d))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Canvas
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _scoreService.getScoreHistory(
              childId: activeChild.childId,
              skillDomain: _chartDomainFilter == 'all' ? null : _chartDomainFilter,
            ),
            builder: (context, snapshot) {
              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return Container(
                  height: 240,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MeadowColors.surfaceAlt.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MeadowColors.borderLight, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_graph_rounded, size: 48, color: MeadowColors.sage.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No score ledger history recorded yet for ${_chartDomainFilter == 'all' ? activeChild.name : MeadowDomain.labelFor(_chartDomainFilter)}',
                        style: MeadowTypography.label.copyWith(color: MeadowColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          'Evaluated scores logged through mobile interactive play or developmental assessments will automatically chart here.',
                          textAlign: TextAlign.center,
                          style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Reverse chronologically so left-to-right is oldest-to-newest
              final chronological = events.reversed.toList();
              final spots = <FlSpot>[];
              double runningScore = 0;

              for (int i = 0; i < chronological.length; i++) {
                final ev = chronological[i];
                final delta = (ev['appliedScoreDelta'] is num) ? (ev['appliedScoreDelta'] as num).toDouble() : 0.0;
                runningScore = (runningScore + delta).clamp(0.0, 100.0);
                spots.add(FlSpot(i.toDouble(), runningScore));
              }

              final chartColor = _chartDomainFilter == 'all'
                  ? MeadowColors.primary
                  : MeadowDomain.colorFor(_chartDomainFilter);

              return SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (val) => FlLine(
                        color: MeadowColors.borderLight,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          reservedSize: 38,
                          getTitlesWidget: (val, meta) => Text(
                            '${val.toInt()}%',
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, color: MeadowColors.textTertiary),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: max(1, (spots.length / 5).floor()).toDouble(),
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < chronological.length) {
                              final d = (chronological[idx]['createdAt'] as Timestamp?)?.toDate();
                              if (d != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    DateFormat.MMMd().format(d),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 9, color: MeadowColors.textTertiary),
                                  ),
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: max(1, spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: chartColor,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: chartColor.withOpacity(0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChartFilterChip(String key, String label) {
    final isSelected = _chartDomainFilter == key;
    return InkWell(
      onTap: () => setState(() => _chartDomainFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? MeadowColors.primary : MeadowColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? MeadowColors.primary : MeadowColors.borderLight),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : MeadowColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // DOMAIN-LEVEL PROGRESS SUMMARIES
  // =========================================================================
  Widget _buildDomainScoresSection(ChildModel activeChild) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Developmental Domains (VSMS)', style: MeadowTypography.h2),
                const SizedBox(height: 4),
                Text(
                  'Core skill areas evaluated against the Vineland Social Maturity Scale',
                  style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                ),
              ],
            ),
            Row(
              children: [
                _buildWeightLegend('Measured (1.0x)', MeadowColors.success),
                const SizedBox(width: 14),
                _buildWeightLegend('AI Guided (0.5x)', MeadowColors.cognitive),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore != null
              ? _firestore!.collection('skillProfiles').doc(activeChild.childId).snapshots()
              : const Stream.empty(),
          builder: (context, snapshot) {
            final profile = snapshot.data?.data() ?? {};

            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                final crossAxisCount = isNarrow ? 2 : 3;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: _domains.length,
                  itemBuilder: (context, idx) {
                    final d = _domains[idx];
                    final raw = profile[d];
                    final score = (raw is num) ? raw.toDouble() : 0.0;
                    final color = MeadowDomain.colorFor(d);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: MeadowColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: MeadowColors.borderLight),
                        boxShadow: MeadowShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(MeadowDomain.iconFor(d), size: 16, color: color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  MeadowDomain.labelFor(d),
                                  style: MeadowTypography.label.copyWith(fontSize: 13),
                                ),
                              ),
                              Text(
                                '${score.toStringAsFixed(1)}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (score / 100).clamp(0.0, 1.0),
                              backgroundColor: MeadowColors.creamDark,
                              color: color,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                score >= 70 ? 'Mastered' : (score > 0 ? 'In Progress' : 'Pending Baseline'),
                                style: MeadowTypography.caption.copyWith(
                                  color: score >= 70 ? MeadowColors.success : MeadowColors.textTertiary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                'VSMS Standard Benchmark',
                                style: MeadowTypography.caption.copyWith(fontSize: 10, color: MeadowColors.textTertiary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeightLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: MeadowTypography.caption.copyWith(fontSize: 11, color: MeadowColors.textSecondary)),
      ],
    );
  }

  // =========================================================================
  // MILESTONES WORKSPACE SECTION
  // =========================================================================
  Widget _buildMilestonesSection(ChildModel activeChild) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Milestones & Developmental Targets', style: MeadowTypography.h2),
                  const SizedBox(height: 4),
                  Text(
                    'Core milestones tracked for your child\'s developmental age bracket',
                    style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                  ),
                ],
              ),
              const Icon(Icons.flag_circle_outlined, color: MeadowColors.primary, size: 26),
            ],
          ),
          const SizedBox(height: 20),

          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore != null
                ? _firestore!.collection('skillProfiles').doc(activeChild.childId).snapshots()
                : const Stream.empty(),
            builder: (context, profileSnap) {
              final profile = profileSnap.data?.data() ?? {};

              final milestones = [
                {
                  'domain': 'cognitive',
                  'title': 'Problem Solving & Cause-Effect Reasoning',
                  'desc': 'Identifies patterns and tests solutions during structured interactive play.',
                  'ageRange': '3–5 Years',
                },
                {
                  'domain': 'language',
                  'title': 'Expressive Vocabulary & Sentence Flow',
                  'desc': 'Communicates full thoughts using descriptive words and listening comprehension.',
                  'ageRange': '3–5 Years',
                },
                {
                  'domain': 'motor',
                  'title': 'Fine Motor Dexterity & Precision Grasp',
                  'desc': 'Exhibits steady hand-eye coordination in drawing and manipulation exercises.',
                  'ageRange': '3–5 Years',
                },
                {
                  'domain': 'social',
                  'title': 'Cooperative Play & Empathetic Sharing',
                  'desc': 'Demonstrates turn-taking and responsive social cues in group scenarios.',
                  'ageRange': '3–5 Years',
                },
                {
                  'domain': 'emotional',
                  'title': 'Emotional Expression & Self-Regulation',
                  'desc': 'Recognizes personal emotional states and employs calming strategies.',
                  'ageRange': '3–5 Years',
                },
                {
                  'domain': 'creative',
                  'title': 'Imaginative Role-Play & Storytelling',
                  'desc': 'Constructs original narratives and uses objects symbolically.',
                  'ageRange': '3–5 Years',
                },
              ];

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: milestones.length,
                separatorBuilder: (context, i) => const Divider(height: 1, color: MeadowColors.borderLight),
                itemBuilder: (context, i) {
                  final m = milestones[i];
                  final domain = m['domain']!;
                  final raw = profile[domain];
                  final score = (raw is num) ? raw.toDouble() : 0.0;
                  final isAchieved = score >= 70.0;
                  final isInProgress = score > 0.0 && score < 70.0;
                  final color = MeadowDomain.colorFor(domain);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAchieved
                                ? MeadowColors.primarySurface
                                : MeadowDomain.surfaceFor(domain),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isAchieved ? Icons.check_circle_rounded : MeadowDomain.iconFor(domain),
                            size: 18,
                            color: isAchieved ? MeadowColors.primary : color,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    m['title']!,
                                    style: MeadowTypography.label.copyWith(fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: MeadowDomain.surfaceFor(domain),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      MeadowDomain.labelFor(domain),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m['desc']!,
                                style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Target Age: ${m['ageRange']} • VSMS Standard Item',
                                style: MeadowTypography.caption.copyWith(fontSize: 10, color: MeadowColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAchieved
                                ? MeadowColors.primarySurface
                                : (isInProgress ? MeadowColors.goldSurface : MeadowColors.surfaceAlt),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isAchieved
                                  ? MeadowColors.primary.withOpacity(0.3)
                                  : (isInProgress ? MeadowColors.gold.withOpacity(0.3) : MeadowColors.borderLight),
                            ),
                          ),
                          child: Text(
                            isAchieved ? 'Achieved' : (isInProgress ? '${score.toInt()}% In Progress' : 'Target Milestone'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isAchieved
                                  ? MeadowColors.primary
                                  : (isInProgress ? MeadowColors.primaryDark : MeadowColors.textTertiary),
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
        ],
      ),
    );
  }

  // =========================================================================
  // ACTIVITY & MILESTONE HISTORY AUDIT TIMELINE
  // =========================================================================
  Widget _buildActivityHistorySection(ChildModel activeChild) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Activity History & Audit Ledger', style: MeadowTypography.h2),
                  const SizedBox(height: 4),
                  Text(
                    'Immutable audit ledger verifying genuine evaluations and practice sessions',
                    style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                  ),
                ],
              ),
              const Icon(Icons.history_edu, color: MeadowColors.primary, size: 24),
            ],
          ),
          const SizedBox(height: 16),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _scoreService.getScoreHistory(childId: activeChild.childId),
            builder: (context, snapshot) {
              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        const Icon(Icons.event_note_outlined, size: 36, color: MeadowColors.sage),
                        const SizedBox(height: 10),
                        Text(
                          'No activity events recorded yet',
                          style: MeadowTypography.label.copyWith(color: MeadowColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete interactive milestone games on mobile to see score entries verified here.',
                          style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.take(8).length,
                separatorBuilder: (context, i) => const Divider(height: 1, color: MeadowColors.borderLight),
                itemBuilder: (context, i) {
                  final e = events[i];
                  final title = e['activityTitle'] ?? 'Activity Completed';
                  final domain = (e['skillDomain'] ?? 'general').toString();
                  final source = (e['activitySource'] ?? 'preset').toString();
                  final delta = (e['appliedScoreDelta'] is num) ? (e['appliedScoreDelta'] as num).toDouble() : 0.0;
                  final time = (e['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final isAi = source == 'ai_generated';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: MeadowDomain.surfaceFor(domain),
                          child: Icon(MeadowDomain.iconFor(domain), size: 16, color: MeadowDomain.colorFor(domain)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: MeadowTypography.label.copyWith(fontSize: 13)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '${MeadowDomain.labelFor(domain)} • ${DateFormat.yMMMd().format(time)}',
                                    style: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isAi ? MeadowColors.cognitiveSurface : MeadowColors.primarySurface,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isAi ? 'AI Guided (0.5x)' : 'Measured (1.0x)',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: isAi ? MeadowColors.cognitive : MeadowColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${delta.toStringAsFixed(1)} pts',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: MeadowColors.success,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SUPPORTING INTELLIGENCE SIDE PANEL CARDS
  // =========================================================================
  Widget _buildMobileAppSidebarCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MeadowColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_android_rounded, color: MeadowColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mobile App Companion', style: MeadowTypography.label.copyWith(fontSize: 14)),
                    Text('LittleLumin is Mobile-Only for Parents', style: MeadowTypography.caption.copyWith(fontSize: 10, color: MeadowColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Interactive activities, bedtime stories, and tactile milestone play are optimized for touchscreens on our mobile app. This desktop website gives you complete visibility into long-term growth and specialist guidance.',
            style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildStoreBadge(Icons.android, 'Google Play', 'Mobile App')),
              const SizedBox(width: 8),
              Expanded(child: _buildStoreBadge(Icons.apple, 'App Store', 'Mobile App')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAppNoticeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: MeadowColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MeadowColors.sageLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded, color: MeadowColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textPrimary),
                children: [
                  const TextSpan(
                    text: 'LittleLumin is Mobile-Only for Parents • Desktop Companion Active: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: 'Interactive activities and daily milestone play are available on mobile.',
                    style: TextStyle(color: MeadowColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreBadge(IconData icon, String storeName, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MeadowColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MeadowColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MeadowColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(storeName, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: MeadowColors.textPrimary)),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 8, color: MeadowColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ASSIGNED GUIDE STATUS CARD
  // =========================================================================
  Widget _buildGuideCaseCard(ChildModel activeChild, User user) {
    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getParentCasesStream(user.uid, childId: activeChild.childId),
      builder: (context, caseSnap) {
        final cases = caseSnap.data ?? [];
        if (cases.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MeadowColors.borderLight),
              boxShadow: MeadowShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 28, color: MeadowColors.sage),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('No Learning Guide Assigned Yet', style: MeadowTypography.h3.copyWith(fontSize: 15)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Request a verified specialist through the mobile app to receive clinical consultation and personalized growth recommendations.',
                  style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                ),
              ],
            ),
          );
        }

        final activeCase = cases.firstWhere(
          (c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active,
          orElse: () => cases.first,
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: MeadowColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MeadowColors.borderLight),
            boxShadow: MeadowShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: MeadowColors.primarySurface,
                    child: Text(
                      activeCase.specialistName.isNotEmpty ? activeCase.specialistName[0].toUpperCase() : 'S',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: MeadowColors.primary, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activeCase.specialistName, style: MeadowTypography.h3.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          activeCase.specialistRole.replaceAll('_', ' ').toUpperCase(),
                          style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: activeCase.status == CaseStatus.accepted || activeCase.status == CaseStatus.active
                          ? MeadowColors.primarySurface
                          : MeadowColors.goldSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      activeCase.status.name.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: activeCase.status == CaseStatus.accepted || activeCase.status == CaseStatus.active
                            ? MeadowColors.primary
                            : MeadowColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Consultation Purpose: ${activeCase.purpose}',
                style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isChatOpen = true),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message Guide'),
                  style: MeadowButtons.small(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // RECOMMENDATIONS SIDE PANEL
  // =========================================================================
  Widget _buildRecommendationsSidePanel(ChildModel activeChild) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LLG Recommendations', style: MeadowTypography.h3.copyWith(fontSize: 15)),
              const Icon(Icons.lightbulb_outline, size: 18, color: MeadowColors.primary),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<RecommendationModel>>(
            stream: RecommendationService().getChildRecommendationsStream(activeChild.childId),
            builder: (context, snapshot) {
              final recs = snapshot.data ?? [];
              if (recs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No personalized recommendations assigned yet for ${activeChild.name}.',
                      textAlign: TextAlign.center,
                      style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recs.take(4).length,
                separatorBuilder: (context, i) => const Divider(height: 16, color: MeadowColors.borderLight),
                itemBuilder: (context, i) => _buildRecommendationCard(recs[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(RecommendationModel rec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(rec.title, style: MeadowTypography.label.copyWith(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: MeadowDomain.surfaceFor(rec.skillDomain),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rec.status.name.replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  color: MeadowDomain.colorFor(rec.skillDomain),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'By ${rec.llgName} • Domain: ${MeadowDomain.labelFor(rec.skillDomain)}',
          style: MeadowTypography.caption.copyWith(fontSize: 10, color: MeadowColors.textSecondary),
        ),
        if (rec.rationale.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(rec.rationale, style: MeadowTypography.body.copyWith(fontSize: 11, color: MeadowColors.textPrimary)),
        ],
        if (rec.hasParentResponded) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MeadowColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 12, color: MeadowColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Responded: "${rec.parentFeedback ?? rec.parentResponse.name}"',
                    style: MeadowTypography.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // CONSULTATIONS SIDE PANEL
  // =========================================================================
  Widget _buildConsultationsSidePanel(ChildModel activeChild) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Consultation Summaries', style: MeadowTypography.h3.copyWith(fontSize: 15)),
              const Icon(Icons.assignment_outlined, size: 18, color: MeadowColors.primary),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<ConsultationSummaryModel>>(
            stream: ConsultationSummaryService().getChildSummariesStream(activeChild.childId),
            builder: (context, snapshot) {
              final summaries = snapshot.data ?? [];
              if (summaries.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No external consultation summaries logged yet.',
                      textAlign: TextAlign.center,
                      style: MeadowTypography.body.copyWith(fontSize: 12, color: MeadowColors.textSecondary),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: summaries.take(3).length,
                separatorBuilder: (context, i) => const Divider(height: 16, color: MeadowColors.borderLight),
                itemBuilder: (context, i) => _buildConsultationSummaryCard(summaries[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationSummaryCard(ConsultationSummaryModel s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MeadowColors.primarySurface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    s.consultationMode.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(color: MeadowColors.primary, fontWeight: FontWeight.bold, fontSize: 9),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.llgName,
                  style: MeadowTypography.label.copyWith(fontSize: 12),
                ),
              ],
            ),
            Text(
              DateFormat.yMMMd().format(s.consultationDate),
              style: MeadowTypography.caption.copyWith(fontSize: 10, color: MeadowColors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Focus: ${s.consultationReason}', style: MeadowTypography.body.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(s.guidanceProvided, style: MeadowTypography.body.copyWith(fontSize: 11, color: MeadowColors.textSecondary)),
        if (s.agreedFollowUpActions.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...s.agreedFollowUpActions.take(2).map((a) => Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text('• $a', style: MeadowTypography.caption.copyWith(fontSize: 10, color: MeadowColors.primary)),
          )),
        ],
      ],
    );
  }

  // =========================================================================
  // FLOATING SECURE CHAT LAUNCHER & PANEL
  // =========================================================================
  Widget _buildFloatingChatLauncher(ChildModel activeChild, User user) {
    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getParentCasesStream(user.uid, childId: activeChild.childId),
      builder: (context, snapshot) {
        final cases = snapshot.data ?? [];
        final hasActiveCase = cases.any((c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active);

        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(30),
          color: MeadowColors.primary,
          child: InkWell(
            onTap: () => setState(() => _isChatOpen = true),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 9),
                  Text(
                    hasActiveCase ? 'Chat with Guide' : 'Guide Chat',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (hasActiveCase) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingChatPanel(ChildModel activeChild, User user) {
    final screenSize = MediaQuery.of(context).size;
    final panelWidth = min(390.0, screenSize.width - 32);
    final panelHeight = min(530.0, screenSize.height - 80);

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getParentCasesStream(user.uid, childId: activeChild.childId),
      builder: (context, snapshot) {
        final cases = snapshot.data ?? [];
        final SpecialistCaseModel? targetCase = cases.isNotEmpty
            ? cases.firstWhere(
                (c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active,
                orElse: () => cases.first,
              )
            : null;

        return Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: Container(
            width: panelWidth,
            height: panelHeight,
            decoration: BoxDecoration(
              color: MeadowColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MeadowColors.borderLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Chat Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: MeadowColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: MeadowColors.sageLight,
                        child: Text(
                          targetCase != null && targetCase.specialistName.isNotEmpty
                              ? targetCase.specialistName[0].toUpperCase()
                              : 'G',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: MeadowColors.primaryDark, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetCase?.specialistName ?? 'LittleLumin Guide',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'For ${activeChild.name} • Secure DPDP Protected',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        tooltip: 'Close chat',
                        onPressed: () => setState(() => _isChatOpen = false),
                      ),
                    ],
                  ),
                ),

                // Message Body
                Expanded(
                  child: targetCase == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_bubble_outline, size: 40, color: MeadowColors.sage),
                                const SizedBox(height: 12),
                                Text(
                                  'No active consultation case',
                                  style: MeadowTypography.label,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Request an LLG guide from the mobile app to begin two-way secure messaging.',
                                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : StreamBuilder<List<MessageModel>>(
                          stream: _messagingService.getMessagesStream(targetCase.caseId),
                          builder: (context, msgSnap) {
                            if (msgSnap.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: MeadowColors.primary));
                            }

                            final messages = msgSnap.data ?? [];
                            if (messages.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.forum_outlined, size: 36, color: MeadowColors.sage),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Start a conversation with ${targetCase.specialistName}',
                                        style: MeadowTypography.label,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ask questions about recommendations, milestone observations, or activity progress.',
                                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_chatScrollController.hasClients) {
                                _chatScrollController.animateTo(
                                  _chatScrollController.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                              }
                            });

                            return ListView.builder(
                              controller: _chatScrollController,
                              padding: const EdgeInsets.all(12),
                              itemCount: messages.length,
                              itemBuilder: (context, i) {
                                final msg = messages[i];
                                final isMe = msg.senderId == user.uid;

                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    constraints: BoxConstraints(maxWidth: panelWidth * 0.75),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMe ? MeadowColors.primary : MeadowColors.surfaceAlt,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(12),
                                        topRight: const Radius.circular(12),
                                        bottomLeft: Radius.circular(isMe ? 12 : 2),
                                        bottomRight: Radius.circular(isMe ? 2 : 12),
                                      ),
                                      border: isMe ? null : Border.all(color: MeadowColors.borderLight),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.content,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: isMe ? Colors.white : MeadowColors.textPrimary,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          DateFormat.jm().format(msg.timestamp),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9,
                                            color: isMe ? Colors.white.withOpacity(0.7) : MeadowColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // Chat Input Bar
                if (targetCase != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: MeadowColors.surface,
                      border: Border(top: BorderSide(color: MeadowColors.borderLight)),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatInputController,
                            style: MeadowTypography.body.copyWith(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: MeadowTypography.body.copyWith(fontSize: 13, color: MeadowColors.textTertiary),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onSubmitted: (_) => _handleSendMessage(targetCase, user),
                          ),
                        ),
                        IconButton(
                          icon: _isSendingMessage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: MeadowColors.primary),
                                )
                              : const Icon(Icons.send_rounded, color: MeadowColors.primary, size: 20),
                          onPressed: _isSendingMessage ? null : () => _handleSendMessage(targetCase, user),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSendMessage(SpecialistCaseModel targetCase, User user) async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _isSendingMessage) return;

    setState(() => _isSendingMessage = true);
    try {
      await _messagingService.sendMessage(
        caseId: targetCase.caseId,
        childId: targetCase.childId,
        senderId: user.uid,
        senderName: user.displayName ?? 'Parent',
        senderRole: 'parent',
        recipientId: targetCase.specialistId,
        content: text,
      );
      _chatInputController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e'), backgroundColor: MeadowColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  // =========================================================================
  // NO CHILDREN STATE (Encourages adding child on mobile)
  // =========================================================================
  Widget _buildNoChildrenDashboard(User user) {
    return Column(
      children: [
        _buildDesktopWebHeader(
          user,
          ChildModel(childId: '', name: 'No Profile', dateOfBirth: DateTime.now(), gender: '', parentId: user.uid, createdAt: DateTime.now()),
          [],
          true,
        ),
        _buildMobileAppNoticeBanner(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: MeadowColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.child_care_rounded, size: 56, color: MeadowColors.primary),
                  ),
                  const SizedBox(height: 20),
                  Text('No Child Profiles Connected', style: MeadowTypography.h2),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(
                      'Please open the LittleLumin mobile app on your phone to add your child and complete the baseline developmental milestone assessment.',
                      textAlign: TextAlign.center,
                      style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
