import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/child_model.dart';
import '../../services/child_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/global_header.dart';

class EditChildPage extends StatefulWidget {
  final ChildModel? child;

  const EditChildPage({super.key, this.child});

  @override
  State<EditChildPage> createState() => _EditChildPageState();
}

class _EditChildPageState extends State<EditChildPage> {
  ChildModel? _child;
  final _formKey = GlobalKey<FormState>();
  final bool _isLoading = false;
  bool _isSaving = false;

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDOB;
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
    if (_child != null) {
      _loadData();
    } else {
      _selectedGender = 'Male';
    }
  }

  void _loadData() {
    if (_child == null) return;
    _nameController.text = _child!.name;
    _selectedDOB = _child!.dateOfBirth;
    _dobController.text = DateFormat('dd/MM/yyyy').format(_child!.dateOfBirth);
    _selectedGender = _child!.gender;

    _birthWeightController.text = _child!.birthWeight?.toString() ?? '';
    _heightController.text = _child!.height?.toString() ?? '';
    _weightController.text = _child!.weight?.toString() ?? '';
    _sleepDurationController.text = _child!.sleepDuration?.toString() ?? '';
    _nightWakingsController.text = _child!.nightWakings?.toString() ?? '';
    _birthOrderController.text = _child!.birthOrder?.toString() ?? '';
    _motherAgeController.text = _child!.motherAgeAtConception?.toString() ?? '';
    _fatherAgeController.text = _child!.fatherAgeAtConception?.toString() ?? '';
    _complicationsController.text = _child!.birthComplications ?? '';

    _selectedDeliveryType = _child!.deliveryType;
    _selectedGestationalAge = _child!.gestationalAge;
    _selectedSleepHabit = _child!.sleepHabit;
    _selectedMood = _child!.mood;
    _selectedAttention = _child!.attention;
    _selectedSocialInteraction = _child!.socialInteraction;
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _selectedDOB ?? DateTime(now.year - 4, now.month, now.day);
    final firstDate = DateTime(now.year - 10, now.month, now.day);
    final lastDate = DateTime(now.year - 2, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate)
          ? firstDate
          : (initialDate.isAfter(lastDate) ? lastDate : initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final err = Validators.dateOfBirth(picked);
      if (err != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
        return;
      }
      setState(() {
        _selectedDOB = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDOB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final parentId = user?.uid ?? '';

      if (widget.child == null) {
        // Adding new child
        final docRef = FirebaseFirestore.instance.collection('children').doc();
        final newChild = ChildModel(
          childId: docRef.id,
          parentId: parentId,
          name: _nameController.text.trim(),
          dateOfBirth: _selectedDOB!,
          gender: _selectedGender ?? 'Male',
          deliveryType: _selectedDeliveryType,
          gestationalAge: _selectedGestationalAge,
          birthWeight: _birthWeightController.text.isNotEmpty ? double.tryParse(_birthWeightController.text) : null,
          birthComplications: _complicationsController.text.isNotEmpty ? _complicationsController.text : null,
          birthOrder: _birthOrderController.text.isNotEmpty ? int.tryParse(_birthOrderController.text) : null,
          motherAgeAtConception: _motherAgeController.text.isNotEmpty ? int.tryParse(_motherAgeController.text) : null,
          fatherAgeAtConception: _fatherAgeController.text.isNotEmpty ? int.tryParse(_fatherAgeController.text) : null,
          height: _heightController.text.isNotEmpty ? double.tryParse(_heightController.text) : null,
          weight: _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
          sleepHabit: _selectedSleepHabit,
          sleepDuration: _sleepDurationController.text.isNotEmpty ? int.tryParse(_sleepDurationController.text) : null,
          nightWakings: _nightWakingsController.text.isNotEmpty ? int.tryParse(_nightWakingsController.text) : null,
          mood: _selectedMood,
          attention: _selectedAttention,
          socialInteraction: _selectedSocialInteraction,
          isFlagged: false,
          createdAt: DateTime.now(),
        );

        final error = await ChildService().addChild(
          name: newChild.name,
          dateOfBirth: newChild.dateOfBirth,
          gender: newChild.gender,
        );

        if (error == null) {
          // Save additional fields if provided
          await FirebaseFirestore.instance.collection('children').doc(newChild.childId).update(newChild.toMap());

          if (mounted) {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Child added successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          throw Exception(error);
        }
      } else {
        // Updating existing child
        final updatedChild = ChildModel(
          childId: _child!.childId,
          parentId: _child!.parentId,
          name: _nameController.text.trim(),
          dateOfBirth: _selectedDOB ?? _child!.dateOfBirth,
          gender: _selectedGender ?? _child!.gender,
          deliveryType: _selectedDeliveryType,
          gestationalAge: _selectedGestationalAge,
          birthWeight: _birthWeightController.text.trim().isNotEmpty
              ? double.tryParse(_birthWeightController.text.trim())
              : null,
          birthComplications: _complicationsController.text.trim().isNotEmpty
              ? _complicationsController.text.trim()
              : null,
          birthOrder: _birthOrderController.text.trim().isNotEmpty
              ? int.tryParse(_birthOrderController.text.trim())
              : null,
          motherAgeAtConception: _motherAgeController.text.trim().isNotEmpty
              ? int.tryParse(_motherAgeController.text.trim())
              : null,
          fatherAgeAtConception: _fatherAgeController.text.trim().isNotEmpty
              ? int.tryParse(_fatherAgeController.text.trim())
              : null,
          height: _heightController.text.trim().isNotEmpty
              ? double.tryParse(_heightController.text.trim())
              : null,
          weight: _weightController.text.trim().isNotEmpty
              ? double.tryParse(_weightController.text.trim())
              : null,
          sleepHabit: _selectedSleepHabit,
          sleepDuration: _sleepDurationController.text.trim().isNotEmpty
              ? int.tryParse(_sleepDurationController.text.trim())
              : null,
          nightWakings: _nightWakingsController.text.trim().isNotEmpty
              ? int.tryParse(_nightWakingsController.text.trim())
              : null,
          mood: _selectedMood,
          attention: _selectedAttention,
          socialInteraction: _selectedSocialInteraction,
          isFlagged: _child!.isFlagged,
          flagReason: _child!.flagReason,
          flaggedAt: _child!.flaggedAt,
          createdAt: _child!.createdAt,
          updatedAt: DateTime.now(),
        );

        final error = await ChildService().updateChild(updatedChild);

        setState(() => _isSaving = false);

        if (error == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Profile saved successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          throw Exception(error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final completion = _child?.profileCompletion ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const GlobalHeader(
        showBack: true,
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
                              _child != null && _child!.name.isNotEmpty ? _child!.name[0].toUpperCase() : '👶',
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
                              _child?.name ?? 'New Child',
                              style: AppTextStyles.heading2,
                            ),
                            Text(
                              _child != null ? '${_child!.ageDisplay} • ${_child!.gender}' : 'Enter child details below',
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
                        validator: Validators.name,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDobField(),
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
                              isDecimal: true,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.nonNegativeNumber(v, 'Birth weight', min: 0.5, max: 10, decimals: 2)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _birthOrderController,
                              label: 'Birth Order',
                              hint: 'e.g. 1, 2, 3',
                              isDecimal: false,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.integer(v, 'Birth order', min: 1, max: 20)
                                  : null,
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
                        validator: (v) => (v != null && v.trim().isNotEmpty)
                            ? Validators.safeText(v, 'Birth complications', min: 0, max: 300)
                            : null,
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
                              isDecimal: false,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.integer(v, "Mother's age", min: 14, max: 70)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _fatherAgeController,
                              label: 'Father\'s Age',
                              hint: 'e.g. 30',
                              isDecimal: false,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.integer(v, "Father's age", min: 14, max: 80)
                                  : null,
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
                              isDecimal: true,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.height(v)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _weightController,
                              label: 'Weight (kg)',
                              hint: 'e.g. 16.5',
                              isDecimal: true,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.weight(v)
                                  : null,
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
                              isDecimal: false,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.integer(v, 'Sleep duration', min: 1, max: 24)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _buildNumberField(
                              controller: _nightWakingsController,
                              label: 'Night Wakings (times)',
                              hint: 'e.g. 1',
                              isDecimal: false,
                              validator: (v) => (v != null && v.trim().isNotEmpty)
                                  ? Validators.integer(v, 'Night wakings', min: 0, max: 20)
                                  : null,
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
          autovalidateMode: AutovalidateMode.onUserInteraction,
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

  Widget _buildDobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date of Birth', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: _dobController,
          readOnly: true,
          onTap: () => _selectDate(context),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) => Validators.dateOfBirth(_selectedDOB),
          decoration: InputDecoration(
            hintText: 'DD/MM/YYYY',
            prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
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
        DropdownButtonFormField<String>(
          value: _selectedGender,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
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
          hint: const Text('Select'),
          items: _genders.map((gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender),
            );
          }).toList(),
          validator: Validators.gender,
          onChanged: (value) => setState(() => _selectedGender = value),
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
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
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
          hint: const Text('Select'),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isDecimal = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: [
            if (isDecimal)
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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