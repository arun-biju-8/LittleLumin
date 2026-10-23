// lib/screens/parent/widgets/personalized_recommendations_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../models/child_model.dart';
import '../../../models/recommendation_model.dart';
import '../../../services/recommendation_service.dart';
import '../../../theme/meadow_theme.dart';

class PersonalizedRecommendationsSection extends StatefulWidget {
  final ChildModel activeChild;
  final RecommendationService? recommendationService;

  const PersonalizedRecommendationsSection({
    super.key,
    required this.activeChild,
    this.recommendationService,
  });

  @override
  State<PersonalizedRecommendationsSection> createState() =>
      _PersonalizedRecommendationsSectionState();
}

class _PersonalizedRecommendationsSectionState
    extends State<PersonalizedRecommendationsSection> {
  late final RecommendationService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.recommendationService ?? RecommendationService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RecommendationModel>>(
      stream: _service.getChildRecommendationsStream(widget.activeChild.childId),
      builder: (context, snapshot) {
        final recommendations = snapshot.data ?? [];

        if (recommendations.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Personalized Guide Activities (${recommendations.length})',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MeadowColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Activities specifically recommended for ${widget.activeChild.name} by your verified guide.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MeadowColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recommendations.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildRecommendationCard(recommendations[index]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendationCard(RecommendationModel rec) {
    Color statusBg;
    Color statusColor;
    String statusText;

    switch (rec.status) {
      case RecommendationStatus.completed:
        statusBg = const Color(0xFFDCFCE7);
        statusColor = const Color(0xFF15803D);
        statusText = 'Completed';
        break;
      case RecommendationStatus.partially_completed:
        statusBg = const Color(0xFFFEF9C3);
        statusColor = const Color(0xFFA16207);
        statusText = 'Partially Completed';
        break;
      case RecommendationStatus.skipped:
        statusBg = const Color(0xFFF1F5F9);
        statusColor = const Color(0xFF475569);
        statusText = 'Skipped / Deferred';
        break;
      case RecommendationStatus.paused:
        statusBg = const Color(0xFFFFEDD5);
        statusColor = const Color(0xFFC2410C);
        statusText = 'Paused';
        break;
      case RecommendationStatus.discontinued:
        statusBg = const Color(0xFFFEE2E2);
        statusColor = const Color(0xFFB91C1C);
        statusText = 'Discontinued';
        break;
      case RecommendationStatus.recommended:
      case RecommendationStatus.in_progress:
        statusBg = const Color(0xFFE0F2FE);
        statusColor = const Color(0xFF0369A1);
        statusText = 'Active Recommendation';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'From ${rec.llgName}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rec.skillDomain.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rec.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          if (rec.rationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Why it was suggested: ${rec.rationale}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Duration & Frequency & Review Date
          Row(
            children: [
              _buildMetaChip(Icons.timer_outlined, '${rec.durationMinutes} mins'),
              const SizedBox(width: 8),
              _buildMetaChip(Icons.repeat, rec.frequency),
              if (rec.reviewDate != null) ...[
                const SizedBox(width: 8),
                _buildMetaChip(
                  Icons.event_outlined,
                  'Review: ${DateFormat.MMMd().format(rec.reviewDate!)}',
                ),
              ],
            ],
          ),

          if (rec.instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Instructions:',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            ...rec.instructions.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${entry.key + 1}. ',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF334155), height: 1.35),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          if (rec.materials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.handyman_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Materials: ${rec.materials.join(', ')}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Safety: ${rec.safetyGuidance}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),

          // Parent Response Section
          if (rec.hasParentResponded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        'Your Feedback (${rec.parentResponse.name.replaceAll('_', ' ')})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      if (rec.parentRespondedAt != null)
                        Text(
                          DateFormat.MMMd().format(rec.parentRespondedAt!),
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                  if (rec.parentFeedback != null && rec.parentFeedback!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      rec.parentFeedback!,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
                    ),
                  ],
                  if (rec.skippedReason != null && rec.skippedReason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Reason: ${rec.skippedReason!}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // LLG Feedback Section
          if (rec.llgFeedback != null && rec.llgFeedback!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        'Guide Follow-up from ${rec.llgName}:',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.llgFeedback!,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF15803D)),
                  ),
                  if (rec.nextSteps != null && rec.nextSteps!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Next Step: ${rec.nextSteps}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF166534),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons for Parent
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _openResponseDialog(rec),
                icon: const Icon(Icons.edit_note, size: 16),
                label: Text(rec.hasParentResponded ? 'Update Feedback' : 'Report Activity Response'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  void _openResponseDialog(RecommendationModel rec) {
    ParentActivityResponse selectedResponse = rec.parentResponse != ParentActivityResponse.none
        ? rec.parentResponse
        : ParentActivityResponse.completed;
    final feedbackController = TextEditingController(text: rec.parentFeedback ?? '');
    String selectedSkipReason = rec.skippedReason ?? 'Not enough time today';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Activity Response',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How did ${widget.activeChild.name} do with "${rec.title}"?',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Completed'),
                      selected: selectedResponse == ParentActivityResponse.completed,
                      onSelected: (val) => setDialogState(() => selectedResponse = ParentActivityResponse.completed),
                    ),
                    ChoiceChip(
                      label: const Text('Partially Done'),
                      selected: selectedResponse == ParentActivityResponse.partially_completed,
                      onSelected: (val) =>
                          setDialogState(() => selectedResponse = ParentActivityResponse.partially_completed),
                    ),
                    ChoiceChip(
                      label: const Text('Struggled / Tricky'),
                      selected: selectedResponse == ParentActivityResponse.struggled,
                      onSelected: (val) => setDialogState(() => selectedResponse = ParentActivityResponse.struggled),
                    ),
                    ChoiceChip(
                      label: const Text('Skip for Now'),
                      selected: selectedResponse == ParentActivityResponse.skipped,
                      onSelected: (val) => setDialogState(() => selectedResponse = ParentActivityResponse.skipped),
                    ),
                  ],
                ),
                if (selectedResponse == ParentActivityResponse.skipped) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Reason for skipping (no pressure, we understand!):',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSkipReason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Not enough time today', child: Text('Not enough time today')),
                      DropdownMenuItem(value: 'Child preferred other activity', child: Text('Child preferred other activity')),
                      DropdownMenuItem(value: 'Materials unavailable', child: Text('Materials unavailable')),
                      DropdownMenuItem(value: 'Too complex right now', child: Text('Too complex right now')),
                      DropdownMenuItem(value: 'Child was tired or unwell', child: Text('Child was tired or unwell')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedSkipReason = val);
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Your Observations / Notes for ${rec.llgName}:',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: feedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share how your child reacted, questions you have, or what went well...',
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _service.submitParentResponse(
                    recommendationId: rec.id,
                    response: selectedResponse,
                    feedback: feedbackController.text.trim(),
                    skippedReason: selectedResponse == ParentActivityResponse.skipped
                        ? selectedSkipReason
                        : null,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Response recorded and shared with your guide.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save Response'),
            ),
          ],
        ),
      ),
    );
  }
}
