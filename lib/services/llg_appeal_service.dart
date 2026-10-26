// lib/services/llg_appeal_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/admin_models.dart';
import 'admin_service.dart';

class LLGAppealService {
  final FirebaseFirestore? _customFirestore;
  final AdminService? _customAdminService;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  AdminService get _adminService => _customAdminService ?? AdminService(firestore: _firestore);

  LLGAppealService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
  })  : _customFirestore = firestore,
        _customAdminService = adminService;

  static const String collectionName = 'llgAppeals';

  /// Submit a suspension review or appeal
  Future<String> submitAppeal({
    required String llgId,
    required String llgName,
    required String llgEmail,
    required String suspensionReason,
    required String appealText,
    List<String>? supportingDocuments,
  }) async {
    final fs = _firestore;
    if (fs == null) {
      throw Exception('Database service is temporarily unavailable.');
    }

    final now = DateTime.now();
    final appealData = {
      'llgId': llgId,
      'llgName': llgName,
      'llgEmail': llgEmail,
      'suspensionReason': suspensionReason,
      'appealText': appealText,
      'supportingDocuments': supportingDocuments ?? [],
      'status': 'pending',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    final docRef = await fs.collection(collectionName).add(appealData);

    // Notify administrators
    try {
      await fs.collection('notifications').add({
        'recipientRole': 'admin',
        'type': 'new_llg_appeal',
        'appealId': docRef.id,
        'specialistId': llgId,
        'title': 'New Suspension Appeal: $llgName',
        'body': 'Specialist $llgName submitted an appeal for review.',
        'actionRoute': '/admin-appeals',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Audit log entry
      await fs.collection('auditLogs').add({
        'action': 'llg_appeal_submitted',
        'userId': llgId,
        'userEmail': llgEmail,
        'targetId': docRef.id,
        'details': {
          'llgName': llgName,
          'suspensionReason': suspensionReason,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning logging appeal submission notification/audit: $e');
    }

    return docRef.id;
  }

  /// Stream appeals for a specific specialist
  Stream<List<LLGAppealModel>> getAppealsForLLGStream(String llgId) {
    final fs = _firestore;
    if (fs == null || llgId.isEmpty) return Stream.value([]);

    return fs
        .collection(collectionName)
        .where('llgId', isEqualTo: llgId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => LLGAppealModel.fromMap(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream all appeals for administrative review
  Stream<List<LLGAppealModel>> getAllAppealsStream({String? statusFilter}) {
    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    Query query = fs.collection(collectionName);
    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => LLGAppealModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Process an administrator appeal decision (Approve or Reject)
  Future<void> processAppealDecision({
    required String appealId,
    required String llgId,
    required bool approve,
    required String adminId,
    required String adminNotes,
    List<String>? restorationConditions,
  }) async {
    final fs = _firestore;
    if (fs == null) {
      throw Exception('Database service is unavailable.');
    }

    final statusStr = approve ? 'approved' : 'rejected';
    final now = DateTime.now();

    final updateData = <String, dynamic>{
      'status': statusStr,
      'adminNotes': adminNotes,
      'reviewedBy': adminId,
      'reviewedAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      if (restorationConditions != null && restorationConditions.isNotEmpty)
        'restorationConditions': restorationConditions,
    };

    await fs.collection(collectionName).doc(appealId).update(updateData);

    // If approved, trigger account restoration through authoritative flow
    if (approve) {
      try {
        await _adminService.restoreAccount(
          userId: llgId,
          restorationReason: 'Appeal approved by administrator ($adminId): $adminNotes',
          sendEmail: true,
        );
      } catch (e) {
        debugPrint('Note: AdminService API restore caught error, fallback to direct status update: $e');
        // Direct fallback update to ensure account is not stuck
        await fs.collection('users').doc(llgId).update({
          'status': 'active',
          'isSuspended': false,
          'restoredAt': FieldValue.serverTimestamp(),
          'restorationReason': adminNotes,
        });
        await fs.collection('llgProfiles').doc(llgId).update({
          'status': 'active',
          'restoredAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Notify the specialist
    try {
      await fs.collection('notifications').add({
        'userId': llgId,
        'type': 'appeal_decision',
        'appealId': appealId,
        'title': approve ? 'Appeal Approved: Account Restored' : 'Appeal Decision',
        'body': approve
            ? 'Your suspension appeal has been approved. Your account access has been restored.'
            : 'Your suspension appeal was reviewed: $adminNotes',
        'actionRoute': '/account-status',
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Audit log
      await fs.collection('auditLogs').add({
        'action': approve ? 'appeal_approved_account_restored' : 'appeal_rejected',
        'adminId': adminId,
        'targetId': llgId,
        'appealId': appealId,
        'details': {
          'decision': statusStr,
          'adminNotes': adminNotes,
          'conditions': restorationConditions ?? [],
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Warning logging appeal decision notification/audit: $e');
    }
  }
}
