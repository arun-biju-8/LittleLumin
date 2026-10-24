// lib/models/specialist_report_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum SpecialistReportStatus {
  draft,
  finalized,
  shared,
}

class SpecialistReportModel {
  final String id;
  final String caseId;
  final String childId;
  final String childName;
  final String specialistId;
  final String specialistName;
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

  SpecialistReportModel({
    required this.id,
    required this.caseId,
    required this.childId,
    required this.childName,
    required this.specialistId,
    required this.specialistName,
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

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
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

    return SpecialistReportModel(
      id: id,
      caseId: data['caseId'] ?? '',
      childId: data['childId'] ?? '',
      childName: data['childName'] ?? '',
      specialistId: data['specialistId'] ?? '',
      specialistName: data['specialistName'] ?? '',
      title: data['title'] ?? 'Developmental Progress Assessment',
      summary: data['summary'] ?? '',
      domainScores: parseScores(data['domainScores']),
      keyFindings: parseList(data['keyFindings']),
      strengths: parseList(data['strengths']),
      growthAreas: parseList(data['growthAreas']),
      recommendations: parseList(data['recommendations']),
      status: parseStatus(data['status']),
      generatedAt: parseDate(data['generatedAt']),
      finalizedAt: data['finalizedAt'] != null ? parseDate(data['finalizedAt']) : null,
      sharedAt: data['sharedAt'] != null ? parseDate(data['sharedAt']) : null,
      specialistNotes: data['specialistNotes'],
    );
  }

  SpecialistReportModel copyWith({
    String? title,
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
  }) {
    return SpecialistReportModel(
      id: id,
      caseId: caseId,
      childId: childId,
      childName: childName,
      specialistId: specialistId,
      specialistName: specialistName,
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
    );
  }
}
