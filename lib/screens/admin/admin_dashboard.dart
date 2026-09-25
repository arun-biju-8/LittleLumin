// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/llg_service.dart';
import '../../utils/validators.dart';
import '../auth/login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LLGService _llgService = LLGService();

  int _selectedSidebarIndex = 0;
  String _searchQuery = '';
  Map<String, dynamic>? _selectedLLG;
  bool _isSplitPanelOpen = false;

  // Colors matching LLG Dashboard
  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorCard = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorGreen = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  String _currentAdminName = 'Administrator';

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  Future<void> _loadAdminInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentAdminName = user.displayName ?? 'Administrator';
      });
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out of the administrator portal?',
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
                      if (_isSplitPanelOpen && _selectedLLG != null)
                        _buildLLGVerificationSplitPanel(_selectedLLG!),
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
          // Header / Logo
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined, color: colorTeal, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LittleLumin',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Admin Portal',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: colorTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sidebar Navigation Items
          _buildSidebarNavItem(0, Icons.dashboard_outlined, 'Overview'),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('llgProfiles')
                .where('verificationStatus', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _buildSidebarNavItem(
                1,
                Icons.verified_outlined,
                'LLG Verification Queue',
                badgeCount: count > 0 ? count : null,
              );
            },
          ),
          _buildSidebarNavItem(2, Icons.people_outline, 'Users Directory'),
          _buildSidebarNavItem(3, Icons.auto_stories_outlined, 'Activities Library'),
          _buildSidebarNavItem(4, Icons.analytics_outlined, 'Platform Analytics'),
          _buildSidebarNavItem(5, Icons.security_outlined, 'Audit Trail'),

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

  Widget _buildSidebarNavItem(int index, IconData icon, String label, {int? badgeCount}) {
    final isSelected = _selectedSidebarIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSidebarIndex = index;
            _isSplitPanelOpen = false;
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
              Icon(icon, color: isSelected ? colorTeal : colorTextMuted, size: 19),
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
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
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
                  hintText: 'Search users, applications, activities...',
                  hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: colorTextMuted, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: colorTextMuted, size: 22),
            onPressed: () {},
          ),

          const SizedBox(width: 12),

          // Admin Profile Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorNavy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colorBorder),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: colorTeal,
                  child: Icon(Icons.shield, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentAdminName,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: colorTeal, size: 16),
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
        return _buildLLGVerificationQueuePage();
      case 2:
        return _buildUsersDirectoryPage();
      case 3:
        return _buildActivitiesLibraryPage();
      case 4:
        return _buildPlatformAnalyticsPage();
      case 5:
        return _buildAuditTrailPage();
      default:
        return _buildOverviewPage();
    }
  }

  // =========================================================================
  // OVERVIEW PAGE
  // =========================================================================
  Widget _buildOverviewPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, userSnap) {
        final users = userSnap.data?.docs ?? [];
        final totalUsers = users.length;
        final parentsCount = users.where((u) => u.data() is Map && (u.data() as Map)['userType'] == 'parent').length;
        final llgsCount = users.where((u) => u.data() is Map && (u.data() as Map)['userType'] == 'llg').length;
        final pendingLLGsCount = users.where((u) => u.data() is Map && (u.data() as Map)['userType'] == 'llg_pending').length;

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('children').snapshots(),
          builder: (context, childSnap) {
            final childrenCount = childSnap.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('activities').snapshots(),
              builder: (context, actSnap) {
                final activitiesCount = actSnap.data?.docs.length ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Row (6 cards)
                      GridView.count(
                        crossAxisCount: 6,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.3,
                        children: [
                          _buildKPICard('Total Users', totalUsers.toString(), Icons.group_outlined, colorTeal),
                          _buildKPICard('Parents', parentsCount.toString(), Icons.family_restroom_outlined, colorGreen),
                          _buildKPICard('Verified LLGs', llgsCount.toString(), Icons.psychology_outlined, colorTeal),
                          _buildKPICard('Pending LLGs', pendingLLGsCount.toString(), Icons.pending_actions_outlined, colorAmber),
                          _buildKPICard('Children', childrenCount.toString(), Icons.child_care_outlined, const Color(0xFFEC4899)),
                          _buildKPICard('Activities', activitiesCount.toString(), Icons.auto_stories_outlined, const Color(0xFF818CF8)),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // User Type Distribution Chart & Quick Actions
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Distribution Bar Chart
                          Expanded(
                            flex: 6,
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
                                    'User Type Distribution',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 180,
                                    child: BarChart(
                                      BarChartData(
                                        alignment: BarChartAlignment.spaceAround,
                                        maxY: (totalUsers + 5).toDouble(),
                                        barTouchData: BarTouchData(enabled: true),
                                        titlesData: FlTitlesData(
                                          show: true,
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              getTitlesWidget: (val, _) {
                                                switch (val.toInt()) {
                                                  case 0:
                                                    return const Text('Parents', style: TextStyle(color: colorTextMuted, fontSize: 11));
                                                  case 1:
                                                    return const Text('LLG', style: TextStyle(color: colorTextMuted, fontSize: 11));
                                                  case 2:
                                                    return const Text('Pending', style: TextStyle(color: colorTextMuted, fontSize: 11));
                                                  case 3:
                                                    return const Text('Children', style: TextStyle(color: colorTextMuted, fontSize: 11));
                                                  default:
                                                    return const Text('');
                                                }
                                              },
                                            ),
                                          ),
                                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        ),
                                        gridData: const FlGridData(show: false),
                                        borderData: FlBorderData(show: false),
                                        barGroups: [
                                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: parentsCount.toDouble(), color: colorGreen, width: 28, borderRadius: BorderRadius.circular(4))]),
                                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: llgsCount.toDouble(), color: colorTeal, width: 28, borderRadius: BorderRadius.circular(4))]),
                                          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: pendingLLGsCount.toDouble(), color: colorAmber, width: 28, borderRadius: BorderRadius.circular(4))]),
                                          BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: childrenCount.toDouble(), color: const Color(0xFFEC4899), width: 28, borderRadius: BorderRadius.circular(4))]),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Recent Platform Activity (Timeline)
                          Expanded(
                            flex: 6,
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
                                        'Recent Platform Activity',
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const Icon(Icons.history, color: colorTextMuted, size: 18),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: _firestore.collection('adminAuditLogs').orderBy('timestamp', descending: true).limit(5).snapshots(),
                                    builder: (context, auditSnap) {
                                      final logs = auditSnap.data?.docs ?? [];
                                      if (logs.isEmpty) {
                                        return Text('No recent administrative logs.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13));
                                      }

                                      return ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: logs.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                                        itemBuilder: (context, idx) {
                                          final log = logs[idx].data() as Map<String, dynamic>;
                                          final action = log['action'] ?? 'Platform Event';
                                          final actor = log['actorType'] ?? 'system';
                                          return Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: colorNavy,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: colorBorder),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.check_circle_outline, color: colorTeal, size: 16),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    '$action ($actor)',
                                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                                                    overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted, fontWeight: FontWeight.w500)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // LLG VERIFICATION QUEUE (Per-Certificate Verification)
  // =========================================================================
  Widget _buildLLGVerificationQueuePage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('llgProfiles').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data?.docs ?? [];
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final spec = (data['specialization'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || spec.contains(_searchQuery);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LLG Specialist Verification Queue (${docs.length})',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Per-certificate verification workflow required for platform approval',
                      style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.5),
                        1: FlexColumnWidth(2.0),
                        2: FlexColumnWidth(2.0),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
                          ),
                          children: [
                            _buildTableHeader('Specialist Name'),
                            _buildTableHeader('Specialization'),
                            _buildTableHeader('Certificates Uploaded'),
                            _buildTableHeader('Status'),
                            _buildTableHeader('Action'),
                          ],
                        ),
                        ...docs.map((d) {
                          final data = d.data() as Map<String, dynamic>;
                          final uid = d.id;
                          data['uid'] = uid;
                          final name = data['name'] ?? 'Specialist';
                          final spec = data['specialization'] ?? 'Early Childhood';
                          final isVerified = data['isVerified'] == true;
                          final status = data['verificationStatus'] ?? (isVerified ? 'approved' : 'pending');

                          // Count certificates
                          int certCount = 0;
                          if ((data['qualificationCertificateLink'] ?? '').toString().isNotEmpty) certCount++;
                          if ((data['licenseCertificateLink'] ?? '').toString().isNotEmpty) certCount++;
                          if ((data['experienceCertificateLink'] ?? '').toString().isNotEmpty) certCount++;
                          if ((data['identityProofLink'] ?? '').toString().isNotEmpty) certCount++;
                          if ((data['professionalAssociationLink'] ?? '').toString().isNotEmpty) certCount++;

                          return TableRow(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: colorBorder, width: 0.5)),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(spec, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text('$certCount / 5 Documents', style: GoogleFonts.inter(fontSize: 12, color: colorTeal)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isVerified ? colorGreen.withOpacity(0.15) : colorAmber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isVerified ? colorGreen : colorAmber,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedLLG = data;
                                      _isSplitPanelOpen = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorTeal,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: Text('Verify Docs', style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
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
  // SPLIT PANEL: PER-CERTIFICATE VERIFICATION
  // =========================================================================
  Widget _buildLLGVerificationSplitPanel(Map<String, dynamic> llg) {
    final llgId = llg['uid'] ?? '';
    final name = llg['name'] ?? 'Specialist';
    final qualification = llg['qualification'] ?? 'N/A';
    final experience = llg['experience'] ?? 'N/A';
    final specialization = llg['specialization'] ?? 'N/A';
    final region = llg['region'] ?? 'N/A';
    final languages = llg['languages'] ?? 'N/A';

    final certs = [
      {'type': 'qualification', 'label': 'Qualification Degree', 'url': llg['qualificationCertificateLink']},
      {'type': 'license', 'label': 'Clinical License', 'url': llg['licenseCertificateLink']},
      {'type': 'experience', 'label': 'Experience Certification', 'url': llg['experienceCertificateLink']},
      {'type': 'identity', 'label': 'Government Identity Proof', 'url': llg['identityProofLink']},
      {'type': 'professional', 'label': 'Professional Association Membership', 'url': llg['professionalAssociationLink']},
    ];

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 580,
      child: Container(
        decoration: const BoxDecoration(
          color: colorSlate,
          border: Border(left: BorderSide(color: colorBorder, width: 1)),
          boxShadow: [
            BoxShadow(color: Colors.black45, blurRadius: 25, offset: Offset(-5, 0)),
          ],
        ),
        child: Column(
          children: [
            // Split Panel Header
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
                        Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Independent Per-Certificate Verification', style: GoogleFonts.inter(fontSize: 11, color: colorTeal)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => setState(() => _isSplitPanelOpen = false),
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
                    // Profile Overview Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorNavy,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colorBorder),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Qualification', qualification),
                          const Divider(color: colorBorder, height: 16),
                          _buildDetailRow('Experience', experience),
                          const Divider(color: colorBorder, height: 16),
                          _buildDetailRow('Specialization', specialization),
                          const Divider(color: colorBorder, height: 16),
                          _buildDetailRow('Region & Languages', '$region • $languages'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Certificate Validation Cards (Must verify each)',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),

                    // Certificate Cards Stream
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _llgService.getCertificateVerificationsStream(llgId),
                      builder: (context, snapshot) {
                        final verifDocs = snapshot.data?.docs ?? [];
                        final Map<String, Map<String, dynamic>> verifMap = {};
                        for (var doc in verifDocs) {
                          verifMap[doc.data()['certificateType'] ?? ''] = doc.data();
                        }

                        return Column(
                          children: certs.map((cert) {
                            final type = cert['type'] as String;
                            final label = cert['label'] as String;
                            final url = (cert['url'] ?? '').toString();
                            final verif = verifMap[type];
                            final status = verif?['status'] ?? (url.isNotEmpty ? 'pending' : 'missing');
                            final rejectionReason = verif?['rejectionReason'] as String?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorNavy,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: status == 'verified'
                                      ? colorGreen.withOpacity(0.4)
                                      : (status == 'rejected' ? Colors.redAccent.withOpacity(0.4) : colorBorder),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        status == 'verified'
                                            ? Icons.check_circle
                                            : (status == 'rejected' ? Icons.cancel : Icons.file_present_outlined),
                                        color: status == 'verified'
                                            ? colorGreen
                                            : (status == 'rejected' ? Colors.redAccent : colorTeal),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: status == 'verified'
                                              ? colorGreen.withOpacity(0.15)
                                              : (status == 'rejected' ? Colors.redAccent.withOpacity(0.15) : colorAmber.withOpacity(0.15)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: status == 'verified'
                                                ? colorGreen
                                                : (status == 'rejected' ? Colors.redAccent : colorAmber),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Rejection Reason: $rejectionReason',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.redAccent)),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (url.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: () async {
                                            final uri = Uri.tryParse(url);
                                            if (uri != null) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          icon: const Icon(Icons.open_in_new, size: 14, color: colorTeal),
                                          label: Text('Open Document', style: GoogleFonts.inter(fontSize: 12, color: colorTeal)),
                                        )
                                      else
                                        Text('No link uploaded', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                                      const Spacer(),
                                      if (url.isNotEmpty) ...[
                                        OutlinedButton(
                                          onPressed: () => _showRejectCertificateDialog(llgId, type, url),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            side: const BorderSide(color: Colors.redAccent),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          child: const Text('Reject', style: TextStyle(fontSize: 11)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final admin = _auth.currentUser;
                                            await _llgService.verifyCertificate(
                                              llgId: llgId,
                                              certType: type,
                                              certUrl: url,
                                              adminId: admin?.uid ?? 'admin',
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('✅ $label verified successfully.')),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colorGreen,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          child: const Text('Verify', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRejectCertificateDialog(String llgId, String certType, String certUrl) async {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Reject Certificate: $certType', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify the rejection reason so the specialist can re-upload:',
                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Incomplete license, expired document, blurred photo...',
                hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                filled: true,
                fillColor: colorNavy,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              final err = Validators.safeText(reason, 'Rejection reason', min: 5, max: 500);
              if (err != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
                );
                return;
              }
              Navigator.pop(ctx);
              final admin = _auth.currentUser;
              await _llgService.rejectCertificate(
                llgId: llgId,
                certType: certType,
                certUrl: certUrl,
                adminId: admin?.uid ?? 'admin',
                reason: reason,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Certificate rejection recorded.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // USERS DIRECTORY PAGE (4 tabs: All, Parents, LLG, Pending)
  // =========================================================================
  Widget _buildUsersDirectoryPage() {
    return DefaultTabController(
      length: 4,
      child: Padding(
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
              TabBar(
                labelColor: colorTeal,
                unselectedLabelColor: colorTextMuted,
                indicatorColor: colorTeal,
                tabs: const [
                  Tab(text: 'All Users'),
                  Tab(text: 'Parents'),
                  Tab(text: 'LLG Specialists'),
                  Tab(text: 'Pending LLG'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildUserTableByFilter(null),
                    _buildUserTableByFilter('parent'),
                    _buildUserTableByFilter('llg'),
                    _buildUserTableByFilter('llg_pending'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTableByFilter(String? roleFilter) {
    Query query = _firestore.collection('users');
    if (roleFilter != null) {
      query = query.where('userType', isEqualTo: roleFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No users found in this category.', style: GoogleFonts.inter(color: colorTextMuted)),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(color: colorBorder, height: 1),
          itemBuilder: (context, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            final name = data['name'] ?? 'User';
            final email = data['email'] ?? 'No email';
            final userType = data['userType'] ?? 'parent';
            final phone = data['phone'] ?? '';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: colorNavy,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: GoogleFonts.inter(color: colorTeal, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('$email • $phone', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorNavy,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colorBorder),
                ),
                child: Text(
                  userType.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTeal),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ACTIVITIES LIBRARY & PLATFORM ANALYTICS
  // =========================================================================
  Widget _buildActivitiesLibraryPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('activities').snapshots(),
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
                Text(
                  'Activities Library (${docs.length})',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final act = docs[idx].data() as Map<String, dynamic>;
                      final title = act['title'] ?? 'Activity';
                      final skill = act['skillType'] ?? 'Cognitive';
                      final difficulty = act['difficulty'] ?? 'Easy';
                      final isPreset = act['isPreset'] ?? true;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorNavy,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('$skill • $difficulty • ${isPreset ? 'Preset' : 'AI Generated'}',
                                    style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorTeal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(difficulty, style: GoogleFonts.inter(color: colorTeal, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildPlatformAnalyticsPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('feedback').orderBy('createdAt', descending: true).limit(5).snapshots(),
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
                Text(
                  'Real-Time Feedback & Analytics Stream',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text('Recent Parent Activity Feedbacks (Latest 5):',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: colorTeal, fontSize: 13)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final f = docs[idx].data() as Map<String, dynamic>;
                      final resp = f['childResponse'] ?? 'Okay';
                      final eng = f['engagement'] ?? 'Engaged';
                      final diff = f['difficulty'] ?? 'Just Right';
                      final notes = f['notes'] ?? '';

                      return Container(
                        padding: const EdgeInsets.all(14),
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
                                Text('Response: $resp', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                const SizedBox(width: 12),
                                Text('Engagement: $eng', style: GoogleFonts.inter(color: colorTeal, fontSize: 12)),
                                const Spacer(),
                                Text('Difficulty: $diff', style: GoogleFonts.inter(color: colorAmber, fontSize: 12)),
                              ],
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Parent Notes: "$notes"', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12, fontStyle: FontStyle.italic)),
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

  Widget _buildAuditTrailPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('adminAuditLogs').orderBy('timestamp', descending: true).snapshots(),
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
                    Text('Administrative Audit Trail (${docs.length})',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Row(
                      children: [
                        const Icon(Icons.lock, size: 14, color: colorAmber),
                        const SizedBox(width: 6),
                        Text('Immutable System Trail', style: GoogleFonts.inter(color: colorAmber, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final log = docs[idx].data() as Map<String, dynamic>;
                      final action = log['action'] ?? 'Action';
                      final actorType = log['actorType'] ?? 'system';
                      final target = log['targetId'] ?? '';
                      final timestamp = (log['timestamp'] is Timestamp)
                          ? (log['timestamp'] as Timestamp).toDate()
                          : DateTime.now();

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorNavy,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security, color: colorTeal, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$action by $actorType', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                                  if (target.isNotEmpty)
                                    Text('Target ID: $target', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(DateFormat.yMMMd().add_jm().format(timestamp),
                                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
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

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTextMuted, letterSpacing: 0.5),
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