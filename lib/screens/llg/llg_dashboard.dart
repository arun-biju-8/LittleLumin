// lib/screens/llg/llg_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../models/recommendation_model.dart';
import '../../models/consultation_summary_model.dart';
import '../../models/contact_consent_model.dart';
import '../../models/message_model.dart';
import '../../services/score_ledger_service.dart';
import '../../services/flag_service.dart';
import '../../services/specialist_case_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/consultation_summary_service.dart';
import '../../services/contact_consent_service.dart';
import '../../services/messaging_service.dart';
import '../../services/child_service.dart';
import '../auth/login_page.dart';
import '../chat/chat_screen.dart';
import 'add_observation_page.dart';
import 'llg_profile_page.dart';
import 'send_recommendation_page.dart';
import 'child_profile_page.dart';

class LLGDashboard extends StatefulWidget {
  const LLGDashboard({super.key});

  @override
  State<LLGDashboard> createState() => _LLGDashboardState();
}

class _LLGDashboardState extends State<LLGDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SpecialistCaseService _caseService = SpecialistCaseService();

  int _selectedSidebarIndex = 0;
  String _searchQuery = '';
  String _recommendationFilter = 'all';
  String _recommendationSearch = '';
  ChildModel? _selectedChild;
  SpecialistCaseModel? _selectedCase;
  bool _isDrawerOpen = false;
  bool _isCasesGridView = false;
  String _casesStatusFilter = 'all';

  void _openChildProfile(SpecialistCaseModel c) {
    final child = ChildModel(
      childId: c.childId,
      parentId: c.parentId,
      name: c.childName,
      dateOfBirth: DateTime.now().subtract(Duration(days: c.childAgeYears * 365)),
      gender: 'Child',
      createdAt: c.createdAt,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildProfilePage(
          caseModel: c,
          initialChild: child,
          onCaseUpdated: () => setState(() {}),
        ),
      ),
    );
  }

  // Colors
  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorCard = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  String _currentLLGName = 'LLG Specialist';
  bool _isVerified = true;

  @override
  void initState() {
    super.initState();
    _loadLLGProfile();
  }

  Future<void> _loadLLGProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('llgProfiles').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _currentLLGName = doc.data()?['name'] ?? user.displayName ?? 'LLG Specialist';
          _isVerified = doc.data()?['isVerified'] ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out of the specialist portal?',
            style: GoogleFonts.inter(color: colorTextMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (r) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      backgroundColor: colorNavy,
      drawer: isNarrow ? Drawer(child: _buildSidebar()) : null,
      body: Row(
        children: [
          // 1. Persistent Left Sidebar (240px) on wider screens
          if (!isNarrow) _buildSidebar(),

          // 2. Main Content Area with Top Bar (64px)
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isNarrow),
                Expanded(
                  child: Stack(
                    children: [
                      _buildSelectedView(),
                      if (_isDrawerOpen && _selectedChild != null)
                        _buildChildDetailPanel(_selectedChild!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. SIDEBAR
  // =========================================================================
  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(right: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Column(
        children: [
          // Branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorTeal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('LLG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LittleLumin',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    Text(
                      'Specialist Portal',
                      style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Scrollable Sidebar Navigation Items (Guarantees zero overflow on any screen height)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSidebarNavItem(
                    index: 0,
                    icon: Icons.dashboard_outlined,
                    label: 'Overview',
                  ),
                  StreamBuilder<List<SpecialistCaseModel>>(
                    stream: _caseService.getSpecialistCasesStream(specialistId: _auth.currentUser?.uid ?? ''),
                    builder: (context, snapshot) {
                      final cases = snapshot.data ?? [];
                      final activeCount = cases.where((c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active).length;
                      return _buildSidebarNavItem(
                        index: 1,
                        icon: Icons.assignment_ind_outlined,
                        label: 'My Cases',
                        badgeCount: activeCount > 0 ? activeCount : null,
                      );
                    },
                  ),
                  StreamBuilder<List<SpecialistCaseModel>>(
                    stream: _caseService.getSpecialistCasesStream(specialistId: _auth.currentUser?.uid ?? '', statusFilter: CaseStatus.pending),
                    builder: (context, snapshot) {
                      final pendingCount = snapshot.data?.length ?? 0;
                      return _buildSidebarNavItem(
                        index: 2,
                        icon: Icons.pending_actions_outlined,
                        label: 'Active Reviews',
                        badgeCount: pendingCount > 0 ? pendingCount : null,
                      );
                    },
                  ),
                  StreamBuilder<List<RecommendationModel>>(
                    stream: RecommendationService().getSpecialistRecommendationsStream(llgId: _auth.currentUser?.uid ?? ''),
                    builder: (context, snapshot) {
                      final recs = snapshot.data ?? [];
                      final activeRecs = recs.where((r) => r.status == RecommendationStatus.recommended || r.status == RecommendationStatus.in_progress).length;
                      return _buildSidebarNavItem(
                        index: 3,
                        icon: Icons.psychology_outlined,
                        label: 'Recommendations',
                        badgeCount: activeRecs > 0 ? activeRecs : null,
                      );
                    },
                  ),
                  _buildSidebarNavItem(
                    index: 4,
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                  ),
                  _buildSidebarNavItem(
                    index: 5,
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Consultations',
                  ),
                  _buildSidebarNavItem(
                    index: 6,
                    icon: Icons.contact_phone_outlined,
                    label: 'Contact Consents',
                  ),
                  _buildSidebarNavItem(
                    index: 7,
                    icon: Icons.history_edu_outlined,
                    label: 'Observation History',
                  ),
                  _buildSidebarNavItem(
                    index: 8,
                    icon: Icons.person_outline,
                    label: 'Profile & Credentials',
                  ),
                ],
              ),
            ),
          ),

          // Sign Out Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _signOut,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _selectedSidebarIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSidebarIndex = index;
            _isDrawerOpen = false;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? colorTeal.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: colorTeal.withOpacity(0.3)) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? colorTeal : colorTextMuted,
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : colorTextMuted,
                  ),
                ),
              ),
              if (badgeCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorAmber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. TOP BAR
  // =========================================================================
  Widget _buildTopBar([bool isNarrow = false]) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Row(
        children: [
          if (isNarrow) ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Search Field
          Expanded(
            child: Container(
              height: 40,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: colorNavy,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorBorder),
              ),
              child: TextField(
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search flagged children or domains...',
                  hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: colorTextMuted, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Notifications bell
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: colorTextMuted, size: 22),
            onPressed: () {},
          ),

          const SizedBox(width: 12),

          // Profile Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorNavy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorTeal,
                  child: Text(
                    _currentLLGName.isNotEmpty ? _currentLLGName[0].toUpperCase() : 'S',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentLLGName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                if (_isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: colorTeal, size: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. ROUTER / SELECTED VIEW
  // =========================================================================
  Widget _buildSelectedView() {
    switch (_selectedSidebarIndex) {
      case 0:
        return _buildOverviewPage();
      case 1:
        return _buildMyCasesPage();
      case 2:
        return _buildActiveReviewsPage();
      case 3:
        return _buildRecommendationsPage();
      case 4:
        return _buildMessagesPage();
      case 5:
        return _buildConsultationsPage();
      case 6:
        return _buildContactConsentsPage();
      case 7:
        return _buildObservationHistoryPage();
      case 8:
        return const LLGProfilePage();
      default:
        return _buildOverviewPage();
    }
  }

  // =========================================================================
  // OVERVIEW PAGE (Scoped to Specialist's Authorized Cases)
  // =========================================================================
  Widget _buildOverviewPage() {
    final user = _auth.currentUser;
    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getSpecialistCasesStream(specialistId: user?.uid ?? ''),
      builder: (context, caseSnap) {
        final allCases = caseSnap.data ?? [];
        final activeCases = allCases.where((c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active).toList();
        final pendingCases = allCases.where((c) => c.status == CaseStatus.pending).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('llgObservations')
              .where('llgId', isEqualTo: user?.uid ?? '')
              .snapshots(),
          builder: (context, obsSnap) {
            final obsDocs = obsSnap.data?.docs ?? [];

            return StreamBuilder<List<RecommendationModel>>(
              stream: RecommendationService().getSpecialistRecommendationsStream(llgId: user?.uid ?? ''),
              builder: (context, recSnap) {
                final allRecs = recSnap.data ?? [];
                final activeRecs = allRecs.where((r) => r.status == RecommendationStatus.recommended || r.status == RecommendationStatus.in_progress).length;

                return StreamBuilder<List<ConsultationSummaryModel>>(
                  stream: ConsultationSummaryService().getSpecialistSummariesStream(user?.uid ?? ''),
                  builder: (context, sumSnap) {
                    final totalConsultations = sumSnap.data?.length ?? 0;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Responsive KPI Cards (No overflow on small screens)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = constraints.maxWidth < 650
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth < 1100
                                      ? (constraints.maxWidth - 16) / 2
                                      : (constraints.maxWidth - 48) / 4);

                              return Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildKPICard(
                                      title: 'My Active Cases',
                                      value: activeCases.length.toString(),
                                      subtitle: 'Consented child consultations',
                                      icon: Icons.assignment_ind_outlined,
                                      color: const Color(0xFF10B981),
                                      onTap: () => setState(() => _selectedSidebarIndex = 1),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildKPICard(
                                      title: 'Pending Reviews',
                                      value: pendingCases.length.toString(),
                                      subtitle: 'Awaiting your acceptance',
                                      icon: Icons.pending_actions_outlined,
                                      color: colorAmber,
                                      onTap: () => setState(() => _selectedSidebarIndex = 2),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildKPICard(
                                      title: 'Active Recommendations',
                                      value: activeRecs.toString(),
                                      subtitle: 'Ongoing guidance plans',
                                      icon: Icons.psychology_outlined,
                                      color: colorTeal,
                                      onTap: () => setState(() => _selectedSidebarIndex = 3),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildKPICard(
                                      title: 'Consultations Logged',
                                      value: totalConsultations.toString(),
                                      subtitle: 'Documented session summaries',
                                      icon: Icons.assignment_turned_in_outlined,
                                      color: const Color(0xFF818CF8),
                                      onTap: () => setState(() => _selectedSidebarIndex = 5),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                  const SizedBox(height: 24),

                  // Responsive Main Split (Stack vertically if width < 1050)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isStacked = constraints.maxWidth < 1050;

                      final leftTable = Container(
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
                                Text(
                                  'Active Cases Queue',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(() => _selectedSidebarIndex = 1),
                                  child: Text(
                                    'View All (${activeCases.length})',
                                    style: GoogleFonts.inter(color: colorTeal, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildMyCasesTable(activeCases.take(5).toList()),
                          ],
                        ),
                      );

                      final rightTimeline = Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Reviews Timeline',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildRecentReviewsList(obsDocs.take(5).toList()),
                          ],
                        ),
                      );

                      if (isStacked) {
                        return Column(
                          children: [
                            leftTable,
                            const SizedBox(height: 20),
                            rightTimeline,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: leftTable),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: rightTimeline),
                        ],
                      );
                    },
                  ),
                ],
              ),
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

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildMyCasesTable(List<SpecialistCaseModel> cases) {
    if (cases.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Text(
          'No authorized cases assigned yet. Cases appear when parents submit consultation requests.',
          style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(1.8),
        2: FlexColumnWidth(2.2),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
          ),
          children: [
            _buildTableHeader('Child / Age'),
            _buildTableHeader('Parent'),
            _buildTableHeader('Consultation Purpose'),
            _buildTableHeader('Consent Status'),
            _buildTableHeader('Action'),
          ],
        ),
        ...cases.map((c) {
          final isAccepted = c.status == CaseStatus.accepted || c.status == CaseStatus.active;
          final isRevoked = c.status == CaseStatus.revoked;

          Color statusColor;
          String statusText;
          if (isRevoked) {
            statusColor = Colors.redAccent;
            statusText = 'REVOKED';
          } else if (isAccepted) {
            statusColor = const Color(0xFF10B981);
            statusText = 'ACTIVE';
          } else if (c.status == CaseStatus.pending) {
            statusColor = colorAmber;
            statusText = 'PENDING';
          } else {
            statusColor = colorTextMuted;
            statusText = c.status.name.toUpperCase();
          }

          return TableRow(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: colorBorder, width: 0.5)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colorTeal.withOpacity(0.2),
                      child: Text(
                        c.childName.isNotEmpty ? c.childName[0].toUpperCase() : 'C',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTeal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.childName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${c.childAgeYears} yrs • DPDP ${c.consentNoticeVersion}',
                            style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  c.parentName,
                  style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  c.purpose,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () => _openChildProfile(c),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRevoked ? colorBorder : colorTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(
                    isRevoked ? 'View Case' : 'Open Profile',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colorTextMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRecentReviewsList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: Text('No reviews documented yet.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final obs = docs[index].data() as Map<String, dynamic>;
        final llg = obs['llgName'] ?? 'Specialist';
        final severity = obs['severity'] ?? 'medium';
        final note = obs['observation'] ?? '';

        return Container(
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
                  Text(llg, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: severity == 'critical' ? Colors.red.withOpacity(0.2) : colorTeal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      severity.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: severity == 'critical' ? Colors.redAccent : colorTeal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted, height: 1.3),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // MY CASES FULL PAGE (DPDP Consent-Enforced)
  // =========================================================================
  Widget _buildMyCasesPage() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please authenticate as a specialist'));
    }

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getSpecialistCasesStream(specialistId: user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var cases = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          cases = cases.where((c) {
            return c.childName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.parentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.purpose.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (_casesStatusFilter != 'all') {
          cases = cases.where((c) {
            if (_casesStatusFilter == 'active') {
              return c.status == CaseStatus.active || c.status == CaseStatus.accepted;
            } else if (_casesStatusFilter == 'pending') {
              return c.status == CaseStatus.pending;
            } else if (_casesStatusFilter == 'revoked') {
              return c.status == CaseStatus.revoked;
            } else if (_casesStatusFilter == 'completed') {
              return c.status == CaseStatus.completed;
            }
            return true;
          }).toList();
        }

        if (cases.isEmpty && _searchQuery.isEmpty && _casesStatusFilter == 'all') {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 64, color: colorTeal.withOpacity(0.6)),
                const SizedBox(height: 16),
                Text(
                  'No Cases Assigned',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Under DPDP guidelines, specialist access is restricted exclusively to children whose\nparents have submitted a consultation request and granted active consent.',
                  style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Assigned Cases (${cases.length})',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.verified_user, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          'Consent Verified & Case-Scoped',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search, Filter & Grid/List Toggle Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorNavy,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: colorTextMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by child, parent, or consultation purpose...',
                            hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 24, color: colorBorder),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _casesStatusFilter,
                        dropdownColor: colorSlate,
                        underline: const SizedBox.shrink(),
                        icon: const Icon(Icons.arrow_drop_down, color: colorTextMuted),
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                          DropdownMenuItem(value: 'active', child: Text('Active Only')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending Only')),
                          DropdownMenuItem(value: 'revoked', child: Text('Revoked Only')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed Only')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _casesStatusFilter = val);
                        },
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 24, color: colorBorder),
                      const SizedBox(width: 12),
                      // Working Grid View / List View Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: colorSlate,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.view_list_rounded,
                                size: 18,
                                color: !_isCasesGridView ? colorTeal : colorTextMuted,
                              ),
                              tooltip: 'List View',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _isCasesGridView = false),
                            ),
                            Container(width: 1, height: 16, color: colorBorder),
                            IconButton(
                              icon: Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                                color: _isCasesGridView ? colorTeal : colorTextMuted,
                              ),
                              tooltip: 'Grid View',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _isCasesGridView = true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // View Content (Grid View or List View)
                Expanded(
                  child: SingleChildScrollView(
                    child: _isCasesGridView ? _buildMyCasesGrid(cases) : _buildMyCasesTable(cases),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyCasesGrid(List<SpecialistCaseModel> cases) {
    if (cases.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        alignment: Alignment.center,
        child: Text(
          'No matching cases found for the selected filter.',
          style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1050;
        final isMedium = constraints.maxWidth > 680;
        final int crossAxisCount = isWide ? 3 : (isMedium ? 2 : 1);
        final double cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cases.map((c) {
            final isAccepted = c.status == CaseStatus.accepted || c.status == CaseStatus.active;
            final isRevoked = c.status == CaseStatus.revoked;

            Color statusColor;
            String statusText;
            if (isRevoked) {
              statusColor = Colors.redAccent;
              statusText = 'REVOKED';
            } else if (isAccepted) {
              statusColor = const Color(0xFF10B981);
              statusText = 'ACTIVE';
            } else if (c.status == CaseStatus.pending) {
              statusColor = colorAmber;
              statusText = 'PENDING';
            } else {
              statusColor = colorTextMuted;
              statusText = c.status.name.toUpperCase();
            }

            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: colorTeal.withOpacity(0.2),
                          child: Text(
                            c.childName.isNotEmpty ? c.childName[0].toUpperCase() : 'C',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: colorTeal),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.childName,
                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${c.childAgeYears} yrs • Child',
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
                            statusText,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: colorBorder, height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: colorTextMuted),
                        const SizedBox(width: 6),
                        Text('Parent: ', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                        Expanded(
                          child: Text(
                            c.parentName,
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.psychology_outlined, size: 14, color: colorTextMuted),
                        const SizedBox(width: 6),
                        Text('Focus: ', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                        Expanded(
                          child: Text(
                            c.purpose,
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorSlate,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 12, color: isAccepted ? const Color(0xFF10B981) : colorAmber),
                          const SizedBox(width: 4),
                          Text(
                            'DPDP v${c.consentNoticeVersion} • ${isAccepted ? 'Consent Verified' : 'Consent Pending'}',
                            style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openChildProfile(c),
                        icon: const Icon(Icons.badge_outlined, size: 14),
                        label: Text(isRevoked ? 'View Case Details' : 'Open Child Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isRevoked ? colorBorder : colorTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================================
  // ACTIVE REVIEWS / PENDING REQUESTS PAGE (Scoped to Specialist ID)
  // =========================================================================
  Widget _buildActiveReviewsPage() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please authenticate as a specialist'));
    }

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getSpecialistCasesStream(specialistId: user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCases = snapshot.data ?? [];
        final pendingCases = allCases.where((c) => c.status == CaseStatus.pending).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    Text(
                      'Pending Consultation Requests (${pendingCases.length})',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Parent consent notice must be accepted before data access',
                      style: GoogleFonts.inter(fontSize: 12, color: colorAmber),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (pendingCases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: colorTextMuted),
                          const SizedBox(height: 12),
                          Text('No pending consultation requests assigned to you.',
                              style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: pendingCases.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final c = pendingCases[idx];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorNavy,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorAmber.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.assignment_ind_outlined, color: colorAmber, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${c.childName} (${c.childAgeYears} yrs)',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorTeal.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'DPDP v${c.consentNoticeVersion}',
                                            style: GoogleFonts.inter(fontSize: 10, color: colorTeal, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Requested by: ${c.parentName} • Purpose: ${c.purpose}',
                                      style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Authorized Categories: ${c.authorizedCategories.join(", ")}',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () async {
                                  await _caseService.declineCase(c.id, specialistId: user.uid, reason: 'Specialist unavailable');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Declined case for ${c.childName}')),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorTextMuted,
                                  side: const BorderSide(color: colorBorder),
                                ),
                                child: const Text('Decline', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  await _caseService.acceptCase(c.id, specialistId: user.uid);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Accepted case for ${c.childName}. Records are now accessible.'),
                                        backgroundColor: colorTeal,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
                                child: const Text('Accept Case', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // 4. RECOMMENDATIONS WORKSPACE (Scoped to Specialist's Authorized Cases)
  // =========================================================================
  Widget _buildRecommendationsPage() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please authenticate as a specialist', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<List<RecommendationModel>>(
      stream: RecommendationService().getSpecialistRecommendationsStream(llgId: user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final allRecs = snapshot.data ?? [];
        
        // Filter by status
        var filteredRecs = allRecs.where((r) {
          if (_recommendationFilter == 'in_progress') {
            return r.status == RecommendationStatus.recommended || r.status == RecommendationStatus.in_progress;
          } else if (_recommendationFilter == 'parent_responded') {
            return r.parentResponse != ParentActivityResponse.none;
          } else if (_recommendationFilter == 'completed') {
            return r.status == RecommendationStatus.completed || r.parentResponse == ParentActivityResponse.completed;
          } else if (_recommendationFilter == 'struggled') {
            return r.parentResponse == ParentActivityResponse.struggled;
          } else if (_recommendationFilter == 'skipped') {
            return r.status == RecommendationStatus.skipped || r.parentResponse == ParentActivityResponse.skipped;
          } else if (_recommendationFilter == 'paused') {
            return r.status == RecommendationStatus.paused;
          }
          return true;
        }).toList();

        // Filter by search query
        if (_recommendationSearch.isNotEmpty) {
          final q = _recommendationSearch.toLowerCase().trim();
          filteredRecs = filteredRecs.where((r) {
            return r.childName.toLowerCase().contains(q) ||
                r.title.toLowerCase().contains(q) ||
                r.skillDomain.toLowerCase().contains(q);
          }).toList();
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Action Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personalized Recommendations (${allRecs.length})',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Assign, review parent responses, and adjust developmental guidance',
                          style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openNewRecommendationFlow(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Recommendation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorNavy,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: colorTextMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by child, activity title, or domain...',
                            hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) => setState(() => _recommendationSearch = val),
                        ),
                      ),
                      if (_recommendationSearch.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _recommendationSearch = ''),
                          child: const Icon(Icons.close, size: 16, color: colorTextMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All (${allRecs.length})'),
                      _buildFilterChip('in_progress', 'Active (${allRecs.where((r) => r.status == RecommendationStatus.recommended || r.status == RecommendationStatus.in_progress).length})'),
                      _buildFilterChip('parent_responded', 'Parent Responded (${allRecs.where((r) => r.parentResponse != ParentActivityResponse.none).length})'),
                      _buildFilterChip('completed', 'Completed (${allRecs.where((r) => r.status == RecommendationStatus.completed || r.parentResponse == ParentActivityResponse.completed).length})'),
                      _buildFilterChip('struggled', 'Struggled (${allRecs.where((r) => r.parentResponse == ParentActivityResponse.struggled).length})'),
                      _buildFilterChip('skipped', 'Skipped (${allRecs.where((r) => r.status == RecommendationStatus.skipped || r.parentResponse == ParentActivityResponse.skipped).length})'),
                      _buildFilterChip('paused', 'Paused (${allRecs.where((r) => r.status == RecommendationStatus.paused).length})'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Content List
                Expanded(
                  child: filteredRecs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.psychology_outlined, size: 48, color: colorTextMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No recommendations found for this filter',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Assign personalized developmental activities to your active child cases.',
                                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredRecs.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildRecommendationCard(filteredRecs[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _recommendationFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : colorTextMuted,
        ),
        backgroundColor: colorNavy,
        selectedColor: colorTeal.withOpacity(0.3),
        checkmarkColor: colorTeal,
        side: BorderSide(color: isSelected ? colorTeal : colorBorder),
        onSelected: (_) => setState(() => _recommendationFilter = key),
      ),
    );
  }

  Widget _buildRecommendationCard(RecommendationModel rec) {
    Color statusColor;
    switch (rec.status) {
      case RecommendationStatus.completed:
        statusColor = const Color(0xFF10B981);
        break;
      case RecommendationStatus.partially_completed:
      case RecommendationStatus.skipped:
        statusColor = colorAmber;
        break;
      case RecommendationStatus.paused:
        statusColor = const Color(0xFFF97316);
        break;
      case RecommendationStatus.discontinued:
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = colorTeal;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorNavy,
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: colorTeal.withOpacity(0.2),
                      child: Text(
                        rec.childName.isNotEmpty ? rec.childName[0].toUpperCase() : 'C',
                        style: const TextStyle(color: colorTeal, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${rec.childName} • ${rec.title}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  rec.status.name.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorSlate,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rec.skillDomain.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${rec.durationMinutes} mins • ${rec.frequency}',
                style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
              ),
              if (rec.reviewDate != null) ...[
                const SizedBox(width: 8),
                Text(
                  '• Review: ${DateFormat.yMMMd().format(rec.reviewDate!)}',
                  style: GoogleFonts.inter(fontSize: 12, color: colorAmber),
                ),
              ],
            ],
          ),
          if (rec.rationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Why suggested: ${rec.rationale}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ],

          // Parent Response Section
          if (rec.parentResponse != ParentActivityResponse.none) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorTeal.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.feedback_outlined, size: 14, color: colorTeal),
                      const SizedBox(width: 6),
                      Text(
                        'Parent Reported: ${rec.parentResponse.name.toUpperCase()}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTeal),
                      ),
                      if (rec.parentRespondedAt != null) ...[
                        const Spacer(),
                        Text(
                          DateFormat.yMMMd().format(rec.parentRespondedAt!),
                          style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted),
                        ),
                      ],
                    ],
                  ),
                  if (rec.parentFeedback != null && rec.parentFeedback!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '"${rec.parentFeedback!}"',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (rec.skippedReason != null && rec.skippedReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${rec.skippedReason!}',
                      style: GoogleFonts.inter(fontSize: 11, color: colorAmber),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // LLG Feedback & Next Steps
          if (rec.llgFeedback != null && rec.llgFeedback!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_outlined, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        'Specialist Guidance & Next Steps',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.llgFeedback!,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                  if (rec.nextSteps != null && rec.nextSteps!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Next Steps: ${rec.nextSteps!}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showReviewRecommendationDialog(context, rec),
                icon: const Icon(Icons.rate_review_outlined, size: 14),
                label: const Text('Review & Add Next Steps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorTeal,
                  side: const BorderSide(color: colorTeal),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              if (rec.status == RecommendationStatus.recommended || rec.status == RecommendationStatus.in_progress)
                OutlinedButton(
                  onPressed: () async {
                    await RecommendationService().updateStatus(
                      rec.id,
                      RecommendationStatus.paused,
                      statusReason: 'Paused by specialist for reassessment',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorAmber,
                    side: const BorderSide(color: colorAmber),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 11),
                  ),
                  child: const Text('Pause'),
                )
              else if (rec.status == RecommendationStatus.paused)
                OutlinedButton(
                  onPressed: () async {
                    await RecommendationService().updateStatus(
                      rec.id,
                      RecommendationStatus.in_progress,
                      statusReason: 'Resumed by specialist',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    textStyle: GoogleFonts.inter(fontSize: 11),
                  ),
                  child: const Text('Resume'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReviewRecommendationDialog(BuildContext context, RecommendationModel rec) {
    final feedbackCtrl = TextEditingController(text: rec.llgFeedback ?? '');
    final nextStepsCtrl = TextEditingController(text: rec.nextSteps ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'Review Recommendation (${rec.title})',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rec.parentResponse != ParentActivityResponse.none) ...[
                    Container(
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
                            children: [
                              const Icon(Icons.feedback_outlined, size: 16, color: colorTeal),
                              const SizedBox(width: 6),
                              Text(
                                'Parent Reported: ${rec.parentResponse.name.toUpperCase()}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colorTeal, fontSize: 12),
                              ),
                            ],
                          ),
                          if (rec.parentFeedback != null && rec.parentFeedback!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '"${rec.parentFeedback!}"',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                          if (rec.skippedReason != null && rec.skippedReason!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Reason skipped: ${rec.skippedReason!}',
                              style: GoogleFonts.inter(color: colorAmber, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('Specialist Assessment / Feedback', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: feedbackCtrl,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter guidance, encouragement, or developmental observations...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Next Recommended Steps', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nextStepsCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g., Progress to 10-minute focus sessions next week...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
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
                      if (feedbackCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter specialist feedback.'), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      await RecommendationService().recordLlgReview(
                        rec.id,
                        feedbackCtrl.text.trim(),
                        nextStepsCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Review & next steps saved successfully.'), backgroundColor: Color(0xFF10B981)),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Review', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewRecommendationFlow(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cases = await _caseService.getSpecialistCases(specialistId: user.uid);
    final activeCases = cases.where((c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active).toList();

    if (activeCases.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active cases available. Please accept a pending consultation request first.'),
            backgroundColor: colorAmber,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Select Child for Recommendation', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: activeCases.map((c) {
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: colorNavy,
                leading: CircleAvatar(
                  backgroundColor: colorTeal,
                  radius: 16,
                  child: Text(c.childName.isNotEmpty ? c.childName[0].toUpperCase() : 'C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: Text(c.childName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('Parent: ${c.parentName} • Purpose: ${c.purpose}', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  Navigator.pop(ctx);
                  final child = await ChildService().getChild(c.childId);
                  if (child != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SendRecommendationPage(child: child, specialistCase: c),
                      ),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 5. MESSAGES PAGE (Direct Unified Communication Hub)
  // =========================================================================
  Widget _buildMessagesPage() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please authenticate as a specialist', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getSpecialistCasesStream(specialistId: user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final allCases = snapshot.data ?? [];
        final activeCases = allCases.where((c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Messages (${activeCases.length} Active Conversations)',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Two-way encrypted communication authorized under DPDP parental consent',
                          style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: activeCases.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 48, color: colorTextMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No active conversations yet',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'When you accept a parent consultation request, a secure two-way conversation channel is created here.',
                                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: activeCases.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildConversationCard(activeCases[i], user.uid),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationCard(SpecialistCaseModel c, String currentUserId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorTeal,
            child: Text(
              c.parentName.isNotEmpty ? c.parentName[0].toUpperCase() : 'P',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      c.parentName.isNotEmpty ? c.parentName : 'Parent',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Child: ${c.childName}',
                        style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                StreamBuilder<List<MessageModel>>(
                  stream: MessagingService().getMessagesStream(c.id),
                  builder: (context, msgSnap) {
                    final msgs = msgSnap.data ?? [];
                    if (msgs.isEmpty) {
                      return Text('No messages sent yet. Click to start the conversation.', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted));
                    }
                    final lastMsg = msgs.last;
                    return Text(
                      '${lastMsg.senderName}: ${lastMsg.content}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StreamBuilder<int>(
            stream: MessagingService().getUnreadCountStream(c.id, currentUserId),
            builder: (context, unreadSnap) {
              final unread = unreadSnap.data ?? 0;
              if (unread > 0) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unread unread',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    specialistCase: c,
                    currentUserId: currentUserId,
                    currentUserName: _currentLLGName,
                    currentUserRole: 'llg',
                    otherParticipantName: c.parentName.isNotEmpty ? c.parentName : 'Parent',
                    otherParticipantRole: 'parent',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat, size: 14),
            label: const Text('Open Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. CONSULTATIONS WORKSPACE (External WhatsApp & In-App Sessions)
  // =========================================================================
  Widget _buildConsultationsPage() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please authenticate as a specialist', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<List<ConsultationSummaryModel>>(
      stream: ConsultationSummaryService().getSpecialistSummariesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final summaries = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consultation Summaries (${summaries.length})',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Formal clinical documentation for WhatsApp, phone, video, and in-person sessions',
                          style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openNewConsultationFlow(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Record Summary'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: summaries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined, size: 48, color: colorTextMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No consultation summaries logged yet',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'After conducting an external WhatsApp or in-app consultation, log a summary to preserve the audit trail.',
                                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: summaries.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildConsultationSummaryCard(summaries[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsultationSummaryCard(ConsultationSummaryModel s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorNavy,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_in_talk, size: 12, color: Color(0xFF25D366)),
                        const SizedBox(width: 4),
                        Text(
                          s.consultationMode.toUpperCase(),
                          style: GoogleFonts.inter(color: const Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${s.childName} (Parent: ${s.parentName})',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
              Text(
                DateFormat.yMMMd().format(s.consultationDate),
                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Reason: ${s.consultationReason}', style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Guidance Provided: ${s.guidanceProvided}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
          if (s.agreedFollowUpActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Agreed Actions:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTeal)),
            ...s.agreedFollowUpActions.map((a) => Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text('• $a', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
            )),
          ],
          if (s.nextReviewDate != null) ...[
            const SizedBox(height: 8),
            Text('Next Review: ${DateFormat.yMMMd().format(s.nextReviewDate!)}', style: GoogleFonts.inter(fontSize: 11, color: colorAmber)),
          ],
        ],
      ),
    );
  }

  void _openNewConsultationFlow(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cases = await _caseService.getSpecialistCases(specialistId: user.uid);
    final activeCases = cases.where((c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active).toList();

    if (activeCases.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active cases available to record consultation summary.'),
            backgroundColor: colorAmber,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Select Case for Consultation Summary', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: activeCases.map((c) {
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: colorNavy,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF59E0B),
                  radius: 16,
                  child: Text(c.childName.isNotEmpty ? c.childName[0].toUpperCase() : 'C', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
                title: Text(c.childName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('Parent: ${c.parentName} • Purpose: ${c.purpose}', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  Navigator.pop(ctx);
                  final child = await ChildService().getChild(c.childId);
                  if (child != null && context.mounted) {
                    _showRecordConsultationDialog(context, child, c);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 7. CONTACT CONSENTS WORKSPACE (Field-Level Permissions)
  // =========================================================================
  Widget _buildContactConsentsPage() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please authenticate as a specialist', style: TextStyle(color: Colors.white)));
    }

    return StreamBuilder<List<ContactConsentModel>>(
      stream: ContactConsentService().getUserConsentRequestsStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final requests = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Sharing & Consents (${requests.length})',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Granular, field-level phone & WhatsApp permissions adhering to DPDP regulations',
                          style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openRequestContactFlow(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Request Contact Sharing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: requests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.contact_phone_outlined, size: 48, color: colorTextMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'No contact-sharing requests logged yet',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Phone numbers and WhatsApp channels remain shielded until explicit mutual consent is recorded.',
                                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: requests.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _buildContactConsentCard(requests[i]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactConsentCard(ContactConsentModel c) {
    Color statusColor;
    switch (c.status) {
      case ContactConsentStatus.approved:
        statusColor = const Color(0xFF10B981);
        break;
      case ContactConsentStatus.pending:
        statusColor = colorAmber;
        break;
      case ContactConsentStatus.declined:
      case ContactConsentStatus.revoked:
        statusColor = Colors.redAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorNavy,
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
                'Case: ${c.caseId}',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  c.status.name.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Requested Item: ${c.requestedItem.name.toUpperCase()} • Purpose: ${c.purpose}',
            style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (c.isApproved) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shared Contact: ${c.sharedPhoneNumber ?? c.sharedEmail ?? "Approved"}',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (c.isPending) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock, size: 16, color: colorAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Locked — Explicit parental approval required. Details are hidden at the data boundary.',
                      style: GoogleFonts.inter(color: colorAmber, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (c.isRevoked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Consent revoked by parent. Shared contact erased.',
                      style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openRequestContactFlow(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cases = await _caseService.getSpecialistCases(specialistId: user.uid);
    final activeCases = cases.where((c) => c.status == CaseStatus.accepted || c.status == CaseStatus.active).toList();

    if (activeCases.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active cases available to request contact sharing.'),
            backgroundColor: colorAmber,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    SpecialistCaseModel selectedCase = activeCases.first;
    ContactItemType selectedItem = ContactItemType.phone;
    final purposeCtrl = TextEditingController(text: 'Direct follow-up on personalized activity guidance and progress.');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Request Contact Sharing', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Child Case', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorNavy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SpecialistCaseModel>(
                        value: selectedCase,
                        isExpanded: true,
                        dropdownColor: colorSlate,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        items: activeCases.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text('${c.childName} (Parent: ${c.parentName})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCase = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Contact Item to Request', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorNavy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ContactItemType>(
                        value: selectedItem,
                        isExpanded: true,
                        dropdownColor: colorSlate,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: ContactItemType.phone, child: Text('Phone Number')),
                          DropdownMenuItem(value: ContactItemType.whatsapp, child: Text('WhatsApp Number')),
                          DropdownMenuItem(value: ContactItemType.email, child: Text('Email Address')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedItem = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Purpose of Request (DPDP Compliance)', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: purposeCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Explain why contact sharing is necessary...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
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
                      if (purposeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Purpose is required.'), backgroundColor: Colors.redAccent),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        await ContactConsentService().requestContactSharing(
                          caseId: selectedCase.id,
                          childId: selectedCase.childId,
                          requesterId: user.uid,
                          requesterName: _currentLLGName,
                          requesterRole: 'llg',
                          recipientId: selectedCase.parentId,
                          recipientName: selectedCase.parentName,
                          recipientRole: 'parent',
                          requestedItem: selectedItem,
                          purpose: purposeCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contact-sharing request submitted to parent.'), backgroundColor: Color(0xFF10B981)),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Request', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 8. OBSERVATION HISTORY PAGE (Scoped to Authenticated Specialist)
  // =========================================================================
  Widget _buildObservationHistoryPage() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text('Please authenticate'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('llgObservations')
          .where('llgId', isEqualTo: user.uid)
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    Text(
                      'My Immutable Observation Records (${docs.length})',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.lock, size: 14, color: colorAmber),
                        const SizedBox(width: 6),
                        Text('Locked & Traceable', style: GoogleFonts.inter(color: colorAmber, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('No observation records found for your account.', style: GoogleFonts.inter(color: colorTextMuted)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final obs = docs[idx].data() as Map<String, dynamic>;
                        final llgName = obs['llgName'] ?? 'Specialist';
                        final severity = obs['severity'] ?? 'guidance';
                        final observation = obs['observation'] ?? '';
                        final recommendations = List<String>.from(obs['recommendations'] ?? []);
                        final timestamp = (obs['recordedAt'] is Timestamp)
                            ? (obs['recordedAt'] as Timestamp).toDate()
                            : DateTime.now();

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorNavy,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Logged by $llgName',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: severity == 'critical'
                                          ? Colors.red.withOpacity(0.2)
                                          : (severity == 'high' ? colorAmber.withOpacity(0.2) : colorTeal.withOpacity(0.2)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      severity.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: severity == 'critical'
                                            ? Colors.redAccent
                                            : (severity == 'high' ? colorAmber : colorTeal),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(timestamp),
                                    style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                observation,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.9), height: 1.4),
                              ),
                              if (recommendations.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Recommendations:',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colorTeal, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                ...recommendations.map((r) => Padding(
                                      padding: const EdgeInsets.only(left: 6, bottom: 2),
                                      child: Text('• $r', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                                    )),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // CHILD DETAIL PANEL (Right side drawer)
  // =========================================================================
  Widget _buildChildDetailPanel(ChildModel child) {
    final user = _auth.currentUser;
    final isPermitted = _selectedCase != null && _selectedCase!.canAccessChildData;
    final hasScoresPermission = _selectedCase?.authorizedCategories.contains('skill_scores') ?? false;
    final hasActivityPermission = _selectedCase?.authorizedCategories.contains('activity_history') ?? false;

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 440,
      child: Container(
        decoration: const BoxDecoration(
          color: colorSlate,
          border: Border(left: BorderSide(color: colorBorder, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(-4, 0)),
          ],
        ),
        child: Column(
          children: [
            // Drawer Header
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: colorBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          child.name,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          isPermitted
                              ? 'Age ${child.ageYears} • Case ID: ${_selectedCase!.id}'
                              : 'Age ${child.ageYears} • Access Restricted',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isPermitted ? colorTeal : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => setState(() => _isDrawerOpen = false),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // If access is NOT permitted (pending, revoked, or no consent)
                    if (!isPermitted) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.gpp_bad_outlined, color: Colors.redAccent, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Access Restricted',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedCase?.status == CaseStatus.revoked
                                  ? 'Parent revoked consultation consent on ${DateFormat.yMMMd().format(_selectedCase!.revokedAt ?? DateTime.now())}.\nReason: ${_selectedCase?.revocationReason ?? "Parental withdrawal under DPDP"}.'
                                  : 'Active parental consent is required before accessing clinical notes, developmental scores, or activity history.',
                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Case & DPDP Consent Scope Card
                    if (_selectedCase != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorNavy,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isPermitted ? colorTeal.withOpacity(0.4) : colorBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'DPDP Consent Record',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: colorTeal),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isPermitted ? const Color(0xFF10B981) : colorAmber).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _selectedCase!.status.name.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isPermitted ? const Color(0xFF10B981) : colorAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildDetailRow('Purpose', _selectedCase!.purpose),
                            const Divider(color: colorBorder, height: 12),
                            _buildDetailRow('Parent Name', _selectedCase!.parentName),
                            const Divider(color: colorBorder, height: 12),
                            _buildDetailRow('Notice Version', 'DPDP v${_selectedCase!.consentNoticeVersion}'),
                            const Divider(color: colorBorder, height: 12),
                            _buildDetailRow(
                              'Consent Expiry',
                              _selectedCase!.consentExpiresAt != null
                                  ? DateFormat.yMMMd().format(_selectedCase!.consentExpiresAt!)
                                  : '90 days from grant',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Permitted Child Data (Data Minimised - Exact DOB masked)
                    if (isPermitted) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorNavy,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Child Age', '${child.ageYears} years (DOB masked)'),
                            const Divider(color: colorBorder, height: 16),
                            _buildDetailRow('Gender', child.gender),
                            const Divider(color: colorBorder, height: 16),
                            _buildDetailRow('Focus Domain', _selectedCase?.purpose ?? 'Developmental'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Current Skill Scores (Only if authorized)
                      if (hasScoresPermission) ...[
                        Text(
                          'Developmental Domain Scores',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<DocumentSnapshot>(
                          stream: _firestore.collection('skillProfiles').doc(child.childId).snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                            final domains = ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative'];

                            return Column(
                              children: domains.map((domain) {
                                final score = (data[domain] is num) ? (data[domain] as num).toDouble() : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          domain[0].toUpperCase() + domain.substring(1),
                                          style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: (score / 100).clamp(0.0, 1.0),
                                            backgroundColor: colorNavy,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              score < 40 ? Colors.redAccent : (score < 70 ? colorAmber : colorTeal),
                                            ),
                                            minHeight: 8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${score.toStringAsFixed(1)}%',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Recent Score Events (Only if activity history authorized)
                      if (hasActivityPermission) ...[
                        Text(
                          'Score Ledger Audit History (Latest 5)',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: ScoreLedgerService().getScoreHistory(childId: child.childId),
                          builder: (context, snapshot) {
                            final events = snapshot.data ?? [];
                            if (events.isEmpty) {
                              return Text('No score events recorded yet.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12));
                            }

                            return Column(
                              children: events.take(5).map((e) {
                                final delta = (e['appliedScoreDelta'] is num) ? (e['appliedScoreDelta'] as num).toDouble() : 0.0;
                                final domain = e['skillDomain'] ?? 'skill';
                                final title = e['activityTitle'] ?? 'Activity';
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
                                            Text(title, style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                                            Text('$domain • Level ${e['levelAtTime'] ?? 1}', style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${isPositive ? '+' : ''}${delta.toStringAsFixed(1)} pts',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isPositive ? const Color(0xFF10B981) : Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Two-Way Direct Secure Messaging
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_selectedCase != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    specialistCase: _selectedCase!,
                                    currentUserId: user?.uid ?? '',
                                    currentUserName: _currentLLGName,
                                    currentUserRole: 'llg',
                                    otherParticipantName: _selectedCase!.parentName.isNotEmpty
                                        ? _selectedCase!.parentName
                                        : 'Parent',
                                    otherParticipantRole: 'parent',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Open Direct Secure Messages'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Assign Personalized Recommendation
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SendRecommendationPage(
                                  child: child,
                                  specialistCase: _selectedCase,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.psychology_outlined, size: 18),
                          label: const Text('Assign Personalized Recommendation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Record Consultation Summary (WhatsApp / Audio / Video)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (_selectedCase != null) {
                              _showRecordConsultationDialog(context, child, _selectedCase!);
                            }
                          },
                          icon: const Icon(Icons.assignment_turned_in_outlined, size: 18, color: Color(0xFFF59E0B)),
                          label: const Text('Record Consultation Summary', style: TextStyle(color: Color(0xFFF59E0B))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Actions: Add Observation / Guidance Note
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddObservationPage(
                                  child: child,
                                  onSuccess: () {
                                    setState(() => _isDrawerOpen = false);
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.note_add_outlined, size: 18),
                          label: const Text('Add Clinical / Educational Observation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Resolve / Close Case
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: colorSlate,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: Text('Complete Consultation Case', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                                content: Text(
                                  'Are you sure you want to mark this consultation as completed for ${child.name}? This will complete the specialist assignment and log an immutable audit resolution.',
                                  style: GoogleFonts.inter(color: colorTextMuted),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                    child: const Text('Complete Case', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && _selectedCase != null && user != null) {
                              await _caseService.closeCase(_selectedCase!.id, specialistId: user.uid);
                              await FlagService().resolveAutoUnflag(childId: child.childId, domain: 'cognitive');
                              setState(() => _isDrawerOpen = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Case completed successfully.'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF10B981)),
                          label: const Text('Complete Case (Mark Resolved)', style: TextStyle(color: Color(0xFF10B981))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),

                      // Contact Sharing Section
                      if (_selectedCase != null) ...[
                        const SizedBox(height: 20),
                        _buildContactSharingSection(_selectedCase!),
                      ],

                      // Assigned Personalized Recommendations Stream
                      const SizedBox(height: 20),
                      Text(
                        'Assigned Personalized Recommendations',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      _buildChildRecommendationsList(child.childId),

                      // Recorded Consultation Summaries Stream
                      if (_selectedCase != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Recorded Consultation Summaries',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        _buildCaseConsultationSummariesList(_selectedCase!.id),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecordConsultationDialog(BuildContext context, ChildModel child, SpecialistCaseModel caseModel) {
    final formKey = GlobalKey<FormState>();
    final reasonCtrl = TextEditingController(text: caseModel.purpose);
    final discussionCtrl = TextEditingController();
    final guidanceCtrl = TextEditingController();
    final questionsCtrl = TextEditingController();
    final followUpCtrl = TextEditingController();
    String mode = 'whatsapp';
    DateTime? reviewDate = DateTime.now().add(const Duration(days: 7));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'Record Consultation Summary (${child.name})',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consultation Mode', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: mode,
                      dropdownColor: colorNavy,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colorNavy,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Consultation')),
                        DropdownMenuItem(value: 'voice_call', child: Text('Phone / Voice Call')),
                        DropdownMenuItem(value: 'video_call', child: Text('Video Consultation')),
                        DropdownMenuItem(value: 'in_person', child: Text('In-Person Session')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => mode = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Reason / Main Topics *', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: reasonCtrl,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      validator: (v) => (v == null || v.trim().length < 4) ? 'Please enter a valid reason.' : null,
                      decoration: InputDecoration(
                        hintText: 'e.g. Fine motor skills progression discussion',
                        hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                        filled: true,
                        fillColor: colorNavy,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Guidance & Recommendations Given *', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: guidanceCtrl,
                      maxLines: 3,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      validator: (v) => (v == null || v.trim().length < 8) ? 'Please enter the guidance provided.' : null,
                      decoration: InputDecoration(
                        hintText: 'Summarize advice and interventions recommended to parent',
                        hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                        filled: true,
                        fillColor: colorNavy,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Parent Questions / Feedback', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: questionsCtrl,
                      maxLines: 2,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Questions raised by the parent during consultation',
                        hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                        filled: true,
                        fillColor: colorNavy,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Agreed Follow-up Actions (one per line)', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: followUpCtrl,
                      maxLines: 2,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Action 1: Try pincer grasp exercises\nAction 2: Report back in 5 days',
                        hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                        filled: true,
                        fillColor: colorNavy,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
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
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final user = _auth.currentUser;
                        final followUps = followUpCtrl.text
                            .split('\n')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        await ConsultationSummaryService().submitSummary(
                          caseId: caseModel.id,
                          childId: child.childId,
                          childName: child.name,
                          parentId: caseModel.parentId,
                          parentName: caseModel.parentName,
                          llgId: user?.uid ?? '',
                          llgName: _currentLLGName,
                          consultationMode: mode,
                          consultationDate: DateTime.now(),
                          consultationReason: reasonCtrl.text.trim(),
                          concernsDiscussed: discussionCtrl.text.trim().isNotEmpty
                              ? [discussionCtrl.text.trim()]
                              : [reasonCtrl.text.trim()],
                          guidanceProvided: guidanceCtrl.text.trim(),
                          parentQuestionsOrFeedback: questionsCtrl.text.trim(),
                          agreedFollowUpActions: followUps,
                          nextReviewDate: reviewDate,
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Consultation summary recorded successfully.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Summary', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSharingSection(SpecialistCaseModel caseModel) {
    return FutureBuilder<ContactConsentModel?>(
      future: ContactConsentService().getActiveConsent(caseModel.id),
      builder: (context, snapshot) {
        final consent = snapshot.data;
        final hasPhone = consent != null && consent.hasValidConsentFor('phone');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorNavy,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hasPhone ? const Color(0xFF10B981).withOpacity(0.4) : colorBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.contact_phone_outlined,
                        size: 16,
                        color: hasPhone ? const Color(0xFF10B981) : colorTextMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Direct Contact Access',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: hasPhone ? const Color(0xFF10B981) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (hasPhone ? const Color(0xFF10B981) : colorAmber).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasPhone ? 'CONSENT GRANTED' : 'CONSENT REQUIRED',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasPhone ? const Color(0xFF10B981) : colorAmber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasPhone) ...[
                Text(
                  'Parent Phone: ${consent.sharedPhoneNumber ?? "Available under DPDP consent"}',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'WhatsApp sessions occur outside LittleLumin. Please log consultation summaries.',
                  style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
                ),
              ] else ...[
                Text(
                  'Phone and WhatsApp contacts are hidden until explicit consent is granted by the parent.',
                  style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final user = _auth.currentUser;
                    if (user != null) {
                      await ContactConsentService().requestContactSharing(
                        caseId: caseModel.id,
                        childId: caseModel.childId,
                        requesterId: user.uid,
                        requesterName: _currentLLGName,
                        requesterRole: 'llg',
                        recipientId: caseModel.parentId,
                        recipientName: caseModel.parentName,
                        recipientRole: 'parent',
                        requestedItem: ContactItemType.phone,
                        purpose: 'Coordinating developmental guidance sessions via WhatsApp/Phone.',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contact-sharing request sent to parent.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.send, size: 14, color: Color(0xFF0EA5E9)),
                  label: const Text('Request Parent Contact Sharing', style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0EA5E9)),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChildRecommendationsList(String childId) {
    return StreamBuilder<List<RecommendationModel>>(
      stream: RecommendationService().getChildRecommendationsStream(childId),
      builder: (context, snapshot) {
        final recs = snapshot.data ?? [];
        if (recs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorNavy,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorBorder),
            ),
            child: Text(
              'No recommendations assigned yet for this child.',
              style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
            ),
          );
        }

        return Column(
          children: recs.map((rec) {
            Color statusColor = colorTeal;
            if (rec.status == RecommendationStatus.completed) statusColor = const Color(0xFF10B981);
            if (rec.status == RecommendationStatus.discontinued) statusColor = Colors.redAccent;
            if (rec.status == RecommendationStatus.paused) statusColor = colorAmber;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorNavy,
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
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rec.status.name.toUpperCase(),
                          style: GoogleFonts.inter(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Domain: ${rec.skillDomain.toUpperCase()} • ${rec.durationMinutes} mins • ${rec.frequency}',
                    style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
                  ),
                  if (rec.parentResponse != ParentActivityResponse.none) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorSlate,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.feedback_outlined, size: 14, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Parent Response: ${rec.parentResponse.name.toUpperCase()}${rec.parentFeedback != null && rec.parentFeedback!.isNotEmpty ? " - \"${rec.parentFeedback}\"" : ""}',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCaseConsultationSummariesList(String caseId) {
    return StreamBuilder<List<ConsultationSummaryModel>>(
      stream: ConsultationSummaryService().getCaseSummariesStream(caseId),
      builder: (context, snapshot) {
        final summaries = snapshot.data ?? [];
        if (summaries.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorNavy,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorBorder),
            ),
            child: Text(
              'No external consultation summaries logged yet.',
              style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
            ),
          );
        }

        return Column(
          children: summaries.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorNavy,
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
                        'Session (${s.consultationMode.toUpperCase()})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        DateFormat.yMMMd().format(s.consultationDate),
                        style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Reason: ${s.consultationReason}', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Guidance: ${s.guidanceProvided}', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }
}
