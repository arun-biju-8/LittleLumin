// lib/services/audit_log_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AuditLogService {
  static const String backendUrl = 'https://littlelumin-backend.onrender.com';
  static http.Client? customHttpClient;

  /// Authoritative audit log dispatch to trusted backend.
  /// Actor identity is derived strictly from verified Firebase token on the backend,
  /// avoiding client-side spoofing and adhering to Firestore 'allow write: if false;' rules.
  static Future<void> logEvent({
    required String action,
    String? targetId,
    String? caseId,
    String? childId,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return;

      final uri = Uri.parse('$backendUrl/api/cases/audit-logs');
      final client = customHttpClient ?? http.Client();
      final payload = <String, dynamic>{'action': action};
      if (targetId != null) payload['target_id'] = targetId;
      if (caseId != null) payload['case_id'] = caseId;
      if (childId != null) payload['child_id'] = childId;
      if (details != null) payload['details'] = details;

      await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('⚠️ Non-critical backend audit log dispatch notice: $e');
    }
  }
}
