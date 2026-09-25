import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/child_model.dart';
import '../../../../models/activity_model.dart';
import '../../../../services/activity_service.dart';
import '../../../../services/activity_state_service.dart';
import '../../../../widgets/activity_card.dart';
import '../../activity_view.dart';
import '../../feedback_form.dart';
import '../../parent_theme.dart';

class AllActivitiesTab extends StatefulWidget {
  final ChildModel? activeChild;

  const AllActivitiesTab({
    super.key,
    required this.activeChild,
  });

  @override
  State<AllActivitiesTab> createState() => _AllActivitiesTabState();
}

class _AllActivitiesTabState extends State<AllActivitiesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    final child = widget.activeChild;

    if (child == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: ParentColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('👶', style: TextStyle(fontSize: 38)),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -6, duration: 1600.ms),
              const SizedBox(height: 16),
              Text(
                'No Child Selected',
                style: ParentTypography.title,
              ),
              const SizedBox(height: 6),
              Text(
                'Please select or add a child to browse curated activities.',
                textAlign: TextAlign.center,
                style: ParentTypography.bodyLight,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & View Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activities for ${child.name}',
                      style: ParentTypography.title.copyWith(fontSize: 20),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Screen-free, parent-guided learning tasks',
                      style: ParentTypography.caption,
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: ParentShadows.card,
                  border: Border.all(color: ParentColors.surfaceAlt),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.grid_view_rounded,
                        size: 20,
                        color: _isGridView
                            ? ParentColors.primary
                            : ParentColors.textTertiary,
                      ),
                      tooltip: 'Grid View',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _isGridView = true),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.view_list_rounded,
                        size: 22,
                        color: !_isGridView
                            ? ParentColors.primary
                            : ParentColors.textTertiary,
                      ),
                      tooltip: 'List View',
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _isGridView = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            style: ParentTypography.body,
            decoration: InputDecoration(
              hintText: 'Search by title or skill...',
              hintStyle: ParentTypography.bodyLight,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: ParentColors.primary,
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: ParentRadius.input,
                borderSide: BorderSide(color: ParentColors.surfaceAlt),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: ParentRadius.input,
                borderSide: BorderSide(color: ParentColors.surfaceAlt),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: ParentRadius.input,
                borderSide: BorderSide(color: ParentColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filters row: Skill Horizontal Pill Chips
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
                    selectedColor: ParentColors.primary,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: ParentRadius.chip,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : ParentColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? ParentColors.primary : ParentColors.surfaceAlt,
                      width: 1.2,
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Difficulty & Duration Dropdown Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParentColors.surfaceAlt),
                    boxShadow: ParentShadows.card,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDifficulty,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: ParentTypography.caption.copyWith(
                        color: ParentColors.textPrimary,
                      ),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedDifficulty = value);
                      },
                      items: _difficultyOptions.map((diff) {
                        return DropdownMenuItem<String>(
                          value: diff,
                          child: Text(
                            'Diff: $diff',
                            style: TextStyle(
                              fontWeight: diff == _selectedDifficulty
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParentColors.surfaceAlt),
                    boxShadow: ParentShadows.card,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDuration,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      style: ParentTypography.caption.copyWith(
                        color: ParentColors.textPrimary,
                      ),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedDuration = value);
                      },
                      items: _durationOptions.map((dur) {
                        return DropdownMenuItem<String>(
                          value: dur,
                          child: Text(
                            'Time: $dur',
                            style: TextStyle(
                              fontWeight: dur == _selectedDuration
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
          const SizedBox(height: 16),

          // Stream Content
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

              final filtered = allActivities.where((a) {
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  if (!a.title.toLowerCase().contains(query) &&
                      !a.skillType.toLowerCase().contains(query)) {
                    return false;
                  }
                }
                if (_selectedSkill != 'All' &&
                    a.skillType.toLowerCase().trim() != _selectedSkill.toLowerCase().trim()) {
                  return false;
                }
                if (_selectedDifficulty != 'All' &&
                    a.difficulty.toLowerCase().trim() != _selectedDifficulty.toLowerCase().trim()) {
                  return false;
                }
                if (_selectedDuration != 'All' && !_matchesDuration(a.duration, _selectedDuration)) {
                  return false;
                }
                return true;
              }).toList();

              filtered.sort((a, b) =>
                  _getDifficultyPriority(a.difficulty).compareTo(_getDifficultyPriority(b.difficulty)));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${filtered.length} activities',
                        style: ParentTypography.caption.copyWith(
                          color: ParentColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_hasActiveFilters)
                        TextButton(
                          onPressed: _resetFilters,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Reset Filters',
                            style: ParentTypography.caption.copyWith(
                              color: ParentColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: ParentRadius.card,
                        border: Border.all(color: ParentColors.surfaceAlt),
                        boxShadow: ParentShadows.card,
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 54, color: ParentColors.textTertiary),
                          const SizedBox(height: 14),
                          Text(
                            'No activities match your filters',
                            style: ParentTypography.cardTitle,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try resetting filters to explore more activities.',
                            style: ParentTypography.bodyLight,
                          ),
                        ],
                      ),
                    )
                  else
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: ActivityStateService().watchActiveActivity(child.childId),
                      builder: (context, activeSnapshot) {
                        final activeData = activeSnapshot.data?.data();

                        void handleAction(ActivityModel activity, ActivityButtonState buttonState) async {
                          if (buttonState == ActivityButtonState.start) {
                            await ActivityStateService().startActivity(
                              childId: child.childId,
                              activityId: activity.id ?? '',
                              activityTitle: activity.title,
                              skillDomain: activity.skillType,
                            );
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityView(
                                  activity: activity,
                                  childId: child.childId,
                                ),
                              ),
                            );
                          } else if (buttonState == ActivityButtonState.continueActivity ||
                              buttonState == ActivityButtonState.view) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ActivityView(
                                  activity: activity,
                                  childId: child.childId,
                                ),
                              ),
                            );
                          } else if (buttonState == ActivityButtonState.submitFeedback) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FeedbackForm(
                                  childId: child.childId,
                                  activityId: activity.id,
                                  activityTitle: activity.title,
                                ),
                              ),
                            );
                          }
                        }

                        if (_isGridView) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.88,
                                ),
                                itemBuilder: (context, index) {
                                  final activity = filtered[index];
                                  final buttonState = ActivityCard.resolveButtonState(
                                    activityId: activity.id,
                                    activeActivity: activeData,
                                  );

                                  return ActivityCard(
                                    activity: activity,
                                    compact: true,
                                    buttonState: buttonState,
                                    onActionButtonTap: () => handleAction(activity, buttonState),
                                    onTap: () => handleAction(activity, buttonState),
                                  )
                                      .animate()
                                      .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms)
                                      .scale(begin: const Offset(0.95, 0.95), duration: 250.ms);
                                },
                              );
                            },
                          );
                        } else {
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final activity = filtered[index];
                              final buttonState = ActivityCard.resolveButtonState(
                                activityId: activity.id,
                                activeActivity: activeData,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ActivityCard(
                                  activity: activity,
                                  compact: false,
                                  buttonState: buttonState,
                                  onActionButtonTap: () => handleAction(activity, buttonState),
                                  onTap: () => handleAction(activity, buttonState),
                                )
                                    .animate()
                                    .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 300.ms)
                                    .slideY(begin: 0.05, end: 0, duration: 300.ms),
                              );
                            },
                          );
                        }
                      },
                    ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
