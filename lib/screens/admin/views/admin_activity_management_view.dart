import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/activity_model.dart';
import '../../../services/activity_service.dart';
import '../../../services/activity_seeder.dart';
import '../../../services/admin_service.dart';

class AdminActivityManagementView extends StatefulWidget {
  final AdminService adminService;
  final int initialSubIndex;
  final Function(int targetGroupIndex, int targetSubIndex)? onNavigate;

  const AdminActivityManagementView({
    super.key,
    required this.adminService,
    this.initialSubIndex = 0,
    this.onNavigate,
  });

  @override
  State<AdminActivityManagementView> createState() => _AdminActivityManagementViewState();
}

class _AdminActivityManagementViewState extends State<AdminActivityManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ActivityService _activityService = ActivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDomain = 'All';
  bool _isLoading = false;

  ActivityModel? _selectedActivity;
  bool _isDetailDrawerOpen = false;

  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorGreen = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  final List<String> _domains = [
    'All',
    'Cognitive',
    'Language',
    'Motor',
    'Social',
    'Emotional',
    'Creative',
    'Listening',
  ];

  @override
  void initState() {
    super.initState();
    int initialTab = 0;
    if (widget.initialSubIndex >= 0 && widget.initialSubIndex <= 2) {
      initialTab = widget.initialSubIndex;
    }
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(AdminActivityManagementView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubIndex != oldWidget.initialSubIndex &&
        widget.initialSubIndex >= 0 &&
        widget.initialSubIndex <= 2) {
      _tabController.animateTo(widget.initialSubIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_isLoading) const LinearProgressIndicator(color: colorTeal, minHeight: 2),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActivitiesLibraryTab(),
                  _buildAiReviewQueueTab(),
                  _buildActivityPerformanceTab(),
                ],
              ),
            ),
          ],
        ),

        // Detail / Preview Drawer
        if (_isDetailDrawerOpen && _selectedActivity != null)
          _buildActivityDetailDrawer(_selectedActivity!),
      ],
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      decoration: const BoxDecoration(
        color: colorNavy,
        border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorSlate,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorBorder),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search activities by title, domain, or materials...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: colorTextMuted, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: colorTextMuted, size: 16),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim().toLowerCase());
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome, color: colorTeal, size: 16),
                label: Text('Seed 112 Presets', style: GoogleFonts.inter(fontSize: 13, color: colorTeal, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: colorTeal),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _seedPresets,
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: Text('Create Activity', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorTeal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showCreateEditActivityDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filter Chips Row
          Row(
            children: [
              Text('Domain: ', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
              const SizedBox(width: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _domains.map((d) {
                    final isSel = _selectedDomain == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(d, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : colorTextMuted)),
                        selected: isSel,
                        selectedColor: colorTeal,
                        backgroundColor: colorSlate,
                        onSelected: (val) {
                          if (val) setState(() => _selectedDomain = d);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: colorNavy,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: colorTeal,
        indicatorWeight: 3,
        labelColor: colorTeal,
        unselectedLabelColor: colorTextMuted,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(text: 'Activities Library'),
          Tab(text: 'AI Content Review Queue'),
          Tab(text: 'Performance & Parent Feedback'),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. ACTIVITIES LIBRARY TAB
  // =========================================================================
  Widget _buildActivitiesLibraryTab() {
    return StreamBuilder<List<ActivityModel>>(
      stream: _activityService.getAllActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        List<ActivityModel> activities = snapshot.data ?? [];

        // Apply Domain Filter
        if (_selectedDomain != 'All') {
          activities = activities.where((a) => a.skillType.toLowerCase() == _selectedDomain.toLowerCase()).toList();
        }

        // Apply Search
        if (_searchQuery.isNotEmpty) {
          activities = activities.where((a) {
            return a.title.toLowerCase().contains(_searchQuery) ||
                (a.shortDescription?.toLowerCase().contains(_searchQuery) ?? false) ||
                a.skillType.toLowerCase().contains(_searchQuery);
          }).toList();
        }

        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined, size: 48, color: colorTextMuted.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text('No activities found matching criteria.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: activities.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final a = activities[index];
            return _buildActivityRow(a);
          },
        );
      },
    );
  }

  Widget _buildActivityRow(ActivityModel a) {
    Color diffColor = colorGreen;
    if (a.difficulty.toLowerCase() == 'medium') diffColor = colorAmber;
    if (a.difficulty.toLowerCase() == 'hard') diffColor = Colors.redAccent;

    final ageLabel = a.ageGroup.isNotEmpty ? 'Age ${a.ageGroup.first}-${a.ageGroup.last} yrs' : 'All ages';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorSlate,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorTeal.withOpacity(0.15),
            child: const Icon(Icons.psychology, color: colorTeal, size: 20),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '${a.skillType} | $ageLabel | Duration: ${a.duration} mins',
                  style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                ),
              ],
            ),
          ),
          // Difficulty
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: diffColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: diffColor.withOpacity(0.3)),
            ),
            child: Text(
              a.difficulty.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: diffColor),
            ),
          ),
          const SizedBox(width: 16),
          // Quick Actions
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: colorTeal, size: 20),
            tooltip: 'View Details',
            onPressed: () {
              setState(() {
                _selectedActivity = a;
                _isDetailDrawerOpen = true;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: colorAmber, size: 20),
            tooltip: 'Edit Activity',
            onPressed: () => _showCreateEditActivityDialog(activity: a),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Colors.redAccent, size: 20),
            tooltip: 'Archive Activity',
            onPressed: () => _archiveActivity(a),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. AI CONTENT REVIEW QUEUE TAB
  // =========================================================================
  Widget _buildAiReviewQueueTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('activities')
          .where('origin', isEqualTo: 'ai_generated')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 48, color: colorGreen),
                const SizedBox(height: 12),
                Text('AI Review Queue is clear!', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('All AI-generated developmental activities have been clinically reviewed.', style: GoogleFonts.inter(fontSize: 13, color: colorTextMuted)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'AI Activity';
            final skill = data['skill'] ?? 'General';
            final status = data['status'] ?? 'pending_review';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.15),
                    child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Target Domain: $skill | Status: ${status.toString().toUpperCase()}', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _firestore.collection('activities').doc(doc.id).update({
                        'status': 'published',
                        'reviewedAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Approved & Published: $title'), backgroundColor: colorGreen),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: colorGreen),
                    child: const Text('Approve & Publish', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // 3. ACTIVITY PERFORMANCE & PARENT FEEDBACK TAB
  // =========================================================================
  Widget _buildActivityPerformanceTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('activityCompletions').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: colorTeal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No activity completion records recorded yet.', style: GoogleFonts.inter(color: colorTextMuted, fontSize: 14)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final actTitle = data['activityTitle'] ?? 'Activity';
            final childName = data['childName'] ?? 'Child';
            final difficultyRating = data['difficultyRating'] ?? 'Optimal';
            final feedback = data['notes'] ?? data['feedback'] ?? 'Completed successfully';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorSlate,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorGreen.withOpacity(0.15),
                    child: const Icon(Icons.check_circle_outline, color: colorGreen, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(actTitle, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Child: $childName | Feedback: "$feedback"', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorTeal.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colorTeal.withOpacity(0.3)),
                    ),
                    child: Text('Reported: $difficultyRating', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: colorTeal)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // SEED PRESETS
  // =========================================================================
  Future<void> _seedPresets() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Seed 112 Preset Activities?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'This will populate Firestore with 112 developmental activities across Cognitive, Language, Motor, Social, Emotional, Creative, and Listening domains.',
          style: GoogleFonts.inter(color: colorTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
            child: const Text('Seed Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seeding 112 preset activities...')));
      try {
        final success = await ActivitySeeder.seedPresetActivities(force: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Successfully seeded 112 preset activities!' : 'Presets already up to date.'),
              backgroundColor: colorGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error seeding: $e'), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // =========================================================================
  // CREATE / EDIT ACTIVITY DIALOG
  // =========================================================================
  void _showCreateEditActivityDialog({ActivityModel? activity}) {
    final isEditing = activity != null;
    final titleController = TextEditingController(text: activity?.title ?? '');
    final descController = TextEditingController(text: activity?.shortDescription ?? '');
    String selectedSkill = activity?.skillType ?? 'Cognitive';
    String selectedDifficulty = activity?.difficulty ?? 'medium';
    int ageMin = (activity != null && activity.ageGroup.isNotEmpty) ? activity.ageGroup.first : 3;
    int ageMax = (activity != null && activity.ageGroup.isNotEmpty) ? activity.ageGroup.last : 6;
    int duration = activity?.duration ?? 15;
    final materialsController = TextEditingController(text: activity?.materials.join(', ') ?? '');
    final stepsController = TextEditingController(text: activity?.instructions.join('\n') ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colorSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: colorBorder)),
          title: Text(
            isEditing ? 'Edit Activity' : 'Create New Activity',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Activity Title', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g., Color Pattern Sorting Adventure',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Domain', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedSkill,
                                  dropdownColor: colorNavy,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                  items: _domains.where((d) => d != 'All').map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedSkill = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Difficulty', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(color: colorNavy, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorBorder)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedDifficulty,
                                  dropdownColor: colorNavy,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                  items: ['easy', 'medium', 'hard'].map((d) => DropdownMenuItem(value: d, child: Text(d.toUpperCase()))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => selectedDifficulty = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Description / Learning Objectives', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter clinical purpose and developmental goal...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Materials Needed (comma separated)', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: materialsController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g., Colored blocks, 3 small bowls',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Instructions (one step per line)', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: stepsController,
                    maxLines: 4,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Step 1: Set out the bowls...\nStep 2: Demonstrate placing one block...\nStep 3: Encourage the child...',
                      hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                      filled: true,
                      fillColor: colorNavy,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final mats = materialsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final steps = stepsController.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                  final newActivity = ActivityModel(
                    id: activity?.id ?? 'act_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleController.text.trim(),
                    shortDescription: descController.text.trim(),
                    skillType: selectedSkill,
                    difficulty: selectedDifficulty,
                    ageGroup: [ageMin, ageMax],
                    duration: duration,
                    materials: mats,
                    instructions: steps,
                    learningGoals: [descController.text.trim().isNotEmpty ? descController.text.trim() : 'Developmental milestone skill progression'],
                    createdAt: activity?.createdAt ?? DateTime.now(),
                  );

                  await _firestore.collection('activities').doc(newActivity.id).set(newActivity.toMap(), SetOptions(merge: true));

                  await widget.adminService.logAdminAudit(
                    action: isEditing ? 'activity_updated' : 'activity_created',
                    targetId: newActivity.id,
                    details: {'title': newActivity.title, 'domain': newActivity.skillType},
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Activity "${newActivity.title}" saved successfully!'), backgroundColor: colorGreen),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.redAccent));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorTeal),
              child: Text(isEditing ? 'Save Changes' : 'Create Activity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ARCHIVE ACTIVITY
  // =========================================================================
  Future<void> _archiveActivity(ActivityModel activity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Archive Activity?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Archiving "${activity.title}" will remove it from future parent assignments while preserving all historical completion records.',
          style: GoogleFonts.inter(color: colorTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: colorTextMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Archive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('activities').doc(activity.id).update({
        'isArchived': true,
        'status': 'archived',
        'archivedAt': FieldValue.serverTimestamp(),
      });
      await widget.adminService.logAdminAudit(
        action: 'activity_archived',
        targetId: activity.id,
        details: {'title': activity.title},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archived "${activity.title}"'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // =========================================================================
  // DETAIL DRAWER
  // =========================================================================
  Widget _buildActivityDetailDrawer(ActivityModel a) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 440,
      child: Container(
        decoration: BoxDecoration(
          color: colorSlate,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(-5, 0)),
          ],
          border: const Border(left: BorderSide(color: colorBorder, width: 1)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: colorBorder, width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Activity Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.close, color: colorTextMuted),
                    onPressed: () => setState(() => _isDetailDrawerOpen = false),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('${a.skillType} • ${a.ageGroup.isNotEmpty ? "Age ${a.ageGroup.first}-${a.ageGroup.last} yrs" : "All ages"} • ${a.duration} mins', style: GoogleFonts.inter(fontSize: 12, color: colorTeal)),
                    const SizedBox(height: 16),
                    Text('Description', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(a.shortDescription ?? 'No description provided.', style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted)),
                    const SizedBox(height: 16),
                    Text('Materials Needed', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    ...a.materials.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $m', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                        )),
                    const SizedBox(height: 16),
                    Text('Step-by-Step Instructions', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    ...a.instructions.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('${e.key + 1}. ${e.value}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
