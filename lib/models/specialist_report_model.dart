// lib/models/specialist_report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum SpecialistReportStatus {
  draft,
  finalized,
  shared,
}

enum ReportType {
  progress,
  activityPerformance,
  parentEngagement,
  clinicalObservation,
  caseSummary,
}

extension ReportTypeExtension on ReportType {
  String get displayName {
    switch (this) {
      case ReportType.progress:
        return 'Child Development Progress Report';
      case ReportType.activityPerformance:
        return 'Activity Performance Report';
      case ReportType.parentEngagement:
        return 'Parent Engagement Report';
      case ReportType.clinicalObservation:
        return 'Specialist Clinical & Observation Report';
      case ReportType.caseSummary:
        return 'Consolidated Case Summary Report';
    }
  }

  String get shortName {
    switch (this) {
      case ReportType.progress:
        return 'Progress';
      case ReportType.activityPerformance:
        return 'Activities';
      case ReportType.parentEngagement:
        return 'Parent Engagement';
      case ReportType.clinicalObservation:
        return 'Clinical Notes';
      case ReportType.caseSummary:
        return 'Case Summary';
    }
  }

  String get description {
    switch (this) {
      case ReportType.progress:
        return 'Comprehensive milestone trajectory, domain proficiencies, and evidence-based progress velocity.';
      case ReportType.activityPerformance:
        return 'Detailed breakdown of activity completions, attempts, difficulty ratings, and domain mastery.';
      case ReportType.parentEngagement:
        return 'Home participation audit, parent-reported confidence, feedback notes, and consultation log.';
      case ReportType.clinicalObservation:
        return 'Professional observations, flagged developmental struggles, clinical notes, and diagnostic guidance.';
      case ReportType.caseSummary:
        return 'Executive multi-dimensional case synopsis unifying progress, current plan, active concerns, and next steps.';
    }
  }
}

class SpecialistReportModel {
  final String id;
  final String caseId;
  final String childId;
  final String childName;
  final String specialistId;
  final String specialistName;
  final ReportType reportType;
  final String title;
  final String summary;
  final Map<String, double> domainScores;
  final List<String> keyFindings;
  final List<String> strengths;
  final List<String> growthAreas;
  final List<String> recommendations;
  final SpecialistReportStatus status;
  final DateTime generatedAt;
  final DateTime? finalizedAt;
  final DateTime? sharedAt;
  final String? specialistNotes;
  final DateTime? periodStartDate;
  final DateTime? periodEndDate;
  final String periodLabel;
  final List<String> includedSections;
  final List<String> dataSources;
  final String? pdfUrl;
  final DateTime? pdfGeneratedAt;
  final List<Map<String, dynamic>> activityRecords;
  final List<Map<String, dynamic>> feedbackRecords;
  final List<Map<String, dynamic>> observationRecords;

  SpecialistReportModel({
    required this.id,
    required this.caseId,
    required this.childId,
    required this.childName,
    required this.specialistId,
    required this.specialistName,
    this.reportType = ReportType.progress,
    required this.title,
    required this.summary,
    required this.domainScores,
    required this.keyFindings,
    required this.strengths,
    required this.growthAreas,
    required this.recommendations,
    this.status = SpecialistReportStatus.draft,
    required this.generatedAt,
    this.finalizedAt,
    this.sharedAt,
    this.specialistNotes,
    this.periodStartDate,
    this.periodEndDate,
    this.periodLabel = 'All Available Time',
    this.includedSections = const [],
    this.dataSources = const [],
    this.pdfUrl,
    this.pdfGeneratedAt,
    this.activityRecords = const [],
    this.feedbackRecords = const [],
    this.observationRecords = const [],
  });

  bool get isDraft => status == SpecialistReportStatus.draft;
  bool get isFinalized => status == SpecialistReportStatus.finalized;
  bool get isShared => status == SpecialistReportStatus.shared;

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'childId': childId,
      'childName': childName,
      'specialistId': specialistId,
      'specialistName': specialistName,
      'reportType': reportType.name,
      'title': title,
      'summary': summary,
      'domainScores': domainScores,
      'keyFindings': keyFindings,
      'strengths': strengths,
      'growthAreas': growthAreas,
      'recommendations': recommendations,
      'status': status.name,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'finalizedAt': finalizedAt != null ? Timestamp.fromDate(finalizedAt!) : null,
      'sharedAt': sharedAt != null ? Timestamp.fromDate(sharedAt!) : null,
      'specialistNotes': specialistNotes,
      'periodStartDate': periodStartDate != null ? Timestamp.fromDate(periodStartDate!) : null,
      'periodEndDate': periodEndDate != null ? Timestamp.fromDate(periodEndDate!) : null,
      'periodLabel': periodLabel,
      'includedSections': includedSections,
      'dataSources': dataSources,
      'pdfUrl': pdfUrl,
      'pdfGeneratedAt': pdfGeneratedAt != null ? Timestamp.fromDate(pdfGeneratedAt!) : null,
      'activityRecords': activityRecords,
      'feedbackRecords': feedbackRecords,
      'observationRecords': observationRecords,
    };
  }

  factory SpecialistReportModel.fromMap(String id, Map<String, dynamic> data) {
    SpecialistReportStatus parseStatus(dynamic val) {
      if (val is String) {
        for (final s in SpecialistReportStatus.values) {
          if (s.name == val) return s;
        }
      }
      return SpecialistReportStatus.draft;
    }

    ReportType parseReportType(dynamic val) {
      if (val is String) {
        for (final t in ReportType.values) {
          if (t.name == val) return t;
        }
      }
      return ReportType.progress;
    }

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    Map<String, double> parseScores(dynamic val) {
      final map = <String, double>{};
      if (val is Map) {
        val.forEach((k, v) {
          if (v is num) {
            map[k.toString()] = v.toDouble();
          }
        });
      }
      return map;
    }

    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<Map<String, dynamic>> parseMapList(dynamic val) {
      if (val is List) {
        return val.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }

    return SpecialistReportModel(
      id: id,
      caseId: data['caseId'] ?? '',
      childId: data['childId'] ?? '',
      childName: data['childName'] ?? '',
      specialistId: data['specialistId'] ?? '',
      specialistName: data['specialistName'] ?? '',
      reportType: parseReportType(data['reportType']),
      title: data['title'] ?? 'Developmental Progress Assessment',
      summary: data['summary'] ?? '',
      domainScores: parseScores(data['domainScores']),
      keyFindings: parseList(data['keyFindings']),
      strengths: parseList(data['strengths']),
      growthAreas: parseList(data['growthAreas']),
      recommendations: parseList(data['recommendations']),
      status: parseStatus(data['status']),
      generatedAt: parseDate(data['generatedAt']),
      finalizedAt: parseNullableDate(data['finalizedAt']),
      sharedAt: parseNullableDate(data['sharedAt']),
      specialistNotes: data['specialistNotes'],
      periodStartDate: parseNullableDate(data['periodStartDate']),
      periodEndDate: parseNullableDate(data['periodEndDate']),
      periodLabel: data['periodLabel'] ?? 'All Available Time',
      includedSections: parseList(data['includedSections']),
      dataSources: parseList(data['dataSources']),
      pdfUrl: data['pdfUrl'],
      pdfGeneratedAt: parseNullableDate(data['pdfGeneratedAt']),
      activityRecords: parseMapList(data['activityRecords']),
      feedbackRecords: parseMapList(data['feedbackRecords']),
      observationRecords: parseMapList(data['observationRecords']),
    );
  }

  SpecialistReportModel copyWith({
    String? title,
    ReportType? reportType,
    String? summary,
    Map<String, double>? domainScores,
    List<String>? keyFindings,
    List<String>? strengths,
    List<String>? growthAreas,
    List<String>? recommendations,
    SpecialistReportStatus? status,
    DateTime? finalizedAt,
    DateTime? sharedAt,
    String? specialistNotes,
    DateTime? periodStartDate,
    DateTime? periodEndDate,
    String? periodLabel,
    List<String>? includedSections,
    List<String>? dataSources,
    String? pdfUrl,
    DateTime? pdfGeneratedAt,
    List<Map<String, dynamic>>? activityRecords,
    List<Map<String, dynamic>>? feedbackRecords,
    List<Map<String, dynamic>>? observationRecords,
  }) {
    return SpecialistReportModel(
      id: id,
      caseId: caseId,
      childId: childId,
      childName: childName,
      specialistId: specialistId,
      specialistName: specialistName,
      reportType: reportType ?? this.reportType,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      domainScores: domainScores ?? this.domainScores,
      keyFindings: keyFindings ?? this.keyFindings,
      strengths: strengths ?? this.strengths,
      growthAreas: growthAreas ?? this.growthAreas,
      recommendations: recommendations ?? this.recommendations,
      status: status ?? this.status,
      generatedAt: generatedAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      sharedAt: sharedAt ?? this.sharedAt,
      specialistNotes: specialistNotes ?? this.specialistNotes,
      periodStartDate: periodStartDate ?? this.periodStartDate,
      periodEndDate: periodEndDate ?? this.periodEndDate,
      periodLabel: periodLabel ?? this.periodLabel,
      includedSections: includedSections ?? this.includedSections,
      dataSources: dataSources ?? this.dataSources,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfGeneratedAt: pdfGeneratedAt ?? this.pdfGeneratedAt,
      activityRecords: activityRecords ?? this.activityRecords,
      feedbackRecords: feedbackRecords ?? this.feedbackRecords,
      observationRecords: observationRecords ?? this.observationRecords,
    );
  }
}
