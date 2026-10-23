// lib/screens/llg/send_recommendation_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../services/recommendation_service.dart';
import '../../services/specialist_case_service.dart';

class SendRecommendationPage extends StatefulWidget {
  final ChildModel child;
  final SpecialistCaseModel? specialistCase;

  const SendRecommendationPage({
    super.key,
    required this.child,
    this.specialistCase,
  });

  @override
  State<SendRecommendationPage> createState() => _SendRecommendationPageState();
}

class _SendRecommendationPageState extends State<SendRecommendationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _rationaleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _materialsController = TextEditingController();
  final _safetyController = TextEditingController(text: 'Adult supervision recommended at all times.');
  
  String _selectedDomain = 'cognitive';
  int _durationMinutes = 15;
  String _frequency = 'Daily';
  DateTime? _reviewDate;
  bool _isLoading = false;

  final List<String> _domains = [
    'cognitive',
    'language',
    'motor',
    'social',
    'emotional',
    'creative',
  ];

  final List<String> _frequencies = [
    'Daily',
    'Every 2 days',
    '3 times per week',
    'Weekly',
    'As needed',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _rationaleController.dispose();
    _instructionsController.dispose();
    _materialsController.dispose();
    _safetyController.dispose();
    super.dispose();
  }

  Future<void> _pickReviewDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() => _reviewDate = picked);
    }
  }

  Future<void> _submitRecommendation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to submit guidance.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Find case if not provided
      SpecialistCaseModel? currentCase = widget.specialistCase;
      if (currentCase == null) {
        final cases = await SpecialistCaseService().getSpecialistCases(
          specialistId: user.uid,
          childId: widget.child.childId,
        );
        if (cases.isNotEmpty) {
          currentCase = cases.first;
        }
      }

      final caseId = currentCase?.id ?? 'case_${widget.child.childId}_${user.uid}';
      final parentId = widget.child.parentId.isNotEmpty ? widget.child.parentId : (currentCase?.parentId ?? '');

      final instructions = _instructionsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final materials = _materialsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await RecommendationService().createRecommendation(
        caseId: caseId,
        childId: widget.child.childId,
        childName: widget.child.name,
        parentId: parentId,
        llgId: user.uid,
        llgName: user.displayName ?? 'LittleLumin Guide',
        title: _titleController.text.trim(),
        rationale: _rationaleController.text.trim(),
        skillDomain: _selectedDomain,
        instructions: instructions.isNotEmpty ? instructions : [_titleController.text.trim()],
        materials: materials,
        durationMinutes: _durationMinutes,
        frequency: _frequency,
        safetyGuidance: _safetyController.text.trim(),
        reviewDate: _reviewDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personalized recommendation sent to parent!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit recommendation: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          'Personalized Guidance for ${widget.child.name}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_outlined, color: Color(0xFF0EA5E9), size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tailored Specialist Recommendation',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This will appear in the parent\'s "My Growth" tab under Personalized Guidance with active response and feedback tracking.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text('Activity Title *', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  validator: (v) => (v == null || v.trim().length < 4) ? 'Please enter a descriptive activity title.' : null,
                  decoration: _inputDecoration('e.g., Tactile Sand Writing & Sound Matching'),
                ),
                const SizedBox(height: 20),

                // Domain & Frequency Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target Domain *', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedDomain,
                            dropdownColor: const Color(0xFF1E293B),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration('Select Domain'),
                            items: _domains.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text(d[0].toUpperCase() + d.substring(1)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDomain = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frequency *', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _frequency,
                            dropdownColor: const Color(0xFF1E293B),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration('Frequency'),
                            items: _frequencies.map((f) {
                              return DropdownMenuItem(
                                value: f,
                                child: Text(f),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _frequency = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Rationale (Why suggested)
                Text('Clinical / Educational Rationale *', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Explain why this activity supports this child\'s current growth.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rationaleController,
                  maxLines: 3,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Please explain the developmental rationale (at least 10 characters).' : null,
                  decoration: _inputDecoration('e.g., Helps strengthen fine motor pincer grasp and phonological letter recognition.'),
                ),
                const SizedBox(height: 20),

                // Instructions (Line by line)
                Text('Step-by-Step Instructions *', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Enter one step per line so parents can easily follow along.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 4,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Please provide clear instructions.' : null,
                  decoration: _inputDecoration('Step 1: Spread sand or fine semolina on a shallow tray.\nStep 2: Trace the letter "S" with index finger.\nStep 3: Ask child to imitate while making the sound.'),
                ),
                const SizedBox(height: 20),

                // Duration & Review Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration (Minutes)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _durationMinutes,
                            dropdownColor: const Color(0xFF1E293B),
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                            decoration: _inputDecoration('Duration'),
                            items: [5, 10, 15, 20, 30, 45].map((mins) {
                              return DropdownMenuItem(
                                value: mins,
                                child: Text('$mins Minutes'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _durationMinutes = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target Review Date', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickReviewDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF0EA5E9)),
                                  const SizedBox(width: 10),
                                  Text(
                                    _reviewDate != null
                                        ? '${_reviewDate!.year}-${_reviewDate!.month.toString().padLeft(2, '0')}-${_reviewDate!.day.toString().padLeft(2, '0')}'
                                        : 'Set review date',
                                    style: GoogleFonts.inter(color: _reviewDate != null ? Colors.white : const Color(0xFF94A3B8), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Required Materials
                Text('Materials Required (comma separated)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _materialsController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('e.g., Shallow tray, sand or fine salt, flashcards'),
                ),
                const SizedBox(height: 20),

                // Safety Guidance
                Text('Safety & Supervision Guidance', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _safetyController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Adult supervision precautions'),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitRecommendation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Send Recommendation to Parent',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}