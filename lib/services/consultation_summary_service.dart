// lib/services/consultation_summary_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/consultation_summary_model.dart';
import 'audit_log_service.dart';

class ConsultationSummaryService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  ConsultationSummaryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  static const String collection = 'consultationSummaries';

  /// Stream consultation summaries for an authorized case
  Stream<List<ConsultationSummaryModel>> getCaseSummariesStream(String caseId) {
    if (caseId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ConsultationSummaryModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.consultationDate.compareTo(a.consultationDate));
      return list;
    });
  }

  /// Stream consultation summaries for a child
  Stream<List<ConsultationSummaryModel>> getChildSummariesStream(String childId) {
    if (childId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('childId', isEqualTo: childId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ConsultationSummaryModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.consultationDate.compareTo(a.consultationDate));
      return list;
    });
  }

  /// Stream all consultation summaries for a specialist across all their cases
  Stream<List<ConsultationSummaryModel>> getSpecialistSummariesStream(String specialistId) {
    if (specialistId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('llgId', isEqualTo: specialistId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ConsultationSummaryModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.consultationDate.compareTo(a.consultationDate));
      return list;
    });
  }

  /// Submit an explicit, authenticated consultation summary
  Future<String> submitSummary({
    required String caseId,
    required String childId,
    required String childName,
    required String parentId,
    required String parentName,
    required String llgId,
    required String llgName,
    String consultationMode = 'WhatsApp',
    required DateTime consultationDate,
    required String consultationReason,
    required List<String> concernsDiscussed,
    required String guidanceProvided,
    String? parentQuestionsOrFeedback,
    required List<String> agreedFollowUpActions,
    DateTime? nextReviewDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != llgId) {
      throw Exception('Unauthorized: only the assigned specialist can submit consultation summaries.');
    }

    if (consultationReason.trim().isEmpty) {
      throw Exception('Consultation reason is required.');
    }
    if (guidanceProvided.trim().isEmpty) {
      throw Exception('Guidance provided cannot be empty.');
    }

    final now = DateTime.now();
    final docRef = _firestore.collection(collection).doc();

    final summary = ConsultationSummaryModel(
      id: docRef.id,
      caseId: caseId,
      childId: childId,
      childName: childName,
      parentId: parentId,
      parentName: parentName,
      llgId: llgId,
      llgName: llgName,
      consultationMode: consultationMode,
      consultationDate: consultationDate,
      consultationReason: consultationReason.trim(),
      concernsDiscussed: concernsDiscussed,
      guidanceProvided: guidanceProvided.trim(),
      parentQuestionsOrFeedback: parentQuestionsOrFeedback?.trim(),
      agreedFollowUpActions: agreedFollowUpActions,
      nextReviewDate: nextReviewDate,
      createdAt: now,
    );

    await docRef.set(summary.toMap());

    // Send persistent notification to parent
    try {
      await _firestore.collection('notifications').add({
        'userId': parentId,
        'senderId': llgId,
        'type': 'consultation_summary_submitted',
        'caseId': caseId,
        'childId': childId,
        'childName': childName,
        'title': 'Consultation Summary Documented',
        'message': '$llgName documented notes for your $consultationMode consultation on $childName.',
        'body': '$llgName documented notes for your $consultationMode consultation on $childName.',
        'data': {'summaryId': docRef.id, 'caseId': caseId},
        'read': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Notification error: $e');
    }

    await AuditLogService.logEvent(
      action: 'consultation_summary_submitted',
      caseId: caseId,
      childId: childId,
      targetId: parentId,
      details: {
        'summaryId': docRef.id,
        'consultationMode': consultationMode,
      },
    );

    return docRef.id;
  }
}
