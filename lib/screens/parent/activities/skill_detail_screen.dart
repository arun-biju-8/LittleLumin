// lib/screens/parent/activities/skill_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/activity_model.dart';
import '../../../models/child_model.dart';
import '../../../theme/meadow_theme.dart';
import '../../../services/curated_packs_service.dart';
import '../activity_view.dart';

class SkillDetailScreen extends StatefulWidget {
  final String? skillDomain;
  final String? packId;
  final String? packName;
  final ChildModel? child;
  final List<ActivityModel>? initialActivities;

  const SkillDetailScreen({
    super.key,
    this.skillDomain,
    this.packId,
    this.packName,
    this.child,
    this.initialActivities,
  });

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  late int? _selectedAge;
  String _selectedDifficulty = 'All';
  String _selectedDuration = 'All'; // All, <5 min, 5-10 min, >10 min
  String _selectedSort = 'Recommended'; // Recommended, Newest, Easiest
  bool _isGridView = false;

  late Future<List<ActivityModel>> _future;

  @override
  void initState() {
    super.initState();
    // Highlight kid's age by default
    final childAge = widget.child?.age;
    if (childAge != null && childAge >= 3 && childAge <= 6) {
      _selectedAge = childAge;
    } else {
      _selectedAge = 4;
    }

    _loadActivities();
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

  String get _title {
    if (widget.packName != null && widget.packName!.isNotEmpty) {
      return widget.packName!;
    }
    if (widget.packId != null && CuratedPacksService.packs.containsKey(widget.packId)) {
      final p = CuratedPacksService.packs[widget.packId]!;
      return '${p['emoji']} ${p['name']}';
    }
    if (widget.skillDomain != null && widget.skillDomain!.isNotEmpty) {
      return MeadowDomain.labelFor(widget.skillDomain!);
    }
    return 'Activities';
  }

  List<ActivityModel> _filterAndSort(List<ActivityModel> all) {
    var list = all;

    // 1. Skill or Pack Filter
    if (widget.skillDomain != null && widget.skillDomain!.isNotEmpty) {
      final domain = widget.skillDomain!.toLowerCase();
      list = list.where((a) => a.skillType.toLowerCase() == domain).toList();
    } else if (widget.packId != null && CuratedPacksService.packs.containsKey(widget.packId)) {
      final filter = CuratedPacksService.packs[widget.packId]!['filter'] as Map<String, dynamic>;
      if (filter.containsKey('maxDuration')) {
        final maxDur = filter['maxDuration'] as int;
        list = list.where((a) => a.duration <= maxDur).toList();
      }
      if (filter.containsKey('skillTypes')) {
        final skillTypes = (filter['skillTypes'] as List).map((s) => s.toString().toLowerCase()).toList();
        list = list.where((a) => skillTypes.contains(a.skillType.toLowerCase())).toList();
      }
    }

    // 2. Age Filter
    if (_selectedAge != null) {
      list = list.where((a) => a.ageGroup.contains(_selectedAge!)).toList();
    }

    // 3. Difficulty Filter
    if (_selectedDifficulty != 'All') {
      list = list.where((a) => a.difficulty.toLowerCase() == _selectedDifficulty.toLowerCase()).toList();
    }

    // 4. Duration Filter
    if (_selectedDuration == '<5 min') {
      list = list.where((a) => a.duration < 5).toList();
    } else if (_selectedDuration == '5-10 min') {
      list = list.where((a) => a.duration >= 5 && a.duration <= 10).toList();
    } else if (_selectedDuration == '>10 min') {
      list = list.where((a) => a.duration > 10).toList();
    }

    // 5. Sort
    final sorted = List<ActivityModel>.from(list);
    if (_selectedSort == 'Newest') {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_selectedSort == 'Easiest') {
      const difficultyOrder = {'easy': 0, 'medium': 1, 'hard': 2};
      sorted.sort((a, b) {
        final da = difficultyOrder[a.difficulty.toLowerCase()] ?? 1;
        final db = difficultyOrder[b.difficulty.toLowerCase()] ?? 1;
        return da.compareTo(db);
      });
    }

    return sorted;
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

  void _showFiltersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MeadowColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MeadowRadius.xl)),
      ),
      builder: (ctx) {
        String tempDifficulty = _selectedDifficulty;
        String tempDuration = _selectedDuration;
        String tempSort = _selectedSort;

        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: MeadowColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filter Activities', style: MeadowTypography.h2),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempDifficulty = 'All';
                              tempDuration = 'All';
                              tempSort = 'Recommended';
                            });
                          },
                          child: Text(
                            'Reset',
                            style: MeadowTypography.caption.copyWith(
                              color: MeadowColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Difficulty
                    Text('Difficulty', style: MeadowTypography.label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['All', 'Easy', 'Medium', 'Hard'].map((diff) {
                        final isSel = tempDifficulty == diff;
                        return ChoiceChip(
                          label: Text(diff),
                          selected: isSel,
                          selectedColor: MeadowColors.primarySurface,
                          labelStyle: MeadowTypography.caption.copyWith(
                            color: isSel ? MeadowColors.primary : MeadowColors.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => tempDifficulty = diff);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Duration
                    Text('Duration', style: MeadowTypography.label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['All', '<5 min', '5-10 min', '>10 min'].map((dur) {
                        final isSel = tempDuration == dur;
                        return ChoiceChip(
                          label: Text(dur),
                          selected: isSel,
                          selectedColor: MeadowColors.primarySurface,
                          labelStyle: MeadowTypography.caption.copyWith(
                            color: isSel ? MeadowColors.primary : MeadowColors.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => tempDuration = dur);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Sort
                    Text('Sort by', style: MeadowTypography.label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Recommended', 'Newest', 'Easiest'].map((sort) {
                        final isSel = tempSort == sort;
                        return ChoiceChip(
                          label: Text(sort),
                          selected: isSel,
                          selectedColor: MeadowColors.primarySurface,
                          labelStyle: MeadowTypography.caption.copyWith(
                            color: isSel ? MeadowColors.primary : MeadowColors.textPrimary,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => tempSort = sort);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: MeadowButtons.primary(),
                        onPressed: () {
                          setState(() {
                            _selectedDifficulty = tempDifficulty;
                            _selectedDuration = tempDuration;
                            _selectedSort = tempSort;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
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
            Text(_title, style: MeadowTypography.h2),
            FutureBuilder<List<ActivityModel>>(
              future: _future,
              builder: (context, snapshot) {
                final count = _filterAndSort(snapshot.data ?? []).length;
                return Text(
                  '$count activities',
                  style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: MeadowColors.textPrimary,
            ),
            tooltip: _isGridView ? 'Switch to List view' : 'Switch to Grid view',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: MeadowColors.textPrimary),
            tooltip: 'Filter activities',
            onPressed: _showFiltersSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Age Filter Chips Row
          Container(
            color: MeadowColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Age:',
                  style: MeadowTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MeadowColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [3, 4, 5, 6].map((age) {
                        final isSel = _selectedAge == age;
                        final isChildAge = widget.child?.age == age;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$age yrs'),
                                if (isChildAge) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check, size: 14, color: MeadowColors.primary),
                                ],
                              ],
                            ),
                            selected: isSel,
                            backgroundColor: MeadowColors.surfaceAlt,
                            selectedColor: MeadowColors.primarySurface,
                            labelStyle: MeadowTypography.caption.copyWith(
                              color: isSel ? MeadowColors.primary : MeadowColors.textPrimary,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(MeadowRadius.pill),
                              side: BorderSide(
                                color: isSel ? MeadowColors.primary : MeadowColors.borderLight,
                              ),
                            ),
                            onSelected: (val) {
                              setState(() {
                                _selectedAge = val ? age : null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: MeadowColors.borderLight),

          // Main list or grid
          Expanded(
            child: FutureBuilder<List<ActivityModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: MeadowColors.primary),
                  );
                }

                final activities = _filterAndSort(snapshot.data ?? []);

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
                          Text('No Activities Found', style: MeadowTypography.h3),
                          const SizedBox(height: 6),
                          Text(
                            'Try clearing or modifying the age and difficulty filters.',
                            textAlign: TextAlign.center,
                            style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedAge = null;
                                _selectedDifficulty = 'All';
                                _selectedDuration = 'All';
                              });
                            },
                            child: const Text('Reset Filters'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_isGridView) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(16),
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
                                    width: 80,
                                    height: 80,
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
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
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
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: MeadowColors.primary,
                                              foregroundColor: MeadowColors.textInverse,
                                              elevation: 0,
                                              minimumSize: const Size(64, 32),
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(MeadowRadius.sm),
                                              ),
                                            ),
                                            onPressed: () => _openActivity(item),
                                            child: const Text('Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
