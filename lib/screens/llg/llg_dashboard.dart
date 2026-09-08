// lib/screens/llg/llg_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/constants.dart';
import '../../services/child_service.dart';
import '../../services/activity_service.dart';
import '../../models/child_model.dart';
import '../../models/activity_model.dart';
import '../auth/login_page.dart';
import 'send_recommendation_page.dart';
import 'llg_activity_management.dart';
import 'add_activity_page.dart';
import 'llg_profile_page.dart';
import '../admin/flagged_children_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LLGDashboard extends StatefulWidget {
  const LLGDashboard({super.key});

  @override
  State<LLGDashboard> createState() => _LLGDashboardState();
}

class _LLGDashboardState extends State<LLGDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  late final List<Widget> _pages;

  final List<String> _pageTitles = [
    'Dashboard Overview',
    'Flagged Children Directory',
    'Activity Management Hub',
    'Create New Activity',
    'My Guide Profile',
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      LLGHomePage(
        onNavigate: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      const FlaggedChildrenPage(),
      const LLGActivityManagement(),
      AddActivityPage(
        onSuccess: () {
          setState(() => _selectedIndex = 2);
        },
      ),
      const LLGProfilePage(),
    ];
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userType = userDoc.data()?['userType'] ?? '';

      if (userType != 'llg') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                userType == 'llg_pending'
                    ? '⏳ Your account is pending administrator verification.'
                    : 'Access restricted. LLG verification required.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
        return;
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb || MediaQuery.of(context).size.width > 800;
    final currentUser = FirebaseAuth.instance.currentUser;
    final userEmail = currentUser?.email ?? 'llg.guide@littlelumin.com';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isWeb
          ? null // Web view uses custom top navigation header
          : AppBar(
              title: Text(
                _pageTitles[_selectedIndex],
                style: AppTextStyles.heading2,
              ),
              backgroundColor: AppColors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: AppColors.textDark),
                  onPressed: _logout,
                ),
              ],
            ),
      body: isWeb
          ? Row(
              children: [
                // ✅ Modern Web Sidebar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isSidebarCollapsed ? 76 : 260,
                  color: AppColors.white,
                  height: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Brand Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '✨',
                                style: TextStyle(fontSize: 20),
                              ),
                            ),
                            if (!_isSidebarCollapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'LittleLumin',
                                      style: AppTextStyles.heading2.copyWith(
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'GUIDE PORTAL',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Navigation Section Header
                      if (!_isSidebarCollapsed)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Text(
                            'MAIN MENU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),

                      // Navigation Items with Live Badges
                      StreamBuilder<List<ChildModel>>(
                        stream: ChildService().getFlaggedChildren(),
                        builder: (context, flaggedSnapshot) {
                          final flaggedCount =
                              flaggedSnapshot.data?.length ?? 0;

                          return StreamBuilder<List<ActivityModel>>(
                            stream: ActivityService().getAllActivities(),
                            builder: (context, activitySnapshot) {
                              final activityCount =
                                  activitySnapshot.data?.length ?? 0;

                              return Column(
                                children: [
                                  _buildWebNavItem(
                                    title: 'Dashboard',
                                    index: 0,
                                    icon: Icons.space_dashboard_rounded,
                                  ),
                                  _buildWebNavItem(
                                    title: 'Flagged Children',
                                    index: 1,
                                    icon: Icons.flag_rounded,
                                    badgeCount: flaggedCount > 0
                                        ? flaggedCount
                                        : null,
                                    badgeColor: AppColors.warning,
                                  ),
                                  _buildWebNavItem(
                                    title: 'Manage Activities',
                                    index: 2,
                                    icon: Icons.auto_stories_rounded,
                                    badgeCount: activityCount > 0
                                        ? activityCount
                                        : null,
                                    badgeColor: AppColors.primary,
                                  ),
                                  _buildWebNavItem(
                                    title: 'Add Activity',
                                    index: 3,
                                    icon: Icons.add_circle_outline_rounded,
                                  ),
                                  _buildWebNavItem(
                                    title: 'My Profile',
                                    index: 4,
                                    icon: Icons.person_rounded,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      const Spacer(),

                      // User Profile Gateway Card (When expanded)
                      if (!_isSidebarCollapsed) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = 4),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary,
                                    child: Text(
                                      userEmail.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LLG Caseworker',
                                          style: AppTextStyles.small.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        Text(
                                          userEmail,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      const Divider(height: 1),

                      // Logout Item
                      _buildLogoutNavItem(),

                      // Hide Sidebar Toggle
                      _buildCollapseToggleNavItem(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Vertical Separator Border
                Container(width: 1, color: Colors.grey[200]),

                // ✅ Web Main View Area with Integrated Header
                Expanded(
                  child: Column(
                    children: [
                      // Web Integrated Top Header Bar
                      _buildWebTopHeaderBar(userEmail),

                      // Page View Container
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: _pages[_selectedIndex],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _pages[_selectedIndex],
      bottomNavigationBar: !isWeb
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textLight,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.flag),
                  label: 'Flagged',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.playlist_add),
                  label: 'Activities',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Add Activity',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }

  // ✅ Web Top Header Bar
  Widget _buildWebTopHeaderBar(String userEmail) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Breadcrumb / Title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LLG Portal  /  ${_pageTitles[_selectedIndex]}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _pageTitles[_selectedIndex],
                style: AppTextStyles.heading2.copyWith(fontSize: 18),
              ),
            ],
          ),

          const Spacer(),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LLG Active Session',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Top Quick Add Button
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _selectedIndex = 3);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Activity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
              ),
              elevation: 0,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Profile Icon Button
          IconButton(
            icon: Icon(
              Icons.person_rounded,
              color: _selectedIndex == 4 ? AppColors.primary : Colors.grey[600],
            ),
            tooltip: 'My Profile',
            onPressed: () => setState(() => _selectedIndex = 4),
          ),

          // Logout Icon
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.grey[600]),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  // ✅ Web Sidebar Nav Item Builder
  Widget _buildWebNavItem({
    required String title,
    required int index,
    required IconData icon,
    int? badgeCount,
    Color? badgeColor,
  }) {
    final isSelected = _selectedIndex == index;

    if (_isSidebarCollapsed) {
      return Tooltip(
        message: title,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          child: Container(
            height: 52,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppColors.primary : AppColors.textLight,
                  size: 22,
                ),
                if (badgeCount != null)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textLight,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textDark,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: badgeCount != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.primary).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? AppColors.primary,
                  ),
                ),
              )
            : null,
        selected: isSelected,
        selectedTileColor: AppColors.primary.withOpacity(0.1),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildLogoutNavItem() {
    if (_isSidebarCollapsed) {
      return Tooltip(
        message: 'Logout',
        child: InkWell(
          onTap: _logout,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: const Icon(
              Icons.logout,
              color: AppColors.textLight,
              size: 20,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: const Icon(Icons.logout, color: AppColors.textLight, size: 20),
        title: Text(
          'Logout',
          style: TextStyle(color: AppColors.textLight, fontSize: 14),
        ),
        onTap: _logout,
      ),
    );
  }

  Widget _buildCollapseToggleNavItem() {
    final tooltipText = _isSidebarCollapsed ? 'Expand Sidebar' : 'Hide Sidebar';
    final iconData = _isSidebarCollapsed
        ? Icons.chevron_right_rounded
        : Icons.chevron_left_rounded;

    if (_isSidebarCollapsed) {
      return Tooltip(
        message: tooltipText,
        child: InkWell(
          onTap: () =>
              setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: Icon(iconData, color: AppColors.primary, size: 22),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(iconData, color: AppColors.primary, size: 20),
        title: Text(
          'Hide Sidebar',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        onTap: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
      ),
    );
  }
}

// ============================================
// LLG Web-Friendly Home Page
// ============================================

class LLGHomePage extends StatelessWidget {
  final Function(int)? onNavigate;

  const LLGHomePage({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Web Hero Welcome Banner
          _buildHeroWelcomeBanner(),
          const SizedBox(height: AppSpacing.lg),

          // ✅ Stats Grid (4 Metrics Cards)
          StreamBuilder<List<ChildModel>>(
            stream: ChildService().getFlaggedChildren(),
            builder: (context, flaggedSnapshot) {
              final flaggedCount = flaggedSnapshot.data?.length ?? 0;

              return StreamBuilder<List<ActivityModel>>(
                stream: ActivityService().getAllActivities(),
                builder: (context, activitySnapshot) {
                  final activityCount = activitySnapshot.data?.length ?? 0;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;

                      return GridView.count(
                        crossAxisCount: isWide ? 4 : 2,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        shrinkWrap: true,
                        childAspectRatio: isWide ? 1.8 : 1.4,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatCard(
                            title: 'FLAGGED CHILDREN',
                            value: '$flaggedCount',
                            subtitle: 'Requires Casework Review',
                            icon: Icons.flag_rounded,
                            color: AppColors.warning,
                            onTap: () => onNavigate?.call(1),
                          ),
                          _buildStatCard(
                            title: 'PENDING REVIEWS',
                            value: '$flaggedCount',
                            subtitle: 'Awaiting Recommendation',
                            icon: Icons.pending_actions_rounded,
                            color: AppColors.primary,
                            onTap: () => onNavigate?.call(1),
                          ),
                          _buildStatCard(
                            title: 'MANAGED ACTIVITIES',
                            value: '$activityCount',
                            subtitle: 'Active in Parent Library',
                            icon: Icons.auto_stories_rounded,
                            color: AppColors.success,
                            onTap: () => onNavigate?.call(2),
                          ),
                          _buildStatCard(
                            title: 'PORTAL STATUS',
                            value: 'Active',
                            subtitle: 'LLG Guide Verified',
                            icon: Icons.verified_user_rounded,
                            color: Colors.purple,
                            onTap: () {},
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // ✅ Web Quick Action Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚡ Quick Management Actions',
                style: AppTextStyles.heading2.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;

              return isWide
                  ? Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            title: 'Review Flagged Cases',
                            subtitle:
                                'Examine VABS-II flagged children & send academic guidance',
                            icon: Icons.flag_circle_rounded,
                            color: AppColors.warning,
                            buttonText: 'View Directory',
                            onTap: () => onNavigate?.call(1),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            title: 'Activity Management',
                            subtitle:
                                'Add, update, or remove developmental activities for parents',
                            icon: Icons.auto_stories_rounded,
                            color: AppColors.primary,
                            buttonText: 'Manage Hub',
                            onTap: () => onNavigate?.call(2),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            title: 'Create Activity',
                            subtitle:
                                'Design custom screen-free learning exercises',
                            icon: Icons.add_circle_outline_rounded,
                            color: AppColors.secondary,
                            buttonText: 'Create New',
                            onTap: () => onNavigate?.call(3),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildActionCard(
                          context,
                          title: 'Review Flagged Cases',
                          subtitle:
                              'Examine VABS-II flagged children & send guidance',
                          icon: Icons.flag_circle_rounded,
                          color: AppColors.warning,
                          buttonText: 'View Directory',
                          onTap: () => onNavigate?.call(1),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildActionCard(
                          context,
                          title: 'Activity Management',
                          subtitle:
                              'Add, update, or remove activities for parents',
                          icon: Icons.auto_stories_rounded,
                          color: AppColors.primary,
                          buttonText: 'Manage Hub',
                          onTap: () => onNavigate?.call(2),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // ✅ Recent Flagged Children Table Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🚩 Priority Flagged Children',
                style: AppTextStyles.heading2.copyWith(fontSize: 18),
              ),
              TextButton.icon(
                onPressed: () => onNavigate?.call(1),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View All Flagged'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          StreamBuilder<List<ChildModel>>(
            stream: ChildService().getFlaggedChildren(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final children = snapshot.data ?? [];
              if (children.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'All Children Are On Track! 🎉',
                        style: AppTextStyles.heading2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No flagged cases require review at this time.',
                        style: AppTextStyles.bodyLight,
                      ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: children.length > 5 ? 5 : children.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final child = children[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.warning.withOpacity(0.15),
                        child: Text(
                          child.name[0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        child.name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${child.age} yrs • ${child.gender}  |  Reason: ${child.flagReason ?? "VABS-II Score Gap"}',
                        style: AppTextStyles.small,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChildDetailPage(child: child),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 16,
                            ),
                            label: const Text('Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withOpacity(0.5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SendRecommendationPage(child: child),
                                ),
                              );
                            },
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: const Text('Recommend'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  // Hero Welcome Banner
  Widget _buildHeroWelcomeBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 700;

        final textColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '✨ LittleLumin Guide Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Empowering Child Growth & Milestones',
              style: AppTextStyles.heading1.copyWith(
                color: Colors.white,
                fontSize: isMobile ? 20 : 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Review flagged profiles, track VABS-II skill gaps, and provide personalized non-clinical recommendations.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          ],
        );

        final actionButton = ElevatedButton.icon(
          onPressed: () => onNavigate?.call(1),
          icon: const Icon(Icons.flag, color: AppColors.primary, size: 18),
          label: const Text('Review Flagged Cases'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 10 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D4ED8).withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textColumn,
                    const SizedBox(height: AppSpacing.md),
                    actionButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: textColumn),
                    const SizedBox(width: AppSpacing.lg),
                    actionButton,
                  ],
                ),
        );
      },
    );
  }

  // Stat Card
  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            Text(
              value,
              style: AppTextStyles.heading1.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // Action Card
  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// LLG Flagged Children Page (Web Friendly)
// ============================================

class LLGFflaggedPage extends StatefulWidget {
  const LLGFflaggedPage({super.key});

  @override
  State<LLGFflaggedPage> createState() => _LLGFflaggedPageState();
}

class _LLGFflaggedPageState extends State<LLGFflaggedPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Web Search & Filter Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchQuery = val.toLowerCase().trim());
                },
                decoration: InputDecoration(
                  hintText: 'Search flagged children by name or reason...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        Expanded(
          child: StreamBuilder<List<ChildModel>>(
            stream: ChildService().getFlaggedChildren(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final allChildren = snapshot.data ?? [];
              final filteredChildren = allChildren.where((child) {
                final nameMatches = child.name.toLowerCase().contains(
                  _searchQuery,
                );
                final reasonMatches = (child.flagReason ?? '')
                    .toLowerCase()
                    .contains(_searchQuery);
                return nameMatches || reasonMatches;
              }).toList();

              if (filteredChildren.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off
                            : Icons.check_circle,
                        size: 64,
                        color: _searchQuery.isNotEmpty
                            ? Colors.grey[400]
                            : AppColors.success,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No flagged children matching "$_searchQuery"'
                            : 'No flagged children! 🎉',
                        style: AppTextStyles.heading2.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Try searching with a different child name or keyword'
                            : 'All children profiles are within expected developmental ranges',
                        style: AppTextStyles.bodyLight,
                      ),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;

                  if (isWide) {
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.md,
                            childAspectRatio: 2.4,
                          ),
                      itemCount: filteredChildren.length,
                      itemBuilder: (context, index) {
                        final child = filteredChildren[index];
                        return _buildFlaggedChildWebCard(context, child);
                      },
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredChildren.length,
                    itemBuilder: (context, index) {
                      final child = filteredChildren[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _buildFlaggedChildWebCard(context, child),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlaggedChildWebCard(BuildContext context, ChildModel child) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.warning.withOpacity(0.15),
                child: Text(
                  child.name[0].toUpperCase(),
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${child.age} years old • ${child.gender}',
                      style: AppTextStyles.small,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: const Text(
                  '🚩 Flagged',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (child.flagReason != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Reason: ${child.flagReason}',
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChildDetailPage(child: child),
                    ),
                  );
                },
                icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                label: const Text('View Profile'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SendRecommendationPage(child: child),
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Send Rec'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// Child Detail Page (LLG Web View)
// ============================================

class ChildDetailPage extends StatefulWidget {
  final ChildModel child;

  const ChildDetailPage({super.key, required this.child});

  @override
  State<ChildDetailPage> createState() => _ChildDetailPageState();
}

class _ChildDetailPageState extends State<ChildDetailPage> {
  Map<String, dynamic>? _skillData;

  @override
  void initState() {
    super.initState();
    _loadSkillProfile();
  }

  Future<void> _loadSkillProfile() async {
    final data = await ChildService().getChildWithProfile(widget.child.childId);
    if (data != null) {
      setState(() {
        _skillData = data['skillProfile'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${child.name}\'s Profile', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.send, color: AppColors.success),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SendRecommendationPage(child: child),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Child Info Header Banner
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.warning, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: AppColors.white,
                    child: Text(
                      child.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: AppTextStyles.heading2.copyWith(
                            color: AppColors.white,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          '${child.age} years • ${child.gender}',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.white.withOpacity(0.9),
                          ),
                        ),
                        if (child.isFlagged)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '🚩 Flagged for LLG Attention',
                              style: AppTextStyles.small.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Skill Profile Box
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📊 VABS-II Skill Assessment Profile',
                    style: AppTextStyles.heading2.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_skillData == null)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _buildSkillRow('Cognitive', _skillData?['cognitive'] ?? 0),
                    _buildSkillRow('Language', _skillData?['language'] ?? 0),
                    _buildSkillRow('Motor', _skillData?['motor'] ?? 0),
                    _buildSkillRow('Social', _skillData?['social'] ?? 0),
                    _buildSkillRow('Emotional', _skillData?['emotional'] ?? 0),
                    _buildSkillRow('Creative', _skillData?['creative'] ?? 0),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Flag Reason
            if (child.flagReason != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ Flag Reason & Clinical Note',
                      style: AppTextStyles.heading2.copyWith(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(child.flagReason ?? '', style: AppTextStyles.body),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                color: value >= 70
                    ? AppColors.success
                    : value >= 50
                    ? AppColors.primary
                    : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 45,
            child: Text(
              '${value.toInt()}%',
              style: AppTextStyles.small.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
