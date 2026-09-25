import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../models/child_model.dart';
import '../../../../services/ai_generation_service.dart';
import '../../../../services/saved_items_service.dart';
import '../../../../utils/validators.dart';
import '../../parent_theme.dart';

class AIStoryTab extends StatefulWidget {
  final ChildModel? activeChild;

  const AIStoryTab({
    super.key,
    required this.activeChild,
  });

  @override
  State<AIStoryTab> createState() => _AIStoryTabState();
}

class _AIStoryTabState extends State<AIStoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AIGenerationService _aiService = AIGenerationService();
  final SavedItemsService _savedService = SavedItemsService();
  final TextEditingController _childNameController = TextEditingController();

  bool _isGenerating = false;
  Map<String, dynamic>? _generatedStory;
  bool _isSaving = false;
  bool _isSaved = false;

  String _selectedTheme = 'Adventure';
  String _childName = '';

  final List<String> _themes = [
    'Adventure',
    'Friendship',
    'Sharing',
    'Kindness',
    'Courage',
    'Bedtime',
  ];

  @override
  void initState() {
    super.initState();
    _syncChildName();
  }

  @override
  void didUpdateWidget(covariant AIStoryTab oldWidget) {
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

  Future<void> _generateStory() async {
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
      _generatedStory = null;
      _isSaved = false;
    });

    try {
      final story = await _aiService.generateStory(
        topicOrMoral: _selectedTheme,
        childName: _childName.isEmpty ? 'Little Explorer' : _childName,
        ageYears: widget.activeChild?.ageInYears ?? 4,
      );
      if (mounted) {
        setState(() {
          _generatedStory = story;
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

  Future<void> _saveStory() async {
    if (_generatedStory == null) return;

    setState(() => _isSaving = true);

    try {
      final childId = widget.activeChild?.childId ?? 'unknown';
      await _savedService.saveStory(
        story: _generatedStory!,
        childId: childId,
      );

      if (mounted) {
        setState(() => _isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Story saved to Library'),
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
                  gradient: LinearGradient(
                    colors: [ParentColors.accent, Color(0xFFF59E0B)],
                  ),
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

  Widget _buildStoryResult(Map<String, dynamic> story) {
    final storyText = story['story'] ?? story['storyContent'] ?? story['content'] ?? '';
    final moralText = story['moral'] ?? story['moralLesson'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ParentRadius.card,
        border: Border.all(color: ParentColors.accent.withOpacity(0.5), width: 1.5),
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
                'Story Ready!',
                style: ParentTypography.cardTitle.copyWith(
                  fontSize: 16,
                  color: ParentColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            story['title'] ?? 'Generated Story',
            style: ParentTypography.title.copyWith(fontSize: 19),
          ),
          const SizedBox(height: 12),
          Text(
            storyText,
            style: ParentTypography.body.copyWith(
              height: 1.6,
              fontSize: 14,
            ),
          ),
          if (moralText.toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParentColors.accent.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌟', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moral Lesson',
                          style: ParentTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$moralText',
                          style: ParentTypography.body.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF92400E),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateStory,
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
                  onPressed: _isSaved ? null : _saveStory,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded, size: 18),
                  label: Text(_isSaved ? 'Saved' : 'Save Story'),
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
                colors: [Color(0xFFFEF3C7), Color(0xFFEDE9FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: ParentRadius.card,
              border: Border.all(color: ParentColors.accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('📖', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Story Creator',
                        style: ParentTypography.cardTitle.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Create personalized stories starring your child with meaningful morals.',
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
                prefixIcon: const Icon(Icons.face_rounded, color: ParentColors.primary, size: 20),
              ),
              onChanged: (val) => setState(() => _childName = val),
            ),
          ),
          const SizedBox(height: 16),

          // Step 2: Story Theme
          _buildStepCard(
            stepNumber: 2,
            title: 'Story Theme',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _themes.map((theme) {
                final isSelected = _selectedTheme == theme;
                return ChoiceChip(
                  label: Text(theme),
                  selected: isSelected,
                  selectedColor: ParentColors.accent.withOpacity(0.2),
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: ParentRadius.chip,
                  ),
                  side: BorderSide(
                    color: isSelected ? ParentColors.accent : ParentColors.surfaceAlt,
                    width: 1.2,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? const Color(0xFF92400E) : ParentColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedTheme = theme);
                  },
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
                onPressed: _isGenerating ? null : _generateStory,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_stories_rounded, size: 20),
                label: Text(
                  _isGenerating ? 'Writing Story...' : '📖 Generate AI Story',
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
          if (_generatedStory != null) ...[
            const SizedBox(height: 20),
            _buildStoryResult(_generatedStory!),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
