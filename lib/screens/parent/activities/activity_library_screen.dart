// lib/screens/parent/activities/activity_library_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/activity_model.dart';
import '../../../models/child_model.dart';
import '../../../theme/meadow_theme.dart';
import '../activity_view.dart';

class ActivityLibraryScreen extends StatefulWidget {
  final ChildModel? child;
  final List<ActivityModel>? initialActivities;

  const ActivityLibraryScreen({
    super.key,
    this.child,
    this.initialActivities,
  });

  @override
  State<ActivityLibraryScreen> createState() => _ActivityLibraryScreenState();
}

class _ActivityLibraryScreenState extends State<ActivityLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedSkill;
  int? _selectedAge;
  String? _selectedDifficulty;
  bool _isGridView = false;

  late Future<List<ActivityModel>> _future;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadActivities() {
    if (widget.initialActivities != null) {
      _future = Future.value(widget.initialActivities!);
      return;
    }
    _future = _fetchActivities();
  }

  Future<List<ActivityModel>> _fetchActivities() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('activities')
          .where('isActive', isEqualTo: true)
          .get();

      return snap.docs
          .map((doc) => ActivityModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<ActivityModel> _filterActivities(List<ActivityModel> all) {
    var list = all;

    // Search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((a) {
        final titleMatch = a.title.toLowerCase().contains(q);
        final descMatch = (a.shortDescription ?? '').toLowerCase().contains(q);
        final tagMatch = a.tags.any((t) => t.toLowerCase().contains(q));
        return titleMatch || descMatch || tagMatch;
      }).toList();
    }

    // Skill filter
    if (_selectedSkill != null) {
      list = list.where((a) => a.skillType.toLowerCase() == _selectedSkill!.toLowerCase()).toList();
    }

    // Age filter
    if (_selectedAge != null) {
      list = list.where((a) => a.ageGroup.contains(_selectedAge!)).toList();
    }

    // Difficulty filter
    if (_selectedDifficulty != null) {
      list = list.where((a) => a.difficulty.toLowerCase() == _selectedDifficulty!.toLowerCase()).toList();
    }

    return list;
  }

  String _mapIllustration(String title, String domain) {
    final t = title.toLowerCase();
    if (t.contains('nature') || t.contains('hunt') || t.contains('treasure')) {
      return 'assets/illustrations/nature_hunt.webp';
    }
    if (t.contains('color') || t.contains('sort')) {
      return 'assets/illustrations/color_sorting.webp';
    }
    if (t.contains('fort') || t.contains('build')) {
      return 'assets/illustrations/build_fort.webp';
    }
    if (t.contains('story') || t.contains('read') || t.contains('book')) {
      return 'assets/illustrations/story_reading.webp';
    }
    if (t.contains('calm') || t.contains('safari')) {
      return 'assets/illustrations/calm_safari.webp';
    }
    if (t.contains('ocean') || t.contains('breath')) {
      return 'assets/illustrations/ocean_breathing.webp';
    }
    if (t.contains('phonic') || t.contains('sound') || t.contains('word') || t.contains('letter')) {
      return 'assets/illustrations/phonics_fun.webp';
    }
    if (t.contains('music') || t.contains('listen')) {
      return 'assets/illustrations/nature_sounds.webp';
    }

    final d = domain.toLowerCase();
    if (d == 'cognitive') return 'assets/illustrations/nature_hunt.webp';
    if (d == 'motor') return 'assets/illustrations/build_fort.webp';
    if (d == 'language') return 'assets/illustrations/phonics_fun.webp';
    if (d == 'emotional') return 'assets/illustrations/ocean_breathing.webp';
    if (d == 'social') return 'assets/illustrations/calm_safari.webp';

    return 'assets/illustrations/home_hero.webp';
  }

  void _openActivity(ActivityModel activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityView(
          activity: activity,
          activityId: activity.id,
          childId: widget.child?.childId,
        ),
      ),
    );
  }

  void _showSkillPicker() {
    final skills = ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'];
    showModalBottomSheet(
      context: context,
      backgroundColor: MeadowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Skill', style: MeadowTypography.h2),
                const SizedBox(height: 12),
                ...skills.map((s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s, style: MeadowTypography.bodyLarge),
                      trailing: _selectedSkill == s ? const Icon(Icons.check, color: MeadowColors.primary) : null,
                      onTap: () {
                        setState(() => _selectedSkill = s);
                        Navigator.pop(ctx);
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAgePicker() {
    final ages = [3, 4, 5, 6];
    showModalBottomSheet(
      context: context,
      backgroundColor: MeadowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Target Age', style: MeadowTypography.h2),
                const SizedBox(height: 12),
                ...ages.map((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('$a years old', style: MeadowTypography.bodyLarge),
                      trailing: _selectedAge == a ? const Icon(Icons.check, color: MeadowColors.primary) : null,
                      onTap: () {
                        setState(() => _selectedAge = a);
                        Navigator.pop(ctx);
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDifficultyPicker() {
    final difficulties = ['Easy', 'Medium', 'Hard'];
    showModalBottomSheet(
      context: context,
      backgroundColor: MeadowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Difficulty', style: MeadowTypography.h2),
                const SizedBox(height: 12),
                ...difficulties.map((d) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(d, style: MeadowTypography.bodyLarge),
                      trailing: _selectedDifficulty == d ? const Icon(Icons.check, color: MeadowColors.primary) : null,
                      onTap: () {
                        setState(() => _selectedDifficulty = d);
                        Navigator.pop(ctx);
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownButton({
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: isHighlighted ? MeadowColors.primary : MeadowColors.textPrimary,
        backgroundColor: isHighlighted ? MeadowColors.primarySurface : MeadowColors.surface,
        side: BorderSide(
          color: isHighlighted ? MeadowColors.primary : MeadowColors.borderLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MeadowRadius.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: MeadowTypography.caption.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }

  Widget _buildRemovableChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MeadowColors.primarySurface,
        borderRadius: BorderRadius.circular(MeadowRadius.pill),
        border: Border.all(color: MeadowColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MeadowTypography.caption.copyWith(
              color: MeadowColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: MeadowColors.primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _selectedSkill != null || _selectedAge != null || _selectedDifficulty != null;

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: AppBar(
        backgroundColor: MeadowColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: MeadowColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity Library', style: MeadowTypography.h2),
            FutureBuilder<List<ActivityModel>>(
              future: _future,
              builder: (context, snapshot) {
                final count = (snapshot.data ?? []).length;
                return Text(
                  '$count activities',
                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            color: MeadowColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search activities...',
                    hintStyle: MeadowTypography.body.copyWith(color: MeadowColors.textTertiary),
                    prefixIcon: const Icon(Icons.search_rounded, color: MeadowColors.primary),
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
                    fillColor: MeadowColors.surfaceAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MeadowRadius.lg),
                      borderSide: const BorderSide(color: MeadowColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MeadowRadius.lg),
                      borderSide: const BorderSide(color: MeadowColors.borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MeadowRadius.lg),
                      borderSide: const BorderSide(color: MeadowColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter Dropdowns
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDropdownButton(
                        label: _selectedSkill ?? 'Skill',
                        isHighlighted: _selectedSkill != null,
                        onTap: _showSkillPicker,
                      ),
                      const SizedBox(width: 8),
                      _buildDropdownButton(
                        label: _selectedAge != null ? 'Age $_selectedAge' : 'Age',
                        isHighlighted: _selectedAge != null,
                        onTap: _showAgePicker,
                      ),
                      const SizedBox(width: 8),
                      _buildDropdownButton(
                        label: _selectedDifficulty ?? 'Difficulty',
                        isHighlighted: _selectedDifficulty != null,
                        onTap: _showDifficultyPicker,
                      ),
                    ],
                  ),
                ),

                // Removable active filters row
                if (hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_selectedSkill != null)
                          _buildRemovableChip(_selectedSkill!, () => setState(() => _selectedSkill = null)),
                        if (_selectedAge != null)
                          _buildRemovableChip('Age $_selectedAge', () => setState(() => _selectedAge = null)),
                        if (_selectedDifficulty != null)
                          _buildRemovableChip(_selectedDifficulty!, () => setState(() => _selectedDifficulty = null)),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedSkill = null;
                              _selectedAge = null;
                              _selectedDifficulty = null;
                            });
                          },
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                          child: Text(
                            'Clear all',
                            style: MeadowTypography.caption.copyWith(color: MeadowColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: MeadowColors.borderLight),

          // Results Count + Grid/List Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: FutureBuilder<List<ActivityModel>>(
              future: _future,
              builder: (context, snapshot) {
                final filtered = _filterActivities(snapshot.data ?? []);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? "result" : "results"}',
                      style: MeadowTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MeadowColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                        color: MeadowColors.textPrimary,
                        size: 20,
                      ),
                      tooltip: _isGridView ? 'Switch to List view' : 'Switch to Grid view',
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                    ),
                  ],
                );
              },
            ),
          ),

          // Main list or grid of filtered activities
          Expanded(
            child: FutureBuilder<List<ActivityModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: MeadowColors.primary));
                }

                final activities = _filterActivities(snapshot.data ?? []);

                if (activities.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: MeadowColors.primarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: MeadowColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('No activities found', style: MeadowTypography.h3),
                          const SizedBox(height: 6),
                          Text(
                            'Try adjusting your search query or removing active filters.',
                            textAlign: TextAlign.center,
                            style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_isGridView) {
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final item = activities[index];
                      final illustration = _mapIllustration(item.title, item.skillType);

                      return Container(
                        decoration: MeadowCards.standard(),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(MeadowRadius.lg),
                            onTap: () => _openActivity(item),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(MeadowRadius.lg)),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 10,
                                    child: Image.asset(
                                      illustration,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: MeadowColors.sageLight,
                                        child: const Icon(Icons.palette_outlined, color: MeadowColors.primary),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: MeadowTypography.label.copyWith(fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.difficulty} · ${item.duration}m',
                                        style: MeadowTypography.caption.copyWith(
                                          color: MeadowColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = activities[index];
                    final illustration = _mapIllustration(item.title, item.skillType);
                    final domainColor = MeadowDomain.colorFor(item.skillType);

                    return Container(
                      decoration: MeadowCards.standard(),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(MeadowRadius.lg),
                          onTap: () => _openActivity(item),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(MeadowRadius.md),
                                  child: SizedBox(
                                    width: 76,
                                    height: 76,
                                    child: Image.asset(
                                      illustration,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: MeadowColors.sageLight,
                                        child: const Icon(Icons.palette_outlined, color: MeadowColors.primary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: MeadowTypography.h3,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Age ${item.ageGroupDisplay} · ${item.difficulty} · ${item.duration} min',
                                        style: MeadowTypography.caption.copyWith(
                                          color: MeadowColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: MeadowDomain.surfaceFor(item.skillType),
                                          borderRadius: BorderRadius.circular(MeadowRadius.sm),
                                        ),
                                        child: Text(
                                          MeadowDomain.labelFor(item.skillType),
                                          style: MeadowTypography.caption.copyWith(
                                            color: domainColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: MeadowColors.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
