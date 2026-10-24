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

  /// Generate an AI Developmental Report based on current child scores, ledger events, and observations
  Future<SpecialistReportModel> generateReport({
    required SpecialistCaseModel caseModel,
    required ChildModel child,
    required String specialistId,
    required String specialistName,
    String? customNotes,
  }) async {
    // 1. Fetch Skill Profile
    final Map<String, double> domainScores = {
      'cognitive': 0.0,
      'language': 0.0,
      'motor': 0.0,
      'social': 0.0,
      'emotional': 0.0,
      'creative': 0.0,
    };

    List<Map<String, dynamic>> recentEvents = [];
    List<Map<String, dynamic>> observations = [];

    final fs = _firestore;
    if (fs != null) {
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

      // 2. Fetch Recent Activities / Score Events
      try {
        final snap = await fs
            .collection('scoreEvents')
            .where('childId', isEqualTo: child.childId)
            .limit(20)
            .get();
        recentEvents = snap.docs.map((d) => d.data()).toList();
      } catch (e) {
        debugPrint('Warning fetching score events: $e');
      }

      // 3. Fetch Observations & Concerns
      try {
        final obsSnap = await fs
            .collection('llgObservations')
            .where('childId', isEqualTo: child.childId)
            .limit(10)
            .get();
        observations = obsSnap.docs.map((d) => d.data()).toList();
      } catch (e) {
        debugPrint('Warning fetching observations: $e');
      }
    }

    // 4. Derive Strengths and Growth Areas
    final sortedDomains = domainScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final strengths = <String>[];
    final growthAreas = <String>[];

    for (final entry in sortedDomains) {
      final domainCap = entry.key[0].toUpperCase() + entry.key.substring(1);
      if (entry.value >= 70.0) {
        strengths.add('$domainCap: Mastered (${entry.value.toStringAsFixed(1)}%). Demonstrates solid developmental milestone consistency.');
      } else if (entry.value >= 40.0) {
        growthAreas.add('$domainCap: Emerging (${entry.value.toStringAsFixed(1)}%). Shows positive learning curve, benefiting from continued guided play.');
      } else {
        growthAreas.add('$domainCap: Needs Focused Support (${entry.value.toStringAsFixed(1)}%). Requires structured scaffolding and sensory exercises.');
      }
    }

    if (strengths.isEmpty && sortedDomains.isNotEmpty) {
      final top = sortedDomains.first;
      strengths.add('${top.key[0].toUpperCase() + top.key.substring(1)}: Highest active domain (${top.value.toStringAsFixed(1)}%).');
    }

    // 5. Derive Key Findings
    final keyFindings = <String>[
      'Overall developmental assessment evaluated across 6 primary early childhood domains.',
      'Completed ${recentEvents.length} tracked developmental activities recorded on the ledger.',
      if (observations.isNotEmpty)
        'Includes clinical insights from ${observations.length} specialist observation note(s).',
      'Child displays best responsiveness in ${sortedDomains.first.key} (${sortedDomains.first.value.toStringAsFixed(1)}%).',
      if (sortedDomains.last.value < 70)
        'Priority developmental target: ${sortedDomains.last.key} (${sortedDomains.last.value.toStringAsFixed(1)}%).',
    ];

    // 6. Derive AI Actionable Recommendations
    final recommendations = <String>[
      'Integrate 15 minutes of play focusing on ${sortedDomains.last.key} using multisensory materials.',
      'Reinforce ${sortedDomains.first.key} through child-led exploratory routines.',
      'Maintain positive parental feedback loop after each activity session to reinforce self-efficacy.',
      'Schedule follow-up review with specialist in 14 days to evaluate progression.',
    ];

    final summary = 'Developmental evaluation for ${child.name} (Age ${child.ageYears}). '
        'Developmental domain analysis indicates highest proficiency in ${sortedDomains.first.key} (${sortedDomains.first.value.toStringAsFixed(1)}%), '
        'with primary developmental opportunities in ${sortedDomains.last.key} (${sortedDomains.last.value.toStringAsFixed(1)}%). '
        'Active case management under DPDP consent version ${caseModel.consentNoticeVersion}.';

    final now = DateTime.now();
    final reportData = SpecialistReportModel(
      id: '',
      caseId: caseModel.caseId,
      childId: child.childId,
      childName: child.name,
      specialistId: specialistId,
      specialistName: specialistName,
      title: 'AI Developmental Progress Assessment - ${child.name}',
      summary: summary,
      domainScores: domainScores,
      keyFindings: keyFindings,
      strengths: strengths,
      growthAreas: growthAreas,
      recommendations: recommendations,
      status: SpecialistReportStatus.draft,
      generatedAt: now,
      specialistNotes: customNotes,
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
      await fs.collection('notifications').add({
        'userId': parentId,
        'type': 'specialist_report_shared',
        'reportId': reportId,
        'title': 'New Developmental Report for $childName',
        'body': '$specialistName has shared a new developmental progress report.',
        'actionRoute': '/llg-connect',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
