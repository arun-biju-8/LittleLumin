// lib/screens/parent_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import 'login_page.dart';
import 'activity_view.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _childData;
  Map<String, dynamic>? _skillData;
  String _childName = '';
  int _childAge = 0;
  int _stars = 0;
  int _streak = 0;
  double _overallProgress = 0.0;
  Map<String, double> _skills = {};

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

      // Fetch child data
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

        // Fetch skill profile
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

        // Fetch rewards
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
                                  Icon(Icons.local_fire_department, size: 14, color: AppColors.white),
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
                                MaterialPageRoute(builder: (_) => const ActivityView()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
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
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: 'Activities'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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