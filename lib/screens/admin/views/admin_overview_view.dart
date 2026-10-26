// lib/screens/admin/views/admin_overview_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../models/admin_models.dart';
import '../../../services/admin_service.dart';

class AdminOverviewView extends StatelessWidget {
  final AdminService adminService;
  final Function(int targetGroupIndex, int targetSubIndex) onNavigate;

  const AdminOverviewView({
    super.key,
    required this.adminService,
    required this.onNavigate,
  });

  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorCard = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorGreen = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<dynamic>>(
      stream: _combineDashboardStreams(),
      builder: (context, snapshot) {
        final users = (snapshot.data != null && snapshot.data!.isNotEmpty)
            ? (snapshot.data![0] as List<DocumentSnapshot>)
            : <DocumentSnapshot>[];
        final children = (snapshot.data != null && snapshot.data!.length > 1)
            ? (snapshot.data![1] as List<DocumentSnapshot>)
            : <DocumentSnapshot>[];
        final activities = (snapshot.data != null && snapshot.data!.length > 2)
            ? (snapshot.data![2] as List<DocumentSnapshot>)
            : <DocumentSnapshot>[];
        final pendingLLGs = (snapshot.data != null && snapshot.data!.length > 3)
            ? (snapshot.data![3] as List<DocumentSnapshot>)
            : <DocumentSnapshot>[];
        final recoveryRequests = (snapshot.data != null && snapshot.data!.length > 4)
            ? (snapshot.data![4] as List<AccountRecoveryRequestModel>)
            : <AccountRecoveryRequestModel>[];

        final totalUsers = users.length;
        final parentsCount = users.where((u) => u.data() is Map && (u.data() as Map)['userType'] == 'parent').length;
        final llgsCount = users.where((u) => u.data() is Map && ((u.data() as Map)['userType'] == 'llg' || (u.data() as Map)['userType'] == 'specialist')).length;
        final suspendedCount = users.where((u) => u.data() is Map && (u.data() as Map)['status'] == 'suspended').length;
        final childrenCount = children.length;
        final activitiesCount = activities.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrative Command & Monitoring',
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time overview of users, specialist verifications, activity assignments, and platform health.',
                        style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onNavigate(6, 3), // Security & Configuration / System Health
                    icon: const Icon(Icons.favorite_border, size: 16, color: colorGreen),
                    label: Text('System Health', style: GoogleFonts.inter(color: colorGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: colorGreen)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // KPI Cards Grid (Actionable)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final crossCount = isWide ? 6 : (constraints.maxWidth > 600 ? 3 : 2);
                  return GridView.count(
                    crossAxisCount: crossCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.35,
                    children: [
                      _buildActionableKPICard(
                        title: 'Total Users',
                        value: totalUsers.toString(),
                        icon: Icons.people_outline,
                        color: colorTeal,
                        onTap: () => onNavigate(1, 0), // User Management / All Users
                      ),
                      _buildActionableKPICard(
                        title: 'Parents',
                        value: parentsCount.toString(),
                        icon: Icons.family_restroom_outlined,
                        color: colorGreen,
                        onTap: () => onNavigate(1, 1), // User Management / Parents
                      ),
                      _buildActionableKPICard(
                        title: 'Verified LLGs',
                        value: llgsCount.toString(),
                        icon: Icons.psychology_outlined,
                        color: colorTeal,
                        onTap: () => onNavigate(2, 0), // LLG Management / Specialist Directory
                      ),
                      _buildActionableKPICard(
                        title: 'Pending LLGs',
                        value: pendingLLGs.length.toString(),
                        icon: Icons.pending_actions_outlined,
                        color: colorAmber,
                        onTap: () => onNavigate(2, 1), // LLG Management / Verification Queue
                      ),
                      _buildActionableKPICard(
                        title: 'Children',
                        value: childrenCount.toString(),
                        icon: Icons.child_care_outlined,
                        color: const Color(0xFFEC4899),
                        onTap: () => onNavigate(1, 2), // User Management / Children
                      ),
                      _buildActionableKPICard(
                        title: 'Activities',
                        value: activitiesCount.toString(),
                        icon: Icons.auto_stories_outlined,
                        color: const Color(0xFF818CF8),
                        onTap: () => onNavigate(3, 0), // Activity Management / Library
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Middle Section: Charts & Distribution
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final userDistributionCard = _buildUserRoleDistributionCard(totalUsers, parentsCount, llgsCount, pendingLLGs.length, suspendedCount);
                  final quickActionsCard = _buildQuickActionsCard();

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: userDistributionCard),
                        const SizedBox(width: 20),
                        Expanded(flex: 5, child: quickActionsCard),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        userDistributionCard,
                        const SizedBox(height: 20),
                        quickActionsCard,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),

              // Pending Administrative Tasks & Action Items
              _buildPendingTasksSection(pendingLLGs, recoveryRequests),
            ],
          ),
        );
      },
    );
  }

  Stream<List<dynamic>> _combineDashboardStreams() async* {
    final firestore = FirebaseFirestore.instance;
    await for (final usersSnap in firestore.collection('users').snapshots()) {
      final childrenSnap = await firestore.collection('children').get();
      final activitiesSnap = await firestore.collection('activities').get();
      final pendingLLG = usersSnap.docs.where((u) => u.data()['userType'] == 'llg_pending').toList();
      final recoverySnap = await firestore
          .collection('accountRecoveryRequests')
          .where('status', isEqualTo: 'pending_review')
          .get();

      final recoveryModels = recoverySnap.docs
          .map((d) => AccountRecoveryRequestModel.fromMap(d.id, d.data()))
          .toList();

      yield [
        usersSnap.docs,
        childrenSnap.docs,
        activitiesSnap.docs,
        pendingLLG,
        recoveryModels,
      ];
    }
  }

  Widget _buildActionableKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
      ),
    );
  }

  Widget _buildUserRoleDistributionCard(
    int totalUsers,
    int parentsCount,
    int llgsCount,
    int pendingLLGsCount,
    int suspendedCount,
  ) {
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
                'User Roles & Account Status Breakdown',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Icon(Icons.pie_chart_outline, color: colorTeal, size: 18),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                      sections: [
                        PieChartSectionData(
                          value: (parentsCount > 0 ? parentsCount : 1).toDouble(),
                          title: '${parentsCount > 0 ? ((parentsCount / (totalUsers > 0 ? totalUsers : 1)) * 100).toInt() : 0}%',
                          color: colorGreen,
                          radius: 46,
                          titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: (llgsCount > 0 ? llgsCount : 1).toDouble(),
                          title: '${llgsCount > 0 ? ((llgsCount / (totalUsers > 0 ? totalUsers : 1)) * 100).toInt() : 0}%',
                          color: colorTeal,
                          radius: 46,
                          titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        PieChartSectionData(
                          value: (pendingLLGsCount > 0 ? pendingLLGsCount : 1).toDouble(),
                          title: '${pendingLLGsCount > 0 ? ((pendingLLGsCount / (totalUsers > 0 ? totalUsers : 1)) * 100).toInt() : 0}%',
                          color: colorAmber,
                          radius: 46,
                          titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (suspendedCount > 0)
                          PieChartSectionData(
                            value: suspendedCount.toDouble(),
                            title: '$suspendedCount',
                            color: Colors.redAccent,
                            radius: 46,
                            titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem('Parents', '$parentsCount', colorGreen),
                      const SizedBox(height: 8),
                      _buildLegendItem('Verified Specialists', '$llgsCount', colorTeal),
                      const SizedBox(height: 8),
                      _buildLegendItem('Pending Review', '$pendingLLGsCount', colorAmber),
                      const SizedBox(height: 8),
                      _buildLegendItem('Suspended', '$suspendedCount', Colors.redAccent),
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

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
        ),
        Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
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
              Text('Fast Operational Shortcuts', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              const Icon(Icons.bolt, color: colorAmber, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          _buildShortcutButton(
            icon: Icons.person_add_alt_1_outlined,
            label: 'Review Specialist Applications',
            subtitle: 'Inspect credentials & certificates in queue',
            color: colorTeal,
            onTap: () => onNavigate(2, 1), // Verification Queue
          ),
          const SizedBox(height: 8),
          _buildShortcutButton(
            icon: Icons.swap_horiz_outlined,
            label: 'Assign Specialist to Parent',
            subtitle: 'Link verified LLG to parent consultation',
            color: colorGreen,
            onTap: () => onNavigate(2, 2), // Parent-LLG Assignments
          ),
          const SizedBox(height: 8),
          _buildShortcutButton(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Generate Administrative Reports',
            subtitle: 'Export audit logs, user lists, and metrics',
            color: const Color(0xFF818CF8),
            onTap: () => onNavigate(5, 4), // Reports & Exports
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorNavy,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: colorTextMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingTasksSection(List<DocumentSnapshot> pendingLLGs, List<AccountRecoveryRequestModel> recoveryRequests) {
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
              Row(
                children: [
                  const Icon(Icons.checklist_rtl_outlined, color: colorAmber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pending Administrative Tasks (${pendingLLGs.length + recoveryRequests.length})',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Text(
                'Requires Review',
                style: GoogleFonts.inter(fontSize: 12, color: colorAmber, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pendingLLGs.isEmpty && recoveryRequests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('✅ No pending administrative tasks! All queues are up to date.',
                    style: GoogleFonts.inter(color: colorGreen, fontSize: 13)),
              ),
            )
          else ...[
            // 1. Pending LLG Applications
            ...pendingLLGs.take(3).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Specialist Applicant';
              final spec = data['specialization'] ?? 'Specialist';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorNavy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions, color: colorAmber, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Specialist Application: $name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('Specialization: $spec • Awaiting document verification', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => onNavigate(2, 1), // Verification Queue
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Review', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              );
            }),

            // 2. Account Recovery Requests
            ...recoveryRequests.take(3).map((req) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorNavy,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_reset, color: colorTeal, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Account Recovery Request: ${req.userName} (${req.userEmail})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('Reason: ${req.userExplanation}', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => onNavigate(1, 5), // Recovery Requests
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      child: const Text('Examine', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
