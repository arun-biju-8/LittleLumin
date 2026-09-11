import 'package:flutter/material.dart';
import '../../models/activity_model.dart';
import '../../models/child_model.dart';
import '../../services/ai_generation_service.dart';
import '../../services/saved_items_service.dart';

class AIActivityGeneratorScreen extends StatefulWidget {
  final ChildModel? child;
  
  const AIActivityGeneratorScreen({super.key, this.child});

  @override
  State<AIActivityGeneratorScreen> createState() => _AIActivityGeneratorScreenState();
}

class _AIActivityGeneratorScreenState extends State<AIActivityGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AIGenerationService _aiService = AIGenerationService();
  final SavedItemsService _savedService = SavedItemsService();
  
  // Activity state
  bool _isGeneratingActivity = false;
  ActivityModel? _generatedActivity;
  bool _isSavingActivity = false;
  bool _isActivitySaved = false;
  
  // Story state
  bool _isGeneratingStory = false;
  Map<String, dynamic>? _generatedStory;
  bool _isSavingStory = false;
  bool _isStorySaved = false;
  
  // User selections
  String _selectedSkill = 'Cognitive';
  String _selectedDifficulty = 'Medium';
  String _childName = '';
  final TextEditingController _childNameController = TextEditingController();
  String _selectedStoryTheme = 'Adventure';

  final List<String> _skills = ['Cognitive', 'Language', 'Motor', 'Social', 'Emotional', 'Creative'];
  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  final List<String> _storyThemes = ['Adventure', 'Friendship', 'Sharing', 'Kindness', 'Courage', 'Bedtime'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.child != null) {
      _childName = widget.child!.name;
      _childNameController.text = widget.child!.name;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _childNameController.dispose();
    super.dispose();
  }

  Future<void> _generateActivity() async {
    setState(() {
      _isGeneratingActivity = true;
      _generatedActivity = null;
      _isActivitySaved = false;
    });

    try {
      final activity = await _aiService.generateActivity(
        skillDomain: _selectedSkill,
        difficulty: _selectedDifficulty,
        ageYears: widget.child?.ageInYears ?? 4,
        childName: _childName.isEmpty ? 'Little Explorer' : _childName,
      );
      if (mounted) {
        setState(() {
          _generatedActivity = activity;
          _isGeneratingActivity = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingActivity = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _saveActivityToFirestore() async {
    if (_generatedActivity == null) {
      debugPrint('❌ No activity to save');
      return;
    }

    setState(() => _isSavingActivity = true);

    try {
      final childId = widget.child?.childId ?? 'unknown';
      await _savedService.saveActivity(
        activity: _generatedActivity!,
        childId: childId,
      );

      if (mounted) {
        setState(() => _isActivitySaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('✅ Activity saved to My Library')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Failed to save: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingActivity = false);
    }
  }

  Future<void> _generateStory() async {
    setState(() {
      _isGeneratingStory = true;
      _generatedStory = null;
      _isStorySaved = false;
    });

    try {
      final story = await _aiService.generateStory(
        childName: _childName.isEmpty ? 'Little Explorer' : _childName,
        topicOrMoral: _selectedStoryTheme,
        ageYears: widget.child?.ageInYears ?? 4,
      );
      if (mounted) {
        setState(() {
          _generatedStory = story;
          _isGeneratingStory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingStory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveStoryToFirestore() async {
    if (_generatedStory == null) {
      debugPrint('❌ No story to save');
      return;
    }

    setState(() => _isSavingStory = true);

    try {
      final childId = widget.child?.childId ?? 'unknown';
      await _savedService.saveStory(
        story: _generatedStory!,
        childId: childId,
      );

      if (mounted) {
        setState(() => _isStorySaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('✅ Story saved to My Library')),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('❌ Failed to save: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingStory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Generator'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Activity'),
            Tab(icon: Icon(Icons.book), text: 'Story'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          _buildStoryTab(),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Child Name
          _buildStepCard(
            stepNumber: 1,
            title: 'Child Name',
            child: TextField(
              controller: _childNameController,
              decoration: InputDecoration(
                hintText: 'Enter child name (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.child_care, color: Colors.purple),
              ),
              onChanged: (val) => setState(() => _childName = val),
            ),
          ),
          const SizedBox(height: 16),

          // Step 2: Skill
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
                  selectedColor: Colors.purple.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.purple.shade900 : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                        backgroundColor: isSelected ? Colors.purple.shade700 : Colors.grey.shade200,
                        foregroundColor: isSelected ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: isSelected ? 2 : 0,
                      ),
                      child: Text(diff, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Generate Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingActivity ? null : _generateActivity,
              icon: _isGeneratingActivity
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGeneratingActivity ? 'Generating...' : 'Generate Activity',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Result
          if (_generatedActivity != null) ...[
            const SizedBox(height: 24),
            _buildActivityResult(_generatedActivity!),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCard({required int stepNumber, required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.purple.shade700,
                  child: Text('$stepNumber', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildActivityResult(ActivityModel activity) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text('Activity Ready!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Text(activity.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (activity.shortDescription != null && activity.shortDescription!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(activity.shortDescription!, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 16),
            const Text('📋 Instructions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            ...activity.instructions.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            ),
            if (activity.materials.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('📦 Materials:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              ...activity.materials.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $m'),
              )),
            ],
            if (activity.learningGoals.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('🎯 Learning Goals:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              ...activity.learningGoals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $g'),
              )),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingActivity ? null : _generateActivity,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSavingActivity || _isActivitySaved ? null : _saveActivityToFirestore,
                    icon: _isSavingActivity
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isActivitySaved ? Icons.check : Icons.bookmark_add),
                    label: Text(_isActivitySaved ? 'Saved!' : 'Save Activity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepCard(
            stepNumber: 1,
            title: 'Child Name',
            child: TextField(
              controller: _childNameController,
              decoration: InputDecoration(
                hintText: 'Enter child name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: const Icon(Icons.face, color: Colors.purple),
              ),
              onChanged: (val) => setState(() => _childName = val),
            ),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            stepNumber: 2,
            title: 'Story Theme',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _storyThemes.map((theme) {
                final isSelected = _selectedStoryTheme == theme;
                return ChoiceChip(
                  label: Text(theme),
                  selected: isSelected,
                  selectedColor: Colors.purple.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.purple.shade900 : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedStoryTheme = theme);
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingStory ? null : _generateStory,
              icon: _isGeneratingStory
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.book),
              label: Text(
                _isGeneratingStory ? 'Creating Story...' : 'Generate Story',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_generatedStory != null) ...[
            const SizedBox(height: 24),
            _buildStoryResult(_generatedStory!),
          ],
        ],
      ),
    );
  }

  Widget _buildStoryResult(Map<String, dynamic> story) {
    final storyText = story['story'] ?? story['storyContent'] ?? '';
    final moralText = story['moral'] ?? story['moralLesson'] ?? '';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text('Story Ready!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24),
            Text(story['title'] ?? 'Story', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(storyText, style: const TextStyle(height: 1.6, fontSize: 15)),
            if (moralText.toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 20)),
                    Expanded(
                      child: Text('Moral: $moralText', style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
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
                    onPressed: _isGeneratingStory ? null : _generateStory,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSavingStory || _isStorySaved ? null : _saveStoryToFirestore,
                    icon: _isSavingStory
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isStorySaved ? Icons.check : Icons.bookmark_add),
                    label: Text(_isStorySaved ? 'Saved!' : 'Save Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
