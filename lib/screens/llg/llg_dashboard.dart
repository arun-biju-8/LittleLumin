// lib/screens/llg/llg_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../services/score_ledger_service.dart';
import '../../services/flag_service.dart';
import '../../services/specialist_case_service.dart';
import '../auth/login_page.dart';
import 'add_observation_page.dart';
import 'llg_profile_page.dart';

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
  ChildModel? _selectedChild;
  SpecialistCaseModel? _selectedCase;
  bool _isDrawerOpen = false;

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
    return Scaffold(
      backgroundColor: colorNavy,
      body: Row(
        children: [
          // 1. Persistent Left Sidebar (240px)
          _buildSidebar(),

          // 2. Main Content Area with Top Bar (64px)
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
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

          // Sidebar Navigation Items
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
          _buildSidebarNavItem(
            index: 3,
            icon: Icons.history_edu_outlined,
            label: 'Observation History',
          ),
          _buildSidebarNavItem(
            index: 4,
            icon: Icons.person_outline,
            label: 'Profile',
          ),

          const Spacer(),

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
  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Row(
        children: [
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
        return _buildObservationHistoryPage();
      case 4:
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
            final totalObservations = obsDocs.length;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Row (4 cards scoped to THIS specialist)
                  Row(
                    children: [
                      Expanded(
                        child: _buildKPICard(
                          title: 'My Active Cases',
                          value: activeCases.length.toString(),
                          subtitle: 'Consented child consultations',
                          icon: Icons.assignment_ind_outlined,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          title: 'Pending Reviews',
                          value: pendingCases.length.toString(),
                          subtitle: 'Awaiting your acceptance',
                          icon: Icons.pending_actions_outlined,
                          color: colorAmber,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          title: 'My Observations',
                          value: totalObservations.toString(),
                          subtitle: 'Documented clinical & guidance notes',
                          icon: Icons.check_circle_outline,
                          color: colorTeal,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildKPICard(
                          title: 'Avg Turnaround',
                          value: '1.8 Days',
                          subtitle: 'Case resolution benchmark',
                          icon: Icons.timer_outlined,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Main Overview Split (Left: Table, Right: Recent Reviews)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Cases Queue (Table)
                      Expanded(
                        flex: 7,
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
                        ),
                      ),

                      const SizedBox(width: 20),

                      // Recent Reviews Timeline (5 latest)
                      Expanded(
                        flex: 4,
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
                        ),
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
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
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
                  onPressed: isRevoked
                      ? null
                      : () {
                          setState(() {
                            _selectedCase = c;
                            _selectedChild = ChildModel(
                              childId: c.childId,
                              parentId: c.parentId,
                              name: c.childName,
                              dateOfBirth: DateTime.now().subtract(Duration(days: c.childAgeYears * 365)),
                              gender: 'Child',
                              createdAt: c.createdAt,
                            );
                            _isDrawerOpen = true;
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(
                    isRevoked ? 'Locked' : 'Open Case',
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
            return c.childName.toLowerCase().contains(_searchQuery) ||
                c.parentName.toLowerCase().contains(_searchQuery) ||
                c.purpose.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (cases.isEmpty) {
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
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildMyCasesTable(cases),
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
  // OBSERVATION HISTORY PAGE (Scoped to Authenticated Specialist)
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
