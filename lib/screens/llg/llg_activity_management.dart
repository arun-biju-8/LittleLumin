// lib/screens/llg/llg_activity_management.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/activity_seeder.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/activity_search_filters.dart';
import 'add_activity_page.dart';
import '../parent/activity_view.dart';

class LLGActivityManagement extends StatefulWidget {
  const LLGActivityManagement({super.key});

  @override
  State<LLGActivityManagement> createState() => _LLGActivityManagementState();
}

class _LLGActivityManagementState extends State<LLGActivityManagement> {
  final ActivityService _activityService = ActivityService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';
  String _selectedSkill = 'All';
  String _selectedDifficulty = 'All';
  int _selectedAgeGroup = 0;
  bool _filterMyActivitiesOnly = false;
  bool _isGridView = false; // Default List View (ultra-compact, ~72px height)

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedSkill = 'All';
      _selectedDifficulty = 'All';
      _selectedAgeGroup = 0;
      _filterMyActivitiesOnly = false;
    });
  }

  void _confirmDelete(ActivityModel activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: Text('Are you sure you want to delete "${activity.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (activity.id != null) {
                final success = await _activityService.deleteActivity(activity.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '✅ Activity deleted successfully.'
                            : 'Error deleting activity.',
                      ),
                      backgroundColor: success ? AppColors.success : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LLG Activity Management', style: AppTextStyles.heading1),
                const SizedBox(height: 2),
                Text(
                  'Manage curriculum activities and video guides.',
                  style: AppTextStyles.bodyLight.copyWith(fontSize: 13),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // View Mode Toggle (Grid vs List)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.grid_view, size: 18),
                        color: _isGridView ? AppColors.white : Colors.grey[700],
                        style: IconButton.styleFrom(
                          backgroundColor: _isGridView ? AppColors.primary : Colors.transparent,
                          minimumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        tooltip: 'Grid View',
                        onPressed: () => setState(() => _isGridView = true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.view_list, size: 18),
                        color: !_isGridView ? AppColors.white : Colors.grey[700],
                        style: IconButton.styleFrom(
                          backgroundColor: !_isGridView ? AppColors.primary : Colors.transparent,
                          minimumSize: const Size(34, 34),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        tooltip: 'List View',
                        onPressed: () => setState(() => _isGridView = false),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddActivityPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Activity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Live Stats Summary Banner
        StreamBuilder<List<ActivityModel>>(
          stream: _activityService.getAllActivities(),
          builder: (context, snapshot) {
            final all = snapshot.data ?? [];
            final myActivities = all.where((a) => a.createdBy == currentUserId).toList();
            final activeCount = all.where((a) => a.isActive).length;

            return Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _buildStatItem('Total Library', '${all.length}', Icons.auto_stories),
                  _buildStatDivider(),
                  _buildStatItem('Active Now', '$activeCount', Icons.check_circle_outline),
                  _buildStatDivider(),
                  _buildStatItem('Created by Me', '${myActivities.length}', Icons.person_pin),
                ],
              ),
            );
          },
        ),

        // Toggle "My Created Activities Only" vs "All Activities"
        Row(
          children: [
            ChoiceChip(
              label: const Text('All Activities'),
              selected: !_filterMyActivitiesOnly,
              onSelected: (val) {
                if (val) setState(() => _filterMyActivitiesOnly = false);
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Created by Me'),
              selected: _filterMyActivitiesOnly,
              onSelected: (val) {
                if (val) setState(() => _filterMyActivitiesOnly = true);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Search & Filter Component
        ActivitySearchFilters(
          searchQuery: _searchQuery,
          selectedSkill: _selectedSkill,
          selectedDifficulty: _selectedDifficulty,
          selectedAgeGroup: _selectedAgeGroup,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          onSkillChanged: (s) => setState(() => _selectedSkill = s ?? 'All'),
          onDifficultyChanged: (d) => setState(() => _selectedDifficulty = d ?? 'All'),
          onAgeGroupChanged: (a) => setState(() => _selectedAgeGroup = a ?? 0),
          onClearFilters: _clearFilters,
        ),

        // Activities List/Grid Stream
        Expanded(
          child: StreamBuilder<List<ActivityModel>>(
            stream: _activityService.getFilteredActivities(
              searchQuery: _searchQuery,
              skillType: _selectedSkill,
              difficulty: _selectedDifficulty,
              ageGroup: _selectedAgeGroup,
              createdBy: _filterMyActivitiesOnly ? currentUserId : null,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No activities found.', style: AppTextStyles.heading2),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Click "Add Activity" to create your first activity or clear filters.',
                        style: AppTextStyles.bodyLight,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await ActivitySeeder.seedPresetActivities(force: true);
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Seed Sample Preset Activities'),
                      ),
                    ],
                  ),
                );
              }

              final activeCount = activities.where((a) => a.isActive).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // List Header Stats
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${activities.length} activities · $activeCount active',
                          style: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          _isGridView ? 'Grid View' : 'List View',
                          style: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Activities Grid or List Content
                  Expanded(
                    child: _isGridView
                        ? _buildGridView(activities)
                        : _buildListView(activities),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(List<ActivityModel> activities) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 4;
        if (width <= 600) {
          crossAxisCount = 2;
        } else if (width <= 900) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: crossAxisCount == 2 ? 1.45 : 1.6,
          ),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final canDelete = !activity.isPreset && (activity.createdBy == currentUserId || currentUserId.isEmpty);

            return ActivityCard(
              activity: activity,
              compact: true,
              showAdminControls: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityView(activity: activity, userRole: 'llg'),
                  ),
                );
              },
              onEdit: () => _handleEditActivity(activity),
              onDelete: canDelete ? () => _confirmDelete(activity) : null,
              onToggleStatus: () async {
                if (activity.id != null) {
                  await _activityService.toggleActivityStatus(activity.id!);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildListView(List<ActivityModel> activities) {
    final currentUserId = _auth.currentUser?.uid ?? '';

    return ListView.builder(
      itemCount: activities.length,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemBuilder: (context, index) {
        final activity = activities[index];
        final canDelete = !activity.isPreset && (activity.createdBy == currentUserId || currentUserId.isEmpty);

        return ActivityCard(
          activity: activity,
          compact: false,
          showAdminControls: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityView(activity: activity, userRole: 'llg'),
              ),
            );
          },
          onEdit: () => _handleEditActivity(activity),
          onDelete: canDelete ? () => _confirmDelete(activity) : null,
          onToggleStatus: () async {
            if (activity.id != null) {
              await _activityService.toggleActivityStatus(activity.id!);
            }
          },
        );
      },
    );
  }

  Future<void> _handleEditActivity(ActivityModel activity) async {
    final user = _auth.currentUser;
    final uid = user?.uid ?? '';
    final userRole = await _authService.getUserRole(uid);

    if (activity.isPreset && userRole != 'admin') {
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
                  'You are about to edit LittleLumin\'s preset activity "${activity.title}".',
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
        builder: (_) => AddActivityPage(activity: activity),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }
}
