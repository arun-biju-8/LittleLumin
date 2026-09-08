// lib/screens/parent/parent_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../services/child_service.dart';
import '../../models/child_model.dart';
import '../../services/tip_service.dart';
import '../../services/reward_service.dart';
import '../../models/milestone_model.dart';
import '../../services/milestone_service.dart';
import '../auth/login_page.dart';
import '../landing_page.dart';
import 'add_child_page.dart';
import 'edit_child_page.dart';
import 'profile_page.dart';
import 'parent_activities_tab.dart';
import 'journey_view.dart';
import 'activity_view.dart';
import 'feedback_form.dart';
import '../../services/journey_service.dart';
import '../../models/journey_model.dart';
import '../../widgets/journey_card.dart';
import '../../widgets/active_activity_banner.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  int _selectedIndex = 0;

  Map<String, dynamic>? _skillData;
  double _overallProgress = 0.0;
  Map<String, double> _skills = {
    'Cognitive': 75.0,
    'Language': 80.0,
    'Motor': 65.0,
    'Social': 55.0,
    'Emotional': 45.0,
    'Creative': 70.0,
  };

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

        final skillDoc = await _firestore
            .collection('skillProfiles')
            .doc(childDoc.id)
            .get();

        if (skillDoc.exists) {
          _skillData = skillDoc.data() as Map<String, dynamic>;
          _skills = {
            'Cognitive': _skillData?['cognitive']?.toDouble() ?? 75.0,
            'Language': _skillData?['language']?.toDouble() ?? 80.0,
            'Motor': _skillData?['motor']?.toDouble() ?? 65.0,
            'Social': _skillData?['social']?.toDouble() ?? 55.0,
            'Emotional': _skillData?['emotional']?.toDouble() ?? 45.0,
            'Creative': _skillData?['creative']?.toDouble() ?? 70.0,
          };
        }

        _overallProgress =
            _skills.values.reduce((a, b) => a + b) / _skills.length;
      }
    } catch (e) {
      debugPrint('Error fetching child data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToLogin() {
    if (!mounted) return;
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
              setState(() => _isLoading = true);

              final error = await ChildService().deleteChild(child.childId);

              if (!mounted) return;
              setState(() => _isLoading = false);

              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Child profile deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
                _fetchChildData();
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

  void _showAllBadgesDialog(Map<String, dynamic> rewards) {
    final List<dynamic> badges = rewards['badges'] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        ),
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('All Badges & Rewards', style: AppTextStyles.heading2),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadgeTile(
                icon: '🏅',
                title: 'First Activity',
                subtitle: 'Completed 1st learning task',
                isUnlocked: badges.contains('First Activity'),
              ),
              _buildBadgeTile(
                icon: '🏅',
                title: '5 Activities Completed',
                subtitle: 'Completed 5 learning tasks',
                isUnlocked: badges.contains('5 Activities'),
              ),
              _buildBadgeTile(
                icon: '🔥',
                title: '7 Day Streak Master',
                subtitle: 'Active 7 days in a row',
                isUnlocked: badges.contains('Streak Master'),
              ),
              _buildBadgeTile(
                icon: '⭐',
                title: 'Star Collector',
                subtitle: 'Earned 40+ stars',
                isUnlocked: badges.contains('Star Collector'),
              ),
              _buildBadgeTile(
                icon: '🧠',
                title: 'Cognitive Explorer',
                subtitle: 'Reach 80% Cognitive score',
                isUnlocked: badges.contains('Cognitive Explorer'),
              ),
              _buildBadgeTile(
                icon: '❤️',
                title: 'Parent Partner',
                subtitle: 'Complete 10 parent-guided sessions',
                isUnlocked: badges.contains('Parent Partner'),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
              ),
            ),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTile({
    required String icon,
    required String title,
    required String subtitle,
    required bool isUnlocked,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUnlocked ? AppColors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        border: Border.all(
          color: isUnlocked ? AppColors.accent : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style: TextStyle(
              fontSize: 24,
              color: isUnlocked ? null : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? AppColors.textDark : Colors.grey[600],
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.small.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isUnlocked ? Icons.check_circle : Icons.lock_outline,
            color: isUnlocked ? AppColors.success : Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              await _auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LandingPageWidget()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Logout',
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
    final parentName = user?.displayName ?? 'Parent';

    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex == 0) {
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit App?'),
              content: const Text('Press "Exit" to close the app.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Exit', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
          return false;
        }
        setState(() => _selectedIndex = 0);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('LittleLumin', style: AppTextStyles.heading2),
          backgroundColor: AppColors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.textDark),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.textDark),
              onPressed: _confirmLogout,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<ChildModel>>(
                stream: ChildService().getChildren(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final children = snapshot.data ?? [];
                  final bool hasChild = children.isNotEmpty;
                  final ChildModel? activeChild = hasChild ? children.first : null;

                  final effectiveIndex = hasChild
                      ? _selectedIndex.clamp(0, 3)
                      : (_selectedIndex > 0 ? 1 : 0);

                  return _buildBodyForTab(
                    context: context,
                    parentName: parentName,
                    hasChild: hasChild,
                    children: children,
                    activeChild: activeChild,
                    tabIndex: effectiveIndex,
                  );
                },
              ),
        bottomNavigationBar: StreamBuilder<List<ChildModel>>(
          stream: ChildService().getChildren(),
          builder: (context, snapshot) {
            final children = snapshot.data ?? [];
            final bool hasChild = children.isNotEmpty;

            return BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: hasChild
                  ? _selectedIndex.clamp(0, 3)
                  : (_selectedIndex > 0 ? 1 : 0),
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textLight,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                if (hasChild)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.bar_chart),
                    label: 'Progress',
                  ),
                if (hasChild)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.play_circle),
                    label: 'Activities',
                  ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBodyForTab({
    required BuildContext context,
    required String parentName,
    required bool hasChild,
    required List<ChildModel> children,
    required ChildModel? activeChild,
    required int tabIndex,
  }) {
    if (!hasChild) {
      if (tabIndex == 1) {
        return const ProfilePage();
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: _buildWelcomeOnboardingView(context, parentName),
      );
    }

    switch (tabIndex) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: _buildHomeDailyChallengesView(context, parentName, children, activeChild!),
        );
      case 1:
        return RefreshIndicator(
          onRefresh: _fetchChildData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _buildProgressTabView(context, activeChild!),
          ),
        );
      case 2:
        return ParentActivitiesTab(activeChild: activeChild!);
      case 3:
      default:
        return const ProfilePage();
    }
  }

  // ===========================================================================
  // 1A. WELCOME / ONBOARDING VIEW
  // ===========================================================================

  Widget _buildWelcomeOnboardingView(BuildContext context, String parentName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('👋 Hello, $parentName!', style: AppTextStyles.heading1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Let\'s start your parenting journey',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.lg),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🌟 Welcome to LittleLumin!',
                style: AppTextStyles.heading1.copyWith(
                  color: AppColors.white,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Every child\'s journey is unique. Let\'s get started by adding your child to create their personalized learning path.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.white.withValues(alpha: 0.95),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildBenefitRow('✅', 'Personalized activities for your child\'s age & skills'),
              const SizedBox(height: AppSpacing.xs),
              _buildBenefitRow('📊', 'Track developmental progress across 6 domains'),
              const SizedBox(height: AppSpacing.xs),
              _buildBenefitRow('📱', 'Screen-free, parent-guided activities'),
              const SizedBox(height: AppSpacing.xs),
              _buildBenefitRow('🤖', 'AI-powered recommendations that grow with your child'),
              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddChildPage()),
                    );
                  },
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  label: Text(
                    'Add Your Child',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text(
          'Why Parents Love LittleLumin',
          style: AppTextStyles.heading2,
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 1.3 : 1.05,
              children: [
                _buildFeatureCard(
                  icon: '🧠',
                  title: 'Screen-Free Learning',
                  description: 'Hands-on activities built for real-world parent-child play.',
                ),
                _buildFeatureCard(
                  icon: '📊',
                  title: 'Progress Tracking',
                  description: 'Clear visual insights into developmental milestones.',
                ),
                _buildFeatureCard(
                  icon: '🤖',
                  title: 'AI-Powered Guidance',
                  description: 'Smart recommendations tailored to your child\'s pace.',
                ),
                _buildFeatureCard(
                  icon: '❤️',
                  title: 'Parent Support',
                  description: 'Expert guidance to support your nurturing journey.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildBenefitRow(String icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: AppColors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTextStyles.small.copyWith(
              color: AppColors.textLight,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeGuidanceBanner(ChildModel child) {
    if (child.age >= 3 && child.age <= 6) {
      return const SizedBox.shrink();
    }

    final isUnder3 = child.age < 3;
    final emoji = isUnder3 ? '🌱' : '🌟';
    final title = isUnder3
        ? '🌱 Your Little One is Growing!'
        : 'Your child is ready for new adventures! 🌟';
    final message = isUnder3
        ? 'LittleLumin is designed for ages 3-6. Here are some gentle activities you can try today.'
        : 'LittleLumin activities are optimized for ages 3–6. Your child is thriving into big kid milestones!';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isUnder3 ? Colors.purple[50] : Colors.amber[50],
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: isUnder3 ? Colors.purple[200]! : Colors.amber[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUnder3 ? Colors.purple[900] : Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.small.copyWith(
                    color: isUnder3 ? Colors.purple[800] : Colors.amber[900],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1B. HOME TAB (DAILY CHALLENGES VIEW)
  // ===========================================================================

  Widget _buildHomeDailyChallengesView(
    BuildContext context,
    String parentName,
    List<ChildModel> children,
    ChildModel activeChild,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('👋 Hello, $parentName!', style: AppTextStyles.heading1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Let\'s make today great for ${activeChild.name}! 🎉',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.md),

        _buildAgeGuidanceBanner(activeChild),
        _buildChildListCard(context, children),
        const SizedBox(height: AppSpacing.md),

        // Journey Section Stream (Active Activity Banner & Your Journey Card)
        StreamBuilder<JourneyProgress?>(
          stream: JourneyService().getJourneyProgress(activeChild.childId),
          builder: (context, snapshot) {
            final journey = snapshot.data;
            final activeActivity = journey?.activeActivity;

            return Column(
              children: [
                if (activeActivity != null) ...[
                  ActiveActivityBanner(
                    activeActivity: activeActivity,
                    onTapComplete: () {
                      if (activeActivity.isCompleted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedbackForm(
                              childId: activeChild.childId,
                              activityId: activeActivity.activityId,
                              activityTitle: activeActivity.activityTitle,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityView(
                              activityId: activeActivity.activityId,
                              childId: activeChild.childId,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                JourneyCard(
                  journeyProgress: journey ??
                      JourneyProgress(
                        childId: activeChild.childId,
                        currentLevel: 1,
                        levelProgress: {
                          1: LevelProgress(completed: [], total: 6, isUnlocked: true, activityIds: []),
                        },
                      ),
                  onTapContinue: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JourneyViewScreen(activeChild: activeChild),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // AI Activity & Story Generator Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90D9), Color(0xFF6C5CE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Activity & Story Generator ✨',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generate custom screen-free activities & stories for ${activeChild.name}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/ai-generator');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Try Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Today's Challenge Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.deepOrange, Colors.orangeAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🌟 Today\'s Challenge',
                    style: AppTextStyles.heading2.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'DAILY',
                      style: AppTextStyles.small.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '🎯 Complete 2 activities today',
                style: AppTextStyles.heading1.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '⭐ Reward: 10 bonus stars',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                    elevation: 1,
                  ),
                  child: Text(
                    'Start Challenge',
                    style: AppTextStyles.button.copyWith(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Rewards Card from Firestore
        _buildRewards(activeChild.childId),
        const SizedBox(height: AppSpacing.md),

        // Quick Actions
        Text('⚡ Quick Actions', style: AppTextStyles.heading2),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.play_circle_fill,
                label: 'View Activities',
                color: AppColors.primary,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.bar_chart,
                label: 'View Progress',
                color: Colors.purple,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.edit,
                label: 'Edit Child',
                color: AppColors.secondary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditChildPage(child: activeChild),
                    ),
                  ).then((updated) {
                    if (updated == true) _fetchChildData();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Tip of the Day from Firestore
        _buildTipOfTheDay(),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildChildListCard(BuildContext context, List<ChildModel> children) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          ),
          child: ListTile(
            leading: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
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
                  radius: 17,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    child.name.isNotEmpty ? child.name[0].toUpperCase() : '👶',
                    style: const TextStyle(
                      fontSize: 15,
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
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (child.isFlagged)
                  const Icon(Icons.flag, color: Colors.red, size: 16),
              ],
            ),
            subtitle: Text('${child.ageDisplay} • ${child.gender}'),
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
                    if (updated == true) _fetchChildData();
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
                      Icon(Icons.edit, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Edit Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Child', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewards(String childId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: RewardService().getRewards(childId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final rewards = snapshot.data ?? {'stars': 0, 'streak': 0, 'badges': []};
        final stars = rewards['stars'] ?? 0;
        final streak = rewards['streak'] ?? 0;
        final List<dynamic> badges = rewards['badges'] ?? [];

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🏆 Rewards & Achievements', style: AppTextStyles.heading2),
                  TextButton(
                    onPressed: () => _showAllBadgesDialog(rewards),
                    child: Text(
                      'View All',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildRewardStatBox(
                      icon: '⭐',
                      value: '$stars',
                      label: 'Total Stars',
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildRewardStatBox(
                      icon: '🔥',
                      value: '$streak Days',
                      label: 'Active Streak',
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Recent Badges:',
                style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              badges.isEmpty
                  ? Text('No badges unlocked yet. Start activities to earn badges!', style: AppTextStyles.small.copyWith(color: AppColors.textLight))
                  : Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: badges.map((b) => _buildBadgeChip('🏅 $b')).toList(),
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipOfTheDay() {
    return FutureBuilder<String>(
      future: TipService().getTipOfTheDay(),
      builder: (context, snapshot) {
        final tip = snapshot.data ?? 'Encourage your child with specific praise like "I love how hard you tried!"';

        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline, color: Colors.blue, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Tip of the Day',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip,
                      style: AppTextStyles.small.copyWith(
                        color: Colors.blue[800],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewardStatBox({
    required String icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.heading2.copyWith(fontSize: 16),
              ),
              Text(
                label,
                style: AppTextStyles.small.copyWith(
                  color: AppColors.textLight,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.small.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. PROGRESS TAB
  // ===========================================================================

  Widget _buildProgressTabView(BuildContext context, ChildModel activeChild) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📊 ${activeChild.name}\'s Progress', style: AppTextStyles.heading1),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Last updated: Today • Pull down to refresh',
          style: AppTextStyles.bodyLight,
        ),
        const SizedBox(height: AppSpacing.lg),

        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Overall Development', style: AppTextStyles.heading2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '▲ +5% this week',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_overallProgress / 100).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor: Colors.grey[200],
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${_overallProgress.toStringAsFixed(0)}%',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Great progress! ${activeChild.name} is excelling in Language & Cognitive skills! 🎉',
                style: AppTextStyles.bodyLight,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📈 Skill Domains Breakdown', style: AppTextStyles.heading2),
              const SizedBox(height: AppSpacing.md),
              ..._skills.entries.map((entry) {
                final percentage = entry.value;
                final color = percentage >= 70.0
                    ? AppColors.success
                    : (percentage >= 50.0 ? Colors.blue : AppColors.warning);

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${percentage.toInt()}%',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (percentage / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        _buildVabsMilestonesSection(activeChild),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildVabsMilestonesSection(ChildModel activeChild) {
    final milestoneService = MilestoneService();
    final milestones = milestoneService.getMilestonesForAge(activeChild.age);
    final achievedCount = milestones.where((m) => milestoneService.isMilestoneAchieved(_skills, m)).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🏅 VABS-II Milestones (${activeChild.age} yrs)', style: AppTextStyles.heading2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$achievedCount/${milestones.length} Achieved',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...milestones.map((milestone) {
            final isAchieved = milestoneService.isMilestoneAchieved(_skills, milestone);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildVabsMilestoneTile(milestone, isAchieved),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVabsMilestoneTile(MilestoneModel milestone, bool isAchieved) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isAchieved ? AppColors.success.withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        border: Border.all(
          color: isAchieved ? AppColors.success.withValues(alpha: 0.25) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Text(milestone.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      milestone.title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isAchieved ? AppColors.textDark : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        milestone.domain,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  milestone.description,
                  style: AppTextStyles.small.copyWith(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isAchieved ? Icons.check_circle : Icons.hourglass_empty,
            color: isAchieved ? AppColors.success : AppColors.warning,
            size: 20,
          ),
        ],
      ),
    );
  }





}