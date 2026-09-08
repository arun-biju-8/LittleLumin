// lib/screens/parent/parent_activities_tab.dart
import 'package:flutter/material.dart';
import '../../models/child_model.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../utils/constants.dart';
import '../../widgets/activity_card.dart';
import 'activity_view.dart';

class ParentActivitiesTab extends StatefulWidget {
  final ChildModel activeChild;

  const ParentActivitiesTab({
    super.key,
    required this.activeChild,
  });

  @override
  State<ParentActivitiesTab> createState() => _ParentActivitiesTabState();
}

class _ParentActivitiesTabState extends State<ParentActivitiesTab> {
  final ActivityService _activityService = ActivityService();
  final TextEditingController _searchController = TextEditingController();

  bool _isGridView = true;
  String _searchQuery = '';
  String _selectedSkill = 'All';
  String _selectedDifficulty = 'All';
  String _selectedDuration = 'All';

  final List<String> _skillOptions = [
    'All',
    'Cognitive',
    'Language',
    'Motor',
    'Social',
    'Emotional',
    'Creative',
    'Listening',
  ];

  final List<String> _difficultyOptions = [
    'All',
    'Easy',
    'Medium',
    'Hard',
  ];

  final List<String> _durationOptions = [
    'All',
    '5-10 min',
    '10-15 min',
    '15-20 min',
    '20+ min',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _getDifficultyPriority(String difficulty) {
    switch (difficulty.trim().toLowerCase()) {
      case 'easy':
        return 1;
      case 'medium':
        return 2;
      case 'hard':
        return 3;
      default:
        return 4;
    }
  }

  bool _matchesDuration(int duration, String option) {
    switch (option) {
      case '5-10 min':
        return duration >= 5 && duration <= 10;
      case '10-15 min':
        return duration >= 10 && duration <= 15;
      case '15-20 min':
        return duration >= 15 && duration <= 20;
      case '20+ min':
        return duration >= 20;
      default:
        return true;
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedSkill != 'All' ||
      _selectedDifficulty != 'All' ||
      _selectedDuration != 'All';

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSkill = 'All';
      _selectedDifficulty = 'All';
      _selectedDuration = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.activeChild;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Title & Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎯 Activities for ${child.name}', style: AppTextStyles.heading1),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Screen-free, parent-guided learning tasks',
                      style: AppTextStyles.bodyLight,
                    ),
                  ],
                ),
              ),
              // Grid / List Toggle Buttons
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.grid_view,
                        size: 20,
                        color: _isGridView ? AppColors.primary : Colors.grey[400],
                      ),
                      tooltip: 'Grid View',
                      onPressed: () => setState(() => _isGridView = true),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.view_list,
                        size: 22,
                        color: !_isGridView ? AppColors.primary : Colors.grey[400],
                      ),
                      tooltip: 'List View',
                      onPressed: () => setState(() => _isGridView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Under-3 Banner (if child age < 3)
          if (child.age < 3) ...[
            _buildUnder3Banner(),
            const SizedBox(height: AppSpacing.md),
          ],

          // 3. Search Bar
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search by title or skill type...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 4. Filters Section (Skill Chips + Difficulty & Duration Dropdowns)
          _buildFilterControls(),
          const SizedBox(height: AppSpacing.md),

          // 5. Activities Stream & Content Area
          StreamBuilder<List<ActivityModel>>(
            stream: _activityService.getActivitiesForAge(child.age),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final allActivities = snapshot.data ?? [];

              // Apply Filters
              List<ActivityModel> filtered = allActivities.where((a) {
                // Search query
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  final matchTitle = a.title.toLowerCase().contains(query);
                  final matchSkill = a.skillType.toLowerCase().contains(query);
                  if (!matchTitle && !matchSkill) return false;
                }

                // Skill filter
                if (_selectedSkill != 'All' && a.skillType != _selectedSkill) {
                  return false;
                }

                // Difficulty filter
                if (_selectedDifficulty != 'All' && a.difficulty != _selectedDifficulty) {
                  return false;
                }

                // Duration filter
                if (_selectedDuration != 'All' && !_matchesDuration(a.duration, _selectedDuration)) {
                  return false;
                }

                return true;
              }).toList();

              // Sort by difficulty: Easy -> Medium -> Hard
              filtered.sort((a, b) =>
                  _getDifficultyPriority(a.difficulty).compareTo(_getDifficultyPriority(b.difficulty)));

              // Count text label
              final countText = _hasActiveFilters
                  ? 'Showing ${filtered.length} results'
                  : (child.age < 3
                      ? 'Showing ${filtered.length} gentle activities'
                      : 'Showing ${filtered.length} activities for age ${child.age}');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Count Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        countText,
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_hasActiveFilters)
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh, size: 14, color: AppColors.primary),
                          label: Text(
                            'Reset Filters',
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Empty State or Activity List/Grid
                  if (filtered.isEmpty)
                    _buildEmptyState()
                  else if (_isGridView)
                    _buildGridView(filtered, child.childId)
                  else
                    _buildListView(filtered, child.childId),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Under-3 Guidance Banner
  Widget _buildUnder3Banner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🌱 Your Little One is Growing!',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'LittleLumin is designed for ages 3-6. Here are gentle activities for your child.',
                  style: AppTextStyles.small.copyWith(
                    color: Colors.purple[800],
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

  /// Filter Controls (Skill horizontal chips + Dropdowns)
  Widget _buildFilterControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skill Filter Horizontal Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _skillOptions.map((skill) {
              final isSelected = _selectedSkill == skill;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(skill),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedSkill = skill);
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border.withValues(alpha: 0.6),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Difficulty & Duration Dropdown Row
        Row(
          children: [
            // Difficulty Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDifficulty,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    style: AppTextStyles.small.copyWith(color: AppColors.textDark),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedDifficulty = value);
                    },
                    items: _difficultyOptions.map((diff) {
                      return DropdownMenuItem<String>(
                        value: diff,
                        child: Text(
                          'Difficulty: $diff',
                          style: AppTextStyles.small.copyWith(
                            fontWeight: diff == _selectedDifficulty ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Duration Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDuration,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                    style: AppTextStyles.small.copyWith(color: AppColors.textDark),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedDuration = value);
                    },
                    items: _durationOptions.map((dur) {
                      return DropdownMenuItem<String>(
                        value: dur,
                        child: Text(
                          'Duration: $dur',
                          style: AppTextStyles.small.copyWith(
                            fontWeight: dur == _selectedDuration ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Empty State View
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No activities found',
            style: AppTextStyles.heading2.copyWith(color: Colors.grey[800]),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try adjusting your filters or search term',
            style: AppTextStyles.bodyLight,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Clear All Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Grid View Layout (4 columns web / 2 columns mobile)
  Widget _buildGridView(List<ActivityModel> activities, String childId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 600;
        final crossAxisCount = isWeb ? 4 : 2;
        final childAspectRatio = isWeb ? 1.4 : 1.1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ActivityCard(
              activity: activity,
              compact: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityView(
                      activity: activity,
                      childId: childId,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// List View Layout (Full-width detailed cards)
  Widget _buildListView(List<ActivityModel> activities, String childId) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ActivityCard(
            activity: activity,
            compact: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActivityView(
                    activity: activity,
                    childId: childId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
