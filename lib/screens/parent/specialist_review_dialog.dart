// lib/screens/parent/specialist_review_dialog.dart
import 'package:flutter/material.dart';
import '../../services/specialist_review_service.dart';
import 'parent_theme.dart';

class SpecialistReviewDialog extends StatefulWidget {
  final String parentId;
  final String parentName;
  final String specialistId;
  final String specialistName;
  final String caseId;
  final VoidCallback? onReviewSubmitted;

  const SpecialistReviewDialog({
    super.key,
    required this.parentId,
    required this.parentName,
    required this.specialistId,
    required this.specialistName,
    required this.caseId,
    this.onReviewSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String parentId,
    required String parentName,
    required String specialistId,
    required String specialistName,
    required String caseId,
    VoidCallback? onReviewSubmitted,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SpecialistReviewDialog(
        parentId: parentId,
        parentName: parentName,
        specialistId: specialistId,
        specialistName: specialistName,
        caseId: caseId,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  State<SpecialistReviewDialog> createState() => _SpecialistReviewDialogState();
}

class _SpecialistReviewDialogState extends State<SpecialistReviewDialog> {
  final SpecialistReviewService _reviewService = SpecialistReviewService();
  final TextEditingController _reviewController = TextEditingController();

  int _selectedStars = 5;
  bool _isSubmitting = false;
  bool _isCheckingExisting = true;
  bool _alreadyReviewed = false;

  @override
  void initState() {
    super.initState();
    _checkExistingReview();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingReview() async {
    try {
      final exists = await _reviewService.hasReviewedCase(widget.caseId, widget.parentId);
      if (mounted) {
        setState(() {
          _alreadyReviewed = exists;
          _isCheckingExisting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingExisting = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      await _reviewService.submitReview(
        parentId: widget.parentId,
        parentName: widget.parentName,
        specialistId: widget.specialistId,
        specialistName: widget.specialistName,
        caseId: widget.caseId,
        rating: _selectedStars,
        reviewText: _reviewController.text.trim().isNotEmpty ? _reviewController.text.trim() : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onReviewSubmitted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your rating and feedback have been submitted successfully.'),
          backgroundColor: ParentColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: ParentColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingExisting) {
      return const AlertDialog(
        content: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Checking consultation status...'),
            ],
          ),
        ),
      );
    }

    if (_alreadyReviewed) {
      return AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
        title: Text('Review Already Submitted', style: ParentTypography.cardTitle),
        content: Text(
          'You have already submitted a rating and review for this consultation with ${widget.specialistName}. Only one review is permitted per completed consultation.',
          style: ParentTypography.body,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: ParentColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ParentColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: ParentColors.accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rate & Review Specialist',
              style: ParentTypography.cardTitle.copyWith(fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'How was your developmental guidance consultation with ${widget.specialistName}?',
              textAlign: TextAlign.center,
              style: ParentTypography.bodyLight,
            ),
            const SizedBox(height: 20),

            // Star Rating Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                final isSelected = starNum <= _selectedStars;
                return IconButton(
                  iconSize: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  icon: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected ? ParentColors.accent : Colors.grey.shade300,
                  ),
                  onPressed: () => setState(() => _selectedStars = starNum),
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              '$_selectedStars out of 5 stars',
              style: ParentTypography.caption.copyWith(fontWeight: FontWeight.bold, color: ParentColors.primary),
            ),
            const SizedBox(height: 20),

            // Optional written review
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Written Feedback (Optional)',
                style: ParentTypography.caption.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              style: ParentTypography.body,
              decoration: InputDecoration(
                hintText: 'Share your experience, specialist communication, and guidance helpfulness...',
                hintStyle: ParentTypography.bodyLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Your review helps other families choose the best developmental guides.',
              textAlign: TextAlign.center,
              style: ParentTypography.caption.copyWith(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: ParentTypography.caption.copyWith(color: ParentColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: ParentColors.primary,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit Review'),
        ),
      ],
    );
  }
}
