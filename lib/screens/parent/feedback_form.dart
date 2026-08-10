// lib/screens/parent/feedback_form.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/constants.dart';
import 'parent_dashboard.dart';

class FeedbackForm extends StatefulWidget {
  final String childId;
  final String activityId;
  final String activityTitle;

  const FeedbackForm({
    super.key,
    required this.childId,
    required this.activityId,
    required this.activityTitle,
  });

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isCorrect = true;
  int _timeTaken = 30;
  String _difficultyRating = 'Medium';
  final TextEditingController _observationsController = TextEditingController();
  bool _isLoading = false;

  final List<String> _difficultyOptions = ['Easy', 'Medium', 'Hard'];

  Future<void> _submitFeedback() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('feedback').add({
        'childId': widget.childId,
        'activityId': widget.activityId,
        'parentId': user.uid,
        'correct': _isCorrect,
        'timeTaken': _timeTaken,
        'difficultyRating': _difficultyRating,
        'observations': _observationsController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // TODO: Update skill scores and generate next activity

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Feedback submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentDashboard()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Submit Feedback', style: AppTextStyles.heading2),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📝 Feedback for ${widget.activityTitle}',
              style: AppTextStyles.heading1.copyWith(fontSize: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'How did your child do?',
              style: AppTextStyles.bodyLight,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Correct/Incorrect
            Text(
              'Did your child complete it correctly?',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _buildToggleButton('✅ Correct', true),
                const SizedBox(width: AppSpacing.md),
                _buildToggleButton('❌ Incorrect', false),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Time Taken
            Text(
              'Time taken (seconds)',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: () {
                    if (_timeTaken > 10) setState(() => _timeTaken -= 10);
                  },
                ),
                Text(
                  '$_timeTaken s',
                  style: AppTextStyles.heading2,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: () {
                    if (_timeTaken < 300) setState(() => _timeTaken += 10);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Difficulty
            Text(
              'Difficulty rating',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: _difficultyOptions.map((option) {
                return ChoiceChip(
                  label: Text(option),
                  selected: _difficultyRating == option,
                  onSelected: (selected) {
                    if (selected) setState(() => _difficultyRating = option);
                  },
                  selectedColor: AppColors.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),

            // Observations
            Text(
              'Observations (Optional)',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _observationsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'How did your child respond? Any special observations?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                filled: true,
                fillColor: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitFeedback,
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
                    : Text('Submit Feedback', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String label, bool value) {
    final isSelected = _isCorrect == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isCorrect = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}