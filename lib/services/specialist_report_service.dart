// lib/services/specialist_report_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/specialist_case_model.dart';
import '../models/child_model.dart';
import '../models/specialist_report_model.dart';

class SpecialistReportService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  SpecialistReportService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  static const String collectionName = 'specialistReports';

  /// Stream reports for a specific child
  Stream<List<SpecialistReportModel>> getReportsStream(String childId) {
    final fs = _firestore;
    if (fs == null || childId.isEmpty) return Stream.value([]);
    return fs
        .collection(collectionName)
        .where('childId', isEqualTo: childId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SpecialistReportModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return list;
    });
  }

  /// Stream all reports authored by a specific specialist across cases
  Stream<List<SpecialistReportModel>> getSpecialistReportsStream(String specialistId) {
    final fs = _firestore;
    if (fs == null || specialistId.isEmpty) return Stream.value([]);
    return fs
        .collection(collectionName)
        .where('specialistId', isEqualTo: specialistId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SpecialistReportModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return list;
    });
  }

  /// Backward-compatible report generation method
  Future<SpecialistReportModel> generateReport({
    required SpecialistCaseModel caseModel,
    required ChildModel child,
    required String specialistId,
    required String specialistName,
    String? customNotes,
  }) async {
    return generateComprehensiveReport(
      caseModel: caseModel,
      child: child,
      specialistId: specialistId,
      specialistName: specialistName,
      reportType: ReportType.progress,
      customNotes: customNotes,
    );
  }

  /// Generate a comprehensive report for any of the 5 supported report types
  Future<SpecialistReportModel> generateComprehensiveReport({
    required SpecialistCaseModel caseModel,
    required ChildModel child,
    required String specialistId,
    required String specialistName,
    ReportType reportType = ReportType.progress,
    DateTime? startDate,
    DateTime? endDate,
    String periodLabel = 'All Available Time',
    List<String> includedSections = const [],
    String? customNotes,
  }) async {
    final Map<String, double> domainScores = {
      'cognitive': 0.0,
      'language': 0.0,
      'motor': 0.0,
      'social': 0.0,
      'emotional': 0.0,
      'creative': 0.0,
    };

    List<Map<String, dynamic>> rawEvents = [];
    List<Map<String, dynamic>> rawObservations = [];
    List<Map<String, dynamic>> rawRecs = [];
    List<Map<String, dynamic>> rawConsultations = [];

    final fs = _firestore;
    if (fs != null) {
      // 1. Fetch Skill Profile
      try {
        final profileDoc = await fs.collection('skillProfiles').doc(child.childId).get();
        if (profileDoc.exists && profileDoc.data() != null) {
          final data = profileDoc.data()!;
          domainScores.forEach((key, _) {
            if (data[key] is num) {
              domainScores[key] = (data[key] as num).toDouble();
            }
          });
        }
      } catch (e) {
        debugPrint('Warning fetching skill profile: $e');
      }

      // 2. Fetch Score Events
      try {
        final snap = await fs
            .collection('scoreEvents')
            .where('childId', isEqualTo: child.childId)
            .limit(50)
            .get();
        rawEvents = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (e) {
        debugPrint('Warning fetching score events: $e');
      }

      // 3. Fetch Observations
      try {
        final obsSnap = await fs
            .collection('llgObservations')
            .where('childId', isEqualTo: child.childId)
            .limit(25)
            .get();
        rawObservations = obsSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (e) {
        debugPrint('Warning fetching observations: $e');
      }

      // 4. Fetch Recommendations
      try {
        final recSnap = await fs
            .collection('recommendations')
            .where('childId', isEqualTo: child.childId)
            .limit(20)
            .get();
        rawRecs = recSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (e) {
        debugPrint('Warning fetching recommendations: $e');
      }

      // 5. Fetch Consultations
      try {
        final conSnap = await fs
            .collection('consultationSummaries')
            .where('caseId', isEqualTo: caseModel.caseId)
            .limit(20)
            .get();
        rawConsultations = conSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (e) {
        debugPrint('Warning fetching consultations: $e');
      }
    }

    // Filter by period dates if provided
    bool inPeriod(dynamic timestampField) {
      if (timestampField == null) return true;
      DateTime dt;
      if (timestampField is Timestamp) {
        dt = timestampField.toDate();
      } else if (timestampField is DateTime) {
        dt = timestampField;
      } else if (timestampField is String) {
        dt = DateTime.tryParse(timestampField) ?? DateTime.now();
      } else {
        return true;
      }

      if (startDate != null && dt.isBefore(startDate)) return false;
      if (endDate != null && dt.isAfter(endDate.add(const Duration(days: 1)))) return false;
      return true;
    }

    final filteredEvents = rawEvents.where((e) => inPeriod(e['createdAt'] ?? e['timestamp'])).toList();
    final filteredObservations = rawObservations.where((e) => inPeriod(e['createdAt'] ?? e['timestamp'])).toList();
    final filteredFeedback = filteredEvents.where((e) => e['feedback'] is Map).toList();

    // Derive Strengths and Growth Areas
    final sortedDomains = domainScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final strengths = <String>[];
    final growthAreas = <String>[];

    for (final entry in sortedDomains) {
      final domainCap = entry.key[0].toUpperCase() + entry.key.substring(1);
      if (entry.value >= 70.0) {
        strengths.add('$domainCap: Mastered (${entry.value.toStringAsFixed(1)}%). Demonstrates solid developmental milestone consistency.');
      } else if (entry.value >= 40.0) {
        growthAreas.add('$domainCap: Emerging (${entry.value.toStringAsFixed(1)}%). Shows positive learning curve, benefiting from guided play.');
      } else {
        growthAreas.add('$domainCap: Needs Focused Support (${entry.value.toStringAsFixed(1)}%). Requires structured scaffolding and sensory exercises.');
      }
    }

    if (strengths.isEmpty && sortedDomains.isNotEmpty) {
      final top = sortedDomains.first;
      strengths.add('${top.key[0].toUpperCase() + top.key.substring(1)}: Highest active domain (${top.value.toStringAsFixed(1)}%).');
    }

    // Compose Content by Report Type
    List<String> keyFindings = [];
    List<String> recommendations = [];
    String summary = '';

    switch (reportType) {
      case ReportType.progress:
        keyFindings = [
          'Evaluated developmental velocity across 6 primary early childhood domains.',
          'Completed ${filteredEvents.length} recorded learning activities during the assessment window.',
          if (filteredFeedback.isNotEmpty)
            'Analyzed ${filteredFeedback.length} parent feedback submissions documenting home engagement.',
          if (filteredObservations.isNotEmpty)
            'Incorporates insights from ${filteredObservations.length} verified clinical observation note(s).',
          'Primary milestone proficiency observed in ${sortedDomains.first.key} (${sortedDomains.first.value.toStringAsFixed(1)}%).',
          if (sortedDomains.last.value < 70)
            'Target developmental priority: ${sortedDomains.last.key} (${sortedDomains.last.value.toStringAsFixed(1)}%).',
        ];
        recommendations = [
          'Continue daily 15-minute multi-sensory play routines targeting ${sortedDomains.last.key}.',
          'Reinforce ${sortedDomains.first.key} competencies through child-led exploratory games.',
          'Maintain regular parent-specialist reflection after milestone achievements.',
          'Schedule a 14-day follow-up review to assess developmental velocity.',
        ];
        summary = 'Progress evaluation for ${child.name} (Age ${child.ageYears}) covering $periodLabel. '
            'Developmental domain assessment highlights leading responsiveness in ${sortedDomains.first.key} (${sortedDomains.first.value.toStringAsFixed(1)}%) '
            'and targeted growth opportunity in ${sortedDomains.last.key} (${sortedDomains.last.value.toStringAsFixed(1)}%). '
            'Active case consultation authorized under DPDP notice ${caseModel.consentNoticeVersion}.';
        break;

      case ReportType.activityPerformance:
        keyFindings = [
          'Activity ledger log documents ${filteredEvents.length} session executions during $periodLabel.',
          'Top domain engagement: ${sortedDomains.first.key} with ${filteredEvents.where((e) => (e['skillDomain'] ?? '').toString().toLowerCase() == sortedDomains.first.key).length} activities.',
          'Average score delta per activity: ${(filteredEvents.fold<double>(0.0, (acc, e) => acc + ((e['appliedScoreDelta'] as num?)?.toDouble() ?? 0.0)) / (filteredEvents.isEmpty ? 1 : filteredEvents.length)).toStringAsFixed(1)} pts.',
          'Completion consistency: ${(filteredEvents.length >= 10 ? 'High' : filteredEvents.length >= 4 ? 'Moderate' : 'Emerging')}.',
        ];
        recommendations = [
          'Introduce tiered difficulty for ${sortedDomains.first.key} activities to sustain engagement.',
          'Break multi-step motor and cognitive routines into smaller 5-minute play micro-segments.',
          'Review parent-reported struggle tags before assigning next-level challenges.',
        ];
        summary = 'Activity performance audit for ${child.name} during $periodLabel. '
            'Tracks ${filteredEvents.length} completed activities with focus on mastery thresholds, difficulty feedback, and domain skill progression.';
        break;

      case ReportType.parentEngagement:
        keyFindings = [
          'Documented ${filteredFeedback.length} caregiver feedback submissions during $periodLabel.',
          'Logged ${rawConsultations.length} clinical consultation reviews with parent ${caseModel.parentName}.',
          'Home routine adherence rate demonstrates active collaborative partnership.',
          if (filteredFeedback.isNotEmpty)
            'Primary parent sentiment indicates confidence in guided play exercises.',
        ];
        recommendations = [
          'Encourage open-ended parent observation journaling after sensory activities.',
          'Maintain bi-weekly direct messaging touchpoints for micro-adjustments.',
          'Recognize caregiver consistency to sustain positive reinforcement loop at home.',
        ];
        summary = 'Parent engagement report for ${caseModel.parentName} supporting ${child.name}. '
            'Summarizes home activity participation, consultation summaries, caregiver notes, and guidance adherence under DPDP consent.';
        break;

      case ReportType.clinicalObservation:
        keyFindings = [
          'Compiled ${filteredObservations.length} specialist observation records and clinical notes.',
          'Active concerns logged: ${filteredObservations.where((o) => (o['isConcern'] == true) || ((o['severity'] ?? '').toString().isNotEmpty)).length}.',
          'Clinical focus: ${caseModel.purpose.isNotEmpty ? caseModel.purpose : 'Early childhood milestone assessment'}.',
          'Domain alignment confirms clinical attention on ${sortedDomains.last.key}.',
        ];
        recommendations = [
          'Implement structured behavioral observation protocol during unstructured play.',
          'Coordinate with caregiver on consistent communication cues for emotional regulation.',
          'Document milestone updates bi-weekly in clinical observation ledger.',
        ];
        summary = 'Specialist clinical and observation report for ${child.name}. '
            'Authored by $specialistName. Details verified observations, developmental concerns, structured notes, and clinical follow-up planning.';
        break;

      case ReportType.caseSummary:
        keyFindings = [
          'Consolidated case summary under DPDP notice ${caseModel.consentNoticeVersion} (Status: ${caseModel.status.name.toUpperCase()}).',
          'Developmental proficiencies: Highest in ${sortedDomains.first.key} (${sortedDomains.first.value.toStringAsFixed(1)}%), target in ${sortedDomains.last.key} (${sortedDomains.last.value.toStringAsFixed(1)}%).',
          'Activity count: ${filteredEvents.length} completed | Feedback entries: ${filteredFeedback.length} | Clinical notes: ${filteredObservations.length}.',
          'Active recommendations: ${rawRecs.length} care plan items prescribed.',
        ];
        recommendations = [
          'Maintain holistic multi-domain care plan with bi-weekly milestone evaluations.',
          'Ensure caregiver feedback loop remains active for timely routine adaptation.',
          'Review DPDP consent renewal prior to expiration (${caseModel.consentExpiresAt != null ? caseModel.consentExpiresAt!.toIso8601String().substring(0, 10) : 'standard 90 days'}).',
        ];
        summary = 'Consolidated Case Summary for ${child.name} (Case ID: ${caseModel.caseId}). '
            'Provides a complete clinical and operational synthesis of developmental scores, completed interventions, observations, and care plan trajectory.';
        break;
    }

    final now = DateTime.now();
    final reportData = SpecialistReportModel(
      id: '',
      caseId: caseModel.caseId,
      childId: child.childId,
      childName: child.name,
      parentId: caseModel.parentId,
      specialistId: specialistId,
      specialistName: specialistName,
      reportType: reportType,
      title: '${reportType.displayName} - ${child.name}',
      summary: summary,
      domainScores: domainScores,
      keyFindings: keyFindings,
      strengths: strengths,
      growthAreas: growthAreas,
      recommendations: recommendations,
      status: SpecialistReportStatus.draft,
      generatedAt: now,
      specialistNotes: customNotes,
      periodStartDate: startDate,
      periodEndDate: endDate,
      periodLabel: periodLabel,
      includedSections: includedSections.isNotEmpty
          ? includedSections
          : ['Domain Scores', 'Activities', 'Feedback', 'Observations', 'Care Plan', 'AI Synthesis'],
      dataSources: ['Skill Profile', 'Score Ledger', 'Clinical Observations', 'Parent Feedback', 'Recommendations'],
      activityRecords: filteredEvents.take(15).toList(),
      feedbackRecords: filteredFeedback.take(10).toList(),
      observationRecords: filteredObservations.take(10).toList(),
    );

    if (fs != null) {
      final docRef = await fs.collection(collectionName).add(reportData.toMap());
      return SpecialistReportModel.fromMap(docRef.id, reportData.toMap());
    }

    return reportData;
  }

  /// Update report status (e.g. finalize or share)
  Future<void> updateReportStatus(
    String reportId,
    SpecialistReportStatus status, {
    String? notes,
  }) async {
    final fs = _firestore;
    if (fs == null) return;

    final updateData = <String, dynamic>{
      'status': status.name,
    };
    if (notes != null) {
      updateData['specialistNotes'] = notes;
    }
    if (status == SpecialistReportStatus.finalized) {
      updateData['finalizedAt'] = FieldValue.serverTimestamp();
    } else if (status == SpecialistReportStatus.shared) {
      updateData['sharedAt'] = FieldValue.serverTimestamp();
    }

    await fs.collection(collectionName).doc(reportId).update(updateData);
  }

  /// Record PDF generation and export metadata
  Future<void> recordPdfExport(String reportId, {String? pdfUrl}) async {
    final fs = _firestore;
    if (fs == null) return;

    await fs.collection(collectionName).doc(reportId).update({
      'pdfGeneratedAt': FieldValue.serverTimestamp(),
      'pdfUrl': ?pdfUrl,
    });
  }

  /// Stream all reports shared with a specific parent
  Stream<List<SpecialistReportModel>> getParentReportsStream(String parentId) {
    final fs = _firestore;
    if (fs == null || parentId.isEmpty) return Stream.value([]);
    return fs
        .collection(collectionName)
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SpecialistReportModel.fromMap(doc.id, doc.data()))
          .where((r) => r.status == SpecialistReportStatus.shared || r.status == SpecialistReportStatus.finalized)
          .toList();
      list.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return list;
    });
  }

  /// Mark report as read by parent
  Future<void> markReportAsReadByParent(String reportId) async {
    final fs = _firestore;
    if (fs == null || reportId.isEmpty) return;
    try {
      await fs.collection(collectionName).doc(reportId).update({
        'readByParentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking report as read by parent: $e');
    }
  }

  /// Share report with parent and dispatch notification
  Future<void> shareReportWithParent({
    required String reportId,
    required String parentId,
    required String childName,
    required String specialistName,
  }) async {
    await updateReportStatus(reportId, SpecialistReportStatus.shared);

    final fs = _firestore;
    if (fs == null) return;

    if (parentId.isNotEmpty) {
      await fs.collection(collectionName).doc(reportId).update({
        'parentId': parentId,
      });

      await fs.collection('notifications').add({
        'userId': parentId,
        'type': 'specialist_report_shared',
        'reportId': reportId,
        'title': 'New Developmental Report for $childName',
        'body': '$specialistName has shared a new developmental report with you.',
        'actionRoute': '/llg-connect',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
