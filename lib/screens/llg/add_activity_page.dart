// lib/screens/llg/add_activity_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../widgets/activity_card.dart';

class AddActivityPage extends StatefulWidget {
  final ActivityModel? activity;
  final VoidCallback? onSuccess;

  const AddActivityPage({
    super.key,
    this.activity,
    this.onSuccess,
  });

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final ActivityService _activityService = ActivityService();
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;

  late TextEditingController _titleController;
  late TextEditingController _shortDescriptionController;
  late TextEditingController _durationController;
  late TextEditingController _instructionsController;
  late TextEditingController _learningGoalsController;
  late TextEditingController _materialsController;
  late TextEditingController _categoryController;
  late TextEditingController _tagsController;
  late TextEditingController _imageUrlController;
  late TextEditingController _videoUrlController;
  late TextEditingController _videoThumbnailController;
  late TextEditingController _videoDurationController;

  String _selectedSkill = 'Cognitive';
  String _selectedDifficulty = 'Medium';
  final Set<int> _selectedAgeGroups = {3, 4};

  static const List<String> skillOptions = [
    'Cognitive',
    'Language',
    'Motor',
    'Social',
    'Emotional',
    'Creative',
    'Listening',
  ];

  static const List<String> difficultyOptions = [
    'Easy',
    'Medium',
    'Hard',
  ];

  static const List<int> ageOptions = [3, 4, 5, 6];

  bool get isEditMode => widget.activity != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;

    _titleController = TextEditingController(text: a?.title ?? '');
    _shortDescriptionController = TextEditingController(text: a?.shortDescription ?? '');
    _durationController = TextEditingController(text: a?.duration.toString() ?? '10');
    _instructionsController = TextEditingController(text: a?.instructions.join('\n') ?? '');
    _learningGoalsController = TextEditingController(text: a?.learningGoals.join('\n') ?? '');
    _materialsController = TextEditingController(text: a?.materials.join('\n') ?? '');
    _categoryController = TextEditingController(text: a?.category ?? 'General');
    _tagsController = TextEditingController(text: a?.tags.join(', ') ?? '');
    _imageUrlController = TextEditingController(text: a?.imageUrl ?? '');
    _videoUrlController = TextEditingController(text: a?.videoUrl ?? '');
    _videoThumbnailController = TextEditingController(text: a?.videoThumbnail ?? '');
    _videoDurationController = TextEditingController(text: a?.videoDuration ?? '');

    if (a != null) {
      if (skillOptions.contains(a.skillType)) {
        _selectedSkill = a.skillType;
      }
      if (difficultyOptions.contains(a.difficulty)) {
        _selectedDifficulty = a.difficulty;
      }
      _selectedAgeGroups.clear();
      _selectedAgeGroups.addAll(a.ageGroup);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescriptionController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _learningGoalsController.dispose();
    _materialsController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _imageUrlController.dispose();
    _videoUrlController.dispose();
    _videoThumbnailController.dispose();
    _videoDurationController.dispose();
    super.dispose();
  }

  List<String> _parseLines(String text) {
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  List<String> _parseTags(String text) {
    return text
        .split(',')
        .map((tag) => tag.trim().replaceAll('#', ''))
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please correct errors in the form.')),
      );
      return;
    }

    if (_selectedAgeGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one target age group.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final currentUser = _auth.currentUser;
    final uid = currentUser?.uid ?? '';
    String userName = (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty)
        ? currentUser.displayName!
        : 'LLG Guide';
    String userRole = 'llg';

    if (uid.isNotEmpty) {
      userRole = (await _authService.getUserRole(uid)) ?? 'llg';
      final uDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (uDoc.exists && uDoc.data() != null) {
        userName = uDoc.data()?['name'] ?? userName;
      }
    }

    final bool isPresetEditByLLG = isEditMode && widget.activity!.isPreset && userRole != 'admin';

    // Show Save Confirmation Prompt Dialog
    if (!mounted) return;
    final confirmSave = await showDialog<bool>(
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
              child: const Text('💾', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Text(
              isPresetEditByLLG ? 'Save Adapted Copy?' : (isEditMode ? 'Save Changes?' : 'Create Activity?'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isPresetEditByLLG
              ? 'Confirm saving your custom adaptation of "${widget.activity!.title}" to your curriculum library?'
              : isEditMode
                  ? 'Are you sure you want to update this activity?'
                  : 'Are you sure you want to publish this new activity to the library?',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review Changes'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Confirm & Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (confirmSave != true) return;

    setState(() => _isLoading = true);

    try {
      final instructions = _parseLines(_instructionsController.text);
      final learningGoals = _parseLines(_learningGoalsController.text);
      final materials = _parseLines(_materialsController.text);
      final tags = _parseTags(_tagsController.text);

      final activityData = ActivityModel(
        id: isPresetEditByLLG ? null : widget.activity?.id,
        title: _titleController.text.trim(),
        shortDescription: _shortDescriptionController.text.trim().isEmpty
            ? null
            : _shortDescriptionController.text.trim(),
        skillType: _selectedSkill,
        difficulty: _selectedDifficulty,
        ageGroup: _selectedAgeGroups.toList()..sort(),
        duration: int.tryParse(_durationController.text.trim()) ?? 10,
        instructions: instructions.isNotEmpty ? instructions : ['Follow parent guidance.'],
        learningGoals: learningGoals.isNotEmpty ? learningGoals : ['Build developmental skills.'],
        materials: materials.isNotEmpty ? materials : ['None required'],
        isActive: widget.activity?.isActive ?? true,
        isPreset: isPresetEditByLLG ? false : (widget.activity?.isPreset ?? false),
        isEditedFromPreset: isPresetEditByLLG ? true : (widget.activity?.isEditedFromPreset ?? false),
        editedFromActivityId: isPresetEditByLLG ? widget.activity!.id : widget.activity?.editedFromActivityId,
        originalTitle: isPresetEditByLLG
            ? (widget.activity!.originalTitle ?? widget.activity!.title)
            : widget.activity?.originalTitle,
        createdBy: isPresetEditByLLG
            ? uid
            : (widget.activity?.createdBy.isNotEmpty == true ? widget.activity!.createdBy : uid),
        createdByName: isPresetEditByLLG
            ? userName
            : (widget.activity?.createdByName.isNotEmpty == true
                ? widget.activity!.createdByName
                : userName),
        tags: tags,
        category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
        videoUrl: _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim(),
        videoThumbnail: _videoThumbnailController.text.trim().isEmpty ? null : _videoThumbnailController.text.trim(),
        videoDuration: _videoDurationController.text.trim().isEmpty ? null : _videoDurationController.text.trim(),
        createdAt: isPresetEditByLLG ? DateTime.now() : (widget.activity?.createdAt ?? DateTime.now()),
        editedAt: isPresetEditByLLG ? DateTime.now() : widget.activity?.editedAt,
      );

      bool success = false;
      if (isPresetEditByLLG || !isEditMode) {
        final newId = await _activityService.createActivity(activityData);
        success = newId != null;
      } else {
        success = await _activityService.updateActivity(widget.activity!.id!, activityData.toMap());
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        final message = isPresetEditByLLG
            ? '✅ Created custom copy adapted from "${widget.activity!.title}"!'
            : isEditMode
                ? '✅ Activity updated successfully!'
                : '✅ Activity created successfully!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
          ),
        );

        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving activity. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final skillColor = ActivityCard.getSkillColor(_selectedSkill);
    final skillEmoji = ActivityCard.getSkillEmoji(_selectedSkill);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEditMode
              ? (widget.activity?.isPreset == true ? 'Adapt Preset Activity' : 'Edit Activity')
              : 'Create New Activity',
          style: AppTextStyles.heading2,
        ),
        backgroundColor: AppColors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Banner Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [skillColor, skillColor.withOpacity(0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: skillColor.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                skillEmoji,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditMode
                                        ? (widget.activity?.isPreset == true
                                            ? 'Adapting Preset Activity'
                                            : 'Editing Custom Activity')
                                        : 'Create Curriculum Activity',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isEditMode && widget.activity?.isPreset == true
                                        ? 'Original Preset: "${widget.activity?.title}"'
                                        : 'Design engaging developmental tasks for early learners',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.92),
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isEditMode && widget.activity?.isPreset == true) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '📌 The original preset remains untouched. Saving edits creates your personal adapted copy in your curriculum library.',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Responsive Form Grid (2-Column Desktop, 1-Column Mobile)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWebDesktop = constraints.maxWidth >= 768;

                      final basicInfoCard = _buildSectionCard(
                        title: '1. Basic Information',
                        icon: Icons.edit_note,
                        badgeColor: Colors.blue,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Activity Title *',
                                hintText: 'e.g., Animal Sounds Hunt',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.title, color: AppColors.primary),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Title is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _shortDescriptionController,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                labelText: 'Short Description / Tagline',
                                hintText: 'e.g., Find matching pairs to build memory skills',
                                helperText: 'Brief summary displayed on activity cards (max 80 chars)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.short_text, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _categoryController,
                                    decoration: const InputDecoration(
                                      labelText: 'Category',
                                      hintText: 'e.g., Early Math',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: TextFormField(
                                    controller: _tagsController,
                                    decoration: const InputDecoration(
                                      labelText: 'Tags (comma separated)',
                                      hintText: 'shapes, math',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      final skillAudienceCard = _buildSectionCard(
                        title: '2. Skill Domain & Target Audience',
                        icon: Icons.psychology,
                        badgeColor: Colors.purple,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Skill Domain *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: skillOptions.map((skill) {
                                final isSelected = _selectedSkill == skill;
                                final color = ActivityCard.getSkillColor(skill);
                                final emoji = ActivityCard.getSkillEmoji(skill);

                                return ChoiceChip(
                                  avatar: Text(emoji, style: const TextStyle(fontSize: 14)),
                                  label: Text(skill),
                                  selected: isSelected,
                                  selectedColor: color.withOpacity(0.2),
                                  labelStyle: TextStyle(
                                    color: isSelected ? color : AppColors.textDark,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedSkill = skill);
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            const Text(
                              'Difficulty Level *',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: difficultyOptions.map((diff) {
                                final isSelected = _selectedDifficulty == diff;
                                final color = diff == 'Easy'
                                    ? AppColors.success
                                    : diff == 'Medium'
                                        ? AppColors.primary
                                        : AppColors.warning;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: ChoiceChip(
                                      label: Center(child: Text(diff)),
                                      selected: isSelected,
                                      selectedColor: color.withOpacity(0.2),
                                      labelStyle: TextStyle(
                                        color: isSelected ? color : AppColors.textDark,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      onSelected: (val) {
                                        if (val) setState(() => _selectedDifficulty = diff);
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Target Age Group *',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: ageOptions.map((age) {
                                    final isSelected = _selectedAgeGroups.contains(age);
                                    return FilterChip(
                                      label: Text('$age yrs'),
                                      selected: isSelected,
                                      selectedColor: AppColors.primary.withOpacity(0.2),
                                      checkmarkColor: AppColors.primary,
                                      onSelected: (val) {
                                        setState(() {
                                          if (val) {
                                            _selectedAgeGroups.add(age);
                                          } else {
                                            _selectedAgeGroups.remove(age);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),

                            TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Activity Duration (in minutes) *',
                                hintText: 'e.g. 10 or 15',
                                helperText: 'Recommended time required to complete the activity',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer_outlined, color: AppColors.primary),
                                suffixText: 'mins',
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Duration is required';
                                if (int.tryParse(val.trim()) == null) return 'Must be a valid number';
                                return null;
                              },
                            ),
                          ],
                        ),
                      );

                      final guidanceCard = _buildSectionCard(
                        title: '3. Guidance & Learning Goals',
                        icon: Icons.menu_book,
                        badgeColor: Colors.teal,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _instructionsController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Step-by-Step Parent Instructions',
                                hintText: 'Enter one step per line:\n1. Set up colored bowls...\n2. Ask child to sort items...',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _learningGoalsController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Learning Goals',
                                hintText: 'Enter one goal per line:\n- Color identification\n- Fine motor sorting',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _materialsController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Materials Needed',
                                hintText: 'Enter items per line:\n- Colored bowls\n- Buttons or pom-poms',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      );

                      final mediaCard = _buildSectionCard(
                        title: '4. Video & Media Support (Optional)',
                        icon: Icons.video_library,
                        badgeColor: Colors.deepOrange,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _videoUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Video Guide URL (mp4)',
                                hintText: 'https://example.com/demo.mp4',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.link, color: Colors.deepOrange),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _videoThumbnailController,
                              decoration: const InputDecoration(
                                labelText: 'Video Thumbnail Image URL',
                                hintText: 'https://images.unsplash.com/...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.photo, color: Colors.purple),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _videoDurationController,
                              decoration: const InputDecoration(
                                labelText: 'Video Length (e.g. 1:45)',
                                hintText: '1:45',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.schedule, color: Colors.purple),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _imageUrlController,
                              decoration: const InputDecoration(
                                labelText: 'Activity Banner Image URL',
                                hintText: 'https://images.unsplash.com/...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.image, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (isWebDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  basicInfoCard,
                                  const SizedBox(height: AppSpacing.md),
                                  skillAudienceCard,
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                children: [
                                  guidanceCard,
                                  const SizedBox(height: AppSpacing.md),
                                  mediaCard,
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            basicInfoCard,
                            const SizedBox(height: AppSpacing.md),
                            skillAudienceCard,
                            const SizedBox(height: AppSpacing.md),
                            guidanceCard,
                            const SizedBox(height: AppSpacing.md),
                            mediaCard,
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Bottom Action Bar Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: AppColors.border.withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitForm,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(isEditMode ? Icons.check_circle : Icons.add_task),
                          label: Text(
                            _isLoading
                                ? 'Saving Activity...'
                                : (isEditMode && widget.activity?.isPreset == true
                                    ? 'Save Adapted Copy'
                                    : isEditMode
                                        ? 'Update Activity'
                                        : 'Save Activity'),
                            style: AppTextStyles.button.copyWith(fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color badgeColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: badgeColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTextStyles.heading2.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }
}
