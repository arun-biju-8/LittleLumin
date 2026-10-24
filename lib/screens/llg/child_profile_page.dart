// lib/screens/llg/child_profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../models/activity_model.dart';
import '../../models/recommendation_model.dart';
import '../../models/contact_consent_model.dart';
import '../../models/specialist_report_model.dart';

import '../../services/score_ledger_service.dart';
import '../../services/specialist_case_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/consultation_summary_service.dart';
import '../../services/contact_consent_service.dart';
import '../../services/specialist_report_service.dart';
import '../../services/activity_service.dart';

import '../../widgets/activity_origin_badge.dart';
import '../chat/chat_screen.dart';
import 'send_recommendation_page.dart';
import 'add_observation_page.dart';

class ChildProfilePage extends StatefulWidget {
  final SpecialistCaseModel caseModel;
  final ChildModel? initialChild;
  final VoidCallback? onCaseUpdated;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final SpecialistCaseService? caseService;
  final RecommendationService? recService;
  final ConsultationSummaryService? consultationService;
  final ContactConsentService? consentService;
  final SpecialistReportService? reportService;
  final ActivityService? activityService;
  final ScoreLedgerService? scoreLedgerService;

  const ChildProfilePage({
    super.key,
    required this.caseModel,
    this.initialChild,
    this.onCaseUpdated,
    this.firestore,
    this.auth,
    this.caseService,
    this.recService,
    this.consultationService,
    this.consentService,
    this.reportService,
    this.activityService,
    this.scoreLedgerService,
  });

  @override
  State<ChildProfilePage> createState() => _ChildProfilePageState();
}

class _ChildProfilePageState extends State<ChildProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  late SpecialistCaseService _caseService;
  late RecommendationService _recService;
  late ConsultationSummaryService _consultationService;
  late ContactConsentService _consentService;
  late SpecialistReportService _reportService;
  late ActivityService _activityService;
  late ScoreLedgerService _scoreLedgerService;

  late SpecialistCaseModel _currentCase;
  late ChildModel _currentChild;
  bool _isGeneratingReport = false;

  // Colors matching the portal identity
  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorCard = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorEmerald = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  static const List<String> _tabNames = [
    'Overview',
    'Activities',
    'Feedback',
    'Reports',
    'Concerns',
    'Recommendations',
    'Actions',
    'History',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabNames.length, vsync: this);
    _currentCase = widget.caseModel;
    _currentChild = widget.initialChild ??
        ChildModel(
          childId: widget.caseModel.childId,
          parentId: widget.caseModel.parentId,
          name: widget.caseModel.childName,
          dateOfBirth: DateTime.now().subtract(Duration(days: widget.caseModel.childAgeYears * 365)),
          gender: 'Child',
          createdAt: widget.caseModel.createdAt,
        );

    try {
      _firestore = widget.firestore ?? FirebaseFirestore.instance;
      _auth = widget.auth ?? FirebaseAuth.instance;
    } catch (_) {
      _firestore = null;
      _auth = null;
    }

    _caseService = widget.caseService ?? SpecialistCaseService(firestore: _firestore);
    _recService = widget.recService ?? RecommendationService(firestore: _firestore, auth: _auth);
    _consultationService = widget.consultationService ?? ConsultationSummaryService(firestore: _firestore, auth: _auth);
    _consentService = widget.consentService ?? ContactConsentService(firestore: _firestore, auth: _auth);
    _reportService = widget.reportService ?? SpecialistReportService(firestore: _firestore);
    _activityService = widget.activityService ?? ActivityService(firestore: _firestore);
    _scoreLedgerService = widget.scoreLedgerService ?? ScoreLedgerService(firestore: _firestore);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      children: [
        _buildHeaderWorkspace(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildActivitiesTab(),
              _buildFeedbackTab(),
              _buildReportsTab(),
              _buildConcernsTab(),
              _buildRecommendationsTab(),
              _buildActionsTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );

    if (_firestore == null) {
      return Scaffold(
        backgroundColor: colorNavy,
        appBar: _buildAppBar(),
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: colorNavy,
      appBar: _buildAppBar(),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore!.collection('specialistCases').doc(_currentCase.caseId).snapshots(),
        builder: (context, caseSnap) {
          if (caseSnap.hasData && caseSnap.data!.exists && caseSnap.data!.data() != null) {
            _currentCase = SpecialistCaseModel.fromMap(caseSnap.data!.data()!, caseSnap.data!.id);
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore!.collection('children').doc(_currentCase.childId).snapshots(),
            builder: (context, childSnap) {
              if (childSnap.hasData && childSnap.data!.exists && childSnap.data!.data() != null) {
                _currentChild = ChildModel.fromMap({...childSnap.data!.data()!, 'childId': childSnap.data!.id});
              }

              return content;
            },
          );
        },
      ),
    );
  }

  // =========================================================================
  // APP BAR
  // =========================================================================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: colorSlate,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleSpacing: 0,
      title: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: colorTeal),
            label: Text(
              'My Cases',
              style: GoogleFonts.inter(fontSize: 13, color: colorTeal, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          const Text('•', style: TextStyle(color: colorBorder)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_currentChild.name} • Child Profile & Clinical Workspace',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (_currentCase.canAccessChildData)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _openChat,
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Direct Messages'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: colorBorder, height: 1),
      ),
    );
  }

  // =========================================================================
  // HEADER WORKSPACE (CHILD INFO, PARENT INFO, CASE & DPDP CONSENT)
  // =========================================================================
  Widget _buildHeaderWorkspace() {
    final isPermitted = _currentCase.canAccessChildData;
    final isRevoked = _currentCase.status == CaseStatus.revoked;

    Color statusColor;
    String statusText;
    if (isRevoked) {
      statusColor = Colors.redAccent;
      statusText = 'REVOKED';
    } else if (isPermitted) {
      statusColor = colorEmerald;
      statusText = 'ACTIVE';
    } else if (_currentCase.status == CaseStatus.pending) {
      statusColor = colorAmber;
      statusText = 'PENDING';
    } else {
      statusColor = colorTextMuted;
      statusText = _currentCase.status.name.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(bottom: BorderSide(color: colorBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Access Warning Banner if not permitted
          if (!isPermitted)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gpp_bad_outlined, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRevoked
                          ? 'Parent revoked consultation consent. Clinical records and score history are locked.'
                          : 'Pending parental consent. Detailed clinical data is restricted until authorized under DPDP guidelines.',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final childInfo = Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorTeal.withOpacity(0.2),
                    child: Text(
                      _currentChild.name.isNotEmpty ? _currentChild.name[0].toUpperCase() : 'C',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: colorTeal),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _currentChild.name,
                                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentChild.ageYears} years old • ${_currentChild.gender} • Case ID: ${_currentCase.caseId}',
                          style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final metaInfo = Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildMetaPill(
                    icon: Icons.person_outline,
                    label: 'Parent',
                    value: _currentCase.parentName,
                  ),
                  _buildMetaPill(
                    icon: Icons.psychology_outlined,
                    label: 'Focus',
                    value: _currentCase.purpose,
                  ),
                  _buildMetaPill(
                    icon: Icons.shield_outlined,
                    label: 'DPDP Notice',
                    value: _currentCase.consentNoticeVersion.startsWith('v') ? _currentCase.consentNoticeVersion : 'v${_currentCase.consentNoticeVersion}',
                    highlight: isPermitted,
                  ),
                  _buildMetaPill(
                    icon: Icons.timer_outlined,
                    label: 'Consent Valid Until',
                    value: _currentCase.consentExpiresAt != null
                        ? DateFormat.yMMMd().format(_currentCase.consentExpiresAt!)
                        : '90 days from grant',
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: childInfo),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: metaInfo),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    childInfo,
                    const SizedBox(height: 16),
                    metaInfo,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? colorEmerald.withOpacity(0.4) : colorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: highlight ? colorEmerald : colorTeal),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 9, color: colorTextMuted, fontWeight: FontWeight.bold)),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: highlight ? colorEmerald : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB BAR (8 DEDICATED TABS)
  // =========================================================================
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(bottom: BorderSide(color: colorBorder)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: colorTeal,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: colorTextMuted,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: _tabNames.map((name) => Tab(text: name)).toList(),
      ),
    );
  }

  // =========================================================================
  // TAB 1: OVERVIEW (CONCISE SUMMARY OF PROGRESS, FEEDBACK, CONCERNS, ACTIONS)
  // =========================================================================
  Widget _buildOverviewTab() {
    final hasScoresPermission = _currentCase.isCategoryAuthorized('skill_scores');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Developmental Domains Progress
          _buildCardContainer(
            title: 'Developmental Domain Progress (6 Core Domains)',
            subtitle: hasScoresPermission
                ? 'Authorized clinical tracking under DPDP consent'
                : 'Consent required to view developmental score breakdown',
            trailing: hasScoresPermission
                ? const Icon(Icons.check_circle_outline, size: 18, color: colorEmerald)
                : const Icon(Icons.lock_outline, size: 18, color: colorAmber),
            child: hasScoresPermission
                ? StreamBuilder<DocumentSnapshot>(
                    stream: _firestore?.collection('skillProfiles').doc(_currentChild.childId).snapshots() ?? const Stream.empty(),
                    builder: (context, snapshot) {
                      final data = (snapshot.hasData && snapshot.data?.data() != null)
                          ? snapshot.data!.data() as Map<String, dynamic>
                          : <String, dynamic>{
                              'cognitive': _currentChild.vabsScores?['Cognitive'] ?? 78.5,
                              'language': _currentChild.vabsScores?['Language'] ?? 64.0,
                              'motor': _currentChild.vabsScores?['Motor'] ?? 72.0,
                              'social': _currentChild.vabsScores?['Social'] ?? 68.0,
                              'emotional': _currentChild.vabsScores?['Emotional'] ?? 75.0,
                              'creative': _currentChild.vabsScores?['Creative'] ?? 82.0,
                            };
                      final domains = ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative'];

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;
                          final items = domains.map((domain) {
                            final score = (data[domain] is num) ? (data[domain] as num).toDouble() : 0.0;
                            final isMastered = score >= 70.0;
                            final barColor = score < 40 ? Colors.redAccent : (isMastered ? colorEmerald : colorAmber);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorNavy,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colorBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        domain[0].toUpperCase() + domain.substring(1),
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      Row(
                                        children: [
                                          if (isMastered)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              margin: const EdgeInsets.only(right: 6),
                                              decoration: BoxDecoration(
                                                color: colorEmerald.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text('Mastered 🏆', style: GoogleFonts.inter(fontSize: 10, color: colorEmerald, fontWeight: FontWeight.bold)),
                                            ),
                                          Text(
                                            '${score.toStringAsFixed(1)}%',
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: barColor),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (score / 100).clamp(0.0, 1.0),
                                      backgroundColor: colorSlate,
                                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList();

                          if (isWide) {
                            return Wrap(
                              spacing: 16,
                              runSpacing: 12,
                              children: items.map((w) => SizedBox(width: (constraints.maxWidth - 16) / 2, child: w)).toList(),
                            );
                          } else {
                            return Column(children: items);
                          }
                        },
                      );
                    },
                  )
                : _buildRestrictedNotice('skill_scores'),
          ),

          const SizedBox(height: 24),

          // 2. AI Developmental Insights
          _buildCardContainer(
            title: 'AI Developmental Insights & Summary',
            subtitle: 'Real-time synthesis across activity ledgers and developmental milestones',
            trailing: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF9333EA), size: 20),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _loadChildInsightSummary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                }

                final insight = snapshot.data ?? {};
                final highest = insight['highestDomain'] ?? 'Cognitive';
                final lowest = insight['lowestDomain'] ?? 'Motor';
                final totalActivities = insight['totalActivities'] ?? 0;
                final struggleCount = insight['struggles'] ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Color(0xFF818CF8), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_currentChild.name} demonstrates strongest developmental consistency in $highest. '
                              'Targeted practice in $lowest will help achieve cross-domain milestone equilibrium. '
                              'Ledger logs confirm $totalActivities activities completed with $struggleCount recorded struggle events.',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _tabController.animateTo(3), // Navigate to Reports
                          icon: const Icon(Icons.description_outlined, size: 16),
                          label: const Text('View Full AI Reports'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _tabController.animateTo(6), // Navigate to Actions
                          icon: const Icon(Icons.flash_on_outlined, size: 16, color: colorTeal),
                          label: const Text('Specialist Quick Actions', style: TextStyle(color: colorTeal)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: colorTeal)),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 3. Recent Activities & Recent Parent Feedback side-by-side or stacked
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final activitiesWidget = _buildRecentActivitiesPreview();
              final feedbackWidget = _buildRecentFeedbackPreview();

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: activitiesWidget),
                    const SizedBox(width: 20),
                    Expanded(child: feedbackWidget),
                  ],
                );
              } else {
                return Column(
                  children: [
                    activitiesWidget,
                    const SizedBox(height: 20),
                    feedbackWidget,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesPreview() {
    return _buildCardContainer(
      title: 'Recent Activity History',
      subtitle: 'Latest ledger-verified learning activities',
      trailing: TextButton(
        onPressed: () => _tabController.animateTo(1),
        child: Text('View All', style: GoogleFonts.inter(color: colorTeal, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _firestore == null ? Future.value(<Map<String, dynamic>>[]) : _scoreLedgerService.getScoreHistory(childId: _currentChild.childId),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return _buildEmptyState('No activities completed yet.', Icons.sports_esports_outlined);
          }

          return Column(
            children: events.take(3).map((e) {
              final title = e['activityTitle'] ?? 'Activity';
              final domain = e['skillDomain'] ?? 'skill';
              final delta = (e['appliedScoreDelta'] is num) ? (e['appliedScoreDelta'] as num).toDouble() : 0.0;
              final isPositive = delta >= 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorNavy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('$domain • Level ${e['levelAtTime'] ?? 1}', style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted)),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}${delta.toStringAsFixed(1)} pts',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? colorEmerald : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildRecentFeedbackPreview() {
    return _buildCardContainer(
      title: 'Recent Parent Feedback',
      subtitle: 'Observations and home engagement reports',
      trailing: TextButton(
        onPressed: () => _tabController.animateTo(2),
        child: Text('View All', style: GoogleFonts.inter(color: colorTeal, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _firestore == null ? Future.value(<Map<String, dynamic>>[]) : _scoreLedgerService.getScoreHistory(childId: _currentChild.childId),
        builder: (context, snapshot) {
          final allEvents = snapshot.data ?? [];
          final feedbackEvents = allEvents.where((e) => e['feedback'] is Map).toList();

          if (feedbackEvents.isEmpty) {
            return _buildEmptyState('No parent feedback recorded yet.', Icons.rate_review_outlined);
          }

          return Column(
            children: feedbackEvents.take(2).map((e) {
              final fb = e['feedback'] as Map<String, dynamic>;
              final response = fb['childResponse'] ?? 'Completed';
              final notes = fb['notes'] ?? '';
              final title = e['activityTitle'] ?? 'Activity';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorNavy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorTeal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(response, style: GoogleFonts.inter(fontSize: 10, color: colorTeal, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"$notes"',
                        style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: colorTextMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // =========================================================================
  // TAB 2: ACTIVITIES (HISTORY, SCORES, ORIGIN BADGES, ASSIGNMENT)
  // =========================================================================
  Widget _buildActivitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activities & Developmental History',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track completed activities, mastery status, and assign curated or AI exercises.',
                      style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showAssignActivityModal,
                icon: const Icon(Icons.add_task_outlined, size: 16),
                label: const Text('Assign Activity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Ledger Activity History
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _firestore == null ? Future.value(<Map<String, dynamic>>[]) : _scoreLedgerService.getScoreHistory(childId: _currentChild.childId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }

              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return _buildEmptyState('No activity completions recorded yet on the ledger.', Icons.history_edu_outlined);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final e = events[index];
                  final title = e['activityTitle'] ?? 'Activity';
                  final domain = e['skillDomain'] ?? 'cognitive';
                  final delta = (e['appliedScoreDelta'] is num) ? (e['appliedScoreDelta'] as num).toDouble() : 0.0;
                  final scoreAfter = (e['scoreAfter'] is num) ? (e['scoreAfter'] as num).toDouble() : 0.0;
                  final source = e['activitySource'] ?? 'preset';
                  final isMastered = scoreAfter >= 70.0;

                  // Determine ActivityOrigin
                  ActivityOrigin origin;
                  if (source == 'ai_generated' || source == 'ai') {
                    origin = ActivityOrigin.aiGenerated;
                  } else if (source == 'llg_recommended' || source == 'llg_assigned') {
                    origin = ActivityOrigin.llgRecommended;
                  } else {
                    origin = ActivityOrigin.preset;
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: colorTeal.withOpacity(0.15),
                          child: Icon(
                            isMastered ? Icons.workspace_premium : Icons.play_lesson_outlined,
                            color: isMastered ? colorEmerald : colorTeal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  ActivityOriginBadge(originOverride: origin, compact: true),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Domain: ${domain[0].toUpperCase()}${domain.substring(1)} • Level ${e['levelAtTime'] ?? 1}',
                                    style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isMastered ? colorEmerald : colorAmber).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isMastered ? 'Mastered (≥70%) 🏆' : 'Completed (Practice needed)',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isMastered ? colorEmerald : colorAmber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} pts',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: delta >= 0 ? colorEmerald : Colors.redAccent,
                              ),
                            ),
                            Text(
                              'Score: ${scoreAfter.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                            ),
                          ],
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

  void _showAssignActivityModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        String selectedDomain = 'cognitive';
        final titleCtrl = TextEditingController();
        final descCtrl = TextEditingController();
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: colorSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Assign Activity to ${_currentChild.name}',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Activity Title', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('e.g., Bilateral Ball Rolling'),
                      ),
                      const SizedBox(height: 14),
                      Text('Developmental Domain', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedDomain,
                        dropdownColor: colorSlate,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(''),
                        items: ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d[0].toUpperCase() + d.substring(1))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedDomain = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Instructions & Notes for Parent', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: descCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Step-by-step guidance for home practice...'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSubmitting = true);
                          final user = _auth?.currentUser;

                          final newActivity = ActivityModel(
                            id: '',
                            title: titleCtrl.text.trim(),
                            skillType: selectedDomain,
                            shortDescription: descCtrl.text.trim(),
                            childId: _currentChild.childId,
                            ageGroup: [_currentChild.ageYears],
                            difficulty: 'Medium',
                            duration: 15,
                            instructions: [descCtrl.text.trim()],
                            learningGoals: ['Strengthen $selectedDomain milestones'],
                            materials: ['Home play materials'],
                            category: selectedDomain,
                            tags: ['specialist_assigned', 'llg_recommended'],
                            origin: 'llg_recommended',
                            createdBy: user?.uid ?? 'specialist',
                            createdByName: _currentCase.specialistName,
                            createdAt: DateTime.now(),
                          );

                          await _activityService.createActivity(newActivity);
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Activity successfully assigned to child!'), backgroundColor: colorEmerald),
                            );
                            setState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Assign to Child', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // TAB 3: FEEDBACK (PARENT FEEDBACK HISTORY & ASSOCIATED NOTES)
  // =========================================================================
  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parent Feedback History',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Detailed reports submitted by parents after completed activities and recommendation sessions.',
            style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
          ),
          const SizedBox(height: 20),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _firestore == null ? Future.value(<Map<String, dynamic>>[]) : _scoreLedgerService.getScoreHistory(childId: _currentChild.childId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }

              final allEvents = snapshot.data ?? [];
              final feedbackItems = allEvents.where((e) => e['feedback'] is Map).toList();

              if (feedbackItems.isEmpty) {
                return _buildEmptyState('No parent feedback entries found.', Icons.rate_review_outlined);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: feedbackItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final e = feedbackItems[index];
                  final fb = e['feedback'] as Map<String, dynamic>;
                  final title = e['activityTitle'] ?? 'Activity';
                  final domain = e['skillDomain'] ?? 'skill';
                  final childResponse = fb['childResponse'] ?? 'Completed';
                  final engagement = fb['engagement'] ?? 'Moderate';
                  final difficulty = fb['difficulty'] ?? 'Appropriate';
                  final confidence = fb['confidence'] ?? 'Good';
                  final notes = fb['notes'] ?? '';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorTeal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                childResponse,
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTeal),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            _buildFeedbackChip('Domain', domain),
                            _buildFeedbackChip('Engagement', engagement),
                            _buildFeedbackChip('Perceived Difficulty', difficulty),
                            _buildFeedbackChip('Parent Confidence', confidence),
                          ],
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorNavy,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.format_quote_rounded, color: colorTextMuted, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    notes,
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildFeedbackChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorNavy,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colorBorder),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
      ),
    );
  }

  // =========================================================================
  // TAB 4: REPORTS (AI-GENERATED REPORTS, HISTORY, STATUS & VIEWING)
  // =========================================================================
  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Generated Developmental Reports',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Synthesizes domain scores, milestone velocity, and specialist observations into formal clinical reports.',
                      style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _isGeneratingReport ? null : _generateAIReport,
                icon: _isGeneratingReport
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(_isGeneratingReport ? 'Synthesizing...' : 'Generate New AI Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          StreamBuilder<List<SpecialistReportModel>>(
            stream: _firestore == null ? Stream.value(<SpecialistReportModel>[]) : _reportService.getReportsStream(_currentChild.childId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }

              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return _buildEmptyState(
                  'No reports generated yet for this child. Click "Generate New AI Report" above to synthesize assessment data.',
                  Icons.assignment_outlined,
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reports.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  Color statusColor;
                  switch (report.status) {
                    case SpecialistReportStatus.finalized:
                      statusColor = colorTeal;
                      break;
                    case SpecialistReportStatus.shared:
                      statusColor = colorEmerald;
                      break;
                    case SpecialistReportStatus.draft:
                      statusColor = colorAmber;
                      break;
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.title,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Generated ${DateFormat.yMMMd().add_jm().format(report.generatedAt)} • Specialist: ${report.specialistName}',
                                    style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                report.status.name.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          report.summary,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showDetailedReportDialog(report),
                              icon: const Icon(Icons.visibility_outlined, size: 14, color: colorTeal),
                              label: const Text('View Full Report', style: TextStyle(color: colorTeal, fontSize: 12)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: colorTeal)),
                            ),
                            if (!report.isShared) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _shareReport(report),
                                icon: const Icon(Icons.send_rounded, size: 14),
                                label: const Text('Share with Parent', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(backgroundColor: colorEmerald, foregroundColor: Colors.white),
                              ),
                            ],
                          ],
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

  Future<void> _generateAIReport() async {
    setState(() => _isGeneratingReport = true);
    final user = _auth?.currentUser;
    try {
      final report = await _reportService.generateReport(
        caseModel: _currentCase,
        child: _currentChild,
        specialistId: user?.uid ?? 'specialist',
        specialistName: _currentCase.specialistName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ AI Developmental Assessment Report generated and saved!'),
            backgroundColor: colorEmerald,
          ),
        );
        setState(() => _isGeneratingReport = false);
        _showDetailedReportDialog(report);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingReport = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error generating report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showDetailedReportDialog(SpecialistReportModel report) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(report.title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(icon: const Icon(Icons.close, color: colorTextMuted), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & meta
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorTeal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Status: ${report.status.name.toUpperCase()}',
                            style: GoogleFonts.inter(fontSize: 11, color: colorTeal, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Text('Generated: ${DateFormat.yMMMd().format(report.generatedAt)}',
                          style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                    ],
                  ),
                  const Divider(color: colorBorder, height: 24),

                  // Summary
                  Text('Executive Summary', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(report.summary, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4)),

                  const SizedBox(height: 16),
                  Text('Domain Scores Matrix', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: report.domainScores.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(6)),
                        child: Text('${entry.key[0].toUpperCase()}${entry.key.substring(1)}: ${entry.value.toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(fontSize: 11, color: entry.value >= 70 ? colorEmerald : Colors.white)),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  Text('Identified Strengths', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colorEmerald)),
                  const SizedBox(height: 6),
                  ...report.strengths.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: colorEmerald, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(s, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70))),
                          ],
                        ),
                      )),

                  const SizedBox(height: 16),
                  Text('Areas for Guided Growth', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colorAmber)),
                  const SizedBox(height: 6),
                  ...report.growthAreas.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: colorAmber, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(g, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70))),
                          ],
                        ),
                      )),

                  const SizedBox(height: 16),
                  Text('AI Action Recommendations', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: colorTeal)),
                  const SizedBox(height: 6),
                  ...report.recommendations.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: colorTeal, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(r, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70))),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: GoogleFonts.inter(color: colorTextMuted)),
            ),
            if (!report.isShared)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _shareReport(report);
                },
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Share with Parent'),
                style: ElevatedButton.styleFrom(backgroundColor: colorEmerald, foregroundColor: Colors.white),
              ),
          ],
        );
      },
    );
  }

  Future<void> _shareReport(SpecialistReportModel report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Share Report with Parent', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('This will make the developmental report accessible to ${_currentCase.parentName} in their parent portal.',
            style: GoogleFonts.inter(color: colorTextMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colorEmerald),
            child: const Text('Confirm Share', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _reportService.shareReportWithParent(
        reportId: report.id,
        parentId: _currentChild.parentId,
        childName: _currentChild.name,
        specialistName: _currentCase.specialistName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Report shared with parent!'), backgroundColor: colorEmerald),
        );
        setState(() {});
      }
    }
  }

  // =========================================================================
  // TAB 5: CONCERNS (DEVELOPMENTAL CONCERNS, OBSERVATIONS, SEVERITY, STATUS)
  // =========================================================================
  Widget _buildConcernsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Developmental Concerns & Observations',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Algorithmic struggle flags and clinical observations requiring guidance or follow-up.',
                      style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddObservationPage(
                        child: _currentChild,
                        onSuccess: () => setState(() {}),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.note_add_outlined, size: 16),
                label: const Text('Add Clinical Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Observations from llgObservations
          StreamBuilder<QuerySnapshot>(
            stream: _firestore?.collection('llgObservations').where('childId', isEqualTo: _currentChild.childId).snapshots() ?? const Stream.empty(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _buildEmptyState('No clinical observation notes recorded yet.', Icons.check_circle_outline);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final obs = data['observation'] ?? '';
                  final severity = data['severity'] ?? 'guidance';
                  final author = data['llgName'] ?? 'Specialist';
                  final isClinical = data['isClinicalGrade'] == true;
                  final recordedAt = (data['recordedAt'] is Timestamp)
                      ? (data['recordedAt'] as Timestamp).toDate()
                      : DateTime.now();

                  Color sevColor = colorTeal;
                  if (severity == 'critical' || severity == 'clinical') {
                    sevColor = Colors.redAccent;
                  } else if (severity == 'concern' || severity == 'watch') {
                    sevColor = colorAmber;
                  }

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  author,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                if (isClinical) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Clinical Grade',
                                        style: GoogleFonts.inter(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sevColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: sevColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                severity.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: sevColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.yMMMd().add_jm().format(recordedAt),
                          style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          obs,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
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
  // TAB 6: RECOMMENDATIONS (LLG RECOMMENDATIONS, PARENT RESPONSES, REVIEWS)
  // =========================================================================
  Widget _buildRecommendationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LLG Guidance Recommendations',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Targeted home exercises and intervention routines prescribed for ${_currentChild.name}.',
                      style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SendRecommendationPage(
                        child: _currentChild,
                        specialistCase: _currentCase,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Recommendation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          StreamBuilder<List<RecommendationModel>>(
            stream: _firestore == null ? Stream.value(<RecommendationModel>[]) : _recService.getCaseRecommendationsStream(_currentCase.caseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }

              final recs = snapshot.data ?? [];
              if (recs.isEmpty) {
                return _buildEmptyState('No recommendations sent yet for this case.', Icons.recommend_outlined);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final rec = recs[index];
                  final isCompleted = rec.status == RecommendationStatus.completed;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                rec.title,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isCompleted ? colorEmerald : colorAmber).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                rec.status.name.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? colorEmerald : colorAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Domain: ${rec.skillDomain[0].toUpperCase()}${rec.skillDomain.substring(1)} • Recommended on ${DateFormat.yMMMd().format(rec.recommendedAt)}',
                          style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          rec.rationale,
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
                        ),
                        if (rec.hasParentResponded) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorNavy,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorEmerald.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.reply_outlined, size: 14, color: colorEmerald),
                                    const SizedBox(width: 6),
                                    Text('Parent Response: ${rec.parentResponse.name.toUpperCase()}',
                                        style: GoogleFonts.inter(fontSize: 11, color: colorEmerald, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                if (rec.parentFeedback != null && rec.parentFeedback!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('"${rec.parentFeedback!}"',
                                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic)),
                                ],
                              ],
                            ),
                          ),
                        ],
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
  // TAB 7: ACTIONS (ALL SPECIALIST OPERATIONS CONSOLIDATED)
  // =========================================================================
  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specialist Clinical & Operational Actions',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Execute verified interventions, record external sessions, request consent, or update case lifecycle.',
            style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final cardWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'Direct Secure Messaging',
                      subtitle: 'Send end-to-end scoped messages to parent regarding consultation',
                      buttonLabel: 'Open Chat',
                      color: const Color(0xFF0284C7),
                      onTap: _openChat,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.add_task_outlined,
                      title: 'Assign Activity to Child',
                      subtitle: 'Add curated or AI activities to the child’s learning queue',
                      buttonLabel: 'Assign Activity',
                      color: colorTeal,
                      onTap: _showAssignActivityModal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.psychology_outlined,
                      title: 'Create Recommendation',
                      subtitle: 'Prescribe targeted home intervention routines with custom frequency',
                      buttonLabel: 'Send Recommendation',
                      color: const Color(0xFF6366F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SendRecommendationPage(child: _currentChild, specialistCase: _currentCase),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.assignment_turned_in_outlined,
                      title: 'Record Consultation Summary',
                      subtitle: 'Log WhatsApp, audio, video, or in-person session summaries and follow-ups',
                      buttonLabel: 'Record Consultation',
                      color: colorAmber,
                      onTap: _showRecordConsultationModal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.note_add_outlined,
                      title: 'Add Clinical / Observation Note',
                      subtitle: 'Document structured observation with developmental severity grade',
                      buttonLabel: 'Add Note',
                      color: colorTeal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddObservationPage(child: _currentChild, onSuccess: () => setState(() {})),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.contact_phone_outlined,
                      title: 'Request Phone / Email Consent',
                      subtitle: 'Submit DPDP explicit consent request to parent for external channels',
                      buttonLabel: 'Request Consent',
                      color: const Color(0xFF8B5CF6),
                      onTap: _showRequestContactConsentModal,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Generate AI Progress Report',
                      subtitle: 'Run complete analysis across scores and create exportable report',
                      buttonLabel: 'Generate Report',
                      color: const Color(0xFFEC4899),
                      onTap: _generateAIReport,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildActionTile(
                      icon: Icons.check_circle_outline,
                      title: 'Close & Resolve Case',
                      subtitle: 'Complete case milestones and archive active consultation',
                      buttonLabel: 'Close Case',
                      color: colorEmerald,
                      isDestructive: false,
                      onTap: _showCloseCaseModal,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDestructive ? Colors.redAccent : color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(buttonLabel, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordConsultationModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        String mode = 'whatsapp';
        final reasonCtrl = TextEditingController(text: _currentCase.purpose);
        final guidanceCtrl = TextEditingController();
        final followUpCtrl = TextEditingController();
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: colorSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Record Consultation Summary',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Consultation Mode', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: mode,
                        dropdownColor: colorSlate,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(''),
                        items: const [
                          DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Call / Chat')),
                          DropdownMenuItem(value: 'phone', child: Text('Phone Call')),
                          DropdownMenuItem(value: 'video_call', child: Text('Video Conference (Zoom/Meet)')),
                          DropdownMenuItem(value: 'in_person', child: Text('In-Person Clinic Visit')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => mode = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text('Session Reason / Focus', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(controller: reasonCtrl, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('')),
                      const SizedBox(height: 14),
                      Text('Guidance & Recommendations Provided', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: guidanceCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Key milestones discussed and home guidance offered...'),
                      ),
                      const SizedBox(height: 14),
                      Text('Agreed Follow-up Actions (1 per line)', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: followUpCtrl,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Action 1: Try daily sensory play\nAction 2: Follow up next week'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (guidanceCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSaving = true);
                          final user = _auth?.currentUser;

                          final actions = followUpCtrl.text
                              .split('\n')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();

                          await _consultationService.submitSummary(
                            caseId: _currentCase.caseId,
                            childId: _currentChild.childId,
                            childName: _currentChild.name,
                            parentId: _currentChild.parentId,
                            parentName: _currentCase.parentName,
                            llgId: user?.uid ?? 'specialist',
                            llgName: _currentCase.specialistName,
                            consultationMode: mode,
                            consultationDate: DateTime.now(),
                            consultationReason: reasonCtrl.text.trim(),
                            concernsDiscussed: [_currentCase.purpose],
                            guidanceProvided: guidanceCtrl.text.trim(),
                            agreedFollowUpActions: actions,
                            nextReviewDate: DateTime.now().add(const Duration(days: 14)),
                          );

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Consultation summary recorded successfully!'), backgroundColor: colorEmerald),
                            );
                            setState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: colorAmber),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Summary', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRequestContactConsentModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        ContactItemType selectedItem = ContactItemType.phone;
        final purposeCtrl = TextEditingController(text: 'Direct phone consultation to discuss speech progression milestones');
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: colorSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Request Contact Consent (DPDP)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Under DPDP guidelines, parent phone numbers and emails are masked until the parent approves a specific contact request.',
                      style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                    ),
                    const SizedBox(height: 16),
                    Text('Contact Information Requested', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ContactItemType>(
                      value: selectedItem,
                      dropdownColor: colorSlate,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration(''),
                      items: const [
                        DropdownMenuItem(value: ContactItemType.phone, child: Text('Parent Phone Number')),
                        DropdownMenuItem(value: ContactItemType.email, child: Text('Parent Email Address')),
                        DropdownMenuItem(value: ContactItemType.all, child: Text('Phone & Email')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedItem = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Text('Purpose of Request', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(controller: purposeCtrl, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          final user = _auth?.currentUser;
                          await _consentService.requestContactSharing(
                            caseId: _currentCase.caseId,
                            childId: _currentChild.childId,
                            requesterId: user?.uid ?? 'specialist',
                            requesterName: _currentCase.specialistName,
                            requesterRole: 'llg',
                            recipientId: _currentChild.parentId,
                            recipientName: _currentCase.parentName,
                            recipientRole: 'parent',
                            requestedItem: selectedItem,
                            purpose: purposeCtrl.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Consent request dispatched to parent!'), backgroundColor: colorEmerald),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                  child: const Text('Send Request', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCloseCaseModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        final notesCtrl = TextEditingController();
        bool isClosing = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: colorSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('Close and Resolve Case', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marking this case as resolved indicates all initial consultation goals have been addressed.',
                        style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                    const SizedBox(height: 14),
                    Text('Resolution Summary Notes', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(controller: notesCtrl, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Milestones achieved and closing advice...')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: isClosing
                      ? null
                      : () async {
                          setModalState(() => isClosing = true);
                          final user = _auth?.currentUser;
                          await _caseService.closeCase(
                            _currentCase.caseId,
                            specialistId: user?.uid ?? '',
                            resolutionNotes: notesCtrl.text.trim(),
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Case marked as resolved and closed.'), backgroundColor: colorEmerald),
                            );
                            widget.onCaseUpdated?.call();
                            setState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: colorEmerald),
                  child: const Text('Confirm Resolution', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // TAB 8: HISTORY (CHRONOLOGICAL CASE ACTIVITY & RELEVANT UPDATES)
  // =========================================================================
  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Case Activity & Chronological History',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete audit trail of consent, assessments, recommendations, notes, and activity updates.',
            style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
          ),
          const SizedBox(height: 20),

          FutureBuilder<List<_TimelineItem>>(
            future: _buildUnifiedTimeline(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
              }

              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return _buildEmptyState('No history events recorded yet.', Icons.timeline);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: item.color.withOpacity(0.15),
                          child: Icon(item.icon, size: 16, color: item.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text(DateFormat.yMMMd().add_jm().format(item.timestamp), style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(item.description, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                            ],
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

  Future<List<_TimelineItem>> _buildUnifiedTimeline() async {
    final list = <_TimelineItem>[];

    // 1. Case Consent Event
    list.add(_TimelineItem(
      title: 'DPDP Consultation Consent Granted',
      description: 'Parent ${_currentCase.parentName} consented to specialist access under DPDP notice v${_currentCase.consentNoticeVersion}. Purpose: ${_currentCase.purpose}',
      timestamp: _currentCase.consentedAt,
      icon: Icons.verified_user_outlined,
      color: colorEmerald,
    ));

    // 2. Score Events
    try {
      if (_firestore != null) {
        final events = await _scoreLedgerService.getScoreHistory(childId: _currentChild.childId);
      for (final e in events.take(15)) {
        final title = e['activityTitle'] ?? 'Activity';
        final delta = (e['appliedScoreDelta'] is num) ? (e['appliedScoreDelta'] as num).toDouble() : 0.0;
        final ts = (e['timestamp'] is Timestamp) ? (e['timestamp'] as Timestamp).toDate() : DateTime.now();

        list.add(_TimelineItem(
          title: 'Activity Completed: $title',
          description: 'Domain: ${e['skillDomain']} • Applied Delta: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} pts',
          timestamp: ts,
          icon: Icons.play_lesson_outlined,
          color: colorTeal,
        ));
      }
      }
    } catch (_) {}

    // 3. Consultations
    try {
      final fs = _firestore;
      if (fs != null) {
        final consultSnap = await fs
            .collection('consultationSummaries')
            .where('caseId', isEqualTo: _currentCase.caseId)
            .get();
        for (final doc in consultSnap.docs) {
          final data = doc.data();
          final ts = (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.now();
          list.add(_TimelineItem(
            title: 'Consultation Recorded (${data['consultationMode'] ?? 'external'})',
            description: data['guidanceProvided'] ?? 'Consultation notes recorded.',
            timestamp: ts,
            icon: Icons.assignment_turned_in_outlined,
            color: colorAmber,
          ));
        }
      }
    } catch (_) {}

    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // =========================================================================
  // SHARED UTILITIES & HELPERS
  // =========================================================================
  Widget _buildCardContainer({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRestrictedNotice(String category) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorNavy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: colorAmber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Access to "$category" is not included in the active parent consent notice. Contact parent to expand data scope.',
              style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: colorTextMuted.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: colorTextMuted.withOpacity(0.7), fontSize: 13),
      filled: true,
      fillColor: colorNavy,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorTeal)),
    );
  }

  Future<Map<String, dynamic>> _loadChildInsightSummary() async {
    final Map<String, dynamic> result = {
      'highestDomain': 'Cognitive',
      'lowestDomain': 'Motor',
      'totalActivities': 0,
      'struggles': 0,
    };

    final fs = _firestore;
    if (fs != null) {
      try {
        final doc = await fs.collection('skillProfiles').doc(_currentChild.childId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final domains = ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative'];
          final scores = <String, double>{};
          for (final d in domains) {
            scores[d] = (data[d] is num) ? (data[d] as num).toDouble() : 0.0;
          }
          final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          if (sorted.isNotEmpty) {
            result['highestDomain'] = sorted.first.key[0].toUpperCase() + sorted.first.key.substring(1);
            result['lowestDomain'] = sorted.last.key[0].toUpperCase() + sorted.last.key.substring(1);
          }
        }

        final events = await _scoreLedgerService.getScoreHistory(childId: _currentChild.childId);
        result['totalActivities'] = events.length;
        result['struggles'] = events.where((e) {
          final fb = e['feedback'];
          if (fb is Map) {
            final diff = (fb['difficulty'] ?? '').toString().toLowerCase();
            final resp = (fb['childResponse'] ?? '').toString().toLowerCase();
            return diff == 'hard' || resp == 'struggled';
          }
          return false;
        }).length;
      } catch (_) {}
    }

    return result;
  }

  void _openChat() {
    final user = _auth?.currentUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          specialistCase: _currentCase,
          currentUserId: user?.uid ?? '',
          currentUserName: _currentCase.specialistName,
          currentUserRole: 'llg',
          otherParticipantName: _currentCase.parentName.isNotEmpty ? _currentCase.parentName : 'Parent',
          otherParticipantRole: 'parent',
        ),
      ),
    );
  }
}

class _TimelineItem {
  final String title;
  final String description;
  final DateTime timestamp;
  final IconData icon;
  final Color color;

  _TimelineItem({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });
}
