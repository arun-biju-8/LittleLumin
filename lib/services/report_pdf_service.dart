// lib/services/report_pdf_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/widgets.dart' as pw_widgets;
import 'package:printing/printing.dart';
import '../models/specialist_report_model.dart';
import '../models/child_model.dart';
import '../models/specialist_case_model.dart';

class ReportPdfService {
  /// Generate a print-ready multi-page PDF document for any SpecialistReportModel
  static Future<Uint8List> generateReportPdf({
    required SpecialistReportModel report,
    ChildModel? child,
    SpecialistCaseModel? caseModel,
  }) async {
    final pdf = pw.Document(
      title: report.title,
      author: report.specialistName,
      creator: 'LittleLumin Specialist Portal',
    );

    // Color definitions
    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const tealColor = PdfColor.fromInt(0xFF0EA5E9);
    const emeraldColor = PdfColor.fromInt(0xFF10B981);
    const amberColor = PdfColor.fromInt(0xFFF59E0B);
    const textMutedColor = PdfColor.fromInt(0xFF64748B);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const lightBgColor = PdfColor.fromInt(0xFFF8FAFC);

    final dateFormat = DateFormat.yMMMd();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 26,
                      height: 26,
                      decoration: pw.BoxDecoration(
                        color: tealColor,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'LL',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'LittleLumin',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: navyColor,
                          ),
                        ),
                        pw.Text(
                          'Specialist Clinical & Developmental Workspace',
                          style: const pw.TextStyle(fontSize: 8, color: textMutedColor),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      report.reportType.displayName,
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: tealColor),
                    ),
                    pw.Text(
                      'Report Date: ${dateFormat.format(report.generatedAt)}',
                      style: const pw.TextStyle(fontSize: 8, color: textMutedColor),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            margin: const pw.EdgeInsets.only(top: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CONFIDENTIAL | LittleLumin Specialist Case Assessment | DPDP Compliant',
                  style: const pw.TextStyle(fontSize: 7, color: textMutedColor),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: textMutedColor),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Title Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: navyColor,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          report.title,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Reporting Period: ${report.periodLabel} | Case ID: ${report.caseId}',
                          style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: report.isShared
                          ? emeraldColor
                          : (report.isFinalized ? tealColor : amberColor),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      report.status.name.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // 2. Child & Specialist Demographics Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: lightBgColor,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildLabelValue('Child Name', report.childName),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Age / Gender', child != null ? '${child.ageYears} years | ${child.gender}' : 'Early Childhood'),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Parent / Guardian', caseModel?.parentName.isNotEmpty == true ? caseModel!.parentName : 'Authorized Caregiver'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildLabelValue('Assigned Specialist', report.specialistName),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('Clinical Focus', caseModel?.purpose.isNotEmpty == true ? caseModel!.purpose : 'Milestone Assessment'),
                        pw.SizedBox(height: 4),
                        _buildLabelValue('DPDP Notice Version', caseModel != null ? 'v${caseModel.consentNoticeVersion}' : 'v1.0-dpdp'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // 3. Executive Assessment Summary
            _buildSectionHeading('Executive Clinical Summary', tealColor),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                report.summary,
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
              ),
            ),
            pw.SizedBox(height: 16),

            // 4. Developmental Domain Scores Table
            if (report.domainScores.isNotEmpty) ...[
              _buildSectionHeading('Developmental Domain Analysis (6 Primary Domains)', tealColor),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: lightBgColor),
                    children: [
                      _buildTableHeaderCell('Domain'),
                      _buildTableHeaderCell('Score / Proficiency'),
                      _buildTableHeaderCell('Clinical Status'),
                      _buildTableHeaderCell('Trajectory Indicator'),
                    ],
                  ),
                  ...report.domainScores.entries.map((entry) {
                    final cap = entry.key[0].toUpperCase() + entry.key.substring(1);
                    final score = entry.value;
                    final isMastered = score >= 70.0;
                    final isEmerging = score >= 40.0;
                    final statusLabel = isMastered ? 'Mastered' : (isEmerging ? 'Emerging' : 'Needs Support');
                    final statusColor = isMastered ? emeraldColor : (isEmerging ? amberColor : PdfColors.redAccent);

                    return pw.TableRow(
                      children: [
                        _buildTableCell(cap, isBold: true),
                        _buildTableCell('${score.toStringAsFixed(1)}%'),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            statusLabel,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: statusColor),
                          ),
                        ),
                        _buildTableCell(isMastered ? 'Milestone Established' : (isEmerging ? 'Progressing Well' : 'Targeted Scaffolding Needed')),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // 5. Strengths & Growth Opportunities
            if (report.strengths.isNotEmpty || report.growthAreas.isNotEmpty) ...[
              _buildSectionHeading('Strengths & Growth Opportunities', tealColor),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: lightBgColor,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: emeraldColor, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Observed Strengths', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: emeraldColor)),
                          pw.SizedBox(height: 6),
                          ...report.strengths.map((s) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 4),
                                child: pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Container(
                                      width: 4,
                                      height: 4,
                                      margin: const pw.EdgeInsets.only(top: 3, right: 6),
                                      decoration: const pw.BoxDecoration(color: emeraldColor, shape: pw.BoxShape.circle),
                                    ),
                                    pw.Expanded(child: pw.Text(s, style: const pw.TextStyle(fontSize: 9))),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: lightBgColor,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: amberColor, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Developmental Focus Areas', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: amberColor)),
                          pw.SizedBox(height: 6),
                          ...report.growthAreas.map((g) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 4),
                                child: pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Container(
                                      width: 4,
                                      height: 4,
                                      margin: const pw.EdgeInsets.only(top: 3, right: 6),
                                      decoration: const pw.BoxDecoration(color: amberColor, shape: pw.BoxShape.circle),
                                    ),
                                    pw.Expanded(child: pw.Text(g, style: const pw.TextStyle(fontSize: 9))),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // 6. Key Assessment Findings
            if (report.keyFindings.isNotEmpty) ...[
              _buildSectionHeading('Key Evidence-Based Findings', tealColor),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: report.keyFindings.map((finding) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 5,
                            height: 5,
                            margin: const pw.EdgeInsets.only(top: 3, right: 6),
                            decoration: const pw.BoxDecoration(color: tealColor, shape: pw.BoxShape.circle),
                          ),
                          pw.Expanded(child: pw.Text(finding, style: const pw.TextStyle(fontSize: 9))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // 7. Recorded Activities (if present in activityRecords)
            if (report.activityRecords.isNotEmpty) ...[
              _buildSectionHeading('Recorded Learning Activities (${report.activityRecords.length})', tealColor),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: lightBgColor),
                    children: [
                      _buildTableHeaderCell('Activity Title'),
                      _buildTableHeaderCell('Domain'),
                      _buildTableHeaderCell('Level'),
                      _buildTableHeaderCell('Score Delta'),
                    ],
                  ),
                  ...report.activityRecords.take(8).map((act) {
                    final delta = (act['appliedScoreDelta'] as num?)?.toDouble() ?? 0.0;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(act['activityTitle'] ?? 'Activity'),
                        _buildTableCell(act['skillDomain'] ?? 'skill'),
                        _buildTableCell('Level ${act['levelAtTime'] ?? 1}'),
                        _buildTableCell('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} pts'),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // 8. Actionable Care Plan Recommendations
            if (report.recommendations.isNotEmpty) ...[
              _buildSectionHeading('Care Plan & Actionable Recommendations', tealColor),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: lightBgColor,
                  border: pw.Border.all(color: borderColor),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: report.recommendations.asMap().entries.map((entry) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 16,
                            height: 16,
                            margin: const pw.EdgeInsets.only(right: 8),
                            decoration: pw.BoxDecoration(
                              color: tealColor,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                '${entry.key + 1}',
                                style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(entry.value, style: const pw.TextStyle(fontSize: 9, lineSpacing: 2)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // 9. Specialist Clinical Notes (if present)
            if (report.specialistNotes?.isNotEmpty == true) ...[
              _buildSectionHeading('Specialist Professional Observations & Clinical Addenda', tealColor),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  report.specialistNotes!,
                  style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // 10. Verification & Attestation Notice
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(6),
                color: lightBgColor,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Specialist Attestation:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMutedColor)),
                      pw.SizedBox(height: 2),
                      pw.Text(report.specialistName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyColor)),
                      pw.Text('Verified Learning & Growth Guide', style: const pw.TextStyle(fontSize: 8, color: textMutedColor)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generation Reference:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textMutedColor)),
                      pw.SizedBox(height: 2),
                      pw.Text(report.id.isNotEmpty ? 'REC-${report.id.substring(0, report.id.length > 8 ? 8 : report.id.length).toUpperCase()}' : 'DRAFT', style: const pw.TextStyle(fontSize: 9, color: navyColor)),
                      pw.Text('DPDP Notice v1.0-dpdp', style: const pw.TextStyle(fontSize: 8, color: textMutedColor)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Launch platform print dialog or share/export PDF file
  static Future<bool> exportReportPdf(SpecialistReportModel report, [BuildContext? context]) async {
    final bytes = await generateReportPdf(report: report);
    final filename = '${report.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase()}_${DateFormat('yyyyMMdd').format(report.generatedAt)}.pdf';
    return exportOrSharePdf(pdfBytes: bytes, filename: filename);
  }

  /// Launch platform print dialog or share/export PDF file
  static Future<bool> exportOrSharePdf({
    required Uint8List pdfBytes,
    required String filename,
  }) async {
    try {
      await Printing.sharePdf(bytes: pdfBytes, filename: filename);
      return true;
    } catch (e) {
      debugPrint('Error sharing/exporting PDF: $e');
      try {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
        return true;
      } catch (inner) {
        debugPrint('Error laying out PDF for print: $inner');
        return false;
      }
    }
  }

  static pw.Widget _buildSectionHeading(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xFF0F172A),
        ),
      ),
    );
  }

  static pw.Widget _buildLabelValue(String label, String value) {
    return pw.Row(
      children: [
        pw.Text('$label: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF64748B))),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF0F172A))),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A)),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: const PdfColor.fromInt(0xFF0F172A),
        ),
      ),
    );
  }
}
