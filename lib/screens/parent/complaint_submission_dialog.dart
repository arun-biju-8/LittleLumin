// lib/screens/parent/complaint_submission_dialog.dart
import 'package:flutter/material.dart';
import '../../models/admin_models.dart';
import '../../services/parent_complaint_service.dart';
import 'parent_theme.dart';

class ComplaintSubmissionDialog extends StatefulWidget {
  final String parentId;
  final String parentName;
  final String parentEmail;
  final String specialistId;
  final String specialistName;
  final String? caseId;

  const ComplaintSubmissionDialog({
    super.key,
    required this.parentId,
    required this.parentName,
    required this.parentEmail,
    required this.specialistId,
    required this.specialistName,
    this.caseId,
  });

  static Future<void> show(
    BuildContext context, {
    required String parentId,
    required String parentName,
    required String parentEmail,
    required String specialistId,
    required String specialistName,
    String? caseId,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ComplaintSubmissionDialog(
        parentId: parentId,
        parentName: parentName,
        parentEmail: parentEmail,
        specialistId: specialistId,
        specialistName: specialistName,
        caseId: caseId,
      ),
    );
  }

  @override
  State<ComplaintSubmissionDialog> createState() => _ComplaintSubmissionDialogState();
}

class _ComplaintSubmissionDialogState extends State<ComplaintSubmissionDialog> {
  final ParentComplaintService _complaintService = ParentComplaintService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _evidenceController = TextEditingController();

  ParentComplaintCategory _selectedCategory = ParentComplaintCategory.unprofessionalConduct;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.length < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least 15 characters describing your concern.'),
          backgroundColor: ParentColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String>? evidence;
      final evidenceText = _evidenceController.text.trim();
      if (evidenceText.isNotEmpty) {
        evidence = [evidenceText];
      }

      await _complaintService.submitComplaint(
        parentId: widget.parentId,
        parentName: widget.parentName,
        parentEmail: widget.parentEmail,
        specialistId: widget.specialistId,
        specialistName: widget.specialistName,
        caseId: widget.caseId,
        category: _selectedCategory,
        description: description,
        supportingEvidence: evidence,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your complaint was submitted and queued for confidential administrative review.'),
          backgroundColor: ParentColors.success,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit complaint: $e'),
          backgroundColor: ParentColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: ParentRadius.card),
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ParentColors.error.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.report_problem_outlined, color: ParentColors.error, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Report Concern / File Complaint',
              style: ParentTypography.cardTitle.copyWith(fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParentColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParentColors.primaryLight.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 18, color: ParentColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Specialist: ${widget.specialistName}',
                      style: ParentTypography.caption.copyWith(fontWeight: FontWeight.bold, color: ParentColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category Picker
            Text('Concern Category', style: ParentTypography.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ParentComplaintCategory>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: ParentComplaintCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.displayName, style: ParentTypography.body),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text('Detailed Description', style: ParentTypography.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: ParentTypography.body,
              decoration: InputDecoration(
                hintText: 'Please detail what occurred, dates, or specific interaction issues...',
                hintStyle: ParentTypography.bodyLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 14),

            // Supporting Evidence (optional)
            Text('Supporting References / Notes (Optional)', style: ParentTypography.caption.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _evidenceController,
              style: ParentTypography.body,
              decoration: InputDecoration(
                hintText: 'e.g. Session timestamps, message dates, or notes',
                hintStyle: ParentTypography.bodyLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Privacy & Non-retaliation notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.privacy_tip_outlined, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your privacy is protected. Submitting a complaint initiates a confidential administrative review without directly notifying or impacting specialist rating until verified.',
                      style: ParentTypography.caption.copyWith(color: const Color(0xFF92400E), fontSize: 11),
                    ),
                  ),
                ],
              ),
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
            backgroundColor: ParentColors.error,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: ParentRadius.button),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit Complaint'),
        ),
      ],
    );
  }
}
