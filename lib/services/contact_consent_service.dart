// lib/services/contact_consent_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/contact_consent_model.dart';
import 'audit_log_service.dart';

class ContactConsentService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ContactConsentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const String collection = 'contactConsentRequests';

  /// Stream all contact consent requests for a specific case
  Stream<List<ContactConsentModel>> getCaseConsentRequestsStream(String caseId) {
    if (caseId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ContactConsentModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  /// Stream pending requests directed to the current user
  Stream<List<ContactConsentModel>> getIncomingRequestsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('recipientId', isEqualTo: userId)
        .where('status', isEqualTo: ContactConsentStatus.pending.name)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ContactConsentModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  /// Stream all consent requests where user is requester or recipient
  Stream<List<ContactConsentModel>> getUserConsentRequestsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _firestore
        .collection(collection)
        .where('requesterId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ContactConsentModel.fromMap(doc.data(), doc.id);
      }).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  /// Get the active, approved consent record for a case (if any)
  Future<ContactConsentModel?> getActiveConsent(String caseId) async {
    if (caseId.isEmpty) return null;
    try {
      final snap = await _firestore
          .collection(collection)
          .where('caseId', isEqualTo: caseId)
          .where('status', isEqualTo: ContactConsentStatus.approved.name)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final consent = ContactConsentModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
      return consent.isApproved ? consent : null;
    } catch (_) {
      return null;
    }
  }

  /// Submit an explicit contact-sharing request
  Future<String> requestContactSharing({
    required String caseId,
    required String childId,
    required String requesterId,
    required String requesterName,
    required String requesterRole,
    required String recipientId,
    required String recipientName,
    required String recipientRole,
    required ContactItemType requestedItem,
    required String purpose,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != requesterId) {
      throw Exception('Unauthorized request.');
    }

    // Check for existing pending request for same item
    final existingSnap = await _firestore
        .collection(collection)
        .where('caseId', isEqualTo: caseId)
        .where('requesterId', isEqualTo: requesterId)
        .where('requestedItem', isEqualTo: requestedItem.name)
        .where('status', isEqualTo: ContactConsentStatus.pending.name)
        .limit(1)
        .get();

    if (existingSnap.docs.isNotEmpty) {
      throw Exception('A pending request for this contact item has already been submitted.');
    }

    final now = DateTime.now();
    final docRef = _firestore.collection(collection).doc();

    final model = ContactConsentModel(
      id: docRef.id,
      caseId: caseId,
      childId: childId,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterRole: requesterRole,
      recipientId: recipientId,
      recipientName: recipientName,
      recipientRole: recipientRole,
      requestedItem: requestedItem,
      purpose: purpose.trim(),
      requestedAt: now,
    );

    await docRef.set(model.toMap());

    // Send persistent notification to recipient
    try {
      final itemLabel = requestedItem.name.toUpperCase();
      await _firestore.collection('notifications').add({
        'userId': recipientId,
        'senderId': requesterId,
        'type': 'contact_sharing_request',
        'caseId': caseId,
        'childId': childId,
        'title': 'Contact Sharing Request from $requesterName',
        'message': '$requesterName is requesting your $itemLabel for: "${purpose.trim()}"',
        'body': '$requesterName is requesting your $itemLabel for: "${purpose.trim()}"',
        'data': {'requestId': docRef.id, 'caseId': caseId},
        'read': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    await AuditLogService.logEvent(
      action: 'contact_sharing_requested',
      caseId: caseId,
      childId: childId,
      targetId: recipientId,
      details: {
        'requestedItem': requestedItem.name,
        'purpose': purpose,
      },
    );

    return docRef.id;
  }

  /// Recipient approves or declines the request
  Future<void> respondToRequest({
    required String requestId,
    required bool approve,
    String? contactValueIfApproved,
    String? declineReason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Authentication required.');

    final docRef = _firestore.collection(collection).doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Contact request not found.');

    final data = snap.data()!;
    if (data['recipientId'] != user.uid) {
      throw Exception('Unauthorized: only the recipient can approve or decline this request.');
    }

    final now = DateTime.now();

    if (approve) {
      String resolvedContact = contactValueIfApproved?.trim() ?? '';
      // If contact value was not passed directly, look up recipient's phone/email safely
      if (resolvedContact.isEmpty) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data() ?? {};
        final requestedItem = data['requestedItem'];
        if (requestedItem == 'phone' || requestedItem == 'whatsapp') {
          resolvedContact = userData['phone'] ?? '';
        } else if (requestedItem == 'email') {
          resolvedContact = userData['email'] ?? user.email ?? '';
        } else {
          resolvedContact = '${userData['phone'] ?? ''} • ${userData['email'] ?? user.email ?? ''}';
        }
      }

      await docRef.update({
        'status': ContactConsentStatus.approved.name,
        'sharedContactValue': resolvedContact,
        'respondedAt': Timestamp.fromDate(now),
        'revokedAt': null,
      });

      // Notify requester
      try {
        await _firestore.collection('notifications').add({
          'userId': data['requesterId'],
          'senderId': user.uid,
          'type': 'contact_sharing_approved',
          'caseId': data['caseId'],
          'childId': data['childId'],
          'title': 'Contact Request Approved!',
          'message': '${data['recipientName']} approved your request for ${data['requestedItem']}.',
          'body': '${data['recipientName']} approved your request for ${data['requestedItem']}.',
          'data': {'requestId': requestId, 'caseId': data['caseId']},
          'read': false,
          'readAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      await AuditLogService.logEvent(
        action: 'contact_sharing_approved',
        caseId: data['caseId'],
        childId: data['childId'],
        targetId: data['requesterId'],
      );
    } else {
      await docRef.update({
        'status': ContactConsentStatus.declined.name,
        'declineOrRevokeReason': declineReason ?? 'User declined contact sharing.',
        'respondedAt': Timestamp.fromDate(now),
        'sharedContactValue': null,
      });

      // Notify requester
      try {
        await _firestore.collection('notifications').add({
          'userId': data['requesterId'],
          'senderId': user.uid,
          'type': 'contact_sharing_declined',
          'caseId': data['caseId'],
          'childId': data['childId'],
          'title': 'Contact Request Declined',
          'message': '${data['recipientName']} is unable to share contact details at this time.',
          'body': '${data['recipientName']} is unable to share contact details at this time.',
          'data': {'requestId': requestId, 'caseId': data['caseId']},
          'read': false,
          'readAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      await AuditLogService.logEvent(
        action: 'contact_sharing_declined',
        caseId: data['caseId'],
        childId: data['childId'],
        targetId: data['requesterId'],
      );
    }
  }

  /// Recipient revokes/withdraws contact sharing immediately
  Future<void> revokeContactConsent({
    required String requestId,
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Authentication required.');

    final docRef = _firestore.collection(collection).doc(requestId);
    final snap = await docRef.get();
    if (!snap.exists) throw Exception('Contact request not found.');

    final data = snap.data()!;
    if (data['recipientId'] != user.uid) {
      throw Exception('Unauthorized: only the contact owner can revoke sharing.');
    }

    final now = DateTime.now();

    await docRef.update({
      'status': ContactConsentStatus.revoked.name,
      'revokedAt': Timestamp.fromDate(now),
      'declineOrRevokeReason': reason ?? 'Owner revoked contact access.',
      'sharedContactValue': null, // Data erasure at boundary!
    });

    // Notify requester
    try {
      await _firestore.collection('notifications').add({
        'userId': data['requesterId'],
        'senderId': user.uid,
        'type': 'contact_sharing_revoked',
        'caseId': data['caseId'],
        'childId': data['childId'],
        'title': 'Contact Sharing Withdrawn',
        'message': '${data['recipientName']} has withdrawn permission to view contact details.',
        'body': '${data['recipientName']} has withdrawn permission to view contact details.',
        'data': {'requestId': requestId, 'caseId': data['caseId']},
        'read': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    await AuditLogService.logEvent(
      action: 'contact_sharing_revoked',
      caseId: data['caseId'],
      childId: data['childId'],
      targetId: data['requesterId'],
    );
  }
}
