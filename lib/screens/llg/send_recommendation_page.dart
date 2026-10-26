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
  final String? initialTitle;
  final String? initialDomain;
  final String? initialRationale;

  const SendRecommendationPage({
    super.key,
    required this.child,
    this.specialistCase,
    this.initialTitle,
    this.initialDomain,
    this.initialRationale,
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

  bool _isStructuredSteps = false;
  final List<TextEditingController> _stepControllers = [];

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
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialRationale != null) {
      _rationaleController.text = widget.initialRationale!;
    }
    if (widget.initialDomain != null && _domains.contains(widget.initialDomain!.trim().toLowerCase())) {
      _selectedDomain = widget.initialDomain!.trim().toLowerCase();
    }
    _stepControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rationaleController.dispose();
    _instructionsController.dispose();
    _materialsController.dispose();
    _safetyController.dispose();
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleStepMode(bool isStructured) {
    if (isStructured == _isStructuredSteps) return;

    setState(() {
      _isStructuredSteps = isStructured;
      if (isStructured) {
        // Convert paragraph to structured steps
        final text = _instructionsController.text.trim();
        if (text.isNotEmpty) {
          final lines = text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .map((l) {
                return l.replaceAll(RegExp(r'^(Step\s*\d+\s*:\s*|\d+[\.)]\s*)', caseSensitive: false), '').trim();
              })
              .where((l) => l.isNotEmpty)
              .toList();

          for (final c in _stepControllers) {
            c.dispose();
          }
          _stepControllers.clear();

          if (lines.isEmpty) {
            _stepControllers.add(TextEditingController());
          } else {
            for (final line in lines) {
              _stepControllers.add(TextEditingController(text: line));
            }
          }
        } else if (_stepControllers.isEmpty) {
          _stepControllers.add(TextEditingController());
        }
      } else {
        // Convert structured steps to paragraph
        final steps = _stepControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (steps.isNotEmpty) {
          _instructionsController.text = steps
              .asMap()
              .entries
              .map((e) => 'Step ${e.key + 1}: ${e.value}')
              .join('\n');
        }
      }
    });
  }

  void _addStep([int? afterIndex]) {
    setState(() {
      final newController = TextEditingController();
      if (afterIndex != null && afterIndex >= 0 && afterIndex < _stepControllers.length) {
        _stepControllers.insert(afterIndex + 1, newController);
      } else {
        _stepControllers.add(newController);
      }
    });
  }

  void _removeStep(int index) {
    if (_stepControllers.length <= 1) {
      _stepControllers.first.clear();
      setState(() {});
      return;
    }
    setState(() {
      final removed = _stepControllers.removeAt(index);
      removed.dispose();
    });
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

      List<String> instructions;
      if (_isStructuredSteps) {
        instructions = _stepControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (instructions.isEmpty) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter at least one instruction step.')),
          );
          return;
        }
      } else {
        instructions = _instructionsController.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (instructions.isEmpty) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please provide clear instructions.')),
          );
          return;
        }
      }

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

                // Instructions with Mode Toggle (Paragraph vs Numbered Steps)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step-by-Step Instructions *',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isStructuredSteps ? 'Numbered Steps' : 'Paragraph',
                          style: GoogleFonts.inter(
                            color: _isStructuredSteps ? const Color(0xFF0EA5E9) : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _isStructuredSteps,
                            activeColor: const Color(0xFF0EA5E9),
                            onChanged: _toggleStepMode,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_isStructuredSteps) ...[
                  const SizedBox(height: 4),
                  Text('Enter instructions in paragraph style or line by line.',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _instructionsController,
                    maxLines: 4,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    validator: (v) {
                      if (_isStructuredSteps) return null;
                      return (v == null || v.trim().length < 5) ? 'Please provide clear instructions.' : null;
                    },
                    decoration: _inputDecoration('e.g. Spread sand or fine semolina on a shallow tray and guide child to trace letters.'),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text('Add and manage sequentially numbered steps. Steps auto-renumber on removal.',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _stepControllers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final controller = _stepControllers[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Step ${index + 1}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF0EA5E9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: controller,
                                minLines: 1,
                                maxLines: 3,
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Enter step instruction...',
                                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF0EA5E9)),
                              tooltip: 'Add Step Below',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _addStep(index),
                            ),
                            if (_stepControllers.length > 1) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                tooltip: 'Remove Step',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _removeStep(index),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _addStep(),
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF0EA5E9)),
                      label: const Text('Add Step', style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
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