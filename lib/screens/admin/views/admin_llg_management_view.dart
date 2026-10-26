// lib/screens/admin/views/admin_llg_management_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/admin_models.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/llg_service.dart';
import '../../../services/parent_complaint_service.dart';
import '../../../services/llg_appeal_service.dart';
import '../../../services/specialist_review_service.dart';

class AdminLLGManagementView extends StatefulWidget {
  final AdminService adminService;
  final int initialSubIndex;
  final Function(int targetGroupIndex, int targetSubIndex)? onNavigate;

  const AdminLLGManagementView({
    super.key,
    required this.adminService,
    this.initialSubIndex = 0,
    this.onNavigate,
  });

  @override
  State<AdminLLGManagementView> createState() => _AdminLLGManagementViewState();
}

class _AdminLLGManagementViewState extends State<AdminLLGManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LLGService _llgService = LLGService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  // Split-panel verification preview state
  Map<String, dynamic>? _selectedVerificationLLG;
  bool _isSplitPanelOpen = false;
  int _selectedDocumentIndex = 0;

  // Parent–LLG Assignments Section Filter ('active', 'pending', 'completed', 'all')
  String _parentAssignmentFilter = 'active';

  // Complaint, Appeal & Review Management Services and Filters
  final ParentComplaintService _complaintService = ParentComplaintService();
  final LLGAppealService _appealService = LLGAppealService();
  final SpecialistReviewService _reviewService = SpecialistReviewService();

  String _complaintStatusFilter = 'all';
  String _appealStatusFilter = 'all';
  bool _reviewsModeratedOnly = false;

  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorGreen = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  // Tabs:
  // 0: Specialist Directory
  // 1: Verification Queue
  // 2: Parent–LLG Assignments
  // 3: Child–LLG Assignments
  // 4: Assignment History
  // 5: Parent Complaints
  // 6: Suspension Appeals
  // 7: Ratings & Reviews
  @override
  void initState() {
    super.initState();
    int initialTab = 0;
    if (widget.initialSubIndex >= 0 && widget.initialSubIndex <= 7) {
      initialTab = widget.initialSubIndex;
    }
    _tabController = TabController(length: 8, vsync: this, initialIndex: initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(AdminLLGManagementView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubIndex != oldWidget.initialSubIndex &&
        widget.initialSubIndex >= 0 &&
        widget.initialSubIndex <= 7) {
      _tabController.animateTo(widget.initialSubIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls & Tabs
            _buildHeader(),
            _buildTabBar(),

            if (_isLoading)
              const LinearProgressIndicator(color: colorTeal, backgroundColor: colorNavy),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSpecialistDirectoryTab(),
                  _buildVerificationQueueTab(),
                  _buildParentAssignmentsTab(),
                  _buildChildAssignmentsTab(),
                  _buildAssignmentHistoryTab(),
                  _buildParentComplaintsTab(),
                  _buildSuspensionAppealsTab(),
                  _buildRatingsModerationTab(),
                ],
              ),
            ),
          ],
        ),

        // Split Panel Verification Inspector
        if (_isSplitPanelOpen && _selectedVerificationLLG != null)
          _buildVerificationSplitPanel(_selectedVerificationLLG!),
      ],
    );
  }

  // =========================================================================
  // HEADER & TAB BAR
  // =========================================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      decoration: const BoxDecoration(
        color: colorNavy,
        border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search specialists, parents, or assignment IDs...',
                  hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: colorTextMuted, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: colorTextMuted, size: 16),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.white),
            label: Text('Assign Specialist', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorTeal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showAssignSpecialistDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: colorNavy,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: colorTeal,
        indicatorWeight: 3,
        labelColor: colorTeal,
        unselectedLabelColor: colorTextMuted,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: [
          const Tab(text: 'Specialist Directory'),
          Tab(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('llgProfiles').where('verificationStatus', isEqualTo: 'pending').snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Row(
                  children: [
                    const Text('Verification Queue'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: colorAmber, borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const Tab(text: 'Parent–LLG Assignments'),
          const Tab(text: 'Child–LLG Assignments'),
          const Tab(text: 'Assignment History'),
          Tab(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('parentComplaints')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Row(
                  children: [
                    const Text('Parent Complaints'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          Tab(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('llgAppeals')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return Row(
                  children: [
                    const Text('Suspension Appeals'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: colorAmber, borderRadius: BorderRadius.circular(10)),
                        child: Text('$count', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const Tab(text: 'Ratings & Reviews'),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. SPECIALIST DIRECTORY TAB
  // =========================================================================
  Widget _buildSpecialistDirectoryTab() {
    return StreamBuilder<List<UserModel>>(
      stream: widget.adminService.getUsersStream(roleFilter: 'llg'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        List<UserModel> specialists = snapshot.data ?? [];

        if (_searchQuery.isNotEmpty) {
          specialists = specialists.where((s) {
            return s.name.toLowerCase().contains(_searchQuery) ||
                s.email.toLowerCase().contains(_searchQuery) ||
                s.uid.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (specialists.isEmpty) {
          return Center(
            child: Text('No LLG specialists registered yet.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: specialists.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final s = specialists[index];
            final isVerified = s.isVerified;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.15),
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(s.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(width: 8),
                            if (isVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: colorGreen.withOpacity(0.3)),
                                ),
                                child: Text('VERIFIED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colorGreen)),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorAmber.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: colorAmber.withOpacity(0.3)),
                                ),
                                child: Text('PENDING VERIFICATION', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colorAmber)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(s.email, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  // Caseload Indicator
                  Expanded(
                    flex: 2,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('specialistCases').where('specialistId', isEqualTo: s.uid).where('status', isEqualTo: 'active').snapshots(),
                      builder: (context, snap) {
                        final activeCases = snap.data?.docs.length ?? 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Active Caseload', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                            const SizedBox(height: 2),
                            Text('$activeCases active case(s)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colorTeal)),
                          ],
                        );
                      },
                    ),
                  ),
                  // Status
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.isSuspended ? 'Account Suspended' : 'Status: ${s.status.toUpperCase()}',
                      style: GoogleFonts.inter(fontSize: 12, color: s.isSuspended ? Colors.redAccent : colorGreen),
                    ),
                  ),
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.assignment_turned_in_outlined, color: colorTeal, size: 20),
                        tooltip: 'Review Credentials & Documents',
                        onPressed: () => _openSpecialistCredentialInspection(s.uid, s.name, s.email),
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add_outlined, color: colorTeal, size: 20),
                        tooltip: 'Assign to Parent',
                        onPressed: isVerified
                            ? () => _showAssignSpecialistDialog(preselectedSpecialistId: s.uid, preselectedSpecialistName: s.name)
                            : null,
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

  // =========================================================================
  // 2. VERIFICATION QUEUE TAB
  // =========================================================================
  Widget _buildVerificationQueueTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('llgProfiles')
          .where('verificationStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_outlined, size: 48, color: colorGreen),
                const SizedBox(height: 12),
                Text('Verification Queue is clear!', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('All specialist applications and credentials have been reviewed.', style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Specialist';
            final email = data['email'] ?? '';
            final specialization = data['specialization'] ?? 'Pediatric Guidance';
            final appliedAt = (data['appliedAt'] as Timestamp?)?.toDate();
            final appliedStr = appliedAt != null ? DateFormat('MMM d, y').format(appliedAt) : 'Recently';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorAmber.withOpacity(0.15),
                    child: const Icon(Icons.hourglass_top_rounded, color: colorAmber, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 3),
                        Text('$email | Specialization: $specialization', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Applied on $appliedStr', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.white),
                    label: const Text('Review Application', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
                    onPressed: () {
                      setState(() {
                        _selectedVerificationLLG = {...data, 'id': doc.id, 'uid': doc.id};
                        _selectedDocumentIndex = 0;
                        _isSplitPanelOpen = true;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 3. PARENT–LLG ASSIGNMENTS TAB
  // =========================================================================
  Widget _buildParentAssignmentsTab() {
    return StreamBuilder<List<LLGAssignmentModel>>(
      stream: widget.adminService.getAssignmentsHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final allAssignments = snapshot.data ?? [];
        final activeList = allAssignments.where((a) => a.isActive).toList();
        final pendingList = allAssignments.where((a) => a.isPending).toList();
        final completedList = allAssignments.where((a) => a.isCompletedOrCancelled).toList();

        List<LLGAssignmentModel> filteredList;
        switch (_parentAssignmentFilter) {
          case 'pending':
            filteredList = pendingList;
            break;
          case 'completed':
            filteredList = completedList;
            break;
          case 'all':
            filteredList = allAssignments;
            break;
          case 'active':
          default:
            filteredList = activeList;
            break;
        }

        if (_searchQuery.isNotEmpty) {
          filteredList = filteredList.where((a) {
            return a.parentName.toLowerCase().contains(_searchQuery) ||
                a.specialistName.toLowerCase().contains(_searchQuery) ||
                (a.childName?.toLowerCase().contains(_searchQuery) ?? false) ||
                a.id.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        return Column(
          children: [
            // Sub-Section Filter Chips
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: colorNavy,
                border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
              ),
              child: Row(
                children: [
                  _buildAssignmentSectionFilterChip(
                    label: 'Active Assignments',
                    count: activeList.length,
                    active: _parentAssignmentFilter == 'active',
                    color: colorGreen,
                    onTap: () => setState(() => _parentAssignmentFilter = 'active'),
                  ),
                  const SizedBox(width: 8),
                  _buildAssignmentSectionFilterChip(
                    label: 'Pending Requests',
                    count: pendingList.length,
                    active: _parentAssignmentFilter == 'pending',
                    color: colorAmber,
                    onTap: () => setState(() => _parentAssignmentFilter = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  _buildAssignmentSectionFilterChip(
                    label: 'Completed / Cancelled',
                    count: completedList.length,
                    active: _parentAssignmentFilter == 'completed',
                    color: colorTextMuted,
                    onTap: () => setState(() => _parentAssignmentFilter = 'completed'),
                  ),
                  const SizedBox(width: 8),
                  _buildAssignmentSectionFilterChip(
                    label: 'All Records',
                    count: allAssignments.length,
                    active: _parentAssignmentFilter == 'all',
                    color: colorTeal,
                    onTap: () => setState(() => _parentAssignmentFilter = 'all'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('New Assignment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showAssignSpecialistDialog(),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _parentAssignmentFilter == 'pending'
                                ? Icons.hourglass_empty_rounded
                                : (_parentAssignmentFilter == 'completed'
                                    ? Icons.history_rounded
                                    : Icons.assignment_ind_outlined),
                            size: 48,
                            color: colorTextMuted.withOpacity(0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _parentAssignmentFilter == 'pending'
                                ? 'No pending Parent–LLG requests.'
                                : (_parentAssignmentFilter == 'completed'
                                    ? 'No completed or cancelled assignments.'
                                    : 'No active Parent–LLG assignments found.'),
                            style: GoogleFonts.inter(fontSize: 14, color: colorTextMuted),
                          ),
                          if (_parentAssignmentFilter == 'active' && pendingList.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.pending_actions, size: 16, color: colorAmber),
                              label: Text('View ${pendingList.length} Pending Request(s)',
                                  style: GoogleFonts.inter(color: colorAmber, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: colorAmber),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => setState(() => _parentAssignmentFilter = 'pending'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final a = filteredList[index];
                        final dateStr = DateFormat('MMM d, y').format(a.assignedAt);
                        final isParentRequest = a.assignedBy.contains('Parent');

                        Color statusColor = colorGreen;
                        String statusLabel = 'ACTIVE ASSIGNMENT';
                        if (a.isPending) {
                          statusColor = colorAmber;
                          statusLabel = 'PENDING REQUEST';
                        } else if (a.status == 'completed') {
                          statusColor = Colors.blue;
                          statusLabel = 'COMPLETED';
                        } else if (a.status == 'declined') {
                          statusColor = Colors.redAccent;
                          statusLabel = 'DECLINED';
                        } else if (a.status == 'revoked') {
                          statusColor = Colors.redAccent;
                          statusLabel = 'REVOKED';
                        } else if (a.status == 'removed') {
                          statusColor = Colors.redAccent;
                          statusLabel = 'REMOVED';
                        } else if (a.status == 'reassigned') {
                          statusColor = colorAmber;
                          statusLabel = 'REASSIGNED';
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorSlate,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colorBorder),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: statusColor.withOpacity(0.15),
                                child: Icon(
                                  a.isPending ? Icons.hourglass_top_rounded : Icons.family_restroom,
                                  color: statusColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Parent & Child
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(a.parentName,
                                            style: GoogleFonts.inter(
                                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isParentRequest
                                                ? colorTeal.withOpacity(0.15)
                                                : const Color(0xFF8B5CF6).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isParentRequest
                                                  ? colorTeal.withOpacity(0.3)
                                                  : const Color(0xFF8B5CF6).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            isParentRequest ? 'PARENT REQUEST' : 'ADMIN ASSIGNMENT',
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isParentRequest ? colorTeal : const Color(0xFF8B5CF6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Child: ${a.childName ?? "All covered children"} | Parent ID: ${a.parentId}',
                                      style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                                    ),
                                    if (a.reason != null && a.reason!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Purpose / Notes: ${a.reason}',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Assigned Specialist
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.arrow_forward, size: 12, color: colorTeal),
                                        const SizedBox(width: 6),
                                        Text(a.specialistName,
                                            style: GoogleFonts.inter(
                                                fontSize: 13, fontWeight: FontWeight.w600, color: colorTeal)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${a.isPending ? "Requested" : "Assigned"} on $dateStr • Role: ${a.specialistRole}',
                                      style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                                    ),
                                  ],
                                ),
                              ),
                              // Status Chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withOpacity(0.3)),
                                ),
                                child: Text(statusLabel,
                                    style: GoogleFonts.inter(
                                        fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                              ),
                              const SizedBox(width: 12),
                              // Action Controls
                              if (a.isPending) ...[
                                ElevatedButton(
                                  onPressed: () => _approvePendingCase(a),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  onPressed: () => _declinePendingCase(a),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                              ],
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: colorTextMuted),
                                color: colorSlate,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: colorBorder)),
                                onSelected: (val) {
                                  if (val == 'details') {
                                    _showCaseDetailsDialog(a);
                                  } else if (val == 'reassign') {
                                    _showReassignSpecialistDialog(a);
                                  } else if (val == 'remove') {
                                    _showRemoveAssignmentDialog(a);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'details',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: colorTeal, size: 16),
                                        const SizedBox(width: 10),
                                        Text('View Case Details', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  if (a.isActive) ...[
                                    PopupMenuItem(
                                      value: 'reassign',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.swap_horiz_rounded, color: colorAmber, size: 16),
                                          const SizedBox(width: 10),
                                          Text('Reassign Specialist', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 16),
                                          const SizedBox(width: 10),
                                          Text('Remove Assignment', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAssignmentSectionFilterChip({
    required String label,
    required int count,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : colorSlate,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : colorBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: active ? Colors.white : colorTextMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: active ? color : colorNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: active ? Colors.black : colorTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 4. CHILD–LLG ASSIGNMENTS TAB
  // =========================================================================
  Widget _buildChildAssignmentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('specialistCases').where('status', isEqualTo: 'active').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No active child case assignments on record.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final childName = data['childName'] ?? 'Child';
            final parentName = data['parentName'] ?? 'Parent';
            final specialistName = data['specialistName'] ?? 'Specialist';
            final role = data['specialistRole'] ?? 'Developmental Guide';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorTeal.withOpacity(0.15),
                    child: const Icon(Icons.child_care, color: colorTeal, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(childName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Parent: $parentName', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Specialist: $specialistName', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colorTeal)),
                        const SizedBox(height: 2),
                        Text(role, style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colorGreen.withOpacity(0.3)),
                    ),
                    child: Text('CONSENTED CASE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: colorGreen)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 5. ASSIGNMENT HISTORY TAB
  // =========================================================================
  Widget _buildAssignmentHistoryTab() {
    return StreamBuilder<List<LLGAssignmentModel>>(
      stream: widget.adminService.getAssignmentsHistoryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return Center(
            child: Text('No historical assignment events logged.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: history.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final h = history[index];
            final dateStr = DateFormat('MMM d, y HH:mm').format(h.assignedAt);

            Color statusColor = colorGreen;
            if (h.status == 'reassigned') statusColor = colorAmber;
            if (h.status == 'removed') statusColor = Colors.redAccent;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: statusColor.withOpacity(0.15),
                    child: Icon(
                      h.status == 'active' ? Icons.check : (h.status == 'reassigned' ? Icons.swap_horiz : Icons.close),
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${h.parentName} ➔ ${h.specialistName}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (h.reason != null && h.reason!.isNotEmpty) ? 'Reason: ${h.reason}' : 'Standard administrative assignment',
                          style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(h.status.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // ASSIGN SPECIALIST DIALOG
  // =========================================================================
  void _showAssignSpecialistDialog({String? preselectedSpecialistId, String? preselectedSpecialistName}) {
    String? selectedParentId;
    String? selectedParentName;
    String? selectedChildId;
    String? selectedChildName;
    String? selectedSpecialistId = preselectedSpecialistId;
    String? selectedSpecialistName = preselectedSpecialistName;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
          title: Row(
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: colorTeal, size: 24),
              const SizedBox(width: 10),
              Text('Assign LLG Specialist to Parent', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('1. Select Parent Account', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  StreamBuilder<List<UserModel>>(
                    stream: widget.adminService.getEligibleParentsStream(),
                    builder: (context, snap) {
                      final rawParents = snap.data ?? [];
                      // Deduplicate strictly by stable user ID (uid) and ensure eligible parent standing
                      final Map<String, UserModel> uniqueParents = {};
                      for (final p in rawParents) {
                        if (AdminService.isEligibleParent(p)) {
                          uniqueParents.putIfAbsent(p.uid, () => p);
                        }
                      }
                      final parents = uniqueParents.values.toList()
                        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                      if (selectedParentId != null && !parents.any((p) => p.uid == selectedParentId)) {
                        selectedParentId = null;
                        selectedParentName = null;
                        selectedChildId = null;
                        selectedChildName = null;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text('Select parent...', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
                            value: selectedParentId,
                            dropdownColor: colorNavy,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            items: parents.map((p) => DropdownMenuItem(value: p.uid, child: Text('${p.name} (${p.email})'))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final p = parents.firstWhere((element) => element.uid == val);
                                setDialogState(() {
                                  selectedParentId = val;
                                  selectedParentName = p.name;
                                  selectedChildId = null;
                                  selectedChildName = null;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Child selection
                  if (selectedParentId != null) ...[
                    Text('2. Select Child (Optional)', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('children').where('parentId', isEqualTo: selectedParentId).snapshots(),
                      builder: (context, snap) {
                        final children = snap.data?.docs ?? [];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text('Cover all children or select one...', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
                              value: selectedChildId,
                              dropdownColor: colorNavy,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              items: [
                                const DropdownMenuItem(value: '', child: Text('All Family Children')),
                                ...children.map((c) {
                                  final data = c.data() as Map<String, dynamic>;
                                  return DropdownMenuItem(value: c.id, child: Text(data['name'] ?? 'Child'));
                                }),
                              ],
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedChildId = (val != null && val.isNotEmpty) ? val : null;
                                  if (selectedChildId != null) {
                                    final match = children.firstWhere((c) => c.id == selectedChildId);
                                    selectedChildName = (match.data() as Map<String, dynamic>)['name'];
                                  } else {
                                    selectedChildName = null;
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('3. Select Verified Specialist', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  StreamBuilder<List<UserModel>>(
                    stream: widget.adminService.getUsersStream(roleFilter: 'llg'),
                    builder: (context, snap) {
                      final specialists = (snap.data ?? []).where((s) => s.isVerified).toList();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text('Select verified specialist...', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
                            value: selectedSpecialistId,
                            dropdownColor: colorNavy,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            items: specialists.map((s) => DropdownMenuItem(value: s.uid, child: Text('${s.name} (${s.email})'))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final s = specialists.firstWhere((element) => element.uid == val);
                                setDialogState(() {
                                  selectedSpecialistId = val;
                                  selectedSpecialistName = s.name;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Assignment Notes / Guidance Purpose', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter administrative reason or specific developmental focus...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
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
              onPressed: () async {
                if (selectedParentId == null || selectedSpecialistId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both parent and specialist.')));
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await widget.adminService.assignSpecialistToParent(
                    parentId: selectedParentId!,
                    parentName: selectedParentName ?? 'Parent',
                    specialistId: selectedSpecialistId!,
                    specialistName: selectedSpecialistName ?? 'Specialist',
                    childId: selectedChildId,
                    childName: selectedChildName,
                    notes: notesController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Assigned $selectedSpecialistName to $selectedParentName successfully!'), backgroundColor: colorGreen),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
              child: const Text('Confirm Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // REASSIGN SPECIALIST DIALOG
  // =========================================================================
  void _showReassignSpecialistDialog(LLGAssignmentModel assignment) {
    String? newSpecialistId;
    String? newSpecialistName;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorAmber)),
          title: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: colorAmber, size: 24),
              const SizedBox(width: 10),
              Text('Reassign Specialist', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Parent: ${assignment.parentName}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Current Specialist: ${assignment.specialistName}', style: GoogleFonts.inter(color: colorAmber, fontSize: 12)),
                const SizedBox(height: 16),
                Text('Select New Verified Specialist', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                StreamBuilder<List<UserModel>>(
                  stream: widget.adminService.getUsersStream(roleFilter: 'llg'),
                  builder: (context, snap) {
                    final specialists = (snap.data ?? []).where((s) => s.isVerified && s.uid != assignment.specialistId).toList();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text('Select new specialist...', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
                          value: newSpecialistId,
                          dropdownColor: colorNavy,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          items: specialists.map((s) => DropdownMenuItem(value: s.uid, child: Text('${s.name} (${s.email})'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final s = specialists.firstWhere((element) => element.uid == val);
                              setDialogState(() {
                                newSpecialistId = val;
                                newSpecialistName = s.name;
                              });
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Reason for Reassignment', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g., Previous specialist unavailable, parent requested transfer...',
                    hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                    filled: true,
                    fillColor: colorNavy,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newSpecialistId == null || reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a new specialist and enter a reason.')));
                  return;
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await widget.adminService.reassignSpecialist(
                    parentId: assignment.parentId,
                    parentName: assignment.parentName,
                    oldSpecialistId: assignment.specialistId,
                    newSpecialistId: newSpecialistId!,
                    newSpecialistName: newSpecialistName ?? 'Specialist',
                    childId: assignment.childId,
                    childName: assignment.childName,
                    reason: reasonController.text.trim(),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reassigned to $newSpecialistName successfully!'), backgroundColor: colorGreen),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorAmber),
              child: const Text('Reassign', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // REMOVE ASSIGNMENT DIALOG
  // =========================================================================
  void _showRemoveAssignmentDialog(LLGAssignmentModel assignment) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent)),
        title: Row(
          children: [
            const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text('Remove Specialist Assignment', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Removing this assignment will revoke case guidance access for ${assignment.specialistName} without deleting either account.',
                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text('Reason for removal', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g., Guidance cycle completed, requested termination...',
                  hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                  filled: true,
                  fillColor: colorNavy,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await widget.adminService.removeSpecialistAssignment(
                  assignmentId: assignment.id,
                  parentId: assignment.parentId,
                  specialistId: assignment.specialistId,
                  childId: assignment.childId,
                  reason: reasonController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assignment successfully removed.'), backgroundColor: Colors.redAccent),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove Assignment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SPLIT PANEL VERIFICATION INSPECTOR
  // =========================================================================
  Widget _buildVerificationSplitPanel(Map<String, dynamic> llg) {
    final llgId = llg['id'] ?? llg['uid'] ?? '';
    final name = llg['name'] ?? 'Specialist';
    final email = llg['email'] ?? '';
    final specialization = llg['specialization'] ?? 'Pediatric Guidance';
    final licenseNumber = llg['license'] ?? llg['licenseNumber'] ?? llg['license_number'] ?? 'Pending submission';

    final notesController = TextEditingController();

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 520,
      child: Container(
        decoration: BoxDecoration(
          color: colorSlate,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, offset: const Offset(-5, 0)),
          ],
          border: const Border(left: BorderSide(color: colorBorder, width: 1)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: colorTeal, size: 20),
                      const SizedBox(width: 10),
                      Text('Credential Review', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => setState(() => _isSplitPanelOpen = false),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _llgService.getCertificateVerificationsStream(llgId),
                builder: (context, snapshot) {
                  final verifMap = <String, Map<String, dynamic>>{};
                  if (snapshot.hasData && snapshot.data != null) {
                    for (final doc in snapshot.data!.docs) {
                      final d = doc.data();
                      final certType = d['certificateType'] ?? '';
                      if (certType.isNotEmpty) {
                        verifMap[certType] = d;
                      }
                    }
                  }

                  final credentialDocs = LLGCredentialDocument.extractCredentials(llg, verificationMap: verifMap);
                  final currentIndex = (_selectedDocumentIndex >= 0 && _selectedDocumentIndex < credentialDocs.length)
                      ? _selectedDocumentIndex
                      : 0;
                  final selectedDoc = credentialDocs.isNotEmpty ? credentialDocs[currentIndex] : null;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(email, style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted)),
                        const SizedBox(height: 16),
                        _buildDrawerInfoRow('Specialization', specialization),
                        _buildDrawerInfoRow('License / Credential #', licenseNumber),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Submitted Credentials & Documents',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: colorTeal),
                            ),
                            Text(
                              '${credentialDocs.where((d) => d.isSubmitted).length} of ${credentialDocs.length} provided',
                              style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Document Category Chips Selector
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(credentialDocs.length, (idx) {
                              final doc = credentialDocs[idx];
                              final isSelected = idx == currentIndex;

                              Color badgeColor = colorTextMuted;
                              IconData badgeIcon = Icons.remove_circle_outline;
                              if (!doc.isSubmitted) {
                                badgeColor = colorTextMuted;
                                badgeIcon = Icons.folder_off_outlined;
                              } else if (doc.verificationStatus == 'verified') {
                                badgeColor = colorGreen;
                                badgeIcon = Icons.check_circle;
                              } else if (doc.verificationStatus == 'rejected') {
                                badgeColor = Colors.redAccent;
                                badgeIcon = Icons.cancel;
                              } else {
                                badgeColor = colorAmber;
                                badgeIcon = Icons.schedule;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() => _selectedDocumentIndex = idx),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? colorTeal.withOpacity(0.15) : colorNavy,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? colorTeal : colorBorder,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(badgeIcon, size: 14, color: badgeColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          doc.categoryLabel,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? Colors.white : colorTextMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Selected Document Inspection & Preview Card
                        if (selectedDoc != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedDoc.categoryLabel,
                                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            selectedDoc.isSubmitted ? selectedDoc.filename : 'No document file attached',
                                            style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildDocStatusBadge(selectedDoc),
                                  ],
                                ),
                                if (selectedDoc.rejectionReason != null && selectedDoc.rejectionReason!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Reason: ${selectedDoc.rejectionReason}',
                                            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 14),

                                // PREVIEW CONTAINER
                                Container(
                                  width: double.infinity,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: colorSlate,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: colorBorder),
                                  ),
                                  child: _buildDocumentPreview(selectedDoc),
                                ),

                                // PER-DOCUMENT ACTIONS
                                if (selectedDoc.isSubmitted && selectedDoc.url.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                          label: const Text('Reject Doc', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.redAccent),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          onPressed: () => _rejectSingleCertificate(llgId, selectedDoc),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.check, size: 14, color: Colors.black),
                                          label: const Text('Verify Doc', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colorTeal,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          onPressed: () => _verifySingleCertificate(llgId, selectedDoc),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        const Divider(color: colorBorder),
                        const SizedBox(height: 12),

                        Text(
                          'Overall Specialist Verification Decision',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter review feedback or approval notes...',
                            hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                            filled: true,
                            fillColor: colorNavy,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                          ),
                        ),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  setState(() {
                                    _isSplitPanelOpen = false;
                                    _isLoading = true;
                                  });
                                  try {
                                    final err = await _llgService.rejectLLG(
                                      llgId,
                                      reason: notesController.text.trim().isNotEmpty
                                          ? notesController.text.trim()
                                          : 'Credential documentation incomplete.',
                                    );
                                    if (err != null) throw Exception(err);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Specialist application for $name rejected.'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isLoading = false);
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Reject Application', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  setState(() {
                                    _isSplitPanelOpen = false;
                                    _isLoading = true;
                                  });
                                  try {
                                    final err = await _llgService.approveLLG(llgId);
                                    if (err != null) throw Exception(err);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Specialist $name approved and verified!'), backgroundColor: colorGreen),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                                    }
                                  } finally {
                                    if (mounted) setState(() => _isLoading = false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorGreen,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text('Approve & Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
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
  }

  Widget _buildDocStatusBadge(LLGCredentialDocument doc) {
    Color bg;
    Color fg;
    String text;

    if (!doc.isSubmitted) {
      bg = colorSlate;
      fg = colorTextMuted;
      text = 'NOT SUBMITTED';
    } else if (doc.verificationStatus == 'verified') {
      bg = colorGreen.withOpacity(0.18);
      fg = colorGreen;
      text = 'VERIFIED';
    } else if (doc.verificationStatus == 'rejected') {
      bg = Colors.redAccent.withOpacity(0.18);
      fg = Colors.redAccent;
      text = 'REJECTED';
    } else {
      bg = colorAmber.withOpacity(0.18);
      fg = colorAmber;
      text = 'PENDING REVIEW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildDocumentPreview(LLGCredentialDocument doc) {
    if (!doc.isSubmitted || doc.url.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off_outlined, color: colorTextMuted, size: 44),
              const SizedBox(height: 10),
              Text(
                'No credential document submitted',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'This specialist has not uploaded documentation for ${doc.categoryLabel}.',
                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (doc.isImage) {
      return Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                doc.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: colorTeal, strokeWidth: 2));
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_outlined, color: colorAmber, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Inline image preview unavailable',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'File access may require direct authenticated browser session.',
                            style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 13),
                            label: const Text('Open in Browser', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorTeal,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => _openDocumentUrl(doc.url),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white, size: 16),
              tooltip: 'Open full image in browser',
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => _openDocumentUrl(doc.url),
            ),
          ),
        ],
      );
    }

    if (doc.isPdf) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent, size: 48),
              const SizedBox(height: 10),
              Text(
                doc.filename,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Portable Document Format (PDF)',
                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Open / Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTeal,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => _openDocumentUrl(doc.url),
              ),
            ],
          ),
        ),
      );
    }

    // Generic document fallback
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file_outlined, color: colorTeal, size: 48),
            const SizedBox(height: 10),
            Text(
              doc.filename,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text('Document File • Ready for Review', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorTeal,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => _openDocumentUrl(doc.url),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HELPER ACTIONS: CREDENTIALS, PREVIEWS & CASE REQUESTS
  // =========================================================================

  Future<void> _openDocumentUrl(String url) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document URL available to open.'), backgroundColor: Colors.amber),
      );
      return;
    }
    try {
      final uri = Uri.parse(url.trim());
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document URL: $url'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error launching credential URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _openSpecialistCredentialInspection(String uid, String name, String email) async {
    setState(() => _isLoading = true);
    try {
      final profile = await _llgService.getLLGProfile(uid);
      if (mounted) {
        setState(() {
          _selectedVerificationLLG = {
            ...?profile,
            'id': uid,
            'uid': uid,
            'name': (profile?['name'] != null && profile!['name'].toString().isNotEmpty) ? profile['name'] : name,
            'email': (profile?['email'] != null && profile!['email'].toString().isNotEmpty) ? profile['email'] : email,
          };
          _selectedDocumentIndex = 0;
          _isSplitPanelOpen = true;
          _tabController.animateTo(1); // Open directly in Verification Queue for seamless review
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load credentials for $name: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifySingleCertificate(String llgId, LLGCredentialDocument doc) async {
    setState(() => _isLoading = true);
    try {
      final adminId = widget.adminService.currentAdminId ?? 'admin';
      await _llgService.verifyCertificate(
        llgId: llgId,
        certType: doc.categoryKey,
        certUrl: doc.url,
        adminId: adminId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doc.categoryLabel} successfully verified!'), backgroundColor: colorGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying certificate: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectSingleCertificate(String llgId, LLGCredentialDocument doc) async {
    final reasonController = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
        title: Text('Reject ${doc.categoryLabel}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify why this credential document is being rejected:', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'e.g., Expired certificate, illegible scan, unaccredited issuer...',
                hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                filled: true,
                fillColor: colorNavy,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: colorTextMuted))),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Reject Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldReject != true) return;

    setState(() => _isLoading = true);
    try {
      final adminId = widget.adminService.currentAdminId ?? 'admin';
      await _llgService.rejectCertificate(
        llgId: llgId,
        certType: doc.categoryKey,
        certUrl: doc.url,
        adminId: adminId,
        reason: reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${doc.categoryLabel} rejected.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting certificate: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approvePendingCase(LLGAssignmentModel assignment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
        title: Text('Approve Specialist Request', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Approve parent ${assignment.parentName}\'s consultation request for specialist ${assignment.specialistName} (${assignment.childName ?? 'Child'})?',
          style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: colorTextMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colorGreen),
            child: const Text('Approve Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.adminService.approveCaseRequest(
        caseId: assignment.id,
        parentId: assignment.parentId,
        specialistId: assignment.specialistId,
        childId: assignment.childId,
        adminNotes: 'Approved by administrator',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request for ${assignment.parentName} approved!'), backgroundColor: colorGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _declinePendingCase(LLGAssignmentModel assignment) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
        title: Text('Decline Request', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specify reason for declining the request from ${assignment.parentName}:', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter reason for declining...',
                hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                filled: true,
                fillColor: colorNavy,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: colorTextMuted))),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Decline Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.adminService.declineCaseRequest(
        caseId: assignment.id,
        parentId: assignment.parentId,
        specialistId: assignment.specialistId,
        childId: assignment.childId,
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request declined.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining request: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCaseDetailsDialog(LLGAssignmentModel assignment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: colorTeal, size: 20),
            const SizedBox(width: 8),
            Text('Relationship Details', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDrawerInfoRow('Record ID', assignment.id),
              _buildDrawerInfoRow('Status', assignment.status.toUpperCase()),
              _buildDrawerInfoRow('Parent Name', assignment.parentName.isNotEmpty ? assignment.parentName : 'N/A'),
              _buildDrawerInfoRow('Parent ID', assignment.parentId),
              _buildDrawerInfoRow('Child Name', assignment.childName ?? 'N/A'),
              _buildDrawerInfoRow('Child ID', assignment.childId ?? 'N/A'),
              _buildDrawerInfoRow('Specialist Name', assignment.specialistName),
              _buildDrawerInfoRow('Specialist ID', assignment.specialistId),
              _buildDrawerInfoRow('Specialist Role', assignment.specialistRole),
              _buildDrawerInfoRow('Assigned / Requested', assignment.assignedAt.toLocal().toString().split('.')[0]),
              if (assignment.endedAt != null)
                _buildDrawerInfoRow('Ended At', assignment.endedAt!.toLocal().toString().split('.')[0]),
              if (assignment.reason != null && assignment.reason!.isNotEmpty)
                _buildDrawerInfoRow('Notes / Purpose', assignment.reason!),
              if (assignment.coveredChildren.isNotEmpty)
                _buildDrawerInfoRow('Covered Children', assignment.coveredChildren.join(', ')),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
            child: const Text('Close', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. PARENT COMPLAINTS TAB
  // =========================================================================
  Widget _buildParentComplaintsTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: colorNavy,
          child: Row(
            children: [
              Text('Status Filter:', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
              const SizedBox(width: 8),
              ...['all', 'pending', 'under_investigation', 'resolved', 'dismissed'].map((status) {
                final isSelected = _complaintStatusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      status == 'all' ? 'All' : status.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colorTeal,
                    backgroundColor: colorSlate,
                    onSelected: (_) => setState(() => _complaintStatusFilter = status),
                  ),
                );
              }),
            ],
          ),
        ),

        // Complaints List Stream
        Expanded(
          child: StreamBuilder<List<ParentComplaintModel>>(
            stream: _complaintService.getAllComplaintsStream(statusFilter: _complaintStatusFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: colorTeal));
              }

              final complaints = snapshot.data ?? [];

              if (complaints.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, size: 48, color: colorTextMuted),
                      const SizedBox(height: 12),
                      Text('No complaints matching the selected filter.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: complaints.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final complaint = complaints[index];

                  Color badgeBg = colorSlate;
                  Color badgeFg = Colors.white;
                  if (complaint.isPending) {
                    badgeBg = const Color(0xFFEF4444).withOpacity(0.2);
                    badgeFg = const Color(0xFFEF4444);
                  } else if (complaint.isUnderInvestigation) {
                    badgeBg = colorAmber.withOpacity(0.2);
                    badgeFg = colorAmber;
                  } else if (complaint.isResolved) {
                    badgeBg = colorGreen.withOpacity(0.2);
                    badgeFg = colorGreen;
                  }

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorSlate,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorTeal.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    complaint.categoryDisplayName,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorTeal),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    complaint.status.replaceAll('_', ' ').toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: badgeFg),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              DateFormat('MMM d, y (h:mm a)').format(complaint.createdAt),
                              style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Specialist: ${complaint.specialistName}',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Parent: ${complaint.parentName} (${complaint.parentEmail})',
                              style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted),
                            ),
                            if (complaint.caseId != null) ...[
                              const SizedBox(width: 16),
                              Text('Case: ${complaint.caseId}', style: GoogleFonts.inter(fontSize: 12, color: colorTeal)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          complaint.description,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0)),
                        ),
                        if (complaint.supportingEvidence.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Evidence / References: ${complaint.supportingEvidence}',
                            style: GoogleFonts.inter(fontSize: 12, color: colorAmber),
                          ),
                        ],
                        if (complaint.investigationNotes != null && complaint.investigationNotes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorNavy,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: colorBorder),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.notes, size: 16, color: colorTeal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Admin Investigation Notes: ${complaint.investigationNotes}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (complaint.resolutionSummary != null && complaint.resolutionSummary!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Resolution: ${complaint.resolutionSummary}',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: colorGreen),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showComplaintInvestigationDialog(complaint),
                              icon: const Icon(Icons.edit_note, size: 16),
                              label: const Text('Update Investigation & Status'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorTeal,
                                foregroundColor: Colors.black,
                                textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
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
          ),
        ),
      ],
    );
  }

  void _showComplaintInvestigationDialog(ParentComplaintModel complaint) {
    String selectedStatus = complaint.status;
    final notesController = TextEditingController(text: complaint.investigationNotes ?? '');
    final resolutionController = TextEditingController(text: complaint.resolutionSummary ?? '');
    bool notifyParent = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Investigate Parent Complaint',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complaint from ${complaint.parentName} regarding ${complaint.specialistName}',
                    style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted),
                  ),
                  const SizedBox(height: 16),
                  Text('Update Complaint Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: colorNavy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        dropdownColor: colorNavy,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'pending', child: Text('Pending Review', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'under_investigation', child: Text('Under Investigation', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'resolved', child: Text('Resolved', style: TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: 'dismissed', child: Text('Dismissed (No Action Required)', style: TextStyle(color: Colors.white))),
                        ],
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedStatus = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Investigation Notes', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Record investigation findings, interviews, or observations...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Resolution Summary (Visible to Parent)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: resolutionController,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Summarize outcome and corrective actions...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: notifyParent,
                    onChanged: (val) => setDlgState(() => notifyParent = val ?? true),
                    title: Text('Notify parent of this status update', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    activeColor: colorTeal,
                    contentPadding: EdgeInsets.zero,
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
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _complaintService.updateComplaintStatus(
                    complaintId: complaint.id,
                    newStatus: selectedStatus,
                    adminId: 'admin',
                    investigationNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    resolutionSummary: resolutionController.text.trim().isNotEmpty ? resolutionController.text.trim() : null,
                    notifyParent: notifyParent,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complaint status and investigation updated successfully.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating complaint: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorTeal, foregroundColor: Colors.black),
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 6. SUSPENSION APPEALS TAB
  // =========================================================================
  Widget _buildSuspensionAppealsTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: colorNavy,
          child: Row(
            children: [
              Text('Status Filter:', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
              const SizedBox(width: 8),
              ...['all', 'pending', 'approved', 'rejected'].map((status) {
                final isSelected = _appealStatusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      status == 'all' ? 'All' : status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colorTeal,
                    backgroundColor: colorSlate,
                    onSelected: (_) => setState(() => _appealStatusFilter = status),
                  ),
                );
              }),
            ],
          ),
        ),

        // Appeals Stream
        Expanded(
          child: StreamBuilder<List<LLGAppealModel>>(
            stream: _appealService.getAllAppealsStream(statusFilter: _appealStatusFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: colorTeal));
              }

              final appeals = snapshot.data ?? [];

              if (appeals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.balance_outlined, size: 48, color: colorTextMuted),
                      const SizedBox(height: 12),
                      Text('No suspension appeals found.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: appeals.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final appeal = appeals[index];

                  Color badgeBg = colorSlate;
                  Color badgeFg = Colors.white;
                  if (appeal.isPending) {
                    badgeBg = colorAmber.withOpacity(0.2);
                    badgeFg = colorAmber;
                  } else if (appeal.isApproved) {
                    badgeBg = colorGreen.withOpacity(0.2);
                    badgeFg = colorGreen;
                  } else if (appeal.isRejected) {
                    badgeBg = const Color(0xFFEF4444).withOpacity(0.2);
                    badgeFg = const Color(0xFFEF4444);
                  }

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorSlate,
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
                                Text(
                                  appeal.llgName,
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    appeal.status.toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              DateFormat('MMM d, y (h:mm a)').format(appeal.createdAt),
                              style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Email: ${appeal.llgEmail}', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                          ),
                          child: Text(
                            'Suspension Reason: ${appeal.suspensionReason}',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFCA5A5)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Appeal Submission:',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorTeal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appeal.appealText,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0)),
                        ),
                        if (appeal.adminNotes != null && appeal.adminNotes!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Admin Review Notes: ${appeal.adminNotes}',
                            style: GoogleFonts.inter(fontSize: 12, color: colorAmber),
                          ),
                        ],
                        if (appeal.restorationConditions != null && appeal.restorationConditions!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Restoration Conditions: ${appeal.restorationConditions!.join(', ')}',
                            style: GoogleFonts.inter(fontSize: 12, color: colorGreen),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (appeal.isPending)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _showAppealDecisionDialog(appeal),
                                icon: const Icon(Icons.rate_review_outlined, size: 16),
                                label: const Text('Review & Decide Appeal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorTeal,
                                  foregroundColor: Colors.black,
                                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
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
          ),
        ),
      ],
    );
  }

  void _showAppealDecisionDialog(LLGAppealModel appeal) {
    bool approve = true;
    final notesController = TextEditingController();
    final conditionsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Review Suspension Appeal',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Specialist: ${appeal.llgName} (${appeal.llgEmail})', style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted)),
                  const SizedBox(height: 12),
                  Text('Suspension Reason: ${appeal.suspensionReason}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444))),
                  const SizedBox(height: 8),
                  Text('Appeal Text: ${appeal.appealText}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE2E8F0))),
                  const SizedBox(height: 16),
                  Text('Decision', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Approve & Restore Account')),
                          selected: approve,
                          selectedColor: colorGreen,
                          labelStyle: TextStyle(color: approve ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                          onSelected: (val) => setDlgState(() => approve = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Reject Appeal')),
                          selected: !approve,
                          selectedColor: const Color(0xFFEF4444),
                          labelStyle: TextStyle(color: !approve ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
                          onSelected: (val) => setDlgState(() => approve = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Reviewer Notes / Justification', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Explain the decision rationale and feedback for the specialist...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  if (approve) ...[
                    const SizedBox(height: 14),
                    Text('Conditions for Restoration (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: conditionsController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Complete platform ethics refresher, monthly supervision',
                        hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                        filled: true,
                        fillColor: colorNavy,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                      ),
                    ),
                  ],
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
              onPressed: () async {
                final notes = notesController.text.trim();
                if (notes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide reviewer notes for this decision.')),
                  );
                  return;
                }

                Navigator.pop(ctx);
                try {
                  List<String>? conditions;
                  if (approve && conditionsController.text.trim().isNotEmpty) {
                    conditions = conditionsController.text.trim().split(',').map((c) => c.trim()).toList();
                  }

                  await _appealService.processAppealDecision(
                    appealId: appeal.id,
                    llgId: appeal.llgId,
                    approve: approve,
                    adminId: 'admin',
                    adminNotes: notes,
                    restorationConditions: conditions,
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(approve ? 'Appeal approved and specialist account restored.' : 'Appeal rejected.'),
                      backgroundColor: approve ? colorGreen : const Color(0xFFEF4444),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error processing appeal: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? colorGreen : const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: Text(approve ? 'Approve & Restore' : 'Reject Appeal', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 7. RATINGS & REVIEWS MODERATION TAB
  // =========================================================================
  Widget _buildRatingsModerationTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: colorNavy,
          child: Row(
            children: [
              FilterChip(
                label: Text(
                  'All Reviews',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: !_reviewsModeratedOnly ? FontWeight.bold : FontWeight.normal,
                    color: !_reviewsModeratedOnly ? Colors.black : Colors.white,
                  ),
                ),
                selected: !_reviewsModeratedOnly,
                selectedColor: colorTeal,
                backgroundColor: colorSlate,
                onSelected: (_) => setState(() => _reviewsModeratedOnly = false),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(
                  'Moderated / Hidden Only',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: _reviewsModeratedOnly ? FontWeight.bold : FontWeight.normal,
                    color: _reviewsModeratedOnly ? Colors.black : Colors.white,
                  ),
                ),
                selected: _reviewsModeratedOnly,
                selectedColor: colorAmber,
                backgroundColor: colorSlate,
                onSelected: (_) => setState(() => _reviewsModeratedOnly = true),
              ),
            ],
          ),
        ),

        // Reviews Stream
        Expanded(
          child: StreamBuilder<List<SpecialistReviewModel>>(
            stream: _reviewService.getAllReviewsStream(moderatedOnly: _reviewsModeratedOnly ? true : null),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: colorTeal));
              }

              final reviews = snapshot.data ?? [];

              if (reviews.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rate_review_outlined, size: 48, color: colorTextMuted),
                      const SizedBox(height: 12),
                      Text('No reviews matching filter.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: reviews.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final rev = reviews[index];

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorSlate,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: rev.isModerated ? const Color(0xFFEF4444).withOpacity(0.4) : colorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Row(
                                  children: List.generate(5, (starIdx) {
                                    return Icon(
                                      starIdx < rev.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: colorAmber,
                                      size: 18,
                                    );
                                  }),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: rev.isModerated ? const Color(0xFFEF4444).withOpacity(0.2) : colorGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    rev.isModerated ? 'HIDDEN / MODERATED' : 'PUBLIC',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: rev.isModerated ? const Color(0xFFEF4444) : colorGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              DateFormat('MMM d, y (h:mm a)').format(rev.createdAt),
                              style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Specialist: ${rev.specialistName} • Parent: ${rev.parentName}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (rev.reviewText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"${rev.reviewText}"',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0), fontStyle: FontStyle.italic),
                          ),
                        ],
                        if (rev.isModerated) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Moderation Reason: ${rev.moderationReason ?? 'Violates platform guidelines'} (by ${rev.moderatedBy ?? 'Admin'})',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFFCA5A5)),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!rev.isModerated)
                              OutlinedButton.icon(
                                onPressed: () => _showModerateReviewDialog(rev),
                                icon: const Icon(Icons.visibility_off_outlined, size: 16, color: Color(0xFFEF4444)),
                                label: const Text('Hide Review (Moderation)', style: TextStyle(color: Color(0xFFEF4444))),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFEF4444)),
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _reviewService.moderateReview(
                                    reviewId: rev.id,
                                    hide: false,
                                    adminId: 'admin',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Review restored to public directory and rating recalculated.')),
                                  );
                                },
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text('Restore Public Review'),
                                style: ElevatedButton.styleFrom(backgroundColor: colorGreen, foregroundColor: Colors.black),
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
        ),
      ],
    );
  }

  void _showModerateReviewDialog(SpecialistReviewModel review) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Moderate Review', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hiding this review will remove it from the parent-facing specialist profile and recalculate the specialist\'s aggregate star rating.',
              style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter reason (e.g. Inappropriate language, off-topic, spam)...',
                hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
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
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a moderation reason.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _reviewService.moderateReview(
                  reviewId: review.id,
                  hide: true,
                  adminId: 'admin',
                  reason: reason,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review hidden and specialist aggregate rating recalculated.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error moderating review: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Hide Review'),
          ),
        ],
      ),
    );
  }
}

