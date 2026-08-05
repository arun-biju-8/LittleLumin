// lib/screens/parent/parent_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';
import '../auth/login_page.dart';
import '../activity_view.dart';
import 'add_child_page.dart';
import 'edit_child_page.dart';
import 'profile_page.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isDeleting = false;
  Map<String, dynamic>? _childData;
  Map<String, dynamic>? _skillData;
  String _childName = '';
  int _childAge = 0;
  int _stars = 0;
  int _streak = 0;
  double _overallProgress = 0.0;
  Map<String, double> _skills = {};
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchChildData();
  }

  Future<void> _fetchChildData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _navigateToLogin();
        return;
      }

      final QuerySnapshot childSnapshot = await _firestore
          .collection('children')
          .where('parentId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (childSnapshot.docs.isNotEmpty) {
        final childDoc = childSnapshot.docs.first;
        _childData = childDoc.data() as Map<String, dynamic>;
        _childName = _childData?['name'] ?? 'Child';
        _childAge = _childData?['age'] ?? 0;

        final skillDoc = await _firestore
            .collection('skillProfiles')
            .doc(childDoc.id)
            .get();

        if (skillDoc.exists) {
          _skillData = skillDoc.data() as Map<String, dynamic>;
          _skills = {
            'Cognitive': _skillData?['cognitive']?.toDouble() ?? 0.0,
            'Language': _skillData?['language']?.toDouble() ?? 0.0,
            'Motor': _skillData?['motor']?.toDouble() ?? 0.0,
            'Social': _skillData?['social']?.toDouble() ?? 0.0,
            'Emotional': _skillData?['emotional']?.toDouble() ?? 0.0,
            'Creative': _skillData?['creative']?.toDouble() ?? 0.0,
          };
          _overallProgress = _skills.values.reduce((a, b) => a + b) / _skills.length;
        }

        final rewardsDoc = await _firestore
            .collection('rewards')
            .doc(childDoc.id)
            .get();

        if (rewardsDoc.exists) {
          final rewardsData = rewardsDoc.data() as Map<String, dynamic>;
          _stars = rewardsData['stars'] ?? 0;
          _streak = rewardsData['streak'] ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Error fetching child data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _confirmDelete(ChildModel child) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Child Profile?',
          style: TextStyle(color: Colors.red),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${child.name}\'s profile?',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This will permanently delete:',
              style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('• All activities for ${child.name}', style: AppTextStyles.small),
            Text('• All progress data', style: AppTextStyles.small),
            Text('• All feedback and history', style: AppTextStyles.small),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This action cannot be undone.',
              style: AppTextStyles.small.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isDeleting = true);

              final error = await ChildService().deleteChild(child.childId);

              setState(() => _isDeleting = false);

              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Child profile deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('LittleLumin', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: AppColors.textDark),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.textDark),
            onPressed: () async {
              await _auth.signOut();
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(
                    'Hello, ${user?.displayName ?? 'Parent'}!',
                    style: AppTextStyles.heading1,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Let\'s make today a great day for your child',
                    style: AppTextStyles.bodyLight,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ✅ Children List with Delete Option
                  StreamBuilder<List<ChildModel>>(
                    stream: ChildService().getChildren(),
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
                            children: [
                              const SizedBox(height: AppSpacing.lg),
                              Icon(Icons.child_care, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No child added yet',
                                style: AppTextStyles.bodyLight,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const AddChildPage()),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add Child'),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: children.length,
                        itemBuilder: (context, index) {
                          final child = children[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ListTile(
                              leading: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: CircularProgressIndicator(
                                      value: child.profileCompletion / 100,
                                      strokeWidth: 4,
                                      backgroundColor: Colors.grey[200],
                                      color: child.profileCompletion >= 80
                                          ? AppColors.success
                                          : child.profileCompletion >= 50
                                              ? AppColors.primary
                                              : AppColors.warning,
                                    ),
                                  ),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Text(
                                      child.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      child.name,
                                      style: AppTextStyles.body
                                          .copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (child.isFlagged)
                                    const Icon(Icons.flag, color: Colors.red, size: 16),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${child.age} years • ${child.gender}'),
                                  if (child.profileCompletion < 100)
                                    Text(
                                      '${child.profileCompletion}% profile complete',
                                      style: AppTextStyles.small.copyWith(
                                        color: child.profileCompletion >= 80
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                                onSelected: (value) async {
                                  if (value == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditChildPage(child: child),
                                      ),
                                    ).then((updated) {
                                      if (updated == true) setState(() {});
                                    });
                                  } else if (value == 'delete') {
                                    _confirmDelete(child);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18,
                                            color: AppColors.primary),
                                        SizedBox(width: 8),
                                        Text('Edit Profile'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18,
                                            color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete Child',
                                            style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditChildPage(child: child),
                                  ),
                                ).then((updated) {
                                  if (updated == true) {
                                    setState(() {});
                                  }
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Child Profile Card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.white,
                          child: Text(
                            _childName.isNotEmpty ? _childName[0].toUpperCase() : '👶',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _childName,
                                style: AppTextStyles.heading2.copyWith(
                                  color: AppColors.white,
                                  fontSize: 20,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(Icons.cake, size: 14, color: AppColors.white),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '$_childAge years',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(Icons.local_fire_department, size: 14,
                                      color: AppColors.white),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '$_streak day streak',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(Icons.star, size: 14, color: AppColors.accent),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '$_stars stars',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Overall Progress
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📊 Overall Progress', style: AppTextStyles.heading2),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: _overallProgress / 100,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey[200],
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${_overallProgress.toStringAsFixed(0)}%',
                              style: AppTextStyles.heading2,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Keep going! You\'re doing great! 🎉',
                          style: AppTextStyles.bodyLight,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Today's Activity
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🌟 Today\'s Activity', style: AppTextStyles.heading2),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Animal Sounds Hunt',
                          style: AppTextStyles.heading1.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: AppColors.textLight),
                            const SizedBox(width: AppSpacing.xs),
                            Text('10 min', style: AppTextStyles.small),
                            const SizedBox(width: AppSpacing.md),
                            Icon(Icons.psychology, size: 16, color: AppColors.textLight),
                            const SizedBox(width: AppSpacing.xs),
                            Text('Listening Skills', style: AppTextStyles.small),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ActivityView()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppBorderRadius.medium),
                              ),
                            ),
                            child: Text(
                              'Start Activity',
                              style: AppTextStyles.button,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Skill Progress
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📈 Skill Progress', style: AppTextStyles.heading2),
                        const SizedBox(height: AppSpacing.md),
                        if (_skills.isNotEmpty)
                          ..._skills.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _buildSkillBar(
                                entry.key,
                                entry.value / 100,
                                _getColorForSkill(entry.key),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        onTap: (index) {
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfilePage(),
              ),
            );
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle),
            label: 'Activities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSkillBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: AppTextStyles.small),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: color,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).toInt()}%',
            style: AppTextStyles.small,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getColorForSkill(String skill) {
    switch (skill) {
      case 'Cognitive':
        return Colors.blue;
      case 'Language':
        return Colors.purple;
      case 'Motor':
        return Colors.orange;
      case 'Social':
        return Colors.green;
      case 'Emotional':
        return Colors.pink;
      case 'Creative':
        return Colors.amber;
      default:
        return AppColors.primary;
    }
  }
}