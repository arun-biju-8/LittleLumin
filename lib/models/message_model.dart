// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class MessageModel {
  final String id;
  final String caseId;
  final String childId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'parent', 'llg', 'clinical_specialist'
  final String recipientId;
  final String content;
  final DateTime timestamp;
  final DateTime? readAt;
  final MessageStatus status;
  final String? linkedRecommendationId;
  final String? linkedActivityId;

  const MessageModel({
    required this.id,
    required this.caseId,
    required this.childId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    this.readAt,
    this.status = MessageStatus.sent,
    this.linkedRecommendationId,
    this.linkedActivityId,
  });

  bool get isRead => readAt != null || status == MessageStatus.read;

  Map<String, dynamic> toMap() {
    return {
      'caseId': caseId,
      'childId': childId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientId': recipientId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'status': status.name,
      'linkedRecommendationId': linkedRecommendationId,
      'linkedActivityId': linkedActivityId,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    MessageStatus parseStatus(dynamic val) {
      if (val == null) return MessageStatus.sent;
      final str = val.toString().toLowerCase().trim();
      return MessageStatus.values.firstWhere(
        (e) => e.name == str,
        orElse: () => MessageStatus.sent,
      );
    }

    return MessageModel(
      id: docId,
      caseId: map['caseId'] ?? '',
      childId: map['childId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'User',
      senderRole: map['senderRole'] ?? 'parent',
      recipientId: map['recipientId'] ?? '',
      content: map['content'] ?? '',
      timestamp: parseDate(map['timestamp']),
      readAt: map['readAt'] != null ? parseDate(map['readAt']) : null,
      status: parseStatus(map['status']),
      linkedRecommendationId: map['linkedRecommendationId'],
      linkedActivityId: map['linkedActivityId'],
    );
  }

  MessageModel copyWith({
    String? id,
    String? caseId,
    String? childId,
    String? senderId,
    String? senderName,
    String? senderRole,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    DateTime? readAt,
    MessageStatus? status,
    String? linkedRecommendationId,
    String? linkedActivityId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      childId: childId ?? this.childId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      linkedRecommendationId: linkedRecommendationId ?? this.linkedRecommendationId,
      linkedActivityId: linkedActivityId ?? this.linkedActivityId,
    );
  }
}
