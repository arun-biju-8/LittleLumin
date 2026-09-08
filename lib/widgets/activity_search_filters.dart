// lib/widgets/activity_search_filters.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ActivitySearchFilters extends StatefulWidget {
  final String searchQuery;
  final String selectedSkill;
  final String selectedDifficulty;
  final int selectedAgeGroup;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onSkillChanged;
  final ValueChanged<String?> onDifficultyChanged;
  final ValueChanged<int?> onAgeGroupChanged;
  final VoidCallback onClearFilters;

  const ActivitySearchFilters({
    super.key,
    required this.searchQuery,
    required this.selectedSkill,
    required this.selectedDifficulty,
    required this.selectedAgeGroup,
    required this.onSearchChanged,
    required this.onSkillChanged,
    required this.onDifficultyChanged,
    required this.onAgeGroupChanged,
    required this.onClearFilters,
  });

  @override
  State<ActivitySearchFilters> createState() => _ActivitySearchFiltersState();
}

class _ActivitySearchFiltersState extends State<ActivitySearchFilters> {
  late TextEditingController _searchController;

  static const List<String> skillTypes = [
    'All',
    'Cognitive',
    'Language',
    'Motor',
    'Social',
    'Emotional',
    'Creative',
    'Listening',
  ];

  static const List<String> difficulties = [
    'All',
    'Easy',
    'Medium',
    'Hard',
  ];

  static const Map<int, String> ageGroups = {
    0: 'All Ages',
    3: '3 years',
    4: '4 years',
    5: '5 years',
    6: '6 years',
  };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant ActivitySearchFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get hasActiveFilters {
    return widget.searchQuery.isNotEmpty ||
        (widget.selectedSkill != 'All' && widget.selectedSkill.isNotEmpty) ||
        (widget.selectedDifficulty != 'All' && widget.selectedDifficulty.isNotEmpty) ||
        widget.selectedAgeGroup != 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by title, skill, tag...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.small),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Filters Header & Clear Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              if (hasActiveFilters)
                InkWell(
                  onTap: () {
                    _searchController.clear();
                    widget.onClearFilters();
                  },
                  child: Text(
                    'Clear All',
                    style: AppTextStyles.small.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Dropdowns Layout (Responsive Wrap)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // Skill Type Dropdown
              _buildDropdownFilter<String>(
                label: 'Skill',
                value: widget.selectedSkill.isEmpty ? 'All' : widget.selectedSkill,
                items: skillTypes.map((skill) {
                  return DropdownMenuItem<String>(
                    value: skill,
                    child: Text(skill, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: widget.onSkillChanged,
              ),

              // Difficulty Dropdown
              _buildDropdownFilter<String>(
                label: 'Difficulty',
                value: widget.selectedDifficulty.isEmpty ? 'All' : widget.selectedDifficulty,
                items: difficulties.map((diff) {
                  return DropdownMenuItem<String>(
                    value: diff,
                    child: Text(diff, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: widget.onDifficultyChanged,
              ),

              // Age Group Dropdown
              _buildDropdownFilter<int>(
                label: 'Age Group',
                value: widget.selectedAgeGroup,
                items: ageGroups.entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: widget.onAgeGroupChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
        ),
      ),
    );
  }
}
