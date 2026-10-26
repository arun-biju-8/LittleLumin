// lib/services/specialist_review_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';

class SpecialistReviewService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  SpecialistReviewService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  static const String collectionName = 'specialistReviews';

  /// Generates a deterministic document ID to prevent duplicate reviews per consultation case
  static String generateReviewDocId(String caseId, String parentId) {
    if (caseId.isNotEmpty) {
      return 'rev_${caseId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}';
    }
    return 'rev_${parentId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Check if a review has already been submitted for a specific case
  Future<bool> hasReviewedCase(String caseId, String parentId) async {
    final fs = _firestore;
    if (fs == null) return false;

    if (caseId.isNotEmpty) {
      final docId = generateReviewDocId(caseId, parentId);
      final docSnap = await fs.collection(collectionName).doc(docId).get();
      if (docSnap.exists) return true;
    }

    final query = await fs
        .collection(collectionName)
        .where('parentId', isEqualTo: parentId)
        .where('caseId', isEqualTo: caseId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// Submit a star rating and optional written review
  Future<String> submitReview({
    required String parentId,
    required String parentName,
    required String specialistId,
    required String specialistName,
    required String caseId,
    required int rating,
    String? reviewText,
  }) async {
    final fs = _firestore;
    if (fs == null) {
      throw Exception('Database service is unavailable.');
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5 stars.');
    }

    // Safeguard: Check for duplicate review
    final alreadySubmitted = await hasReviewedCase(caseId, parentId);
    if (alreadySubmitted) {
      throw Exception('A review has already been submitted for this consultation.');
    }

    final docId = generateReviewDocId(caseId, parentId);
    final now = DateTime.now();

    final reviewData = {
      'parentId': parentId,
      'parentName': parentName,
      'specialistId': specialistId,
      'specialistName': specialistName,
      'caseId': caseId,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': Timestamp.fromDate(now),
      'isModerated': false,
    };

    await fs.collection(collectionName).doc(docId).set(reviewData);

    // Recalculate and persist aggregate rating for specialist
    await recalculateSpecialistRating(specialistId);

    // Dispatch notification to specialist
    try {
      await fs.collection('notifications').add({
        'userId': specialistId,
        'type': 'new_review',
        'specialistId': specialistId,
        'title': 'New Consultation Review',
        'body': '$parentName gave you a $rating-star rating.',
        'actionRoute': '/llg-dashboard',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning sending review notification: $e');
    }

    return docId;
  }

  /// Stream approved/non-moderated reviews for a specialist
  Stream<List<SpecialistReviewModel>> getSpecialistReviewsStream(String specialistId) {
    final fs = _firestore;
    if (fs == null || specialistId.isEmpty) return Stream.value([]);

    return fs
        .collection(collectionName)
        .where('specialistId', isEqualTo: specialistId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => SpecialistReviewModel.fromMap(doc.id, doc.data()))
          .where((r) => !r.isModerated)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream all reviews for administrative inspection and moderation
  Stream<List<SpecialistReviewModel>> getAllReviewsStream({bool? moderatedOnly}) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    Query query = fs.collection(collectionName);
    if (moderatedOnly == true) {
      query = query.where('isModerated', isEqualTo: true);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => SpecialistReviewModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Moderate (hide/unhide) a review by administrator
  Future<void> moderateReview({
    required String reviewId,
    required bool hide,
    required String adminId,
    String? reason,
  }) async {
    final fs = _firestore;
    if (fs == null) {
      throw Exception('Database service is unavailable.');
    }

    final docSnap = await fs.collection(collectionName).doc(reviewId).get();
    if (!docSnap.exists) {
      throw Exception('Review document not found.');
    }
    final specialistId = (docSnap.data()!['specialistId'] as String?) ?? '';

    final updateData = <String, dynamic>{
      'isModerated': hide,
      'moderatedAt': hide ? FieldValue.serverTimestamp() : null,
      'moderatedBy': hide ? adminId : null,
      'moderationReason': hide ? reason : null,
    };

    await fs.collection(collectionName).doc(reviewId).update(updateData);

    // Recalculate specialist aggregate rating after moderation
    if (specialistId.isNotEmpty) {
      await recalculateSpecialistRating(specialistId);
    }

    // Audit log
    try {
      await fs.collection('auditLogs').add({
        'action': hide ? 'review_hidden_by_admin' : 'review_unhidden_by_admin',
        'adminId': adminId,
        'reviewId': reviewId,
        'specialistId': specialistId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning logging review moderation audit: $e');
    }
  }

  /// Recalculates aggregate average rating and review count from unmoderated reviews
  Future<Map<String, dynamic>> recalculateSpecialistRating(String specialistId) async {
    final fs = _firestore;
    if (fs == null || specialistId.isEmpty) {
      return {'rating': 0.0, 'ratingCount': 0};
    }

    final snap = await fs
        .collection(collectionName)
        .where('specialistId', isEqualTo: specialistId)
        .get();

    final legitimateReviews = snap.docs
        .map((d) => d.data())
        .where((data) => data['isModerated'] != true && data['rating'] is num)
        .toList();

    double avgRating = 0.0;
    final count = legitimateReviews.length;

    if (count > 0) {
      final total = legitimateReviews.fold<double>(
        0.0,
        (acc, item) => acc + (item['rating'] as num).toDouble(),
      );
      avgRating = double.parse((total / count).toStringAsFixed(1));
    }

    final updatePayload = {
      'rating': avgRating,
      'ratingCount': count,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Update both llgProfiles and users
    try {
      await fs.collection('llgProfiles').doc(specialistId).update(updatePayload);
    } catch (e) {
      debugPrint('Warning updating rating in llgProfiles: $e');
    }

    try {
      await fs.collection('users').doc(specialistId).update(updatePayload);
    } catch (e) {
      debugPrint('Warning updating rating in users: $e');
    }

    return {'rating': avgRating, 'ratingCount': count};
  }
}
