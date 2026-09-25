import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../models/child_model.dart';
import '../../../../models/activity_model.dart';
import '../../../../services/ai_generation_service.dart';
import '../../../../services/saved_items_service.dart';
import '../../../../services/activity_state_service.dart';
import '../../activity_view.dart';
import '../../../../utils/validators.dart';
import '../../parent_theme.dart';

class AIActivityTab extends StatefulWidget {
  final ChildModel? activeChild;

  const AIActivityTab({
    super.key,
    required this.activeChild,
  });

  @override
  State<AIActivityTab> createState() => _AIActivityTabState();
}

class _AIActivityTabState extends State<AIActivityTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AIGenerationService _aiService = AIGenerationService();
  final SavedItemsService _savedService = SavedItemsService();
  final TextEditingController _childNameController = TextEditingController();

  bool _isGenerating = false;
  ActivityModel? _generatedActivity;
  bool _isSaving = false;
  bool _isSaved = false;

  String _selectedSkill = 'Cognitive';
  String _selectedDifficulty = 'Medium';
  String _childName = '';

  final List<String> _skills = [
    'Cognitive',
    'Language',
    'Motor',
    'Social',
    'Emotional',
    'Creative',
  ];
  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _syncChildName();
  }

  @override
  void didUpdateWidget(covariant AIActivityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChild?.childId != widget.activeChild?.childId) {
      _syncChildName();
    }
  }

  void _syncChildName() {
    if (widget.activeChild != null) {
      _childName = widget.activeChild!.name;
      _childNameController.text = widget.activeChild!.name;
    }
  }

  @override
  void dispose() {
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _generateActivity() async {
    final trimmedName = _childName.trim();
    if (trimmedName.isNotEmpty) {
      final nameErr = Validators.name(trimmedName);
      if (nameErr != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid child name: $nameErr'),
            backgroundColor: ParentColors.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isGenerating = true;
      _generatedActivity = null;
      _isSaved = false;
    });

    try {
      final activity = await _aiService.generateActivity(
        skillDomain: _selectedSkill,
        difficulty: _selectedDifficulty,
        ageYears: widget.activeChild?.ageInYears ?? 4,
        childName: _childName.isEmpty ? 'Little Explorer' : _childName,
      );
      if (mounted) {
        setState(() {
          _generatedActivity = activity;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: ParentColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveActivity() async {
    if (_generatedActivity == null) return;

    setState(() => _isSaving = true);

    try {
      final childId = widget.activeChild?.childId ?? 'unknown';
      await _savedService.saveActivity(
        activity: _generatedActivity!,
        childId: childId,
      );

      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Activity saved to Library'),
            backgroundColor: ParentColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: ParentColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ParentRadius.card,
        boxShadow: ParentShadows.card,
        border: Border.all(color: ParentColors.surfaceAlt, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  gradient: ParentColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stepNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: ParentTypography.cardTitle.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildActivityResult(ActivityModel activity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ParentRadius.card,
        border: Border.all(color: ParentColors.success.withOpacity(0.4), width: 1.5),
        boxShadow: ParentShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: ParentColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: ParentColors.success, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Activity Ready!',
                style: ParentTypography.cardTitle.copyWith(
                  fontSize: 16,
                  color: ParentColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            activity.title,
            style: ParentTypography.title.copyWith(fontSize: 19),
          ),
          if (activity.shortDescription != null && activity.shortDescription!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              activity.shortDescription!,
              style: ParentTypography.bodyLight,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '📋 Instructions:',
            style: ParentTypography.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...activity.instructions.map(
            (inst) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: ParentColors.primary)),
                  Expanded(
                    child: Text(
                      inst,
                      style: ParentTypography.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (activity.materials.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '📦 Materials Needed:',
              style: ParentTypography.body.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              activity.materials.join(', '),
              style: ParentTypography.caption.copyWith(color: ParentColors.textPrimary),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                final childId = widget.activeChild?.childId ?? '';
                if (childId.isNotEmpty) {
                  await ActivityStateService().startActivity(
                    childId: childId,
                    activityId: activity.id ?? 'ai_${DateTime.now().millisecondsSinceEpoch}',
                    activityTitle: activity.title,
                    skillDomain: activity.skillType,
                  );
                }
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityView(
                      activity: activity,
                      childId: widget.activeChild?.childId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Start Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: ParentColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateActivity,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ParentColors.primary,
                    side: const BorderSide(color: ParentColors.primaryLight),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ParentRadius.button,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaved ? null : _saveActivity,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded, size: 18),
                  label: Text(_isSaved ? 'Saved' : 'Save to Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParentColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ParentRadius.button,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEDE9FE), Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: ParentRadius.card,
              border: Border.all(color: ParentColors.primary.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('✨', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Activity Creator',
                        style: ParentTypography.cardTitle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Instant personalized games adapted to your child\'s age and goals.',
                        style: ParentTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step 1: Child Name
          _buildStepCard(
            stepNumber: 1,
            title: 'Child Name',
            child: TextField(
              controller: _childNameController,
              style: ParentTypography.body,
              decoration: InputDecoration(
                hintText: 'Enter child name',
                hintStyle: ParentTypography.bodyLight,
                border: OutlineInputBorder(borderRadius: ParentRadius.input),
                enabledBorder: OutlineInputBorder(
                  borderRadius: ParentRadius.input,
                  borderSide: BorderSide(color: ParentColors.surfaceAlt),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: ParentRadius.input,
                  borderSide: BorderSide(color: ParentColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: ParentColors.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                prefixIcon: const Icon(Icons.child_care_rounded, color: ParentColors.primary, size: 20),
              ),
              onChanged: (val) => setState(() => _childName = val),
            ),
          ),
          const SizedBox(height: 16),

          // Step 2: Skill Area
          _buildStepCard(
            stepNumber: 2,
            title: 'Choose Skill Area',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((skill) {
                final isSelected = _selectedSkill == skill;
                return ChoiceChip(
                  label: Text(skill),
                  selected: isSelected,
                  selectedColor: ParentColors.primary,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: ParentRadius.chip,
                  ),
                  side: BorderSide(
                    color: isSelected ? ParentColors.primary : ParentColors.surfaceAlt,
                    width: 1.2,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : ParentColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedSkill = skill);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Step 3: Difficulty
          _buildStepCard(
            stepNumber: 3,
            title: 'Difficulty Level',
            child: Row(
              children: _difficulties.map((diff) {
                final isSelected = _selectedDifficulty == diff;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: () => setState(() => _selectedDifficulty = diff),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? ParentColors.primary : ParentColors.surfaceAlt,
                        foregroundColor: isSelected ? Colors.white : ParentColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: isSelected ? 2 : 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: ParentRadius.button,
                        ),
                      ),
                      child: Text(
                        diff,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Generate CTA Button (56px)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: const BoxDecoration(
                gradient: ParentColors.primaryGradient,
                borderRadius: ParentRadius.button,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x336C4AB6),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateActivity,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 20),
                label: Text(
                  _isGenerating ? 'Generating Activity...' : '✨ Generate AI Activity',
                  style: ParentTypography.button.copyWith(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: ParentRadius.button,
                  ),
                ),
              ),
            ),
          ),

          // Result section
          if (_generatedActivity != null) ...[
            const SizedBox(height: 20),
            _buildActivityResult(_generatedActivity!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
