// lib/services/recommendation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/recommendation_model.dart';
import 'audit_log_service.dart';

class RecommendationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  RecommendationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const String collection = 'recommendations';

  /// Stream recommendations for an authorized child
  Stream<List<RecommendationModel>> getChildRecommendationsStream(String childId) {
    if (childId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('childId', isEqualTo: childId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return RecommendationModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.recommendedAt.compareTo(a.recommendedAt));
      return list;
    });
  }

  /// Stream recommendations for an active case
  Stream<List<RecommendationModel>> getCaseRecommendationsStream(String caseId) {
    if (caseId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return RecommendationModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.recommendedAt.compareTo(a.recommendedAt));
      return list;
    });
  }

  /// Stream recommendations created by a specialist across all their cases
  Stream<List<RecommendationModel>> getSpecialistRecommendationsStream({required String llgId}) {
    if (llgId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('llgId', isEqualTo: llgId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return RecommendationModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.recommendedAt.compareTo(a.recommendedAt));
      return list;
    });
  }

  /// LLG creates a personalized recommendation
  Future<String> createRecommendation({
    required String caseId,
    required String childId,
    required String childName,
    required String parentId,
    required String llgId,
    required String llgName,
    String llgRole = 'learning_guide',
    required String title,
    required String rationale,
    required String skillDomain,
    required List<String> instructions,
    List<String> materials = const [],
    int durationMinutes = 15,
    String frequency = 'Daily',
    String safetyGuidance = 'Adult supervision recommended at all times.',
    DateTime? reviewDate,
    String? baseActivityId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != llgId) {
      throw Exception('Unauthorized: only the assigned specialist can create recommendations.');
    }

    final now = DateTime.now();
    final docRef = _firestore.collection(collection).doc();

    final rec = RecommendationModel(
      id: docRef.id,
      caseId: caseId,
      childId: childId,
      childName: childName,
      parentId: parentId,
      llgId: llgId,
      llgName: llgName,
      llgRole: llgRole,
      title: title.trim(),
      rationale: rationale.trim(),
      skillDomain: skillDomain.trim().toLowerCase(),
      instructions: instructions,
      materials: materials,
      durationMinutes: durationMinutes,
      frequency: frequency,
      safetyGuidance: safetyGuidance,
      recommendedAt: now,
      reviewDate: reviewDate,
      baseActivityId: baseActivityId,
      createdAt: now,
    );

    await docRef.set(rec.toMap());

    // Notify Parent
    try {
      await _firestore.collection('notifications').add({
        'userId': parentId,
        'senderId': llgId,
        'type': 'new_recommendation',
        'caseId': caseId,
        'childId': childId,
        'childName': childName,
        'title': 'New Activity Recommendation for $childName',
        'message': '$llgName recommended: "$title"',
        'body': '$llgName recommended: "$title"',
        'data': {'recommendationId': docRef.id, 'childId': childId},
        'read': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Notification error: $e');
    }

    await AuditLogService.logEvent(
      action: 'recommendation_created',
      caseId: caseId,
      childId: childId,
      targetId: parentId,
      details: {
        'recommendationId': docRef.id,
        'title': title,
        'skillDomain': skillDomain,
      },
    );

    return docRef.id;
  }

  /// Parent records response / feedback (completion, partial, struggle, skipped)
  Future<void> submitParentResponse({
    required String recommendationId,
    required ParentActivityResponse response,
    String? feedback,
    String? skippedReason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to submit activity response.');
    }

    final docRef = _firestore.collection(collection).doc(recommendationId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Recommendation not found.');

    final data = snap.data()!;
    if (data['parentId'] != user.uid) {
      throw Exception('Unauthorized: only the assigned parent can record responses.');
    }

    final now = DateTime.now();

    RecommendationStatus updatedStatus;
    switch (response) {
      case ParentActivityResponse.completed:
        updatedStatus = RecommendationStatus.completed;
        break;
      case ParentActivityResponse.partially_completed:
        updatedStatus = RecommendationStatus.partially_completed;
        break;
      case ParentActivityResponse.skipped:
        updatedStatus = RecommendationStatus.skipped;
        break;
      case ParentActivityResponse.struggled:
        updatedStatus = RecommendationStatus.in_progress;
        break;
      case ParentActivityResponse.none:
        updatedStatus = RecommendationStatus.in_progress;
        break;
    }

    await docRef.update({
      'parentResponse': response.name,
      'parentFeedback': feedback?.trim(),
      'skippedReason': skippedReason?.trim(),
      'parentRespondedAt': Timestamp.fromDate(now),
      'status': updatedStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify LLG that parent submitted feedback
    try {
      await _firestore.collection('notifications').add({
        'userId': data['llgId'],
        'senderId': user.uid,
        'type': 'parent_activity_feedback',
        'caseId': data['caseId'],
        'childId': data['childId'],
        'childName': data['childName'],
        'title': 'Parent Feedback: ${data['title']}',
        'message': '${data['childName']}\'s parent responded: ${response.name.replaceAll('_', ' ')}',
        'body': '${data['childName']}\'s parent responded: ${response.name.replaceAll('_', ' ')}',
        'data': {'recommendationId': recommendationId, 'childId': data['childId']},
        'read': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    await AuditLogService.logEvent(
      action: 'recommendation_response_recorded',
      caseId: data['caseId'],
      childId: data['childId'],
      details: {
        'recommendationId': recommendationId,
        'response': response.name,
      },
    );
  }

  /// LLG reviews parent response and provides follow-up guidance
  Future<void> submitLLGReview({
    required String recommendationId,
    required String llgFeedback,
    String? nextSteps,
    RecommendationStatus? newStatus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required.');
    }

    final docRef = _firestore.collection(collection).doc(recommendationId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Recommendation not found.');

    final data = snap.data()!;
    if (data['llgId'] != user.uid) {
      throw Exception('Unauthorized: only the assigned specialist can submit reviews.');
    }

    final now = DateTime.now();
    final updateMap = <String, dynamic>{
      'llgFeedback': llgFeedback.trim(),
      'llgReviewedAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nextSteps != null && nextSteps.trim().isNotEmpty) {
      updateMap['nextSteps'] = nextSteps.trim();
    }

    if (newStatus != null) {
      updateMap['status'] = newStatus.name;
    }

    await docRef.update(updateMap);

    // Notify Parent
    try {
      await _firestore.collection('notifications').add({
        'userId': data['parentId'],
        'senderId': user.uid,
        'type': 'llg_feedback_available',
        'caseId': data['caseId'],
        'childId': data['childId'],
        'childName': data['childName'],
        'title': 'Guide Feedback from ${data['llgName']}',
        'message': '${data['llgName']} added follow-up guidance for "${data['title']}"',
        'body': '${data['llgName']} added follow-up guidance for "${data['title']}"',
        'data': {'recommendationId': recommendationId, 'childId': data['childId']},
        'read': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    await AuditLogService.logEvent(
      action: 'recommendation_reviewed_by_llg',
      caseId: data['caseId'],
      childId: data['childId'],
      details: {
        'recommendationId': recommendationId,
      },
    );
  }

  /// LLG pauses or discontinues a recommendation with a reason
  Future<void> updateRecommendationStatus({
    required String recommendationId,
    required RecommendationStatus status,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Authentication required.');

    final docRef = _firestore.collection(collection).doc(recommendationId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Recommendation not found.');

    final data = snap.data()!;
    if (data['llgId'] != user.uid && data['parentId'] != user.uid) {
      throw Exception('Unauthorized operation.');
    }

    await docRef.update({
      'status': status.name,
      'statusReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await AuditLogService.logEvent(
      action: 'recommendation_status_changed',
      caseId: data['caseId'],
      childId: data['childId'],
      details: {
        'recommendationId': recommendationId,
        'newStatus': status.name,
        'reason': reason,
      },
    );
  }

  /// Alias for updateRecommendationStatus
  Future<void> updateStatus(
    String recommendationId,
    RecommendationStatus status, {
    String? statusReason,
    String? reason,
  }) => updateRecommendationStatus(
        recommendationId: recommendationId,
        status: status,
        reason: statusReason ?? reason ?? '',
      );

  /// Alias for submitLLGReview
  Future<void> recordLlgReview(
    String recommendationId,
    String llgFeedback, [
    String? nextSteps,
    RecommendationStatus? newStatus,
  ]) => submitLLGReview(
        recommendationId: recommendationId,
        llgFeedback: llgFeedback,
        nextSteps: nextSteps,
        newStatus: newStatus,
      );
}
