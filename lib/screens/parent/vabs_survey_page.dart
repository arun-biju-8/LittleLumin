// lib/screens/parent/vabs_survey_page.dart
import 'package:flutter/material.dart';
import '../../models/vabs_question.dart';
import '../../services/vabs_service.dart';

class VABSSurveyPage extends StatefulWidget {
  final String childId;
  final String childName;
  final VoidCallback? onCompletedOrSkipped;

  const VABSSurveyPage({
    super.key,
    required this.childId,
    required this.childName,
    this.onCompletedOrSkipped,
  });

  @override
  State<VABSSurveyPage> createState() => _VABSSurveyPageState();
}

class _VABSSurveyPageState extends State<VABSSurveyPage> {
  final VABSService _vabsService = VABSService();
  final List<VABSQuestion> _questions = VABSQuestion.defaultQuestions;
  final Map<String, int> _answers = {}; // questionId -> 0..3

  bool _isSubmitting = false;

  int get _answeredCount => _answers.length;
  bool get _isComplete => _answeredCount == _questions.length;
  double get _progress => _questions.isNotEmpty ? (_answeredCount / _questions.length) : 0.0;

  Future<void> _handleSkip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Skip VABS-II Assessment?'),
        content: const Text(
          'You can skip this assessment and continue using the app normally. You can re-enable or update your child\'s profile anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
            child: const Text('Skip Assessment'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    await _vabsService.skipSurvey(widget.childId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('VABS-II Assessment skipped. You can continue using the app.'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    widget.onCompletedOrSkipped?.call();
    Navigator.pop(context);
  }

  Future<void> _handleSubmit() async {
    if (!_isComplete || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await _vabsService.submitSurvey(
        childId: widget.childId,
        answers: _answers,
      );

      if (!mounted) return;

      if (result.isFlagged) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('Support Flag Triggered'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Based on the VABS-II assessment results for ${widget.childName}, lower scores were detected.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    result.flagReason ?? 'Lower adaptive scores detected.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'An LLG Specialist has been alerted to provide guidance and tailored recommendations.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                child: const Text('Understand & Proceed'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VABS-II Assessment Completed! 🎉 Profile updated for ${widget.childName}.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      widget.onCompletedOrSkipped?.call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving survey: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('VABS-II Assessment'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _handleSkip,
            child: const Text(
              'Skip',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assessing: ${widget.childName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple),
                    ),
                    Text(
                      '$_answeredCount of ${_questions.length} answered',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isComplete ? Colors.green : Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: Colors.purple.shade50,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isComplete ? Colors.green : Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Questions List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                final int? selectedScore = _answers[q.id];
                final bool isAnswered = selectedScore != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14.0),
                  elevation: isAnswered ? 1.5 : 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isAnswered ? Colors.purple.shade300 : Colors.grey.shade300,
                      width: isAnswered ? 1.5 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                VABSDomain.getDisplayName(q.domain).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade800,
                                ),
                              ),
                              backgroundColor: Colors.purple.shade50,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Spacer(),
                            if (isAnswered)
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          q.question,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: List.generate(q.options.length, (optIdx) {
                            final scoreVal = q.scores[optIdx];
                            final optionLabel = q.options[optIdx];
                            final bool isSelected = selectedScore == scoreVal;

                            return ChoiceChip(
                              label: Text(
                                optionLabel,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: Colors.purple.shade700,
                              backgroundColor: Colors.grey.shade100,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _answers[q.id] = scoreVal;
                                  });
                                }
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Submit Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isComplete && !_isSubmitting ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isComplete ? Colors.purple.shade700 : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isComplete
                              ? 'Submit Assessment'
                              : 'Answer All Questions ($_answeredCount/${_questions.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
