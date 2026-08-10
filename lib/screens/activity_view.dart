// lib/screens/activity_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import 'parent/feedback_form.dart';

class ActivityView extends StatefulWidget {
  const ActivityView({super.key});

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _activity;
  String? _childId;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get child ID
      final childSnapshot = await _firestore
          .collection('children')
          .where('parentId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (childSnapshot.docs.isNotEmpty) {
        _childId = childSnapshot.docs.first.id;
      }

      // Fetch today's activity (or generate one)
      // For now, use a preset activity
      _activity = {
        'title': 'Animal Sounds Hunt',
        'skillType': 'Listening Skills',
        'duration': 10,
        'difficulty': 'Easy',
        'instructions': [
          'Play the animal sounds one by one.',
          'Ask your child: "Which animal makes this sound?"',
          'Encourage them to say the animal name out loud.',
          'Celebrate their effort! 🎉',
        ],
        'learningGoals': [
          'Recognize animal sounds',
          'Connect sounds to animals',
          'Build listening skills',
        ],
        'materials': ['Phone/tablet with animal sounds'],
      };
    } catch (e) {
      debugPrint('Error loading activity: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Activity', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activity == null
              ? _buildErrorState()
              : _buildActivityContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Activity Available',
              style: AppTextStyles.heading1,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Check back later for new activities!',
              style: AppTextStyles.bodyLight,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                ),
              ),
              child: Text('Back to Dashboard', style: AppTextStyles.button),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityContent() {
    final activity = _activity!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity Title
          Text(
            activity['title'] ?? 'Activity',
            style: AppTextStyles.heading1.copyWith(fontSize: 24),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Activity Meta Info
          Row(
            children: [
              _buildMetaChip(
                icon: Icons.access_time,
                label: '${activity['duration'] ?? 10} min',
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildMetaChip(
                icon: Icons.psychology,
                label: activity['skillType'] ?? 'Skill Building',
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildMetaChip(
                icon: Icons.star,
                label: activity['difficulty'] ?? 'Medium',
                color: activity['difficulty'] == 'Easy'
                    ? AppColors.success
                    : activity['difficulty'] == 'Medium'
                        ? AppColors.primary
                        : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Instructions Section
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
                Text(
                  '📝 Instructions for Parent',
                  style: AppTextStyles.heading2.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.md),
                ...List.generate(
                  (activity['instructions'] as List).length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTextStyles.small.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            activity['instructions'][index],
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Learning Goals
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
                Text(
                  '🎯 What Your Child Will Learn',
                  style: AppTextStyles.heading2.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...(activity['learningGoals'] as List).map((goal) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: AppColors.success),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            goal,
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Materials
          if (activity['materials'] != null)
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
                  Text(
                    '📦 Materials Needed',
                  style: AppTextStyles.heading2.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...(activity['materials'] as List).map((material) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            material,
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Start Activity Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeedbackForm(
                      childId: _childId ?? '',
                      activityId: 'preset_001', // TODO: Use real activity ID
                      activityTitle: activity['title'] ?? 'Activity',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow, size: 28),
              label: Text(
                'I\'ve Completed This Activity',
                style: AppTextStyles.button.copyWith(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                ),
              ),
              child: Text(
                'Back to Dashboard',
                style: AppTextStyles.body.copyWith(color: AppColors.textLight),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (color ?? AppColors.primary).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: color ?? AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}