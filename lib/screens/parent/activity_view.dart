// lib/screens/parent/activity_view.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/activity_video_player.dart';
import '../llg/add_activity_page.dart';
import 'feedback_form.dart';
import '../../services/journey_service.dart';

class ActivityView extends StatefulWidget {
  final ActivityModel? activity;
  final String? activityId;
  final String? childId;
  final String? userRole; // Optional explicit role override ('parent', 'admin', 'llg')

  const ActivityView({
    super.key,
    this.activity,
    this.activityId,
    this.childId,
    this.userRole,
  });

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityService _activityService = ActivityService();
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  ActivityModel? _activity;
  String? _resolvedChildId;
  String _userRole = 'parent';

  bool get _isAdminOrLlg => _userRole == 'admin' || _userRole == 'llg';

  @override
  void initState() {
    super.initState();
    _resolvedChildId = widget.childId;
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);
    int? childAge;

    try {
      // Determine user role
      if (widget.userRole != null && widget.userRole!.trim().isNotEmpty) {
        _userRole = widget.userRole!.trim().toLowerCase();
      } else {
        final user = _auth.currentUser;
        if (user != null) {
          final role = await _authService.getUserRole(user.uid);
          if (role != null && role.isNotEmpty) {
            _userRole = role.toLowerCase();
          }
        }
      }

      // Load Activity Model
      if (widget.activity != null) {
        _activity = widget.activity;
      } else if (widget.activityId != null) {
        _activity = await _activityService.getActivity(widget.activityId!);
      }

      // Resolve childId & age if not passed (for parent context)
      if (!_isAdminOrLlg) {
        final user = _auth.currentUser;
        if (user != null) {
          if (_resolvedChildId != null && _resolvedChildId!.isNotEmpty) {
            final childDoc = await _firestore.collection('children').doc(_resolvedChildId).get();
            if (childDoc.exists && childDoc.data() != null) {
              childAge = (childDoc.data()!['age'] as num?)?.toInt();
            }
          } else {
            final childSnapshot = await _firestore
                .collection('children')
                .where('parentId', isEqualTo: user.uid)
                .limit(1)
                .get();

            if (childSnapshot.docs.isNotEmpty) {
              final childDoc = childSnapshot.docs.first;
              _resolvedChildId = childDoc.id;
              childAge = (childDoc.data()['age'] as num?)?.toInt();
            }
          }
        }
      }

      // If still no activity, try loading today's activity for parent
      if (_activity == null && _resolvedChildId != null && !_isAdminOrLlg) {
        _activity = await _activityService.getTodayActivity(_resolvedChildId!);
      }

      // Default fallback activity if database is empty
      _activity ??= ActivityModel(
        id: 'preset_001',
        title: 'Animal Sounds Hunt',
        skillType: 'Listening',
        difficulty: 'Easy',
        ageGroup: [3, 4],
        duration: 10,
        instructions: [
          'Play animal sounds one by one.',
          'Ask your child: "Which animal makes this sound?"',
          'Encourage them to say the animal name out loud.',
          'Celebrate their effort enthusiastically! 🎉',
        ],
        learningGoals: [
          'Recognize animal sounds',
          'Connect sounds to mental imagery',
          'Build active listening skills',
        ],
        materials: ['Phone/tablet with animal sounds'],
        videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-mother-and-child-playing-with-blocks-41544-large.mp4',
        videoDuration: '1:45',
        createdAt: DateTime.now(),
      );

      // Register active activity in Journey for parent context
      if (!_isAdminOrLlg && _resolvedChildId != null && _activity != null && _activity!.id != null) {
        final journeyService = JourneyService();
        final journey = await journeyService.getOrInitializeJourney(_resolvedChildId!);
        await journeyService.startActivity(
          childId: _resolvedChildId!,
          activityId: _activity!.id!,
          activityTitle: _activity!.title,
          level: journey.currentLevel,
        );
      }
    } catch (e) {
      debugPrint('Error loading activity view: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (childAge != null) {
          _checkAndShowAgeWarning(childAge);
        }
      }
    }
  }

  void _checkAndShowAgeWarning(int childAge) {
    if (childAge < 3 && (_activity != null && !_activity!.ageGroup.any((g) => g < 3))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Age Guidance Warning',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              'These activities are designed for children aged 3-6. Your child is $childAge years old. Some activities may not be suitable.',
              style: AppTextStyles.body.copyWith(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(this.context);
                },
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  ),
                ),
                child: const Text('View Anyway'),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _navigateToEdit() async {
    if (_activity == null) return;

    final user = _auth.currentUser;
    final uid = user?.uid ?? '';
    final userRole = await _authService.getUserRole(uid);

    if (_activity!.isPreset && userRole != 'admin') {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('✏️', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Adapt Preset Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  'You are about to edit LittleLumin\'s preset activity "${_activity!.title}".',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Saving changes will create a new custom copy in your curriculum library with your adaptations while preserving the original preset.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Proceed to Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddActivityPage(
          activity: _activity,
          onSuccess: () => _loadActivity(),
        ),
      ),
    ).then((_) => _loadActivity());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _activity?.title ?? 'Activity Details',
          style: AppTextStyles.heading2,
        ),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isAdminOrLlg && _activity != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
                tooltip: 'Edit Activity',
                onPressed: _navigateToEdit,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activity == null
              ? _buildErrorState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 600;
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? AppSpacing.lg : AppSpacing.md,
                        vertical: AppSpacing.lg,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _buildActivityCard(isDesktop),
                        ),
                      ),
                    );
                  },
                ),
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
            Text('No Activity Available', style: AppTextStyles.heading1),
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
              child: Text(
                _isAdminOrLlg ? 'Back to Library' : 'Back to Dashboard',
                style: AppTextStyles.button,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(bool isDesktop) {
    final activity = _activity!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.large),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isDesktop ? AppSpacing.xl : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row (Category + Preset/Admin status)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activity.category.isNotEmpty ? activity.category : '${activity.skillType} Skills',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Row(
                children: [
                  if (activity.isPreset)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Preset',
                        style: AppTextStyles.small.copyWith(
                          color: Colors.purple[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_isAdminOrLlg)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: activity.isActive
                            ? AppColors.success.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: activity.isActive
                              ? AppColors.success.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        activity.isActive ? 'Active' : 'Inactive',
                        style: AppTextStyles.small.copyWith(
                          color: activity.isActive ? AppColors.success : Colors.orange[800],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            activity.title,
            style: AppTextStyles.heading1.copyWith(
              fontSize: isDesktop ? 28 : 22,
              height: 1.2,
            ),
          ),
          if (activity.isEditedFromPreset && activity.originalTitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                '📌 Adapted from LittleLumin\'s ${activity.originalTitle}',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Meta Info Chips Row
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _buildMetaChip(
                icon: Icons.access_time,
                label: '${activity.duration} min',
              ),
              _buildMetaChip(
                icon: Icons.psychology,
                label: activity.skillType,
              ),
              _buildMetaChip(
                icon: Icons.star,
                label: '${activity.difficultyIcon} ${activity.difficulty}',
                color: activity.difficulty == 'Easy'
                    ? AppColors.success
                    : activity.difficulty == 'Medium'
                        ? AppColors.primary
                        : AppColors.warning,
              ),
              _buildMetaChip(
                icon: Icons.child_care,
                label: activity.ageGroupDisplay,
                color: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),

          // Demo Video Player Widget (If available)
          if (activity.hasVideo) ...[
            Text(
              '🎥 Demonstration Video',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.sm),
            ActivityVideoPlayer(
              videoUrl: activity.videoUrl!,
              videoThumbnail: activity.videoThumbnail,
              videoDuration: activity.videoDuration,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Instructions Section
          Text(
            _isAdminOrLlg ? '📝 Activity Instructions' : '📝 Instructions for Parent',
            style: AppTextStyles.heading2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
            activity.instructions.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
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
                      activity.instructions[index],
                      style: AppTextStyles.body.copyWith(height: 1.5, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),

          // Learning Goals Section
          Text(
            '🎯 Learning Goals & Outcomes',
            style: AppTextStyles.heading2.copyWith(fontSize: 18),
          ),
          const SizedBox(height: AppSpacing.md),
          ...activity.learningGoals.map((goal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, size: 20, color: AppColors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      goal,
                      style: AppTextStyles.body.copyWith(height: 1.4, fontSize: 15),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // Materials Needed Section
          if (activity.materials.isNotEmpty) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '📦 Materials Needed',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.md),
            ...activity.materials.map((material) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      material,
                      style: AppTextStyles.body.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Admin & LLG Metadata Info Panel
          if (_isAdminOrLlg) ...[
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 20, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Admin & System Info',
                        style: AppTextStyles.heading2.copyWith(fontSize: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildAdminInfoRow('Created By Name:', activity.createdByName),
                  _buildAdminInfoRow('Created By ID:', activity.createdBy.isEmpty ? 'System' : activity.createdBy),
                  _buildAdminInfoRow('Preset Activity:', activity.isPreset ? 'Yes (System Default)' : 'No (Custom)'),
                  _buildAdminInfoRow('Tags:', activity.tags.isEmpty ? 'None' : activity.tags.join(', ')),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Action Buttons Section
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.lg),
          _buildActionButtons(isDesktop),
        ],
      ),
    );
  }

  Widget _buildAdminInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.small.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.small.copyWith(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDesktop) {
    final activity = _activity!;

    if (_isAdminOrLlg) {
      final editBtn = SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _navigateToEdit,
          icon: const Icon(Icons.edit, size: 20),
          label: Text(
            'Edit Activity',
            style: AppTextStyles.button.copyWith(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
          ),
        ),
      );

      final backBtn = SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 20),
          label: Text(
            'Back to Library',
            style: AppTextStyles.body.copyWith(
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
          ),
        ),
      );

      if (isDesktop) {
        return Row(
          children: [
            Expanded(child: editBtn),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: backBtn),
          ],
        );
      } else {
        return Column(
          children: [
            SizedBox(width: double.infinity, child: editBtn),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(width: double.infinity, child: backBtn),
          ],
        );
      }
    } else {
      // Parent Role Buttons
      final completeBtn = SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FeedbackForm(
                  childId: _resolvedChildId ?? '',
                  activityId: activity.id ?? 'preset_001',
                  activityTitle: activity.title,
                ),
              ),
            );
          },
          icon: const Icon(Icons.check_circle_outline, size: 22),
          label: Text(
            "I've Completed This Activity",
            style: AppTextStyles.button.copyWith(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
          ),
        ),
      );

      final backBtn = SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 20),
          label: Text(
            'Back to Dashboard',
            style: AppTextStyles.body.copyWith(color: AppColors.textLight),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
          ),
        ),
      );

      if (isDesktop) {
        return Row(
          children: [
            Expanded(flex: 3, child: completeBtn),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 2, child: backBtn),
          ],
        );
      } else {
        return Column(
          children: [
            SizedBox(width: double.infinity, child: completeBtn),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(width: double.infinity, child: backBtn),
          ],
        );
      }
    }
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: chipColor.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

