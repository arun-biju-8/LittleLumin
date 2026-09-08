// lib/screens/admin/admin_activity_management.dart
import 'package:flutter/material.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/activity_seeder.dart';
import '../../utils/constants.dart';
import '../../widgets/activity_card.dart';
import '../../widgets/activity_search_filters.dart';
import '../llg/add_activity_page.dart';
import '../parent/activity_view.dart';

class AdminActivityManagement extends StatefulWidget {
  const AdminActivityManagement({super.key});

  @override
  State<AdminActivityManagement> createState() => _AdminActivityManagementState();
}

class _AdminActivityManagementState extends State<AdminActivityManagement> {
  final ActivityService _activityService = ActivityService();

  String _searchQuery = '';
  String _selectedSkill = 'All';
  String _selectedDifficulty = 'All';
  int _selectedAgeGroup = 0;
  bool _isGridView = false; // Default List View (ultra-compact, ~72px height)

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedSkill = 'All';
      _selectedDifficulty = 'All';
      _selectedAgeGroup = 0;
    });
  }

  Future<void> _seedPresets() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Preset Activities?'),
        content: const Text(
          'This will populate Firestore with 112 initial preset activities across Cognitive, Language, Motor, Social, Emotional, Creative, and Listening skills.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Seed Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seeding preset activities...')),
      );

      final seeded = await ActivitySeeder.seedPresetActivities(force: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              seeded
                  ? '✅ 112 Preset activities seeded successfully!'
                  : 'Preset activities already exist or seeding failed.',
            ),
            backgroundColor: seeded ? AppColors.success : AppColors.warning,
          ),
        );
      }
    }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Title & Header Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Management', style: AppTextStyles.heading1),
                const SizedBox(height: 2),
                Text(
                  'Manage master activity library, preset tasks, and status.',
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
                OutlinedButton.icon(
                  onPressed: _seedPresets,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: const Text('Seed Presets'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
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
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading activities: ${snapshot.error}'),
                );
              }

              final activities = snapshot.data ?? [];

              if (activities.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No activities found.', style: AppTextStyles.heading2),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Try clearing filters or click "Seed Presets" to add sample activities.',
                        style: AppTextStyles.bodyLight,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: _seedPresets,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Seed 112 Preset Activities'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
            return ActivityCard(
              activity: activity,
              compact: true,
              showAdminControls: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityView(activity: activity, userRole: 'admin'),
                  ),
                );
              },
              onEdit: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddActivityPage(activity: activity),
                  ),
                );
              },
              onDelete: () => _confirmDelete(activity),
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
    return ListView.builder(
      itemCount: activities.length,
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return ActivityCard(
          activity: activity,
          compact: false,
          showAdminControls: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ActivityView(activity: activity, userRole: 'admin'),
              ),
            );
          },
          onEdit: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddActivityPage(activity: activity),
              ),
            );
          },
          onDelete: () => _confirmDelete(activity),
          onToggleStatus: () async {
            if (activity.id != null) {
              await _activityService.toggleActivityStatus(activity.id!);
            }
          },
        );
      },
    );
  }
}

