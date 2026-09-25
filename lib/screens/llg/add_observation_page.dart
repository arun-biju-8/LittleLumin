// lib/screens/llg/add_observation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/validators.dart';
import '../../models/child_model.dart';

class AddObservationPage extends StatefulWidget {
  final ChildModel child;
  final String? flagEventId;
  final VoidCallback? onSuccess;

  const AddObservationPage({
    super.key,
    required this.child,
    this.flagEventId,
    this.onSuccess,
  });

  @override
  State<AddObservationPage> createState() => _AddObservationPageState();
}

class _AddObservationPageState extends State<AddObservationPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _severity = 'medium';
  final _observationController = TextEditingController();
  final List<TextEditingController> _recControllers = [TextEditingController()];
  bool _referralNeeded = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _observationController.dispose();
    for (var c in _recControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRecommendation() {
    if (_recControllers.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum of 10 recommendations allowed.')),
      );
      return;
    }
    setState(() {
      _recControllers.add(TextEditingController());
    });
  }

  void _removeRecommendation(int index) {
    if (_recControllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 1 recommendation is required.')),
      );
      return;
    }
    setState(() {
      final c = _recControllers.removeAt(index);
      c.dispose();
    });
  }

  Future<void> _submitObservation() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the highlighted errors before submitting.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final obsText = _observationController.text.trim();
    if (obsText.length < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observation note must be at least 30 characters.')),
      );
      return;
    }

    final recommendations = _recControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (recommendations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least 1 valid recommendation.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('You must be logged in as an LLG specialist.');

      // Fetch LLG name
      final llgDoc = await _firestore.collection('llgProfiles').doc(user.uid).get();
      final llgName = llgDoc.data()?['name'] ?? user.displayName ?? 'LLG Specialist';

      // 1. Immutable LLG Observation Document
      final obsRef = await _firestore.collection('llgObservations').add({
        'childId': widget.child.childId,
        'llgId': user.uid,
        'llgName': llgName,
        'flagEventId': widget.flagEventId ?? '',
        'observation': obsText,
        'recommendations': recommendations,
        'severity': _severity,
        'referralNeeded': _referralNeeded,
        'recordedAt': FieldValue.serverTimestamp(),
        'isImmutable': true,
      });

      // 2. Notify Parent
      if (widget.child.parentId.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'userId': widget.child.parentId,
          'type': 'llg_observation',
          'childId': widget.child.childId,
          'observationId': obsRef.id,
          'title': 'New Specialist Clinical Note for ${widget.child.name}',
          'body': '$llgName has added detailed observations and recommendations.',
          'actionRoute': '/llg-connect',
          'readAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Admin Audit Log (Immutable)
      await _firestore.collection('adminAuditLogs').add({
        'action': 'llg_observation_recorded',
        'actorId': user.uid,
        'actorType': 'llg',
        'actorName': llgName,
        'targetId': widget.child.childId,
        'observationId': obsRef.id,
        'severity': _severity,
        'timestamp': FieldValue.serverTimestamp(),
        'isImmutable': true,
      });

      debugPrint('✅ Recorded immutable observation: ${obsRef.id} by $llgName');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Observation record submitted and locked permanently.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onSuccess?.call();
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      debugPrint('❌ Error submitting observation: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit observation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Clinical Observation Record',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImmutableNotice(),
                  const SizedBox(height: 20),
                  _buildChildSummaryCard(),
                  const SizedBox(height: 20),
                  _buildSeverityDropdown(),
                  const SizedBox(height: 20),
                  _buildObservationField(),
                  const SizedBox(height: 20),
                  _buildRecommendationsSection(),
                  const SizedBox(height: 20),
                  _buildReferralToggle(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImmutableNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined, color: Color(0xFFF59E0B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Audit-Traceable Record: Once submitted, this observation cannot be edited or deleted. It will be permanently added to the child’s clinical history.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFF59E0B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF0EA5E9),
            radius: 20,
            child: Icon(Icons.child_care, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.child.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Age: ${widget.child.ageYears} years • Gender: ${widget.child.gender}',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clinical Severity Level *',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _severity,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          dropdownColor: const Color(0xFF1E293B),
          isExpanded: true,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E293B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
            ),
          ),
          validator: (v) => Validators.requiredDropdown(v, 'Severity level'),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low — Minor Observation / Normal Fluctuation')),
            DropdownMenuItem(value: 'medium', child: Text('Medium — Skill Lag / Needs Consistent Practice')),
            DropdownMenuItem(value: 'high', child: Text('High — Marked Developmental Delay')),
            DropdownMenuItem(value: 'critical', child: Text('Critical — Immediate Clinical Referral Advised')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _severity = val);
          },
        ),
      ],
    );
  }

  Widget _buildObservationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Clinical Note (Min 30 characters) *',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _observationController,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          maxLines: 5,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          validator: (v) => Validators.safeText(v, 'Observation note', min: 30, max: 2000),
          decoration: InputDecoration(
            hintText: 'Document developmental findings, milestone discrepancies, sensory responses...',
            hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Actionable Recommendations (1 - 10) *',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
            ),
            TextButton.icon(
              onPressed: _addRecommendation,
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF0EA5E9)),
              label: Text(
                'Add Item',
                style: GoogleFonts.inter(color: const Color(0xFF0EA5E9), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_recControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _recControllers[index],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    validator: (v) => (index == 0 || (v != null && v.trim().isNotEmpty))
                        ? Validators.safeText(v, 'Recommendation', min: 3, max: 200)
                        : null,
                    decoration: InputDecoration(
                      hintText: 'Action step #${index + 1} for parents/caregivers...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF0EA5E9)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                if (_recControllers.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _removeRecommendation(index),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReferralToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Formal Clinical Referral Advised',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Flag if child should be referred to a pediatrician, speech-language pathologist, or child psychologist.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Switch(
            value: _referralNeeded,
            activeColor: const Color(0xFF0EA5E9),
            onChanged: (val) => setState(() => _referralNeeded = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitObservation,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0EA5E9),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isSubmitting
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                'Submit & Lock Observation',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
