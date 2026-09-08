// lib/screens/parent/ai_activity_generator.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constants.dart';
import '../../models/activity_model.dart';
import '../../services/ai_generation_service.dart';

class AIActivityGeneratorScreen extends StatefulWidget {
  const AIActivityGeneratorScreen({super.key});

  @override
  State<AIActivityGeneratorScreen> createState() => _AIActivityGeneratorScreenState();
}

class _AIActivityGeneratorScreenState extends State<AIActivityGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AIGenerationService _aiService = AIGenerationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Activity Generator State
  String _selectedDomain = 'Cognitive';
  String _selectedDifficulty = 'Medium';
  final TextEditingController _childNameController = TextEditingController();
  final int _selectedAge = 4;

  bool _isGeneratingActivity = false;
  ActivityModel? _generatedActivity;
  bool _isSavingActivity = false;
  bool _isActivitySaved = false;

  // Story Generator State
  final TextEditingController _storyChildNameController = TextEditingController();
  String _selectedMoralTopic = 'Sharing and Kindness';
  bool _isGeneratingStory = false;
  Map<String, dynamic>? _generatedStory;
  bool _isSavingStory = false;
  bool _isStorySaved = false;

  final List<String> _domains = [
    'Cognitive',
    'Language',
    'Motor',
    'Social',
    'Emotional',
    'Creative',
  ];

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];

  final List<String> _moralTopics = [
    'Sharing and Kindness',
    'Courage and Bravery',
    'Honesty and Truth',
    'Curiosity and Learning',
    'Empathy and Respect',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _childNameController.dispose();
    _storyChildNameController.dispose();
    super.dispose();
  }

  Future<void> _generateActivity() async {
    setState(() {
      _isGeneratingActivity = true;
      _isActivitySaved = false;
      _generatedActivity = null;
    });

    try {
      final activity = await _aiService.generateActivity(
        skillDomain: _selectedDomain,
        difficulty: _selectedDifficulty,
        ageYears: _selectedAge,
        childName: _childNameController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _generatedActivity = activity;
      });
    } catch (e) {
      if (!mounted) return;

      final cleanError = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to generate activity: $cleanError'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingActivity = false;
        });
      }
    }
  }

  Future<void> _saveActivityToFirestore() async {
    if (_generatedActivity == null || _isSavingActivity) return;

    setState(() => _isSavingActivity = true);

    try {
      final user = _auth.currentUser;
      final docRef = _firestore.collection('activities').doc();

      final mapData = _generatedActivity!.toMap();
      mapData['createdBy'] = user?.uid ?? 'parent';
      mapData['createdByName'] = user?.displayName ?? 'Parent';

      await docRef.set(mapData);

      if (!mounted) return;

      setState(() {
        _isSavingActivity = false;
        _isActivitySaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ AI Activity saved to your activities collection!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingActivity = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving activity: $e'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _generateStory() async {
    setState(() {
      _isGeneratingStory = true;
      _isStorySaved = false;
      _generatedStory = null;
    });

    final name = _storyChildNameController.text.trim().isEmpty
        ? (_childNameController.text.trim().isEmpty ? 'Little Explorer' : _childNameController.text.trim())
        : _storyChildNameController.text.trim();

    try {
      final story = await _aiService.generateStory(
        childName: name,
        topicOrMoral: _selectedMoralTopic,
        ageYears: _selectedAge,
      );

      if (!mounted) return;

      setState(() {
        _generatedStory = story;
      });
    } catch (e) {
      if (!mounted) return;

      final cleanError = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to generate story: $cleanError'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingStory = false;
        });
      }
    }
  }

  Future<void> _saveStoryToFirestore() async {
    if (_generatedStory == null || _isSavingStory) return;

    setState(() => _isSavingStory = true);

    try {
      final user = _auth.currentUser;
      await _firestore.collection('stories').add({
        'parentId': user?.uid ?? '',
        'childName': _generatedStory!['childName'],
        'title': _generatedStory!['title'],
        'theme': _generatedStory!['theme'],
        'characters': _generatedStory!['characters'],
        'storyContent': _generatedStory!['storyContent'],
        'moralLesson': _generatedStory!['moralLesson'],
        'discussionQuestions': _generatedStory!['discussionQuestions'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _isSavingStory = false;
        _isStorySaved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Personalized Story saved successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingStory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving story: $e'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Activity & Story Generator'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'AI Activity'),
            Tab(icon: Icon(Icons.auto_stories), text: 'Personalized Story'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityGeneratorTab(),
          _buildStoryGeneratorTab(),
        ],
      ),
    );
  }

  Widget _buildActivityGeneratorTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Header Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A90D9), Color(0xFF6C5CE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          ),
          child: Row(
            children: [
              const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screen-Free AI Generator',
                      style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Instantly generate custom learning activities using everyday household materials.',
                      style: AppTextStyles.small.copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Controls Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Skill Domain Selector
              Text('Select Skill Domain', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _domains.map((dom) {
                  final isSelected = _selectedDomain == dom;
                  return ChoiceChip(
                    label: Text(dom),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.background,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedDomain = dom);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Difficulty Selector
              Text('Select Difficulty', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _difficulties.map((diff) {
                  final isSelected = _selectedDifficulty == diff;
                  return ChoiceChip(
                    label: Text(diff),
                    selected: isSelected,
                    selectedColor: AppColors.secondary,
                    backgroundColor: AppColors.background,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedDifficulty = diff);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Optional Child Name Input
              TextField(
                controller: _childNameController,
                decoration: InputDecoration(
                  labelText: "Child's Name (Optional)",
                  hintText: 'e.g. Leo',
                  prefixIcon: const Icon(Icons.child_care, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingActivity ? null : _generateActivity,
                  icon: _isGeneratingActivity
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, color: Colors.white),
                  label: Text(
                    _isGeneratingActivity ? 'Contacting OpenAI Server...' : 'Generate Screen-Free Activity',
                    style: AppTextStyles.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Loading Indicator Card
        if (_isGeneratingActivity) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Generating custom screen-free activity with OpenAI...',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                SizedBox(height: 4),
                Text('This takes about 3-5 seconds. Please wait.', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
        ],

        // Generated Activity Display
        if (_generatedActivity != null && !_isGeneratingActivity) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity Header Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.nature_people_rounded, size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('Screen-Free', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_generatedActivity!.duration} min',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(_generatedActivity!.difficulty),
                      backgroundColor: AppColors.secondary.withOpacity(0.1),
                      labelStyle: const TextStyle(fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.bold),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title & Description
                Text(_generatedActivity!.title, style: AppTextStyles.heading2),
                const SizedBox(height: 6),
                Text(_generatedActivity!.shortDescription ?? '', style: AppTextStyles.bodyLight),
                const Divider(height: 24),

                // Learning Goals
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: 6),
                    Text('Learning Goals', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ..._generatedActivity!.learningGoals.map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(goal, style: AppTextStyles.small)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Household Materials Needed
                Row(
                  children: [
                    const Icon(Icons.home_repair_service_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Text('Household Materials Needed', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _generatedActivity!.materials.map(
                    (mat) => Chip(
                      avatar: const Icon(Icons.check, size: 14, color: AppColors.primary),
                      label: Text(mat, style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ).toList(),
                ),
                const SizedBox(height: 12),

                // Instructions
                Row(
                  children: [
                    const Icon(Icons.format_list_numbered_rounded, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 6),
                    Text('Step-by-Step Instructions', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._generatedActivity!.instructions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppColors.secondary,
                          child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.value, style: AppTextStyles.small)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingActivity ? null : _generateActivity,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerate'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSavingActivity || _isActivitySaved ? null : _saveActivityToFirestore,
                        icon: _isSavingActivity
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_isActivitySaved ? Icons.check : Icons.bookmark_add),
                        label: Text(_isActivitySaved ? 'Saved!' : 'Save Activity'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStoryGeneratorTab() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Header Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7675), Color(0xFF6C5CE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personalized AI Storyteller',
                      style: AppTextStyles.heading2.copyWith(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate custom stories featuring your child as the main hero with a positive moral lesson.',
                      style: AppTextStyles.small.copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Controls Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child Name Input
              TextField(
                controller: _storyChildNameController,
                decoration: InputDecoration(
                  labelText: "Child's Hero Name",
                  hintText: 'e.g. Maya or Leo',
                  prefixIcon: const Icon(Icons.face, color: AppColors.secondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Moral Topic Selector
              Text('Select Story Theme / Moral Lesson', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _moralTopics.map((top) {
                  final isSelected = _selectedMoralTopic == top;
                  return ChoiceChip(
                    label: Text(top),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6C5CE7),
                    backgroundColor: AppColors.background,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedMoralTopic = top);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingStory ? null : _generateStory,
                  icon: _isGeneratingStory
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_stories, color: Colors.white),
                  label: Text(
                    _isGeneratingStory ? 'Crafting Story with OpenAI...' : 'Generate Personalized Story',
                    style: AppTextStyles.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Loading Indicator Card
        if (_isGeneratingStory) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
            ),
            child: Column(
              children: const [
                CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                SizedBox(height: 16),
                Text(
                  'Crafting personalized story via OpenAI...',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7)),
                ),
                SizedBox(height: 4),
                Text('This takes about 3-5 seconds. Please wait.', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
        ],

        // Generated Story Display
        if (_generatedStory != null && !_isGeneratingStory) ...[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_generatedStory!['title'] ?? 'Story', style: AppTextStyles.heading2),
                const SizedBox(height: 6),

                // Characters Chips
                Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 6),
                    Text('Characters: ', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        (_generatedStory!['characters'] as List? ?? []).join(', '),
                        style: AppTextStyles.small,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Story Narrative Content
                Text(
                  _generatedStory!['storyContent'] ?? '',
                  style: AppTextStyles.body.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),

                // Moral Box
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                    border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: Color(0xFF6C5CE7), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Moral Lesson', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                            Text(_generatedStory!['moralLesson'] ?? '', style: AppTextStyles.small),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Discussion Questions
                if (_generatedStory!['discussionQuestions'] != null) ...[
                  Text('Discussion Questions for Parents:', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...(_generatedStory!['discussionQuestions'] as List).map(
                    (q) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('❓ $q', style: AppTextStyles.small),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingStory ? null : _generateStory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Regenerate'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSavingStory || _isStorySaved ? null : _saveStoryToFirestore,
                        icon: _isSavingStory
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(_isStorySaved ? Icons.check : Icons.bookmark_add),
                        label: Text(_isStorySaved ? 'Saved!' : 'Save Story'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
