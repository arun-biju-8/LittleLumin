// lib/screens/parent/edit_child_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child_model.dart';
import '../../services/child_service.dart';
import '../../utils/constants.dart';

class EditChildPage extends StatefulWidget {
  final ChildModel child;

  const EditChildPage({super.key, required this.child});

  @override
  State<EditChildPage> createState() => _EditChildPageState();
}

class _EditChildPageState extends State<EditChildPage> {
  late ChildModel _child;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthWeightController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _sleepDurationController = TextEditingController();
  final _nightWakingsController = TextEditingController();
  final _birthOrderController = TextEditingController();
  final _motherAgeController = TextEditingController();
  final _fatherAgeController = TextEditingController();
  final _complicationsController = TextEditingController();

  // Dropdown values
  String? _selectedGender;
  String? _selectedDeliveryType;
  String? _selectedGestationalAge;
  String? _selectedSleepHabit;
  String? _selectedMood;
  String? _selectedAttention;
  String? _selectedSocialInteraction;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _deliveryTypes = ['Normal', 'Cesarean'];
  final List<String> _gestationalAges = ['Full-term (≥37 weeks)', 'Premature (<37 weeks)'];
  final List<String> _sleepHabits = ['Good', 'Average', 'Poor'];
  final List<String> _moods = ['Happy', 'Calm', 'Irritable', 'Anxious'];
  final List<String> _attentions = ['Focused', 'Average', 'Distracted'];
  final List<String> _socialInteractions = ['Responsive', 'Selective', 'Avoidant'];

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    _loadData();
  }

  void _loadData() {
    _nameController.text = _child.name;
    _ageController.text = _child.age.toString();
    _selectedGender = _child.gender;

    _birthWeightController.text = _child.birthWeight?.toString() ?? '';
    _heightController.text = _child.height?.toString() ?? '';
    _weightController.text = _child.weight?.toString() ?? '';
    _sleepDurationController.text = _child.sleepDuration?.toString() ?? '';
    _nightWakingsController.text = _child.nightWakings?.toString() ?? '';
    _birthOrderController.text = _child.birthOrder?.toString() ?? '';
    _motherAgeController.text = _child.motherAgeAtConception?.toString() ?? '';
    _fatherAgeController.text = _child.fatherAgeAtConception?.toString() ?? '';
    _complicationsController.text = _child.birthComplications ?? '';

    _selectedDeliveryType = _child.deliveryType;
    _selectedGestationalAge = _child.gestationalAge;
    _selectedSleepHabit = _child.sleepHabit;
    _selectedMood = _child.mood;
    _selectedAttention = _child.attention;
    _selectedSocialInteraction = _child.socialInteraction;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updatedChild = ChildModel(
      childId: _child.childId,
      parentId: _child.parentId,
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text.trim()),
      gender: _selectedGender ?? _child.gender,
      deliveryType: _selectedDeliveryType,
      gestationalAge: _selectedGestationalAge,
      birthWeight: _birthWeightController.text.isNotEmpty
          ? double.parse(_birthWeightController.text)
          : null,
      birthComplications: _complicationsController.text.isNotEmpty
          ? _complicationsController.text
          : null,
      birthOrder: _birthOrderController.text.isNotEmpty
          ? int.parse(_birthOrderController.text)
          : null,
      motherAgeAtConception: _motherAgeController.text.isNotEmpty
          ? int.parse(_motherAgeController.text)
          : null,
      fatherAgeAtConception: _fatherAgeController.text.isNotEmpty
          ? int.parse(_fatherAgeController.text)
          : null,
      height: _heightController.text.isNotEmpty
          ? double.parse(_heightController.text)
          : null,
      weight: _weightController.text.isNotEmpty
          ? double.parse(_weightController.text)
          : null,
      sleepHabit: _selectedSleepHabit,
      sleepDuration: _sleepDurationController.text.isNotEmpty
          ? int.parse(_sleepDurationController.text)
          : null,
      nightWakings: _nightWakingsController.text.isNotEmpty
          ? int.parse(_nightWakingsController.text)
          : null,
      mood: _selectedMood,
      attention: _selectedAttention,
      socialInteraction: _selectedSocialInteraction,
      isFlagged: _child.isFlagged,
      flagReason: _child.flagReason,
      flaggedAt: _child.flaggedAt,
      createdAt: _child.createdAt,
      updatedAt: DateTime.now(),
    );

    final error = await ChildService().updateChild(updatedChild);

    setState(() => _isSaving = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completion = _child.profileCompletion;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Edit ${_child.name}\'s Profile', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: AppColors.primary),
            onPressed: _isSaving ? null : _saveProfile,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Completion Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar with progress ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              value: completion / 100,
                              strokeWidth: 6,
                              backgroundColor: Colors.grey[200],
                              color: completion >= 80
                                  ? AppColors.success
                                  : completion >= 50
                                      ? AppColors.primary
                                      : AppColors.warning,
                            ),
                          ),
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: Text(
                              _child.name[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _child.name,
                              style: AppTextStyles.heading2,
                            ),
                            Text(
                              '${_child.age} years • ${_child.gender}',
                              style: AppTextStyles.bodyLight,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Icon(
                                  completion >= 80
                                      ? Icons.check_circle
                                      : Icons.info_outline,
                                  size: 16,
                                  color: completion >= 80
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '$completion% complete',
                                  style: AppTextStyles.small.copyWith(
                                    color: completion >= 80
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== BASIC INFORMATION =====
                      _buildSectionTitle('Basic Information', Icons.person_outline),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Child\'s Name',
                        hint: 'Enter child\'s name',
                        icon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAgeField(),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildGenderDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ===== BIRTH INFORMATION =====
                      _buildSectionTitle('Birth Information', Icons.family_restroom),
                      _buildDropdownField(
                        label: 'Delivery Type',
                        value: _selectedDeliveryType,
                        items: _deliveryTypes,
                        onChanged: (v) => setState(() => _selectedDeliveryType = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownField(
                        label: 'Gestational Age',
                        value: _selectedGestationalAge,
                        items: _gestationalAges,
                        onChanged: (v) => setState(() => _selectedGestationalAge = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _birthWeightController,
                              label: 'Birth Weight (kg)',
                              hint: 'e.g. 3.2',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _birthOrderController,
                              label: 'Birth Order',
                              hint: 'e.g. 1, 2, 3',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildTextField(
                        controller: _complicationsController,
                        label: 'Birth Complications (Optional)',
                        hint: 'e.g. Jaundice, oxygen support, etc.',
                        icon: Icons.medical_information,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ===== PARENT INFORMATION =====
                      _buildSectionTitle('Parent Information', Icons.people_outline),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _motherAgeController,
                              label: 'Mother\'s Age',
                              hint: 'e.g. 28',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _fatherAgeController,
                              label: 'Father\'s Age',
                              hint: 'e.g. 30',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ===== CURRENT INFORMATION =====
                      _buildSectionTitle('Current Measurements', Icons.straighten),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _heightController,
                              label: 'Height (cm)',
                              hint: 'e.g. 105',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _weightController,
                              label: 'Weight (kg)',
                              hint: 'e.g. 16.5',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ===== SLEEP INFORMATION =====
                      _buildSectionTitle('Sleep Habits', Icons.nightlight_round),
                      _buildDropdownField(
                        label: 'Sleep Quality',
                        value: _selectedSleepHabit,
                        items: _sleepHabits,
                        onChanged: (v) => setState(() => _selectedSleepHabit = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              controller: _sleepDurationController,
                              label: 'Sleep Duration (hours/day)',
                              hint: 'e.g. 10',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _nightWakingsController,
                              label: 'Night Wakings (times)',
                              hint: 'e.g. 1',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ===== BEHAVIOR OBSERVATIONS =====
                      _buildSectionTitle('Behavior Observations', Icons.psychology),
                      _buildDropdownField(
                        label: 'Mood/Emotion',
                        value: _selectedMood,
                        items: _moods,
                        onChanged: (v) => setState(() => _selectedMood = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownField(
                        label: 'Attention/Focus',
                        value: _selectedAttention,
                        items: _attentions,
                        onChanged: (v) => setState(() => _selectedAttention = v),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildDropdownField(
                        label: 'Social Interaction',
                        value: _selectedSocialInteraction,
                        items: _socialInteractions,
                        onChanged: (v) => setState(() => _selectedSocialInteraction = v),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Save Profile',
                                  style: AppTextStyles.button,
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            title,
            style: AppTextStyles.heading2.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildAgeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Age', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v!.isEmpty) return 'Please enter age';
            if (int.tryParse(v) == null) return 'Enter a valid number';
            if (int.parse(v) < 1 || int.parse(v) > 12) return 'Age must be 1-12';
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Age in years',
            prefixIcon: Icon(Icons.cake, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppBorderRadius.small),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              isExpanded: true,
              hint: const Text('Select'),
              items: _genders.map((gender) {
                return DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedGender = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppBorderRadius.small),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: const Text('Select'),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.small),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}