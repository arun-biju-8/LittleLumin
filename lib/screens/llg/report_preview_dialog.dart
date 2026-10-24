// lib/screens/llg/report_preview_dialog.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/specialist_report_model.dart';
import '../../models/child_model.dart';
import '../../models/specialist_case_model.dart';
import '../../services/specialist_report_service.dart';
import '../../services/report_pdf_service.dart';

class ReportPreviewDialog extends StatefulWidget {
  final SpecialistReportModel report;
  final ChildModel? child;
  final SpecialistCaseModel? caseModel;
  final SpecialistReportService? reportService;
  final VoidCallback? onReportUpdated;
  final VoidCallback? onReportFinalized;

  const ReportPreviewDialog({
    super.key,
    required this.report,
    this.child,
    this.caseModel,
    this.reportService,
    this.onReportUpdated,
    this.onReportFinalized,
  });

  static Future<void> show(
    BuildContext context, {
    required SpecialistReportModel report,
    ChildModel? child,
    SpecialistCaseModel? caseModel,
    VoidCallback? onReportUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ReportPreviewDialog(
        report: report,
        child: child,
        caseModel: caseModel,
        onReportUpdated: onReportUpdated,
      ),
    );
  }

  @override
  State<ReportPreviewDialog> createState() => _ReportPreviewDialogState();
}

class _ReportPreviewDialogState extends State<ReportPreviewDialog> {
  late SpecialistReportModel _currentReport;
  bool _isExporting = false;
  bool _isSharing = false;
  bool _isFinalizing = false;

  static const Color colorNavy = Color(0xFF0F172A);
  static const Color colorSlate = Color(0xFF1E293B);
  static const Color colorCard = Color(0xFF1E293B);
  static const Color colorBorder = Color(0xFF334155);
  static const Color colorTeal = Color(0xFF0EA5E9);
  static const Color colorAmber = Color(0xFFF59E0B);
  static const Color colorEmerald = Color(0xFF10B981);
  static const Color colorTextMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final pdfBytes = await ReportPdfService.generateReportPdf(
        report: _currentReport,
        child: widget.child,
        caseModel: widget.caseModel,
      );

      final safeName = _currentReport.childName.replaceAll(' ', '_');
      final fileName = '${_currentReport.reportType.shortName}_Report_${safeName}_${DateFormat('yyyyMMdd').format(_currentReport.generatedAt)}.pdf';

      final success = await ReportPdfService.exportOrSharePdf(
        pdfBytes: pdfBytes,
        filename: fileName,
      );

      if (success) {
        if (_currentReport.id.isNotEmpty) {
          await SpecialistReportService().recordPdfExport(_currentReport.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Report PDF exported successfully!'), backgroundColor: colorEmerald),
          );
        }
      } else {
        throw Exception('Platform export was cancelled or unsupported.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ PDF export note: $e'), backgroundColor: colorAmber),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareWithParent() async {
    if (widget.caseModel == null && _currentReport.caseId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Share with Parent?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'This will publish the ${_currentReport.reportType.displayName} to the parent\'s portal under active DPDP consent.',
          style: GoogleFonts.inter(color: colorTextMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colorEmerald),
            child: const Text('Share Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSharing = true);
    try {
      await SpecialistReportService().shareReportWithParent(
        reportId: _currentReport.id,
        parentId: widget.caseModel?.parentId ?? '',
        childName: _currentReport.childName,
        specialistName: _currentReport.specialistName,
      );

      setState(() {
        _currentReport = _currentReport.copyWith(status: SpecialistReportStatus.shared);
      });
      widget.onReportUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Report successfully shared with parent!'), backgroundColor: colorEmerald),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _finalizeReport() async {
    setState(() => _isFinalizing = true);
    try {
      await SpecialistReportService().updateReportStatus(
        _currentReport.id,
        SpecialistReportStatus.finalized,
      );

      setState(() {
        _currentReport = _currentReport.copyWith(status: SpecialistReportStatus.finalized);
      });
      widget.onReportUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Report status updated to Finalized!'), backgroundColor: colorTeal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finalizing report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Dialog(
      backgroundColor: colorNavy,
      insetPadding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: colorBorder),
      ),
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 850),
        child: Column(
          children: [
            // Header Bar
            _buildDialogHeader(),

            // Scrollable Report Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Demographics & Period Bar
                    _buildMetaBanner(),
                    const SizedBox(height: 20),

                    // Executive Summary
                    _buildSectionCard(
                      title: 'Executive Clinical Summary',
                      icon: Icons.article_outlined,
                      child: Text(
                        _currentReport.summary,
                        style: GoogleFonts.inter(fontSize: 13, height: 1.5, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Domain Analysis Table
                    if (_currentReport.domainScores.isNotEmpty) ...[
                      _buildDomainScoresSection(),
                      const SizedBox(height: 16),
                    ],

                    // Strengths & Growth Areas
                    if (_currentReport.strengths.isNotEmpty || _currentReport.growthAreas.isNotEmpty) ...[
                      _buildStrengthsAndGrowthSection(isWide),
                      const SizedBox(height: 16),
                    ],

                    // Key Evidence-Based Findings
                    if (_currentReport.keyFindings.isNotEmpty) ...[
                      _buildKeyFindingsSection(),
                      const SizedBox(height: 16),
                    ],

                    // Recorded Activities
                    if (_currentReport.activityRecords.isNotEmpty) ...[
                      _buildActivitiesTable(),
                      const SizedBox(height: 16),
                    ],

                    // Care Plan Recommendations
                    if (_currentReport.recommendations.isNotEmpty) ...[
                      _buildRecommendationsSection(),
                      const SizedBox(height: 16),
                    ],

                    // Specialist Notes
                    if (_currentReport.specialistNotes?.isNotEmpty == true) ...[
                      _buildSectionCard(
                        title: 'Specialist Professional Observations & Addenda',
                        icon: Icons.rate_review_outlined,
                        child: Text(
                          _currentReport.specialistNotes!,
                          style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Footer Actions
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    Color statusColor;
    switch (_currentReport.status) {
      case SpecialistReportStatus.finalized:
        statusColor = colorTeal;
        break;
      case SpecialistReportStatus.shared:
        statusColor = colorEmerald;
        break;
      case SpecialistReportStatus.draft:
        statusColor = colorAmber;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: colorSlate,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: colorBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorTeal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined, color: colorTeal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentReport.title,
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_currentReport.reportType.displayName} • Period: ${_currentReport.periodLabel}',
                        style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Text(
              _currentReport.status.name.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: colorTextMuted, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorSlate,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          _buildMetaItem('Child', _currentReport.childName, Icons.child_care),
          _buildMetaItem('Specialist', _currentReport.specialistName, Icons.person_outline),
          _buildMetaItem('Generated', DateFormat.yMMMd().format(_currentReport.generatedAt), Icons.calendar_today_outlined),
          _buildMetaItem('Period', _currentReport.periodLabel, Icons.date_range_outlined),
          _buildMetaItem('DPDP Consent', widget.caseModel?.consentNoticeVersion ?? 'v1.0-dpdp', Icons.verified_user_outlined),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorTeal),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, color: colorTextMuted, fontWeight: FontWeight.bold)),
            Text(value, style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _buildDomainScoresSection() {
    return _buildSectionCard(
      title: 'Developmental Domain Mastery (6 Primary Domains)',
      icon: Icons.bar_chart_outlined,
      child: Column(
        children: _currentReport.domainScores.entries.map((entry) {
          final domainName = entry.key[0].toUpperCase() + entry.key.substring(1);
          final score = entry.value;
          final isMastered = score >= 70.0;
          final isEmerging = score >= 40.0;
          final color = isMastered ? colorEmerald : (isEmerging ? colorAmber : Colors.redAccent);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(domainName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    Text('${score.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (score / 100.0).clamp(0.0, 1.0),
                    backgroundColor: colorNavy,
                    color: color,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStrengthsAndGrowthSection(bool isWide) {
    final strengthsCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorEmerald.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorEmerald.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline, size: 16, color: colorEmerald),
              const SizedBox(width: 6),
              Text('Observed Strengths', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorEmerald)),
            ],
          ),
          const SizedBox(height: 8),
          ..._currentReport.strengths.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: colorEmerald)),
                    Expanded(child: Text(s, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70))),
                  ],
                ),
              )),
        ],
      ),
    );

    final growthCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorAmber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorAmber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: colorAmber),
              const SizedBox(width: 6),
              Text('Developmental Focus Areas', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorAmber)),
            ],
          ),
          const SizedBox(height: 8),
          ..._currentReport.growthAreas.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: colorAmber)),
                    Expanded(child: Text(g, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70))),
                  ],
                ),
              )),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: strengthsCard),
          const SizedBox(width: 14),
          Expanded(child: growthCard),
        ],
      );
    } else {
      return Column(
        children: [
          strengthsCard,
          const SizedBox(height: 12),
          growthCard,
        ],
      );
    }
  }

  Widget _buildKeyFindingsSection() {
    return _buildSectionCard(
      title: 'Key Evidence-Based Findings',
      icon: Icons.checklist_outlined,
      child: Column(
        children: _currentReport.keyFindings.map((f) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: colorTeal),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: GoogleFonts.inter(fontSize: 12, color: Colors.white70))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivitiesTable() {
    return _buildSectionCard(
      title: 'Activities Recorded in Reporting Period',
      icon: Icons.sports_esports_outlined,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _currentReport.activityRecords.take(6).length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, index) {
          final act = _currentReport.activityRecords[index];
          final delta = (act['appliedScoreDelta'] as num?)?.toDouble() ?? 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorNavy,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(act['activityTitle'] ?? 'Activity', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
                Text(act['skillDomain'] ?? 'skill', style: GoogleFonts.inter(fontSize: 10, color: colorTextMuted)),
                const SizedBox(width: 12),
                Text(
                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} pts',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: delta >= 0 ? colorEmerald : Colors.redAccent),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return _buildSectionCard(
      title: 'Care Plan Actionable Recommendations',
      icon: Icons.psychology_outlined,
      child: Column(
        children: _currentReport.recommendations.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 9,
                  backgroundColor: colorTeal,
                  child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.value, style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: Colors.white70))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorTeal),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: colorSlate,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: colorBorder)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close Preview', style: GoogleFonts.inter(color: colorTextMuted)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (_currentReport.isDraft)
                OutlinedButton.icon(
                  onPressed: _isFinalizing ? null : _finalizeReport,
                  icon: _isFinalizing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colorTeal))
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Finalize'),
                  style: OutlinedButton.styleFrom(foregroundColor: colorTeal, side: const BorderSide(color: colorTeal)),
                ),
              if (!_currentReport.isShared)
                ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareWithParent,
                  icon: _isSharing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share with Parent'),
                  style: ElevatedButton.styleFrom(backgroundColor: colorEmerald, foregroundColor: Colors.white),
                ),
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportPdf,
                icon: _isExporting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('Export Print-Ready PDF'),
                style: ElevatedButton.styleFrom(backgroundColor: colorTeal, foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
