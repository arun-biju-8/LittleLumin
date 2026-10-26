// lib/services/parent_complaint_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';

class ParentComplaintService {
  final FirebaseFirestore? _customFirestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  ParentComplaintService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  static const String collectionName = 'parentComplaints';

  /// Submit a complaint about a specialist
  Future<String> submitComplaint({
    required String parentId,
    required String parentName,
    required String parentEmail,
    required String specialistId,
    required String specialistName,
    String? caseId,
    required ParentComplaintCategory category,
    required String description,
    List<String>? supportingEvidence,
  }) async {
    final fs = _firestore;
    if (fs == null) {
      throw Exception('Database service is unavailable.');
    }

    final now = DateTime.now();
    final complaintData = {
      'parentId': parentId,
      'parentName': parentName,
      'parentEmail': parentEmail,
      'specialistId': specialistId,
      'specialistName': specialistName,
      'caseId': caseId,
      'category': category.value,
      'description': description,
      'supportingEvidence': supportingEvidence ?? [],
      'status': 'pending',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final docRef = await fs.collection(collectionName).add(complaintData);

    // Notify administrators of new complaint
    try {
      await fs.collection('notifications').add({
        'recipientRole': 'admin',
        'type': 'new_parent_complaint',
        'complaintId': docRef.id,
        'specialistId': specialistId,
        'parentId': parentId,
        'title': 'New Parent Complaint',
        'body': 'Complaint received from $parentName regarding specialist $specialistName (${category.displayName}).',
        'actionRoute': '/admin-complaints',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Audit log entry
      await fs.collection('auditLogs').add({
        'action': 'parent_complaint_submitted',
        'parentId': parentId,
        'specialistId': specialistId,
        'complaintId': docRef.id,
        'details': {
          'category': category.name,
          'caseId': caseId,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning logging complaint notification/audit: $e');
    }

    return docRef.id;
  }

  /// Stream complaints submitted by a specific parent
  Stream<List<ParentComplaintModel>> getParentComplaintsStream(String parentId) {
    final fs = _firestore;
    if (fs == null || parentId.isEmpty) return Stream.value([]);

    return fs
        .collection(collectionName)
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => ParentComplaintModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream all complaints for admin portal with optional filters
  Stream<List<ParentComplaintModel>> getAllComplaintsStream({
    String? statusFilter,
    String? categoryFilter,
    String? specialistIdFilter,
  }) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    Query query = fs.collection(collectionName);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'all') {
      query = query.where('category', isEqualTo: categoryFilter);
    }
    if (specialistIdFilter != null && specialistIdFilter.isNotEmpty && specialistIdFilter != 'all') {
      query = query.where('specialistId', isEqualTo: specialistIdFilter);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => ParentComplaintModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Update complaint status and investigation details by administrator
  Future<void> updateComplaintStatus({
    required String complaintId,
    required String newStatus,
    required String adminId,
    String? investigationNotes,
    String? resolutionSummary,
    bool notifyParent = true,
  }) async {
    final fs = _firestore;
    if (fs == null) {
      throw Exception('Database service is unavailable.');
    }

    final docSnap = await fs.collection(collectionName).doc(complaintId).get();
    if (!docSnap.exists) {
      throw Exception('Complaint document not found.');
    }
    final data = docSnap.data()!;
    final parentId = data['parentId'] as String? ?? '';
    final specialistName = data['specialistName'] as String? ?? 'the specialist';

    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'status': newStatus,
      'updatedAt': Timestamp.fromDate(now),
      if (investigationNotes != null && investigationNotes.isNotEmpty)
        'investigationNotes': investigationNotes,
      if (resolutionSummary != null && resolutionSummary.isNotEmpty)
        'resolutionSummary': resolutionSummary,
      if (newStatus == 'resolved' || newStatus == 'dismissed')
        'resolvedAt': Timestamp.fromDate(now),
    };

    await fs.collection(collectionName).doc(complaintId).update(updateData);

    // Notify parent if status changed
    if (notifyParent && parentId.isNotEmpty) {
      String statusTitle = 'Complaint Status Update';
      String statusBody = 'Your complaint regarding $specialistName is currently marked as ${newStatus.replaceAll('_', ' ')}.';

      if (newStatus == 'resolved') {
        statusTitle = 'Complaint Resolved';
        statusBody = resolutionSummary != null && resolutionSummary.isNotEmpty
            ? 'Resolution: $resolutionSummary'
            : 'Your complaint regarding $specialistName has been resolved by administrative review.';
      } else if (newStatus == 'under_investigation') {
        statusTitle = 'Complaint Under Investigation';
        statusBody = 'An administrator has initiated an investigation regarding your complaint.';
      }

      try {
        await fs.collection('notifications').add({
          'userId': parentId,
          'type': 'complaint_status_update',
          'complaintId': complaintId,
          'title': statusTitle,
          'body': statusBody,
          'actionRoute': '/llg-connect',
          'readAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Warning notifying parent of complaint update: $e');
      }
    }

    // Audit log entry
    try {
      await fs.collection('auditLogs').add({
        'action': 'parent_complaint_status_updated',
        'adminId': adminId,
        'complaintId': complaintId,
        'details': {
          'newStatus': newStatus,
          'investigationNotes': investigationNotes,
          'resolutionSummary': resolutionSummary,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning logging complaint status audit: $e');
    }
  }
}
