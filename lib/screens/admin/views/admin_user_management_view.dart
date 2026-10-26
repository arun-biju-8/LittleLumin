// lib/screens/admin/views/admin_user_management_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/admin_models.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';

class AdminUserManagementView extends StatefulWidget {
  final AdminService adminService;
  final int initialSubIndex;
  final Function(int targetGroupIndex, int targetSubIndex)? onNavigate;

  const AdminUserManagementView({
    super.key,
    required this.adminService,
    this.initialSubIndex = 0,
    this.onNavigate,
  });

  @override
  State<AdminUserManagementView> createState() => _AdminUserManagementViewState();
}

class _AdminUserManagementViewState extends State<AdminUserManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'name'
  bool _isLoading = false;

  UserModel? _selectedUser;
  bool _isDrawerOpen = false;

  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorGreen = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  // Tabs: 0: All, 1: Parents, 2: Children, 3: Specialists, 4: Suspended, 5: Recovery Requests
  @override
  void initState() {
    super.initState();
    int initialTab = 0;
    if (widget.initialSubIndex >= 0 && widget.initialSubIndex <= 5) {
      initialTab = widget.initialSubIndex;
    }
    _tabController = TabController(length: 6, vsync: this, initialIndex: initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(AdminUserManagementView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubIndex != oldWidget.initialSubIndex &&
        widget.initialSubIndex >= 0 &&
        widget.initialSubIndex <= 5) {
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
            // 1. Top Filter & Search Bar
            _buildHeaderControls(),

            // 2. Tabs Bar
            _buildTabBar(),

            if (_isLoading)
              const LinearProgressIndicator(color: colorTeal, backgroundColor: colorNavy),

            // 3. Tab Views Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUsersList(filterRole: null, filterStatus: null), // All Users
                  _buildUsersList(filterRole: 'parent', filterStatus: null), // Parents
                  _buildChildrenList(), // Children
                  _buildUsersList(filterRole: 'llg', filterStatus: null), // Specialists
                  _buildUsersList(filterRole: null, filterStatus: 'suspended'), // Suspended
                  _buildRecoveryRequestsList(), // Recovery Requests
                ],
              ),
            ),
          ],
        ),

        // 4. Slide-out Detail Drawer
        if (_isDrawerOpen && _selectedUser != null)
          _buildUserDetailDrawer(_selectedUser!),
      ],
    );
  }

  // =========================================================================
  // HEADER CONTROLS
  // =========================================================================
  Widget _buildHeaderControls() {
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
                  hintText: 'Search by name, email, or user ID...',
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
          // Sort Dropdown
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorSlate,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colorBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                dropdownColor: colorSlate,
                icon: const Icon(Icons.sort, color: colorTextMuted, size: 18),
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Sort: Newest First')),
                  DropdownMenuItem(value: 'oldest', child: Text('Sort: Oldest First')),
                  DropdownMenuItem(value: 'name', child: Text('Sort: Name A-Z')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB BAR
  // =========================================================================
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
        tabs: const [
          Tab(text: 'All Users'),
          Tab(text: 'Parents'),
          Tab(text: 'Children'),
          Tab(text: 'LLG Specialists'),
          Tab(text: 'Suspended Accounts'),
          Tab(text: 'Recovery Requests'),
        ],
      ),
    );
  }

  // =========================================================================
  // USERS LIST
  // =========================================================================
  Widget _buildUsersList({String? filterRole, String? filterStatus}) {
    return StreamBuilder<List<UserModel>>(
      stream: widget.adminService.getUsersStream(roleFilter: filterRole, statusFilter: filterStatus),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading users: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.redAccent)),
          );
        }

        List<UserModel> users = snapshot.data ?? [];

        // Apply Search
        if (_searchQuery.isNotEmpty) {
          users = users.where((u) {
            final name = u.name.toLowerCase();
            final email = u.email.toLowerCase();
            final uid = u.uid.toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery) || uid.contains(_searchQuery);
          }).toList();
        }

        // Apply Sort
        if (_sortBy == 'newest') {
          users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        } else if (_sortBy == 'oldest') {
          users.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        } else if (_sortBy == 'name') {
          users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        }

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: colorTextMuted.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('No user records match current filters.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: users.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserRowCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserRowCard(UserModel user) {
    Color roleBadgeColor = colorTeal;
    if (user.userType == 'llg' || user.userType == 'specialist') roleBadgeColor = const Color(0xFF8B5CF6);
    if (user.userType == 'admin') roleBadgeColor = colorAmber;

    Color statusColor = colorGreen;
    String statusLabel = 'ACTIVE';
    if (user.isSuspended) {
      statusColor = Colors.redAccent;
      statusLabel = 'SUSPENDED';
    } else if (user.isWarned) {
      statusColor = colorAmber;
      statusLabel = 'WARNED';
    } else if (user.isDeactivated) {
      statusColor = Colors.grey;
      statusLabel = 'DEACTIVATED';
    } else if (user.isRecoveryPending) {
      statusColor = Colors.orangeAccent;
      statusLabel = 'RECOVERY PENDING';
    }

    final dateStr = DateFormat('MMM d, y').format(user.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorSlate,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: roleBadgeColor.withOpacity(0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: roleBadgeColor, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleBadgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: roleBadgeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        user.userType.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: roleBadgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Status Chip
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ),
          ),
          // Registration Date
          Expanded(
            flex: 2,
            child: Text(
              'Joined $dateStr',
              style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
            ),
          ),
          // Actions Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: colorTextMuted, size: 20),
            color: colorSlate,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: colorBorder)),
            onSelected: (val) => _handleUserAction(val, user),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined, color: colorTeal, size: 16),
                    const SizedBox(width: 10),
                    Text('View Profile & Details', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'warn',
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: colorAmber, size: 16),
                    const SizedBox(width: 10),
                    Text('Issue Warning', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              if (!user.isSuspended)
                PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      const Icon(Icons.block_outlined, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 10),
                      Text('Suspend Account', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      const Icon(Icons.restart_alt_rounded, color: colorGreen, size: 16),
                      const SizedBox(width: 10),
                      Text('Restore Account Access', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              if (!user.isDeactivated && !user.isSuspended)
                PopupMenuItem(
                  value: 'deactivate',
                  child: Row(
                    children: [
                      const Icon(Icons.power_settings_new_rounded, color: Colors.grey, size: 16),
                      const SizedBox(width: 10),
                      Text('Deactivate Account', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 10),
                    Text('Permanently Delete...', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CHILDREN DIRECTORY TAB
  // =========================================================================
  Widget _buildChildrenList() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.adminService.getChildrenStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No children registered yet.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final childName = data['name'] ?? 'Child';
            final age = data['age'] ?? 'N/A';
            final parentId = data['parentId'] ?? 'N/A';
            final specialNeeds = data['specialNeeds'] ?? '';

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
                    backgroundColor: colorTeal.withOpacity(0.15),
                    child: const Icon(Icons.child_care, color: colorTeal, size: 18),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          childName,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Age: $age yrs | Parent ID: $parentId',
                          style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                  if (specialNeeds.toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorAmber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colorAmber.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Needs: $specialNeeds',
                        style: GoogleFonts.inter(fontSize: 11, color: colorAmber, fontWeight: FontWeight.bold),
                      ),
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
  // RECOVERY REQUESTS TAB
  // =========================================================================
  Widget _buildRecoveryRequestsList() {
    return StreamBuilder<List<AccountRecoveryRequestModel>>(
      stream: widget.adminService.getRecoveryRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final reqs = snapshot.data ?? [];
        if (reqs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 48, color: colorGreen),
                const SizedBox(height: 12),
                Text('No pending account recovery requests.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: reqs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final req = reqs[index];
            final dateStr = DateFormat('MMM d, y HH:mm').format(req.requestedAt);

            Color statusColor = colorAmber;
            if (req.status == 'approved') statusColor = colorGreen;
            if (req.status == 'rejected') statusColor = Colors.redAccent;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
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
                            req.userName,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${req.userEmail})',
                            style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          req.status.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Original Suspension: ${req.suspensionReason}',
                    style: GoogleFonts.inter(fontSize: 12, color: colorAmber),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorNavy,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('User Statement:', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          req.userExplanation,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Requested: $dateStr', style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted)),
                      if (req.status == 'pending_review')
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _showProcessRecoveryDialog(req, 'additional_verification_required'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: colorAmber),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text('Request Verification', style: GoogleFonts.inter(color: colorAmber, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _showProcessRecoveryDialog(req, 'rejected'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Text('Reject', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _showProcessRecoveryDialog(req, 'approved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorGreen,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: Text('Approve & Restore', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
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
  // ACTIONS DISPATCHER
  // =========================================================================
  void _handleUserAction(String action, UserModel user) {
    switch (action) {
      case 'view':
        setState(() {
          _selectedUser = user;
          _isDrawerOpen = true;
        });
        break;
      case 'warn':
        _showIssueWarningDialog(user);
        break;
      case 'suspend':
        _showSuspendUserDialog(user);
        break;
      case 'restore':
        _showRestoreUserDialog(user);
        break;
      case 'deactivate':
        _showDeactivateUserDialog(user);
        break;
      case 'delete':
        _showPermanentDeletionSafeguardDialog(user);
        break;
    }
  }

  // =========================================================================
  // ISSUE WARNING DIALOG
  // =========================================================================
  void _showIssueWarningDialog(UserModel user) {
    String selectedCategory = 'Suspicious activity';
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    bool sendEmail = true;

    final categories = [
      'Suspicious activity',
      'Repeated policy violations',
      'Account security concern',
      'Misuse of platform functionality',
      'Other administrative concern',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: colorAmber, size: 24),
              const SizedBox(width: 10),
              Text('Issue Account Warning', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Recipient: ${user.name} (${user.email})', style: GoogleFonts.inter(color: colorTeal, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text('Warning Category', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedCategory,
                        dropdownColor: colorNavy,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Reason (User-facing explanation)', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter specific professional reason for this warning...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Internal Notes (Optional, for admin review)', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Optional notes visible only to administrators...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: sendEmail,
                    onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                    title: Text('Send transactional warning email to user', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: colorTeal,
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
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a warning reason.')));
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await widget.adminService.issueWarning(
                          userId: user.uid,
                          category: selectedCategory,
                          reason: reasonController.text.trim(),
                          notes: notesController.text.trim(),
                          sendEmail: sendEmail,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(sendEmail
                                  ? 'Warning issued to ${user.name}. (Email delivery pending provider configuration)'
                                  : 'Warning issued to ${user.name}.'),
                              backgroundColor: colorAmber,
                            ),
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
              child: const Text('Issue Warning', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SUSPEND USER DIALOG
  // =========================================================================
  void _showSuspendUserDialog(UserModel user) {
    String selectedCategory = 'Security review';
    final reasonController = TextEditingController();
    bool isTemporary = false;
    DateTime? suspensionUntil;
    bool sendEmail = true;

    final categories = [
      'Security review',
      'Policy violation',
      'Suspicious activity',
      'Unverified credential claims',
      'Administrative investigation',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
          title: Row(
            children: [
              const Icon(Icons.block_outlined, color: Colors.redAccent, size: 24),
              const SizedBox(width: 10),
              Text('Suspend User Account', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Target: ${user.name} (${user.email})', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text('Suspension Category', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedCategory,
                        dropdownColor: colorNavy,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Detailed Reason (Authoritative)', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter authoritative reason for account restriction...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: isTemporary,
                    onChanged: (val) {
                      setDialogState(() {
                        isTemporary = val;
                        if (isTemporary && suspensionUntil == null) {
                          suspensionUntil = DateTime.now().add(const Duration(days: 14));
                        }
                      });
                    },
                    title: Text('Temporary Suspension', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    subtitle: Text('Schedule an automated review date', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11)),
                    activeColor: colorTeal,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isTemporary)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, color: colorTeal, size: 16),
                        label: Text(
                          suspensionUntil != null
                              ? 'Review Date: ${DateFormat('MMM d, y').format(suspensionUntil!)}'
                              : 'Select Review Date',
                          style: GoogleFonts.inter(color: colorTeal, fontSize: 12),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: suspensionUntil ?? DateTime.now().add(const Duration(days: 14)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(() => suspensionUntil = picked);
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: sendEmail,
                    onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                    title: Text('Dispatch official suspension notice email with recovery instructions', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.redAccent,
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
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a suspension reason.')));
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await widget.adminService.suspendAccount(
                          userId: user.uid,
                          category: selectedCategory,
                          reason: reasonController.text.trim(),
                          isTemporary: isTemporary,
                          suspensionUntil: suspensionUntil,
                          sendEmail: sendEmail,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Account for ${user.name} has been suspended.'), backgroundColor: Colors.redAccent),
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
              child: const Text('Suspend Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // RESTORE USER DIALOG
  // =========================================================================
  void _showRestoreUserDialog(UserModel user) {
    final reasonController = TextEditingController();
    bool sendEmail = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
          title: Row(
            children: [
              const Icon(Icons.restart_alt_rounded, color: colorGreen, size: 24),
              const SizedBox(width: 10),
              Text('Restore Account Access', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${user.name} (${user.email})', style: GoogleFonts.inter(color: colorGreen, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Text('Restoration Reason / Review Findings', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter reason why account access is being restored...',
                    hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                    filled: true,
                    fillColor: colorNavy,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  value: sendEmail,
                  onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                  title: Text('Send restoration confirmation email to user', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: colorGreen,
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
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a restoration reason.')));
                        return;
                      }
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await widget.adminService.restoreAccount(
                          userId: user.uid,
                          restorationReason: reasonController.text.trim(),
                          sendEmail: sendEmail,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Account for ${user.name} restored successfully.'), backgroundColor: colorGreen),
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
              style: ElevatedButton.styleFrom(backgroundColor: colorGreen),
              child: const Text('Restore Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DEACTIVATE USER DIALOG
  // =========================================================================
  void _showDeactivateUserDialog(UserModel user) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
        title: Row(
          children: [
            const Icon(Icons.power_settings_new_rounded, color: Colors.grey, size: 24),
            const SizedBox(width: 10),
            Text('Deactivate Account', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deactivation pauses account access while preserving all records and relationships. This action can be reversed at any time.',
                style: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Text('Reason for deactivation', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonController,
                maxLines: 2,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter reason (e.g., requested temporary inactivity)...',
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
            onPressed: _isLoading
                ? null
                : () async {
                    if (reasonController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      await widget.adminService.deactivateAccount(userId: user.uid, reason: reasonController.text.trim());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Account for ${user.name} deactivated.'), backgroundColor: Colors.grey.shade700),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
            child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PERMANENT DELETION SAFEGUARD DIALOG
  // =========================================================================
  void _showPermanentDeletionSafeguardDialog(UserModel user) {
    final confirmController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent)),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text('Irreversible Account Deletion', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WARNING: Controlled Permanent Deletion Safeguard',
                        style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This action permanently deletes the user account, terminates all specialist cases, safely detaches dependent child records to prevent orphaned states, and logs an immutable administrative audit ledger.',
                        style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('User: ${user.name} (${user.email})', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text('User ID: ${user.uid}', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 11)),
                const SizedBox(height: 16),
                Text('Administrative Reason for Deletion', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g., Verified user deletion request under DPDP privacy regulations...',
                    hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                    filled: true,
                    fillColor: colorNavy,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('To confirm, type the user\'s exact email (${user.email}) below:', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: confirmController,
                  style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: user.email,
                    hintStyle: GoogleFonts.inter(color: colorTextMuted.withOpacity(0.5), fontSize: 12),
                    filled: true,
                    fillColor: colorNavy,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
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
            onPressed: _isLoading
                ? null
                : () async {
                    if (confirmController.text.trim().toLowerCase() != user.email.trim().toLowerCase()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Confirmation mismatch. Please type the exact user email.')),
                      );
                      return;
                    }
                    if (reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please state the administrative reason for deletion.')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    setState(() => _isLoading = true);
                    try {
                      await widget.adminService.permanentlyDeleteAccountSafeguard(
                        userId: user.uid,
                        userEmail: user.email,
                        reason: reasonController.text.trim(),
                        adminConfirmation: confirmController.text.trim(),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Account for ${user.email} permanently removed under audit trail.'), backgroundColor: Colors.redAccent),
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
            child: const Text('Confirm Permanent Deletion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PROCESS RECOVERY DIALOG
  // =========================================================================
  void _showProcessRecoveryDialog(AccountRecoveryRequestModel req, String decision) {
    final notesController = TextEditingController();
    bool sendEmail = true;

    String title = 'Approve Account Recovery';
    Color actionColor = colorGreen;
    if (decision == 'rejected') {
      title = 'Reject Recovery Request';
      actionColor = Colors.redAccent;
    } else if (decision == 'additional_verification_required') {
      title = 'Request Additional Verification';
      actionColor = colorAmber;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: actionColor)),
          title: Text(title, style: GoogleFonts.inter(color: actionColor, fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${req.userName} (${req.userEmail})', style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text('Reviewer Notes / Instructions', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter specific review notes or instructions sent to the user...',
                    hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                    filled: true,
                    fillColor: colorNavy,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: sendEmail,
                  onChanged: (val) => setDialogState(() => sendEmail = val ?? true),
                  title: Text('Notify user via email with decision instructions', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: actionColor,
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
              onPressed: _isLoading
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await widget.adminService.processRecoveryDecision(
                          requestId: req.id,
                          userId: req.userId,
                          decisionStatus: decision,
                          reviewerNotes: notesController.text.trim(),
                          sendEmail: sendEmail,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Recovery request processed: $decision'), backgroundColor: actionColor),
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
              style: ElevatedButton.styleFrom(backgroundColor: actionColor),
              child: Text('Submit Decision', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // DETAIL DRAWER
  // =========================================================================
  Widget _buildUserDetailDrawer(UserModel user) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 440,
      child: Container(
        decoration: BoxDecoration(
          color: colorSlate,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(-5, 0)),
          ],
          border: const Border(left: BorderSide(color: colorBorder, width: 1)),
        ),
        child: Column(
          children: [
            // Drawer Header
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
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: colorTeal.withOpacity(0.2),
                        child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U', style: const TextStyle(color: colorTeal, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                          Text(user.userType.toUpperCase(), style: GoogleFonts.inter(color: colorTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => setState(() => _isDrawerOpen = false),
                  ),
                ],
              ),
            ),

            // Drawer Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDrawerSectionTitle('Profile Information'),
                    _buildDrawerInfoRow('Email Address', user.email),
                    _buildDrawerInfoRow('User ID', user.uid),
                    _buildDrawerInfoRow('Account Status', user.status.toUpperCase()),
                    _buildDrawerInfoRow(
                      'Registration Date',
                      DateFormat('MMM d, y HH:mm').format(user.createdAt),
                    ),

                    const SizedBox(height: 20),
                    _buildDrawerSectionTitle('Relationships'),
                    if (user.userType == 'parent')
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('children').where('parentId', isEqualTo: user.uid).snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return _buildDrawerInfoRow('Registered Children', '$count child(ren)');
                        },
                      )
                    else if (user.userType == 'llg' || user.userType == 'specialist')
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('specialistCases').where('specialistId', isEqualTo: user.uid).where('status', isEqualTo: 'active').snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return _buildDrawerInfoRow('Active Caseload', '$count active case(s)');
                        },
                      ),

                    const SizedBox(height: 20),
                    _buildDrawerSectionTitle('Account Warnings & History'),
                    if (user.warnings.isEmpty)
                      Text('No previous warnings on record.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12))
                    else
                      ...user.warnings.map((w) {
                        final cat = w['category'] ?? 'Notice';
                        final reason = w['reason'] ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorNavy,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorAmber.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cat, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorAmber)),
                              const SizedBox(height: 2),
                              Text(reason, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 24),
                    _buildDrawerSectionTitle('Quick Actions'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.warning_amber_rounded, size: 14, color: colorAmber),
                          label: Text('Warn', style: GoogleFonts.inter(color: colorAmber, fontSize: 12)),
                          onPressed: () => _showIssueWarningDialog(user),
                        ),
                        if (!user.isSuspended)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.block_outlined, size: 14, color: Colors.redAccent),
                            label: Text('Suspend', style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                            onPressed: () => _showSuspendUserDialog(user),
                          )
                        else
                          ElevatedButton.icon(
                            icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Colors.white),
                            label: Text('Restore', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(backgroundColor: colorGreen),
                            onPressed: () => _showRestoreUserDialog(user),
                          ),
                      ],
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

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: colorTeal, letterSpacing: 0.5),
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
            width: 130,
            child: Text(label, style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
