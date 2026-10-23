// lib/services/messaging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'audit_log_service.dart';

class MessagingService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  MessagingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  static const String rootCollection = 'conversations';

  CollectionReference<Map<String, dynamic>> _messagesRef(String caseId) {
    return _firestore.collection(rootCollection).doc(caseId).collection('messages');
  }

  /// Stream messages for an authorized consultation case
  Stream<List<MessageModel>> getMessagesStream(String caseId) {
    if (caseId.isEmpty) return Stream.value([]);
    return _messagesRef(caseId)
        .orderBy('timestamp', descending: false)
        .limit(200)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MessageModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Send a message within an authorized case
  Future<String> sendMessage({
    required String caseId,
    required String childId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String recipientId,
    required String content,
    String? linkedRecommendationId,
    String? linkedActivityId,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != senderId) {
      throw Exception('Unauthorized sender.');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message content cannot be blank.');
    }
    if (trimmed.length > 2000) {
      throw Exception('Message exceeds maximum limit of 2,000 characters.');
    }

    final now = DateTime.now();
    final docRef = _messagesRef(caseId).doc();

    final message = MessageModel(
      id: docRef.id,
      caseId: caseId,
      childId: childId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      recipientId: recipientId,
      content: trimmed,
      timestamp: now,
      status: MessageStatus.sent,
      linkedRecommendationId: linkedRecommendationId,
      linkedActivityId: linkedActivityId,
    );

    await docRef.set(message.toMap());

    // Update conversation metadata
    try {
      await _firestore.collection(rootCollection).doc(caseId).set({
        'caseId': caseId,
        'childId': childId,
        'lastMessage': trimmed,
        'lastMessageSenderId': senderId,
        'lastMessageTime': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    // Send persistent notification to recipient
    try {
      await _firestore.collection('notifications').add({
        'userId': recipientId,
        'senderId': senderId,
        'type': 'new_chat_message',
        'caseId': caseId,
        'childId': childId,
        'title': 'New Message from $senderName',
        'message': trimmed.length > 80 ? '${trimmed.substring(0, 77)}...' : trimmed,
        'body': trimmed.length > 80 ? '${trimmed.substring(0, 77)}...' : trimmed,
        'data': {'caseId': caseId, 'childId': childId},
        'read': false,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Notification error: $e');
    }

    await AuditLogService.logEvent(
      action: 'message_sent',
      caseId: caseId,
      childId: childId,
      targetId: recipientId,
    );

    return docRef.id;
  }

  /// Mark all unread messages for the recipient as read
  Future<void> markMessagesAsRead(String caseId, String recipientId) async {
    try {
      final unreadSnap = await _messagesRef(caseId)
          .where('recipientId', isEqualTo: recipientId)
          .where('status', isNotEqualTo: MessageStatus.read.name)
          .limit(50)
          .get();

      if (unreadSnap.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in unreadSnap.docs) {
        batch.update(doc.reference, {
          'status': MessageStatus.read.name,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('⚠️ Error marking messages read: $e');
    }
  }

  /// Stream unread message count for a user in a specific case
  Stream<int> getUnreadCountStream(String caseId, String userId) {
    if (caseId.isEmpty) return Stream.value(0);
    return _messagesRef(caseId)
        .where('recipientId', isEqualTo: userId)
        .where('status', isNotEqualTo: MessageStatus.read.name)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
