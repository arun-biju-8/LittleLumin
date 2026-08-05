// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/constants.dart';
import '../auth/login_page.dart';
import 'admin_home_page.dart';
import 'create_llg_page.dart';
import 'flagged_children_page.dart';
import 'manage_users_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const AdminHomePage(),
    const CreateLLGPage(),
    const FlaggedChildrenPage(),
    const ManageUsersPage(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Create LLG',
    'Flagged Children',
    'Manage Users',
  ];

  @override
  Widget build(BuildContext context) {
    final bool isWeb = kIsWeb || MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Admin Dashboard', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.textDark),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginPage(),
                  ), // ✅ Removed const
                );
              }
            },
          ),
        ],
      ),
      body: isWeb
          ? Row(
              children: [
                // Web Sidebar
                Container(
                  width: 240,
                  color: AppColors.white,
                  height: double.infinity,
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '✨ LittleLumin',
                          style: AppTextStyles.heading2.copyWith(fontSize: 18),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      for (int i = 0; i < _pages.length; i++)
                        ListTile(
                          leading: Icon(
                            _getIcon(i),
                            color: _selectedIndex == i
                                ? AppColors.primary
                                : AppColors.textLight,
                          ),
                          title: Text(
                            _titles[i],
                            style: TextStyle(
                              color: _selectedIndex == i
                                  ? AppColors.primary
                                  : AppColors.textDark,
                              fontWeight: _selectedIndex == i
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: _selectedIndex == i,
                          selectedTileColor: AppColors.primary.withOpacity(0.1),
                          onTap: () {
                            setState(() {
                              _selectedIndex = i;
                            });
                          },
                        ),
                      const Spacer(),
                      ListTile(
                        leading: Icon(Icons.logout, color: AppColors.textLight),
                        title: Text(
                          'Logout',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoginPage(),
                              ), // ✅ Removed const
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16), //
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: _pages[_selectedIndex],
                    ),
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
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_add),
                  label: 'Create',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.flag),
                  label: 'Flagged',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Users',
                ),
              ],
            )
          : null,
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard;
      case 1:
        return Icons.person_add;
      case 2:
        return Icons.flag;
      case 3:
        return Icons.people;
      default:
        return Icons.dashboard;
    }
  }
}
