// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import '../../utils/constants.dart';
import '../../screens/auth/login_page.dart';
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
  int _totalChildren = 0;
  int _activeParents = 0;
  int _llgGuides = 0;
  int _flaggedCases = 0;
  bool _isLoading = true;

  final List<Widget> _pages = [
    const AdminHomePage(),
    const ManageUsersPage(),
    const FlaggedChildrenPage(),
    const CreateLLGPage(),
    // Settings page (optional)
  ];

  final List<String> _titles = [
    'Dashboard',
    'User Directory',
    'Flagged Cases',
    'Provision LLG Guide',
  ];

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);

    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final childrenSnapshot = await FirebaseFirestore.instance.collection('children').get();
      final flaggedSnapshot = await FirebaseFirestore.instance
          .collection('children')
          .where('isFlagged', isEqualTo: true)
          .get();

      setState(() {
        _totalChildren = childrenSnapshot.docs.length;
        _activeParents = usersSnapshot.docs.where((doc) => doc['userType'] == 'parent').length;
        _llgGuides = usersSnapshot.docs.where((doc) => doc['userType'] == 'llg').length;
        _flaggedCases = flaggedSnapshot.docs.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb || MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('LittleLumin Admin Portal', style: AppTextStyles.heading2),
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
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: isWeb
          ? Row(
              children: [
                // ✅ Web Sidebar (Like Your Image)
                Container(
                  width: 260,
                  color: AppColors.white,
                  height: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '✨ LittleLumin',
                          style: AppTextStyles.heading2.copyWith(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'ADMIN PORTAL',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Navigation Items
                      _buildNavItem('Dashboard', 0, Icons.dashboard),
                      _buildNavItem('User Directory', 1, Icons.people),
                      _buildNavItem('Flagged Cases', 2, Icons.flag),
                      _buildNavItem('Provision LLG Guide', 3, Icons.person_add),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Portal Gateway',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  'A',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin User',
                                      style: AppTextStyles.small.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'admin@littlelumin.com',
                                      style: AppTextStyles.small.copyWith(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                // ✅ Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildWebDashboard(),
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
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
                BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Flagged'),
                BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Create LLG'),
              ],
            )
          : null,
    );
  }

  Widget _buildNavItem(String title, int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : Colors.grey[500],
        size: 20,
      ),
      title: Text(
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
    );
  }

  // ✅ Web Dashboard with Stats and Charts
  Widget _buildWebDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, Admin!',
          style: AppTextStyles.heading1,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Monitor your platform activity and child development metrics',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.lg),

        // Stats Cards (4 Columns)
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'REGISTERED CHILDREN',
                '$_totalChildren',
                '+${(_totalChildren * 0.142).toInt()}% this month',
                Icons.child_care,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildStatCard(
                'ACTIVE PARENTS',
                '$_activeParents',
                '+${(_activeParents * 0.086).toInt()}% active today',
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildStatCard(
                'LLG GUIDES',
                '$_llgGuides',
                'Active caseworkers',
                Icons.shield,
                Colors.purple,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildStatCard(
                'FLAGGED CASES',
                '$_flaggedCases',
                'Needs LLG Review',
                Icons.flag,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Charts Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildActivityChart(),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 1,
              child: _buildDomainPieChart(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: AppTextStyles.heading1.copyWith(fontSize: 24),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Activity Generation Volume',
            style: AppTextStyles.heading2.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Screen-free activities generated by domain focus',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(toY: 120, color: AppColors.primary, width: 16),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(toY: 80, color: Colors.green, width: 16),
                  ]),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const titles = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];
                        return Text(
                          titles[value.toInt() % titles.length],
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainPieChart() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Domain Needs Distribution',
            style: AppTextStyles.heading2.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'VABS-II weak skill domains targeted',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: 40,
                    color: AppColors.primary,
                    title: '40%',
                    radius: 30,
                  ),
                  PieChartSectionData(
                    value: 30,
                    color: Colors.green,
                    title: '30%',
                    radius: 30,
                  ),
                  PieChartSectionData(
                    value: 20,
                    color: Colors.orange,
                    title: '20%',
                    radius: 30,
                  ),
                  PieChartSectionData(
                    value: 10,
                    color: Colors.purple,
                    title: '10%',
                    radius: 30,
                  ),
                ],
                sectionsSpace: 4,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _buildLegendItem('Cognitive', AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              _buildLegendItem('Language', Colors.green),
              const SizedBox(width: AppSpacing.sm),
              _buildLegendItem('Motor', Colors.orange),
            ],
          ),
          Row(
            children: [
              _buildLegendItem('Social', Colors.purple),
              const SizedBox(width: AppSpacing.sm),
              _buildLegendItem('Emotional', Colors.pink),
              const SizedBox(width: AppSpacing.sm),
              _buildLegendItem('Creative', Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}