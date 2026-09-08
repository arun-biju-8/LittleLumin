// lib/screens/parent/feedback_form.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../services/ai_service.dart';
import '../../services/journey_service.dart';
import '../../widgets/journey_dialogs.dart';

class FeedbackForm extends StatefulWidget {
  final String? activityId;
  final String? childId;
  final String? parentId;
  final String? activityTitle;

  const FeedbackForm({
    super.key,
    this.activityId,
    this.childId,
    this.parentId,
    this.activityTitle,
  });

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _notesController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AIService _aiService = AIService();

  String? _childResponse;
  String? _engagement;
  String? _difficulty;
  String? _confidence;
  String? _timeEstimate;

  bool _isSubmitting = false;

  final List<String> _childResponseOptions = ['Great', 'Okay', 'Struggled'];
  final List<String> _engagementOptions = ['Very Engaged', 'Somewhat Engaged', 'Not Engaged'];
  final List<String> _difficultyOptions = ['Too Easy', 'Just Right', 'Too Hard'];
  final List<String> _confidenceOptions = ['Very Confident', 'Somewhat Confident', 'Not Confident'];
  final List<String> _timeEstimateOptions = ['Short (< 10 min)', 'Medium (10-20 min)', 'Long (> 20 min)'];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _answeredCount {
    int count = 0;
    if (_childResponse != null) count++;
    if (_engagement != null) count++;
    if (_difficulty != null) count++;
    if (_confidence != null) count++;
    if (_timeEstimate != null) count++;
    return count;
  }

  bool get _isFormComplete => _answeredCount == 5;

  Future<void> _submitFeedback() async {
    if (!_isFormComplete || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUserId = widget.parentId ?? _auth.currentUser?.uid ?? '';
      final childId = widget.childId ?? '';
      final activityId = widget.activityId ?? '';

      // 1. Save feedback entry to Firestore
      await _firestore.collection('feedback').add({
        'childId': childId,
        'activityId': activityId,
        'parentId': currentUserId,
        'childResponse': _childResponse,
        'engagement': _engagement,
        'difficulty': _difficulty,
        'confidence': _confidence,
        'timeEstimate': _timeEstimate,
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Process feedback through AI Service
      final result = await _aiService.processFeedback(
        childId: childId,
        activityId: activityId,
        childResponse: _childResponse!,
        engagement: _engagement!,
        difficulty: _difficulty!,
        confidence: _confidence!,
      );

      // 3. Process Journey progress completion
      final JourneyService journeyService = JourneyService();
      int level = 1;
      final journeyDoc = await _firestore.collection('journeyProgress').doc(childId).get();
      if (journeyDoc.exists && journeyDoc.data() != null) {
        level = (journeyDoc.data()!['currentLevel'] is num)
            ? (journeyDoc.data()!['currentLevel'] as num).toInt()
            : 1;
      }

      final journeyResult = await journeyService.completeActivity(
        childId: childId,
        activityId: activityId,
        level: level,
      );

      if (!mounted) return;

      // 4. Check for Level Complete celebration
      if (journeyResult['levelCompleted'] == true) {
        final completedLevel = (journeyResult['completedLevel'] is num)
            ? (journeyResult['completedLevel'] as num).toInt()
            : level;
        final nextLevel = (journeyResult['nextLevel'] is num)
            ? (journeyResult['nextLevel'] as num).toInt()
            : level + 1;
        final trophyName = journeyResult['trophyEarned']?.toString() ?? 'Level Badge 🏆';

        await JourneyDialogs.showLevelCompleteDialog(
          context: context,
          completedLevel: completedLevel,
          nextLevel: nextLevel,
          trophyEarned: trophyName,
          onContinueJourney: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/parent-dashboard', (route) => false);
          },
          onBrowseActivities: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/parent-dashboard', (route) => false);
          },
        );
        return;
      }

      // 5. Show Flag Alert if child was flagged, or Success SnackBar if not
      if (result.isFlagged) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                SizedBox(width: 8),
                Text('Child Flagged for Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Based on recent activity feedback, your child has experienced multiple struggles in the ${result.domain.toUpperCase()} domain.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Reason: ${result.flagReason ?? "3+ struggles detected"}',
                    style: AppTextStyles.small.copyWith(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'An LLG Specialist has been notified to review your child\'s progress and provide tailored support.',
                  style: AppTextStyles.small,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Understand & Proceed'),
              ),
            ],
          ),
        );
      } else {
        final domainName = result.domain[0].toUpperCase() + result.domain.substring(1);
        final scoreStr = result.scoreChange >= 0
            ? '+${result.scoreChange.toStringAsFixed(1)}'
            : result.scoreChange.toStringAsFixed(1);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Activity Completed! 🎉 $domainName score updated: ${result.newScore.toStringAsFixed(1)} ($scoreStr)',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Navigate back to Parent Dashboard
      Navigator.of(context).pushNamedAndRemoveUntil('/parent-dashboard', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing feedback: $e'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _answeredCount / 5.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Activity Feedback'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Header
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.activityTitle != null && widget.activityTitle!.isNotEmpty) ...[
                    Text(
                      'Activity: ${widget.activityTitle}',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completion Status',
                        style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$_answeredCount of 5 answered',
                        style: AppTextStyles.small.copyWith(
                          color: _isFormComplete ? AppColors.success : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.border.withOpacity(0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isFormComplete ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Form Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Question 1: Child Response
                  _buildQuestionCard(
                    questionNumber: 1,
                    title: 'How did your child respond?',
                    subtitle: 'Overall reaction to the activity',
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    options: _childResponseOptions,
                    selectedValue: _childResponse,
                    onSelected: (val) => setState(() => _childResponse = val),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Question 2: Engagement
                  _buildQuestionCard(
                    questionNumber: 2,
                    title: 'How engaged was your child?',
                    subtitle: 'Level of focus and participation',
                    icon: Icons.psychology_rounded,
                    options: _engagementOptions,
                    selectedValue: _engagement,
                    onSelected: (val) => setState(() => _engagement = val),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Question 3: Difficulty
                  _buildQuestionCard(
                    questionNumber: 3,
                    title: 'Was the difficulty appropriate?',
                    subtitle: 'Challenge level relative to child abilities',
                    icon: Icons.extension_rounded,
                    options: _difficultyOptions,
                    selectedValue: _difficulty,
                    onSelected: (val) => setState(() => _difficulty = val),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Question 4: Confidence
                  _buildQuestionCard(
                    questionNumber: 4,
                    title: 'How confident did your child seem?',
                    subtitle: 'Confidence shown while performing tasks',
                    icon: Icons.stars_rounded,
                    options: _confidenceOptions,
                    selectedValue: _confidence,
                    onSelected: (val) => setState(() => _confidence = val),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Question 5: Time Estimate
                  _buildQuestionCard(
                    questionNumber: 5,
                    title: 'How long did you spend?',
                    subtitle: 'Approximate duration of activity session',
                    icon: Icons.timer_rounded,
                    options: _timeEstimateOptions,
                    selectedValue: _timeEstimate,
                    onSelected: (val) => setState(() => _timeEstimate = val),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Optional Notes
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
                        Row(
                          children: [
                            const Icon(Icons.note_alt_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Additional Observations (Optional)',
                              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Share any notes, special moments, or observations...',
                            hintStyle: AppTextStyles.small,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.small),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.small),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppBorderRadius.small),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),

            // Bottom Submit Bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isFormComplete && !_isSubmitting ? _submitFeedback : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormComplete ? AppColors.success : Colors.grey.shade400,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: AppColors.white,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: _isFormComplete ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isFormComplete ? Icons.check_circle : Icons.edit_note_rounded,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isFormComplete
                                  ? 'Submit Feedback'
                                  : 'Please answer all questions ($_answeredCount/5)',
                              style: AppTextStyles.button.copyWith(
                                color: _isFormComplete ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard({
    required int questionNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    final bool isAnswered = selectedValue != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(
          color: isAnswered ? AppColors.primary.withOpacity(0.5) : AppColors.border,
          width: isAnswered ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isAnswered ? AppColors.primary : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAnswered ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Center(
                  child: isAnswered
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text(
                          '$questionNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.small.copyWith(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: options.map((option) {
              final bool isSelected = selectedValue == option;
              return ChoiceChip(
                label: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.background,
                disabledColor: AppColors.background,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
                elevation: isSelected ? 1 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                onSelected: (bool selected) {
                  if (selected) {
                    onSelected(option);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
