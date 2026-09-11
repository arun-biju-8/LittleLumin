// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/constants.dart';
import '../../screens/auth/login_page.dart';
import 'admin_home_page.dart';
import 'admin_llg_verification_page.dart';
import 'llg_management_page.dart';
import 'user_directory_page.dart';
import 'flagged_children_page.dart';
import 'admin_activity_management.dart';
import 'admin_analytics_page.dart';
import 'admin_profile_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      AdminHomePage(onNavigate: (idx) => setState(() => _selectedIndex = idx)),
      const AdminLLGVerificationPage(),
      const LLGManagementPage(),
      const UserDirectoryPage(),
      const FlaggedChildrenPage(),
      const AdminActivityManagement(),
      const AdminAnalyticsPage(),
      const AdminProfilePage(),
    ];
  }

  final List<String> _titles = [
    'Dashboard',
    'LLG Approvals',
    'LLG Guides',
    'User Directory',
    'Flagged Children',
    'Activities Library',
    'Platform Analytics',
    'Admin Profile',
  ];

  final List<IconData> _icons = [
    Icons.dashboard_rounded,
    Icons.verified_user_rounded,
    Icons.supervisor_account_rounded,
    Icons.people_alt_rounded,
    Icons.flag_rounded,
    Icons.auto_stories_rounded,
    Icons.analytics_rounded,
    Icons.admin_panel_settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb || MediaQuery.of(context).size.width > 800;
    final sidebarWidth = _isSidebarCollapsed ? 72.0 : 240.0;
    final sidebarNav = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: sidebarWidth,
      color: AppColors.white,
      height: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.auto_stories, color: AppColors.primary, size: 28),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Text(
                    'LittleLumin',
                    style: AppTextStyles.heading2.copyWith(fontSize: 16),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _isSidebarCollapsed ? 'ADMIN' : 'ADMIN PORTAL',
              style: TextStyle(
                fontSize: _isSidebarCollapsed ? 8 : 11,
                letterSpacing: 1.2,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Navigation Items
          for (int i = 0; i < _pages.length; i++)
            _buildNavItem(
              title: _titles[i],
              index: i,
              icon: _icons[i],
              isCollapsed: _isSidebarCollapsed,
            ),

          const Spacer(),

          ListTile(
            leading: Icon(
              _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
              color: Colors.grey[500],
            ),
            title: _isSidebarCollapsed
                ? null
                : Text(
                    'Hide Sidebar',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
            onTap: () {
              setState(() {
                _isSidebarCollapsed = !_isSidebarCollapsed;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex], style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textDark),
            onPressed: () async {
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
            },
          ),
        ],
      ),
      drawer: !isWeb
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      color: AppColors.primary.withOpacity(0.1),
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings,
                              color: AppColors.primary, size: 32),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LittleLumin',
                                style: AppTextStyles.heading2.copyWith(fontSize: 16),
                              ),
                              const Text(
                                'Executive Admin Portal',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          for (int i = 0; i < _pages.length; i++)
                            ListTile(
                              leading: Icon(_icons[i],
                                  color: _selectedIndex == i
                                      ? AppColors.primary
                                      : Colors.grey[600]),
                              title: Text(
                                _titles[i],
                                style: TextStyle(
                                  color: _selectedIndex == i
                                      ? AppColors.primary
                                      : AppColors.textDark,
                                  fontWeight: _selectedIndex == i
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: _selectedIndex == i,
                              onTap: () {
                                Navigator.pop(context);
                                setState(() => _selectedIndex = i);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: isWeb
          ? Row(
              children: [
                // Sidebar
                sidebarNav,
                // Main Content (No outer SingleChildScrollView to prevent unbounded height layout bugs)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _pages[_selectedIndex],
                    ),
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _pages[_selectedIndex],
            ),
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
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.supervisor_account_rounded),
                  label: 'LLGs',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people_alt_rounded),
                  label: 'Users',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.flag_rounded),
                  label: 'Flagged',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_stories_rounded),
                  label: 'Activities',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.admin_panel_settings_rounded),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildNavItem({
    required String title,
    required int index,
    required IconData icon,
    required bool isCollapsed,
  }) {
    final isSelected = _selectedIndex == index;
    return Tooltip(
      message: isCollapsed ? title : '',
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : Colors.grey[500],
          size: 22,
        ),
        title: isCollapsed
            ? null
            : Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
        selected: isSelected,
        selectedTileColor: AppColors.primary.withOpacity(0.08),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}