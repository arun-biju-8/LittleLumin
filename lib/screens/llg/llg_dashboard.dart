// lib/screens/llg/llg_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/constants.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';
import '../auth/login_page.dart';
import 'send_recommendation_page.dart';
import 'manage_activities_page.dart';

class LLGDashboard extends StatefulWidget {
  const LLGDashboard({super.key});

  @override
  State<LLGDashboard> createState() => _LLGDashboardState();
}

class _LLGDashboardState extends State<LLGDashboard> {
  int _selectedIndex = 0;

  // ✅ Added ManageActivitiesPage
  final List<Widget> _pages = [
    const LLGHomePage(),
    const LLGFflaggedPage(),
    const ManageActivitiesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb || MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('LLG Dashboard', style: AppTextStyles.heading2),
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
                // ✅ Web Sidebar
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
                          '✨ LittleLumin Guide',
                          style: AppTextStyles.heading2.copyWith(fontSize: 18),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 16),
                      // ✅ Navigation Items
                      _buildWebNavItem('Dashboard', 0, Icons.dashboard),
                      _buildWebNavItem('Flagged Children', 1, Icons.flag),
                      _buildWebNavItem('Manage Activities', 2, Icons.playlist_add),
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
                                  builder: (_) => const LoginPage()),
                            );
                          }
                        },
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
              ],
            )
          : null,
    );
  }

  Widget _buildWebNavItem(String title, int index, IconData icon) {
    return ListTile(
      leading: Icon(
        icon,
        color: _selectedIndex == index ? AppColors.primary : AppColors.textLight,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _selectedIndex == index ? AppColors.primary : AppColors.textDark,
          fontWeight: _selectedIndex == index ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: _selectedIndex == index,
      selectedTileColor: AppColors.primary.withOpacity(0.1),
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
    );
  }
}

// ============================================
// LLG Home Page
// ============================================

class LLGHomePage extends StatelessWidget {
  const LLGHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, LLG!',
          style: AppTextStyles.heading1,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Review flagged children and send recommendations to parents.',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.lg),

        StreamBuilder<List<ChildModel>>(
          stream: ChildService().getFlaggedChildren(),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Flagged Children',
                    '$count',
                    Icons.flag,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildStatCard(
                    'Pending Review',
                    '$count',
                    Icons.pending,
                    AppColors.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.heading1.copyWith(fontSize: 24),
              ),
              Text(
                label,
                style: AppTextStyles.bodyLight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================
// LLG Flagged Children Page
// ============================================

class LLGFflaggedPage extends StatelessWidget {
  const LLGFflaggedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🚩 Flagged Children',
          style: AppTextStyles.heading1.copyWith(fontSize: 22),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Review children who need professional attention',
          style: AppTextStyles.bodyLight,
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

              final children = snapshot.data ?? [];

              if (children.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 80, color: AppColors.success),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No flagged children! 🎉',
                        style: AppTextStyles.heading1.copyWith(fontSize: 24),
                      ),
                      Text(
                        'All children are on track',
                        style: AppTextStyles.bodyLight,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: children.length,
                itemBuilder: (context, index) {
                  final child = children[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.warning.withOpacity(0.2),
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${child.age} years • ${child.gender}'),
                          if (child.flagReason != null)
                            Text(
                              'Reason: ${child.flagReason}',
                              style: AppTextStyles.small.copyWith(
                                color: Colors.red[400],
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove_red_eye, color: AppColors.primary),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChildDetailPage(child: child),
                                ),
                              );
                            },
                          ),
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
}

// ============================================
// Child Detail Page (LLG View)
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
            // Child Info Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '🚩 Flagged',
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

            // Skill Profile
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
                    '📊 Skill Profile',
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
                      '⚠️ Flag Reason',
                      style: AppTextStyles.heading2.copyWith(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      child.flagReason ?? '',
                      style: AppTextStyles.body,
                    ),
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
            width: 80,
            child: Text(label, style: AppTextStyles.small),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 8,
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
            width: 40,
            child: Text(
              '${value.toInt()}%',
              style: AppTextStyles.small,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}