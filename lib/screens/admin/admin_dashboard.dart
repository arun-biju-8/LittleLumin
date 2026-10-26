// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/admin_service.dart';
import '../auth/login_page.dart';

import 'views/admin_overview_view.dart';
import 'views/admin_user_management_view.dart';
import 'views/admin_llg_management_view.dart';
import 'views/admin_activity_management_view.dart';
import 'views/admin_communication_view.dart';
import 'views/admin_analytics_reports_view.dart';
import 'views/admin_security_health_view.dart';

class AdminDashboard extends StatefulWidget {
  final int initialGroupIndex;
  final int initialSubIndex;

  const AdminDashboard({
    super.key,
    this.initialGroupIndex = 0,
    this.initialSubIndex = 0,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final AdminService _adminService;

  // Selected Navigation Group & Sub-item
  int _selectedGroupIndex = 0;
  int _selectedSubIndex = 0;

  // Sidebar expansion state for each group
  late List<bool> _isGroupExpanded;

  String _currentAdminName = 'Administrator';
  String _currentAdminEmail = 'admin@littlelumin.com';
  bool _isSidebarCollapsed = false;

  // Colors
  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  // Group definitions
  final List<NavGroup> _navGroups = [
    NavGroup(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      items: ['Overview', 'Pending Tasks', 'System Health'],
    ),
    NavGroup(
      title: 'User Management',
      icon: Icons.people_outline,
      items: ['All Users', 'Parents', 'Children', 'LLG Specialists', 'Suspended Accounts', 'Recovery Requests'],
    ),
    NavGroup(
      title: 'LLG Management',
      icon: Icons.verified_user_outlined,
      items: ['Specialist Directory', 'Verification Queue', 'Parent–LLG Assignments', 'Child–LLG Assignments', 'Assignment History'],
    ),
    NavGroup(
      title: 'Activity Management',
      icon: Icons.auto_stories_outlined,
      items: ['Activities Library', 'AI Content Review', 'Performance & Feedback'],
    ),
    NavGroup(
      title: 'Communication',
      icon: Icons.chat_bubble_outline,
      items: ['Notification Center', 'Email Delivery History', 'Support Inquiries'],
    ),
    NavGroup(
      title: 'Analytics & Reports',
      icon: Icons.analytics_outlined,
      items: ['Platform Analytics', 'Reports & Data Exports'],
    ),
    NavGroup(
      title: 'Security & Admin',
      icon: Icons.security_outlined,
      items: ['Audit Trail', 'Security Events', 'System Health Status'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(firestore: _firestore, auth: _auth);
    _selectedGroupIndex = widget.initialGroupIndex;
    _selectedSubIndex = widget.initialSubIndex;
    _isGroupExpanded = List.generate(_navGroups.length, (i) => i == _selectedGroupIndex);
    _loadAdminInfo();
  }

  Future<void> _loadAdminInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentAdminName = user.displayName ?? (user.email?.split('@').first ?? 'Administrator');
        _currentAdminEmail = user.email ?? 'admin@littlelumin.com';
      });
    }
  }

  void _navigateTo(int groupIndex, int subIndex) {
    setState(() {
      _selectedGroupIndex = groupIndex;
      _selectedSubIndex = subIndex;
      for (int i = 0; i < _isGroupExpanded.length; i++) {
        _isGroupExpanded[i] = (i == groupIndex);
      }
    });
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
        title: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to end your administrative session?',
          style: GoogleFonts.inter(color: colorTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 1000;

    return Scaffold(
      backgroundColor: colorNavy,
      body: Row(
        children: [
          // 1. Grouped Left Sidebar
          _buildSidebar(isCompact),

          // 2. Main Content Area with Top Bar
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildCurrentView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. GROUPED LEFT SIDEBAR
  // =========================================================================
  Widget _buildSidebar(bool isCompact) {
    final width = _isSidebarCollapsed ? 72.0 : 256.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: const BoxDecoration(
        color: colorSlate,
        border: Border(right: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Column(
        children: [
          // Brand Logo Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'LittleLumin',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Admin Portal',
                          style: GoogleFonts.inter(fontSize: 11, color: colorTeal, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(_isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left, color: colorTextMuted, size: 20),
                  onPressed: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
                ),
              ],
            ),
          ),

          // Grouped Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _navGroups.length,
              itemBuilder: (context, gIndex) {
                final group = _navGroups[gIndex];
                final isSelectedGroup = _selectedGroupIndex == gIndex;
                final isExpanded = _isGroupExpanded[gIndex];

                if (_isSidebarCollapsed) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: IconButton(
                      icon: Icon(group.icon, color: isSelectedGroup ? colorTeal : colorTextMuted),
                      tooltip: group.title,
                      onPressed: () {
                        setState(() {
                          _isSidebarCollapsed = false;
                          _navigateTo(gIndex, 0);
                        });
                      },
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Header
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isGroupExpanded[gIndex] = !_isGroupExpanded[gIndex];
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(group.icon, size: 18, color: isSelectedGroup ? colorTeal : colorTextMuted),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                group.title,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSelectedGroup ? FontWeight.bold : FontWeight.w600,
                                  color: isSelectedGroup ? Colors.white : colorTextMuted,
                                ),
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.expand_more : Icons.chevron_right,
                              size: 16,
                              color: colorTextMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sub Items
                    if (isExpanded)
                      ...group.items.asMap().entries.map((entry) {
                        final subIndex = entry.key;
                        final subTitle = entry.value;
                        final isSubSelected = isSelectedGroup && _selectedSubIndex == subIndex;

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(28, 2, 12, 2),
                          child: InkWell(
                            onTap: () => _navigateTo(gIndex, subIndex),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSubSelected ? colorTeal.withOpacity(0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: isSubSelected ? Border.all(color: colorTeal.withOpacity(0.3)) : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: isSubSelected ? colorTeal : colorTextMuted.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      subTitle,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: isSubSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSubSelected ? Colors.white : colorTextMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 6),
                  ],
                );
              },
            ),
          ),

          // Sign Out Button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: colorBorder, width: 1)),
            ),
            child: InkWell(
              onTap: _signOut,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                    if (!_isSidebarCollapsed) ...[
                      const SizedBox(width: 10),
                      Text(
                        'Sign Out',
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. TOP NAVIGATION BAR
  // =========================================================================
  Widget _buildTopBar() {
    final groupTitle = _navGroups[_selectedGroupIndex].title;
    final subTitle = _navGroups[_selectedGroupIndex].items[_selectedSubIndex];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: colorNavy,
        border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Dynamic Breadcrumb
          Row(
            children: [
              Text(
                groupTitle,
                style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted, fontWeight: FontWeight.w500),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right, size: 16, color: colorTextMuted),
              ),
              Text(
                subTitle,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const Spacer(),

          // Notification Bell
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('notifications').where('read', isEqualTo: false).snapshots(),
            builder: (context, snap) {
              final unreadCount = snap.data?.docs.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: colorTextMuted),
                    tooltip: 'Notification Center',
                    onPressed: () => _navigateTo(4, 0), // Communication -> Notifications
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),

          // Administrator Profile Chip
          Tooltip(
            message: 'Signed in as: $_currentAdminEmail',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: colorTeal,
                    child: Text(
                      _currentAdminName.isNotEmpty ? _currentAdminName[0].toUpperCase() : 'A',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentAdminName,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: colorTeal, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. ROUTER / SELECTED VIEW
  // =========================================================================
  Widget _buildCurrentView() {
    switch (_selectedGroupIndex) {
      case 0: // Dashboard
        if (_selectedSubIndex == 2) {
          return AdminSecurityHealthView(
            adminService: _adminService,
            initialSubIndex: 2, // System Health
            onNavigate: _navigateTo,
          );
        }
        return AdminOverviewView(
          adminService: _adminService,
          onNavigate: _navigateTo,
        );

      case 1: // User Management
        return AdminUserManagementView(
          adminService: _adminService,
          initialSubIndex: _selectedSubIndex,
          onNavigate: _navigateTo,
        );

      case 2: // LLG Management
        return AdminLLGManagementView(
          adminService: _adminService,
          initialSubIndex: _selectedSubIndex,
          onNavigate: _navigateTo,
        );

      case 3: // Activity Management
        return AdminActivityManagementView(
          adminService: _adminService,
          initialSubIndex: _selectedSubIndex,
          onNavigate: _navigateTo,
        );

      case 4: // Communication
        return AdminCommunicationView(
          adminService: _adminService,
          initialSubIndex: _selectedSubIndex,
          onNavigate: _navigateTo,
        );

      case 5: // Analytics & Reports
        return AdminAnalyticsReportsView(
          adminService: _adminService,
          initialSubIndex: _selectedSubIndex,
          onNavigate: _navigateTo,
        );

      case 6: // Security & Administration
        return AdminSecurityHealthView(
          adminService: _adminService,
          initialSubIndex: _selectedSubIndex,
          onNavigate: _navigateTo,
        );

      default:
        return AdminOverviewView(
          adminService: _adminService,
          onNavigate: _navigateTo,
        );
    }
  }
}

class NavGroup {
  final String title;
  final IconData icon;
  final List<String> items;

  NavGroup({required this.title, required this.icon, required this.items});
}