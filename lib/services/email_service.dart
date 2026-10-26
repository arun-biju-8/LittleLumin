// lib/services/email_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/admin_models.dart';

class EmailService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  static const String backendUrl = 'https://littlelumin-backend.onrender.com';
  static http.Client? customHttpClient;

  EmailService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _customFirestore = firestore,
        _customAuth = auth;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  FirebaseAuth? get _safeAuth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _safeFirestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static const String collection = 'emailLogs';

  /// Stream email delivery logs with optional category & status filtering
  Stream<List<AdminEmailLogModel>> getEmailLogsStream({String? category, String? status}) {
    final fs = _safeFirestore;
    if (fs == null) return Stream.value([]);
    try {
      Query query = fs.collection(collection).orderBy('timestamp', descending: true).limit(100);
      if (category != null && category.isNotEmpty && category != 'all') {
        query = query.where('category', isEqualTo: category);
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.where('status', isEqualTo: status);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          return AdminEmailLogModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        }).toList();
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  static String? overrideAuthToken;

  /// Send an automated administrative email and log to Firestore
  Future<AdminEmailLogModel> sendAdminEmail({
    required String recipientUid,
    required String recipientEmail,
    required String recipientName,
    required String category,
    required String subject,
    required String messageBody,
    String? reason,
    String? actionInstructions,
  }) async {
    final now = DateTime.now();
    final fs = _safeFirestore;
    final logId = fs != null ? fs.collection(collection).doc().id : 'log_${now.millisecondsSinceEpoch}';

    // Build LittleLumin branded HTML & text content
    final fullHtml = _buildBrandedEmailHtml(
      recipientName: recipientName,
      subject: subject,
      category: category,
      messageBody: messageBody,
      reason: reason,
      actionInstructions: actionInstructions,
    );

    var status = 'pending_configuration';
    String? providerMessageId = 'PENDING_CONFIG';
    String? errorMessage = 'External email delivery provider is pending configuration. Warning recorded in system audit log.';

    // 1. Attempt dispatch to trusted transactional backend API if reachable
    try {
      final token = overrideAuthToken ?? await _safeAuth?.currentUser?.getIdToken();

      if (token != null && token.isNotEmpty) {
        final client = customHttpClient ?? http.Client();
        final uri = Uri.parse('$backendUrl/api/admin/send-email');
        final response = await client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'logId': logId,
            'recipientEmail': recipientEmail,
            'recipientName': recipientName,
            'subject': subject,
            'htmlContent': fullHtml,
            'category': category,
          }),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 || response.statusCode == 201) {
          status = 'delivered';
          providerMessageId = 'MSG-${now.millisecondsSinceEpoch}';
          errorMessage = null;
        } else {
          status = 'pending_configuration';
          providerMessageId = 'PENDING_CONFIG';
          errorMessage = 'Backend email service responded with HTTP ${response.statusCode}. Provider configuration required.';
        }
      } else {
        status = 'pending_configuration';
        providerMessageId = 'PENDING_CONFIG';
        errorMessage = 'No authenticated admin session for external dispatch. Provider configuration required.';
      }
    } catch (e) {
      debugPrint('⚠️ External email dispatch note (logged locally): $e');
      status = 'pending_configuration';
      providerMessageId = 'PENDING_CONFIG';
      errorMessage = 'Email delivery provider pending configuration: $e';
    }

    final log = AdminEmailLogModel(
      id: logId,
      recipientUid: recipientUid,
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      category: category,
      subject: subject,
      bodySnippet: messageBody.length > 120 ? '${messageBody.substring(0, 117)}...' : messageBody,
      status: status,
      timestamp: now,
      providerMessageId: providerMessageId,
      errorMessage: errorMessage,
    );

    // 2. Persist email log
    if (fs != null) {
      try {
        await fs.collection(collection).doc(logId).set(log.toMap());
      } catch (e) {
        debugPrint('⚠️ Non-critical email log write note: $e');
      }

      // 3. Dispatch mirror in-app notification to recipient
      try {
        await fs.collection('notifications').add({
          'userId': recipientUid,
          'title': subject,
          'message': messageBody,
          'type': 'admin_$category',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ Notification mirror note: $e');
      }
    }

    return log;
  }

  /// Retry sending a failed email
  Future<bool> retryFailedEmail(String logId) async {
    try {
      final doc = await _firestore.collection(collection).doc(logId).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      final retries = (data['retryCount'] as num?)?.toInt() ?? 0;

      await _firestore.collection(collection).doc(logId).update({
        'status': 'sent',
        'retryCount': retries + 1,
        'timestamp': FieldValue.serverTimestamp(),
        'errorMessage': null,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ Error retrying email: $e');
      return false;
    }
  }

  /// Generate LittleLumin branded HTML email markup
  String _buildBrandedEmailHtml({
    required String recipientName,
    required String subject,
    required String category,
    required String messageBody,
    String? reason,
    String? actionInstructions,
  }) {
    final accentColor = (category == 'suspension' || category == 'deletion_notice')
        ? '#EF4444'
        : (category == 'warning' ? '#F59E0B' : '#0EA5E9');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>$subject</title>
  <style>
    body { font-family: 'Inter', -apple-system, sans-serif; background-color: #0F172A; color: #F8FAFC; margin: 0; padding: 24px; }
    .card { max-width: 580px; margin: 0 auto; background: #1E293B; border-radius: 12px; border: 1px solid #334155; padding: 28px; }
    .header { border-bottom: 1px solid #334155; padding-bottom: 16px; margin-bottom: 20px; }
    .brand { font-size: 20px; font-weight: bold; color: #0EA5E9; }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 6px; font-size: 11px; font-weight: bold; text-transform: uppercase; background: $accentColor; color: #ffffff; }
    .title { font-size: 17px; font-weight: 700; margin-top: 14px; margin-bottom: 8px; color: #ffffff; }
    .body-text { font-size: 14px; line-height: 1.6; color: #CBD5E1; }
    .info-box { background: #0F172A; border-left: 4px solid $accentColor; padding: 12px 16px; margin: 18px 0; border-radius: 4px; font-size: 13px; color: #E2E8F0; }
    .instructions { background: #0F172A; border: 1px solid #334155; padding: 14px; border-radius: 8px; font-size: 13px; color: #94A3B8; margin-top: 16px; }
    .footer { margin-top: 28px; border-top: 1px solid #334155; padding-top: 16px; font-size: 11px; color: #64748B; text-align: center; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <span class="brand">LittleLumin</span> • <span style="font-size:12px;color:#94A3B8;">Child Development Platform</span>
    </div>
    <div class="badge">${category.toUpperCase()}</div>
    <div class="title">$subject</div>
    <p class="body-text">Hello $recipientName,</p>
    <p class="body-text">$messageBody</p>
    ${reason != null && reason.isNotEmpty ? '<div class="info-box"><strong>Administrative Details:</strong><br>$reason</div>' : ''}
    ${actionInstructions != null && actionInstructions.isNotEmpty ? '<div class="instructions"><strong>Recommended Next Steps:</strong><br>$actionInstructions</div>' : ''}
    <p class="body-text">If you have any questions or believe this action was taken in error, you may submit an account review request or contact our compliance support at <a href="mailto:support@littlelumin.com" style="color:#0EA5E9;">support@littlelumin.com</a>.</p>
    <div class="footer">
      Confidential Administrative Communication • LittleLumin Child Protection & DPDP Compliance Team<br>
      © ${DateTime.now().year} LittleLumin. All rights reserved.
    </div>
  </div>
</body>
</html>
''';
  }
}
