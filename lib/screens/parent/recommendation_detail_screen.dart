// lib/screens/parent/recommendation_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/recommendation_model.dart';
import '../../services/recommendation_service.dart';
import '../../services/journey_service.dart';
import '../../services/activity_state_service.dart';
import '../../services/score_ledger_service.dart';
import '../../theme/meadow_theme.dart';
import '../../widgets/global_header.dart';

class RecommendationDetailScreen extends StatefulWidget {
  final RecommendationModel recommendation;
  final String childId;
  final String? childName;
  final VoidCallback? onResponseSubmitted;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final RecommendationService? recService;
  final JourneyService? journeyService;
  final ScoreLedgerService? scoreLedgerService;

  const RecommendationDetailScreen({
    super.key,
    required this.recommendation,
    required this.childId,
    this.childName,
    this.onResponseSubmitted,
    this.auth,
    this.firestore,
    this.recService,
    this.journeyService,
    this.scoreLedgerService,
  });

  @override
  State<RecommendationDetailScreen> createState() => _RecommendationDetailScreenState();
}

class _RecommendationDetailScreenState extends State<RecommendationDetailScreen> {
  late RecommendationModel _currentRec;
  late RecommendationService _recService;
  late JourneyService _journeyService;
  late ScoreLedgerService _scoreLedgerService;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentRec = widget.recommendation;
    try {
      _auth = widget.auth ?? FirebaseAuth.instance;
    } catch (_) {
      _auth = null;
    }
    try {
      _firestore = widget.firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      _firestore = null;
    }
    _recService = widget.recService ?? RecommendationService(firestore: _firestore, auth: _auth);
    _journeyService = widget.journeyService ?? JourneyService(firestore: _firestore);
    _scoreLedgerService = widget.scoreLedgerService ?? ScoreLedgerService(firestore: _firestore);
  }

  void _showResponseSheet() {
    ParentActivityResponse selectedOutcome = _currentRec.parentResponse != ParentActivityResponse.none
        ? _currentRec.parentResponse
        : ParentActivityResponse.completed;
    final notesController = TextEditingController(text: _currentRec.parentFeedback ?? '');
    final skippedReasonController = TextEditingController(text: _currentRec.skippedReason ?? '');
    String childEngagement = 'Engaged and curious';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isSkipped = selectedOutcome == ParentActivityResponse.skipped;

            return Padding(
              padding: EdgeInsets.only(
                left: MeadowSpacing.screenH,
                right: MeadowSpacing.screenH,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record Child Response',
                                style: MeadowTypography.h2.copyWith(fontSize: 18),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentRec.title,
                                style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: MeadowColors.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: MeadowColors.borderLight, height: 24),

                    // 1. Completion Outcome
                    Text(
                      '1. Activity Completion Outcome *',
                      style: MeadowTypography.label.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildOutcomeChip(
                          ParentActivityResponse.completed,
                          'Completed Successfully',
                          Icons.check_circle_outline,
                          MeadowColors.success,
                          selectedOutcome,
                          setSheetState,
                          (val) => selectedOutcome = val,
                        ),
                        _buildOutcomeChip(
                          ParentActivityResponse.partially_completed,
                          'Partially Completed',
                          Icons.timelapse_rounded,
                          MeadowColors.warning,
                          selectedOutcome,
                          setSheetState,
                          (val) => selectedOutcome = val,
                        ),
                        _buildOutcomeChip(
                          ParentActivityResponse.struggled,
                          'Struggled / Needed Help',
                          Icons.sentiment_dissatisfied_outlined,
                          MeadowColors.cognitive,
                          selectedOutcome,
                          setSheetState,
                          (val) => selectedOutcome = val,
                        ),
                        _buildOutcomeChip(
                          ParentActivityResponse.skipped,
                          'Skipped for Now',
                          Icons.cancel_outlined,
                          MeadowColors.textTertiary,
                          selectedOutcome,
                          setSheetState,
                          (val) => selectedOutcome = val,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // If Skipped, reason field
                    if (isSkipped) ...[
                      Text(
                        'Reason for Skipping (Optional)',
                        style: MeadowTypography.label.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: skippedReasonController,
                        style: MeadowTypography.body.copyWith(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. Lacked required materials, fatigued, or focus elsewhere...',
                          hintStyle: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ] else ...[
                      // 2. Child Engagement
                      Text(
                        '2. Child Reaction / Engagement',
                        style: MeadowTypography.label.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: childEngagement,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          'Engaged and curious',
                          'Happy and enthusiastic',
                          'Required continuous prompting',
                          'Lost interest quickly',
                          'Frustrated with difficulty',
                        ].map((eng) => DropdownMenuItem(value: eng, child: Text(eng, style: MeadowTypography.body.copyWith(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => childEngagement = val);
                        },
                      ),
                      const SizedBox(height: 18),
                    ],

                    // 3. Parent Observations & Notes
                    Text(
                      '3. Parent Observations & Feedback *',
                      style: MeadowTypography.label.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your assigned specialist will read these notes to tailor the next milestones.',
                      style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      style: MeadowTypography.body.copyWith(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Describe how your child approached the steps, any triumphs, or challenges...',
                        hintStyle: MeadowTypography.caption.copyWith(color: MeadowColors.textTertiary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final notesText = notesController.text.trim();
                                if (notesText.isEmpty && !isSkipped) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please add a short note describing your child’s experience.')),
                                  );
                                  return;
                                }

                                Navigator.pop(ctx);
                                await _handleSubmitResponse(
                                  outcome: selectedOutcome,
                                  notes: notesText,
                                  skippedReason: skippedReasonController.text.trim(),
                                  engagement: childEngagement,
                                );
                              },
                        icon: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(_isSubmitting ? 'Submitting Feedback...' : 'Confirm & Save Response'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MeadowColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: MeadowTypography.button,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOutcomeChip(
    ParentActivityResponse value,
    String label,
    IconData icon,
    Color activeColor,
    ParentActivityResponse current,
    void Function(void Function()) setSheetState,
    void Function(ParentActivityResponse) onSelect,
  ) {
    final isSelected = current == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : activeColor),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setSheetState(() => onSelect(value));
        }
      },
      selectedColor: activeColor,
      backgroundColor: MeadowColors.surfaceAlt,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : MeadowColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? activeColor : MeadowColors.borderLight),
      ),
    );
  }

  Future<void> _handleSubmitResponse({
    required ParentActivityResponse outcome,
    required String notes,
    required String skippedReason,
    required String engagement,
    String difficulty = 'Appropriate',
    String confidence = 'Confident',
  }) async {
    final user = _auth?.currentUser;
    if (_auth != null && user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required to record activity responses.')),
      );
      return;
    }
    final parentUid = user?.uid ?? 'parent_202';

    setState(() => _isSubmitting = true);

    try {
      // 1. Submit response through authoritative RecommendationService
      if (_auth != null) {
        await _recService.submitParentResponse(
          recommendationId: _currentRec.id,
          response: outcome,
          feedback: notes.isNotEmpty ? notes : null,
          skippedReason: skippedReason.isNotEmpty ? skippedReason : null,
        );
      }

      // 2. Persist detailed feedback record to global 'feedback' collection
      if (_firestore != null) {
        try {
          await _firestore!.collection('feedback').add({
            'childId': widget.childId,
            'activityId': _currentRec.baseActivityId ?? _currentRec.id,
            'activityTitle': _currentRec.title,
            'recommendationId': _currentRec.id,
            'parentId': parentUid,
            'childResponse': outcome.name,
            'engagement': engagement,
            'notes': notes,
            'source': 'llg_recommendation',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Warning saving feedback collection record: $e');
        }
      }

      // 3. If completed or partially completed, update Journey and Ledger progress
      if (outcome == ParentActivityResponse.completed || outcome == ParentActivityResponse.partially_completed) {
        try {
          await _journeyService.markActivityComplete(
            widget.childId,
            _currentRec.baseActivityId ?? _currentRec.id,
            _currentRec.skillDomain,
          );
        } catch (e) {
          debugPrint('Warning journey service completion note: $e');
        }

        try {
          await ActivityStateService().markCompleted(widget.childId);
        } catch (e) {
          debugPrint('Warning activity state service completion note: $e');
        }

        try {
          await _scoreLedgerService.recordScoreEvent(
            childId: widget.childId,
            activityId: _currentRec.baseActivityId ?? _currentRec.id,
            activityTitle: _currentRec.title,
            activitySource: 'llg_recommended',
            skillDomain: _currentRec.skillDomain,
            difficulty: difficulty,
            levelAtTime: 1,
            rawScoreDelta: 5.0,
            feedback: {
              'childResponse': outcome.name,
              'engagement': engagement,
              'difficulty': difficulty,
              'confidence': confidence,
              'notes': notes,
              'submittedAt': DateTime.now().toIso8601String(),
            },
            submittedByParentId: parentUid,
          );
        } catch (e) {
          debugPrint('Warning ledger completion note: $e');
        }
      }

      // 4. Update local state
      RecommendationStatus newStatus = RecommendationStatus.in_progress;
      if (outcome == ParentActivityResponse.completed) {
        newStatus = RecommendationStatus.completed;
      } else if (outcome == ParentActivityResponse.partially_completed) {
        newStatus = RecommendationStatus.partially_completed;
      } else if (outcome == ParentActivityResponse.skipped) {
        newStatus = RecommendationStatus.skipped;
      }

      setState(() {
        _currentRec = _currentRec.copyWith(
          parentResponse: outcome,
          parentFeedback: notes.isNotEmpty ? notes : _currentRec.parentFeedback,
          skippedReason: skippedReason.isNotEmpty ? skippedReason : _currentRec.skippedReason,
          parentRespondedAt: DateTime.now(),
          status: newStatus,
        );
      });

      widget.onResponseSubmitted?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Activity response and specialist feedback recorded successfully!'),
            backgroundColor: MeadowColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording response: $e'),
            backgroundColor: MeadowColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainColor = MeadowDomain.colorFor(_currentRec.skillDomain);
    final domainSurface = MeadowDomain.surfaceFor(_currentRec.skillDomain);

    Color statusColor;
    switch (_currentRec.status) {
      case RecommendationStatus.completed:
        statusColor = MeadowColors.success;
        break;
      case RecommendationStatus.partially_completed:
        statusColor = MeadowColors.warning;
        break;
      case RecommendationStatus.skipped:
        statusColor = MeadowColors.textTertiary;
        break;
      default:
        statusColor = MeadowColors.primary;
        break;
    }

    return Scaffold(
      backgroundColor: MeadowColors.cream,
      appBar: const GlobalHeader(
        showBack: true,
        title: 'Activity Details',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: MeadowSpacing.screenH, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Activity Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MeadowColors.surface,
                borderRadius: BorderRadius.circular(MeadowRadius.xl),
                border: Border.all(color: MeadowColors.borderLight),
                boxShadow: MeadowShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: domainSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          MeadowDomain.labelFor(_currentRec.skillDomain).toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: domainColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          _currentRec.status.name.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentRec.title,
                    style: MeadowTypography.h1.copyWith(fontSize: 22, height: 1.25),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 16, color: MeadowColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Prescribed by ${_currentRec.llgName} (${_currentRec.llgRole.replaceAll('_', ' ').toUpperCase()})',
                          style: MeadowTypography.body.copyWith(
                            fontSize: 12,
                            color: MeadowColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoBadge(Icons.timer_outlined, '${_currentRec.durationMinutes} Minutes'),
                      _buildInfoBadge(Icons.repeat_rounded, _currentRec.frequency),
                      if (_currentRec.reviewDate != null)
                        _buildInfoBadge(
                          Icons.event_available_outlined,
                          'Target Review: ${DateFormat.yMMMd().format(_currentRec.reviewDate!)}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Clinical / Educational Rationale Card
            if (_currentRec.rationale.isNotEmpty) ...[
              _buildSectionCard(
                icon: Icons.psychology_outlined,
                iconColor: MeadowColors.cognitive,
                title: 'Clinical & Developmental Rationale',
                child: Text(
                  _currentRec.rationale,
                  style: MeadowTypography.body.copyWith(
                    fontSize: 13,
                    color: MeadowColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 3. Materials Required Card
            if (_currentRec.materials.isNotEmpty) ...[
              _buildSectionCard(
                icon: Icons.inventory_2_outlined,
                iconColor: MeadowColors.gold,
                title: 'Materials Needed',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _currentRec.materials.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: MeadowColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(m, style: MeadowTypography.body.copyWith(fontSize: 13)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Instructions Card (Clean Numbered Steps or Paragraph)
            _buildSectionCard(
              icon: Icons.format_list_numbered_rounded,
              iconColor: MeadowColors.primary,
              title: 'Step-by-Step Instructions',
              child: _buildInstructionsList(),
            ),
            const SizedBox(height: 16),

            // 5. Safety Guidance & Supervision Note
            if (_currentRec.safetyGuidance.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MeadowColors.goldSurface,
                  borderRadius: BorderRadius.circular(MeadowRadius.lg),
                  border: Border.all(color: MeadowColors.gold.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.health_and_safety_outlined, size: 20, color: MeadowColors.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Safety & Supervision Note', style: MeadowTypography.label.copyWith(fontSize: 12, color: MeadowColors.primaryDark)),
                          const SizedBox(height: 2),
                          Text(
                            _currentRec.safetyGuidance,
                            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 6. Previous Parent Response Banner (if already submitted)
            if (_currentRec.hasParentResponded) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MeadowColors.primarySurface,
                  borderRadius: BorderRadius.circular(MeadowRadius.lg),
                  border: Border.all(color: MeadowColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rate_review_rounded, size: 18, color: MeadowColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Your Recorded Response',
                          style: MeadowTypography.label.copyWith(fontSize: 13, color: MeadowColors.primaryDark),
                        ),
                        const Spacer(),
                        if (_currentRec.parentRespondedAt != null)
                          Text(
                            DateFormat.yMMMd().format(_currentRec.parentRespondedAt!),
                            style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Outcome: ${_currentRec.parentResponse.name.replaceAll('_', ' ').toUpperCase()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (_currentRec.parentFeedback != null && _currentRec.parentFeedback!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Observations: "${_currentRec.parentFeedback}"',
                        style: MeadowTypography.body.copyWith(
                          fontSize: 12,
                          color: MeadowColors.textPrimary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (_currentRec.skippedReason != null && _currentRec.skippedReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reason for skipping: ${_currentRec.skippedReason}',
                        style: MeadowTypography.caption.copyWith(color: MeadowColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 7. Prominent Submit Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _showResponseSheet,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _currentRec.hasParentResponded ? 'Update Child Response & Feedback' : 'Submit Child Response & Feedback',
                  style: MeadowTypography.button.copyWith(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MeadowColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsList() {
    if (_currentRec.instructions.isEmpty) {
      return Text('No specific instructions provided.', style: MeadowTypography.body.copyWith(color: MeadowColors.textSecondary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _currentRec.instructions.asMap().entries.map((entry) {
        final index = entry.key;
        final rawText = entry.value;
        final stepText = rawText.replaceAll(RegExp(r'^(Step\s*\d+\s*:\s*|\d+[\.)]\s*)', caseSensitive: false), '').trim();

        return Padding(
          padding: EdgeInsets.only(bottom: index == _currentRec.instructions.length - 1 ? 0 : 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MeadowColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MeadowColors.borderLight),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: MeadowColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Step ${index + 1}',
                        style: MeadowTypography.label.copyWith(fontSize: 11, color: MeadowColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stepText.isNotEmpty ? stepText : rawText,
                        style: MeadowTypography.body.copyWith(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MeadowColors.surface,
        borderRadius: BorderRadius.circular(MeadowRadius.xl),
        border: Border.all(color: MeadowColors.borderLight),
        boxShadow: MeadowShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: MeadowTypography.label.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MeadowColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MeadowColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MeadowColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MeadowColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
