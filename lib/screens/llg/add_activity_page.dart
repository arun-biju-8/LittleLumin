// lib/screens/llg/add_activity_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/activity_service.dart';
import '../../models/activity_model.dart';
import '../../utils/constants.dart';
import 'manage_activities_page.dart';

class AddActivityPage extends StatefulWidget {
  final ActivityModel? activityToEdit; // ✅ For editing
  const AddActivityPage({super.key, this.activityToEdit});

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _learningGoalsController = TextEditingController();
  final _materialsController = TextEditingController();
  final _otherSkillController = TextEditingController();

  // ✅ Dropdown values
  String _selectedDifficulty = 'Easy';
  int _selectedAgeGroup = 3;
  String _selectedSkillType = 'Cognitive Skills';
  bool _showOtherSkillField = false;
  bool _isLoading = false;

  // ✅ Skill Types List
  final List<String> _skillTypes = [
    'Cognitive Skills',
    'Language Skills',
    'Motor Skills',
    'Social Skills',
    'Emotional Skills',
    'Creative Skills',
    'Listening Skills',
    'Self-Help Skills',
    'Other (Please Specify)',
  ];

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  final List<int> _ageGroups = [3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    if (widget.activityToEdit != null) {
      _loadActivityForEdit();
    }
  }

  void _loadActivityForEdit() {
    final activity = widget.activityToEdit!;
    _titleController.text = activity.title;
    _durationController.text = activity.duration.toString();
    _instructionsController.text = activity.instructions.join('\n');
    _learningGoalsController.text = activity.learningGoals.join('\n');
    _materialsController.text = activity.materials.join('\n');
    _selectedDifficulty = activity.difficulty;
    _selectedAgeGroup = activity.ageGroup;
    _selectedSkillType = _skillTypes.contains(activity.skillType)
        ? activity.skillType
        : 'Other (Please Specify)';
    if (!_skillTypes.contains(activity.skillType)) {
      _otherSkillController.text = activity.skillType;
      _showOtherSkillField = true;
    }
  }

  String getSkillType() {
    if (_selectedSkillType == 'Other (Please Specify)') {
      return _otherSkillController.text.trim();
    }
    return _selectedSkillType;
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;

    final skillType = getSkillType();
    if (skillType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid skill type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final activity = ActivityModel(
      id: widget.activityToEdit?.id,
      title: _titleController.text.trim(),
      skillType: skillType,
      duration: int.parse(_durationController.text.trim()),
      difficulty: _selectedDifficulty,
      ageGroup: _selectedAgeGroup,
      instructions: _instructionsController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList(),
      learningGoals: _learningGoalsController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList(),
      materials: _materialsController.text
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .toList(),
      isActive: true,
      createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      createdAt: DateTime.now(),
      updatedAt: widget.activityToEdit != null ? DateTime.now() : null,
    );

    final error = widget.activityToEdit == null
        ? await ActivityService().createActivity(activity)
        : await ActivityService().updateActivity(activity.id!, activity.toMap());

    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
      ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.activityToEdit == null
                ? '✅ Activity added successfully!'
                : '✅ Activity updated successfully!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ManageActivitiesPage()),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    _learningGoalsController.dispose();
    _materialsController.dispose();
    _otherSkillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.activityToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Activity' : 'Add Activity',
          style: AppTextStyles.heading2,
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? '✏️ Edit Activity' : '➕ Create New Activity',
                style: AppTextStyles.heading1.copyWith(fontSize: 22),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isEditing
                    ? 'Update the activity details below'
                    : 'Add a new activity for parents and children',
                style: AppTextStyles.bodyLight,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Title
              _buildTextField(
                controller: _titleController,
                label: 'Activity Title *',
                hint: 'e.g. Animal Sounds Hunt',
                validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Skill Type Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skill Type *',
                    style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _selectedSkillType,
                    isExpanded: true,
                    items: _skillTypes.map((skill) {
                      return DropdownMenuItem(
                        value: skill,
                        child: Text(skill),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSkillType = value!;
                        _showOtherSkillField = value == 'Other (Please Specify)';
                        if (!_showOtherSkillField) {
                          _otherSkillController.clear();
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a skill type';
                      }
                      if (value == 'Other (Please Specify)' &&
                          _otherSkillController.text.trim().isEmpty) {
                        return 'Please specify the skill type';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.small),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.small),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                    ),
                  ),
                  if (_showOtherSkillField) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _otherSkillController,
                      decoration: InputDecoration(
                        hintText: 'Enter custom skill type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.small),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppBorderRadius.small),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      validator: (value) {
                        if (_showOtherSkillField &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Please enter a skill type';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Duration, Difficulty, Age Group
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _durationController,
                      label: 'Duration (min) *',
                      hint: 'e.g. 10',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v!.isEmpty) return 'Enter duration';
                        if (int.tryParse(v) == null) return 'Enter a valid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Difficulty *',
                          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _selectedDifficulty,
                          items: _difficulties.map((d) {
                            return DropdownMenuItem(value: d, child: Text(d));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedDifficulty = v!),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.small),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.small),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Age Group
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Age Group *',
                    style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: _selectedAgeGroup,
                    items: _ageGroups.map((age) {
                      return DropdownMenuItem(
                        value: age,
                        child: Text('$age years'),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedAgeGroup = v!),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.small),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.small),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Instructions
              _buildTextField(
                controller: _instructionsController,
                label: 'Instructions (one per line) *',
                hint: 'Step 1\nStep 2\nStep 3',
                maxLines: 6,
                validator: (v) => v!.isEmpty ? 'Please enter instructions' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Learning Goals
              _buildTextField(
                controller: _learningGoalsController,
                label: 'Learning Goals (one per line)',
                hint: 'Goal 1\nGoal 2\nGoal 3',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),

              // Materials
              _buildTextField(
                controller: _materialsController,
                label: 'Materials Needed (one per line)',
                hint: 'Material 1\nMaterial 2',
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveActivity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Activity' : 'Save Activity',
                          style: AppTextStyles.button,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  void _confirmDelete() {
    if (widget.activityToEdit == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity?'),
        content: Text(
          'Are you sure you want to delete "${widget.activityToEdit!.title}"?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final error = await ActivityService()
                  .deleteActivity(widget.activityToEdit!.id!);
              setState(() => _isLoading = false);
              if (error == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Activity deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageActivitiesPage()),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}