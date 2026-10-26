// lib/screens/llg/report_center_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/specialist_report_model.dart';
import '../../models/specialist_case_model.dart';
import '../../models/child_model.dart';
import '../../services/specialist_report_service.dart';
import '../../services/specialist_case_service.dart';
import '../../services/report_pdf_service.dart';
import 'report_preview_dialog.dart';

class ReportCenterPage extends StatefulWidget {
  final SpecialistCaseModel? initialCase;
  final ChildModel? initialChild;
  final String? initialChildId;
  final SpecialistReportService? reportService;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  const ReportCenterPage({
    super.key,
    this.initialCase,
    this.initialChild,
    this.initialChildId,
    this.reportService,
    this.firestore,
    this.auth,
  });

  @override
  State<ReportCenterPage> createState() => _ReportCenterPageState();
}

class _ReportCenterPageState extends State<ReportCenterPage> {
  late final SpecialistReportService _reportService;
  late final SpecialistCaseService _caseService;
  late final FirebaseAuth? _auth;

  String _searchQuery = '';
  String _selectedTypeFilter = 'all';
  bool _isGenerating = false;

  // Generator form state
  SpecialistCaseModel? _selectedCase;
  ReportType _selectedReportType = ReportType.progress;
  String _selectedPeriodPreset = '30_days';
  final TextEditingController _customNotesController = TextEditingController();

  final Map<String, bool> _includedSections = {
    'Domain Scores': true,
    'Activities': true,
    'Parent Feedback': true,
    'Clinical Observations': true,
    'Care Plan Recommendations': true,
    'AI Narrative Synthesis': true,
  };

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
    _reportService = widget.reportService ?? SpecialistReportService(firestore: widget.firestore);
    _caseService = SpecialistCaseService(firestore: widget.firestore);
    if (widget.auth != null) {
      _auth = widget.auth;
    } else {
      try {
        _auth = FirebaseAuth.instance;
      } catch (_) {
        _auth = null;
      }
    }
    _selectedCase = widget.initialCase;
  }

  @override
  void dispose() {
    _customNotesController.dispose();
    super.dispose();
  }

  void _showNewReportModal(List<SpecialistCaseModel> availableCases) {
    if (_selectedCase == null && availableCases.isNotEmpty) {
      _selectedCase = availableCases.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: colorBorder),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.9,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generate Clinical & Progress Report',
                              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select child, report type, period, and included clinical modules.',
                              style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: colorTextMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: colorBorder, height: 24),

                    // 1. Select Child / Case
                    Text('1. Select Child / Case', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: colorSlate,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<SpecialistCaseModel>(
                          value: _selectedCase,
                          isExpanded: true,
                          dropdownColor: colorSlate,
                          items: availableCases.map((c) {
                            return DropdownMenuItem<SpecialistCaseModel>(
                              value: c,
                              child: Text(
                                '${c.childName} (Parent: ${c.parentName}) • Status: ${c.status.name.toUpperCase()}',
                                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => _selectedCase = val);
                              setState(() => _selectedCase = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Select Report Type
                    Text('2. Select Report Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    ...ReportType.values.map((type) {
                      final isSelected = _selectedReportType == type;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setModalState(() => _selectedReportType = type),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? colorTeal.withOpacity(0.12) : colorSlate,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSelected ? colorTeal : colorBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? colorTeal : colorTextMuted,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type.displayName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        type.description,
                                        style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 18),

                    // 3. Reporting Period
                    Text('3. Reporting Period', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPeriodChoiceChip('Last 14 Days', '14_days', setModalState),
                        _buildPeriodChoiceChip('Last 30 Days', '30_days', setModalState),
                        _buildPeriodChoiceChip('Last 90 Days', '90_days', setModalState),
                        _buildPeriodChoiceChip('All Available Time', 'all_time', setModalState),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 4. Included Clinical Modules
                    Text('4. Included Modules', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _includedSections.keys.map((key) {
                        final checked = _includedSections[key] ?? true;
                        return FilterChip(
                          label: Text(key),
                          selected: checked,
                          onSelected: (val) {
                            setModalState(() => _includedSections[key] = val);
                          },
                          backgroundColor: colorSlate,
                          selectedColor: colorTeal.withOpacity(0.2),
                          checkmarkColor: colorTeal,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            color: checked ? Colors.white : colorTextMuted,
                            fontWeight: checked ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: BorderSide(color: checked ? colorTeal : colorBorder),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // 5. Specialist Custom Notes (Optional)
                    Text('5. Specialist Clinical Notes (Optional)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customNotesController,
                      maxLines: 3,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add clinical impressions, observation caveats, or customized home recommendations...',
                        hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                        filled: true,
                        fillColor: colorSlate,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: colorTeal)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _isGenerating
                            ? null
                            : () async {
                                if (_selectedCase == null) return;
                                setModalState(() => _isGenerating = true);
                                setState(() => _isGenerating = true);
                                Navigator.pop(ctx);
                                await _handleGenerateReport();
                              },
                        icon: _isGenerating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(_isGenerating ? 'Synthesizing Records...' : 'Generate & Review Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
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

  Widget _buildPeriodChoiceChip(String label, String key, void Function(void Function()) setModalState) {
    final isSelected = _selectedPeriodPreset == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setModalState(() => _selectedPeriodPreset = key);
        }
      },
      backgroundColor: colorSlate,
      selectedColor: colorTeal.withOpacity(0.2),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: isSelected ? colorTeal : colorTextMuted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: isSelected ? colorTeal : colorBorder),
      ),
    );
  }

  Future<void> _handleGenerateReport() async {
    final c = _selectedCase;
    if (c == null) return;

    DateTime? startDate;
    DateTime? endDate = DateTime.now();
    String periodLabel = 'All Available Time';

    if (_selectedPeriodPreset == '14_days') {
      startDate = DateTime.now().subtract(const Duration(days: 14));
      periodLabel = 'Last 14 Days';
    } else if (_selectedPeriodPreset == '30_days') {
      startDate = DateTime.now().subtract(const Duration(days: 30));
      periodLabel = 'Last 30 Days';
    } else if (_selectedPeriodPreset == '90_days') {
      startDate = DateTime.now().subtract(const Duration(days: 90));
      periodLabel = 'Last 90 Days';
    } else {
      startDate = null;
      periodLabel = 'All Available Time';
    }

    final child = widget.initialChild ??
        ChildModel(
          childId: c.childId,
          parentId: c.parentId,
          name: c.childName,
          dateOfBirth: DateTime.now().subtract(Duration(days: c.childAgeYears * 365)),
          gender: 'Child',
          createdAt: c.createdAt,
        );

    final user = _auth?.currentUser;

    try {
      final report = await _reportService.generateComprehensiveReport(
        caseModel: c,
        child: child,
        specialistId: user?.uid ?? 'specialist',
        specialistName: c.specialistName,
        reportType: _selectedReportType,
        startDate: startDate,
        endDate: endDate,
        periodLabel: periodLabel,
        includedSections: _includedSections.entries.where((e) => e.value).map((e) => e.key).toList(),
        customNotes: _customNotesController.text.trim().isNotEmpty ? _customNotesController.text.trim() : null,
      );

      _customNotesController.clear();

      if (mounted) {
        setState(() => _isGenerating = false);
        ReportPreviewDialog.show(
          context,
          report: report,
          child: child,
          caseModel: c,
          onReportUpdated: () => setState(() {}),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth?.currentUser;

    return StreamBuilder<List<SpecialistCaseModel>>(
      stream: _caseService.getSpecialistCasesStream(specialistId: user?.uid ?? ''),
      builder: (context, caseSnapshot) {
        final cases = caseSnapshot.data ?? [];

        return Scaffold(
          backgroundColor: colorNavy,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action Header
                _buildReportCenterHeader(cases),
                const SizedBox(height: 24),

                // Report Type Filter Tabs
                _buildTypeFilterTabs(),
                const SizedBox(height: 20),

                // Search & Filter Bar
                _buildSearchBar(),
                const SizedBox(height: 20),

                // Report History List
                _buildReportsStreamView(cases),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportCenterHeader(List<SpecialistCaseModel> cases) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorSlate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: colorTeal, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Specialist Report Center',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Synthesize evidence-based assessment reports, export multi-page print-ready PDFs, and securely share developmental insights with parents.',
                  style: GoogleFonts.inter(fontSize: 12, color: colorTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _showNewReportModal(cases),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Generate New Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterTabs() {
    final filters = [
      {'key': 'all', 'label': 'All Reports'},
      {'key': 'progress', 'label': 'Progress'},
      {'key': 'activityPerformance', 'label': 'Activity Performance'},
      {'key': 'parentEngagement', 'label': 'Parent Engagement'},
      {'key': 'clinicalObservation', 'label': 'Clinical Observations'},
      {'key': 'caseSummary', 'label': 'Case Summary'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedTypeFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedTypeFilter = f['key']!),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? colorTeal.withOpacity(0.15) : colorSlate,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? colorTeal : colorBorder),
                ),
                child: Text(
                  f['label']!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : colorTextMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colorCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorBorder),
      ),
      child: TextField(
        style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search by child name, title, or reporting period...',
          hintStyle: GoogleFonts.inter(color: colorTextMuted, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: colorTextMuted, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReportsStreamView(List<SpecialistCaseModel> cases) {
    final user = _auth?.currentUser;
    final childId = widget.initialChild?.childId ?? '';

    // If childId is specified, stream by childId, else stream by specialistId
    final stream = childId.isNotEmpty
        ? _reportService.getReportsStream(childId)
        : _reportService.getSpecialistReportsStream(user?.uid ?? '');

    return StreamBuilder<List<SpecialistReportModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        }

        var reports = snapshot.data ?? [];

        // Apply type filter
        if (_selectedTypeFilter != 'all') {
          reports = reports.where((r) => r.reportType.name == _selectedTypeFilter).toList();
        }

        // Apply search query
        if (_searchQuery.isNotEmpty) {
          reports = reports.where((r) {
            final t = r.title.toLowerCase();
            final c = r.childName.toLowerCase();
            final p = r.periodLabel.toLowerCase();
            return t.contains(_searchQuery) || c.contains(_searchQuery) || p.contains(_searchQuery);
          }).toList();
        }

        if (reports.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined, size: 48, color: colorTextMuted.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(
                  'No reports found matching your criteria',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click "Generate New Report" above to synthesize assessment data.',
                  style: GoogleFonts.inter(color: colorTextMuted, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = reports[index];
            SpecialistCaseModel? matchingCase;
            try {
              matchingCase = cases.firstWhere((c) => c.caseId == report.caseId);
            } catch (_) {}

            return _buildReportCard(report, matchingCase);
          },
        );
      },
    );
  }

  Widget _buildReportCard(SpecialistReportModel report, SpecialistCaseModel? matchingCase) {
    Color statusColor;
    switch (report.status) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            report.reportType.shortName.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report.title,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Child: ${report.childName} • Period: ${report.periodLabel} • Generated: ${DateFormat.yMMMd().format(report.generatedAt)}',
                      style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
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
                  report.status.name.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.summary,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Includes ${report.includedSections.length} clinical modules',
                style: GoogleFonts.inter(fontSize: 11, color: colorTextMuted),
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ReportPreviewDialog.show(
                        context,
                        report: report,
                        caseModel: matchingCase,
                        reportService: _reportService,
                        onReportUpdated: () => setState(() {}),
                      );
                    },
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                    label: const Text('Open Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorTeal,
                      side: const BorderSide(color: colorTeal),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final bytes = await ReportPdfService.generateReportPdf(
                          report: report,
                          caseModel: matchingCase,
                        );
                        await ReportPdfService.exportOrSharePdf(
                          pdfBytes: bytes,
                          filename: '${report.reportType.shortName}_Report_${report.childName.replaceAll(' ', '_')}.pdf',
                        );
                        await _reportService.recordPdfExport(report.id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Export note: $e'), backgroundColor: colorAmber),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
