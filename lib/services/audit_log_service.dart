// lib/services/audit_log_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class AuditLogService {
  static String backendUrl = 'https://littlelumin-backend.onrender.com';
  static http.Client? customHttpClient;

  /// Authoritative audit log dispatch to trusted backend.
  ///
  /// Actor identity is derived strictly from the verified Firebase ID token on the backend,
  /// generating authoritative server-side timestamps and adhering to Firestore rules.
  ///
  /// Returns `true` if the audit event was successfully acknowledged and written by the backend (HTTP 200/201),
  /// or `false` if authentication failed, the payload was rejected, or network errors occurred.
  static Future<bool> logEvent({
    required String action,
    String? targetId,
    String? caseId,
    String? childId,
    Map<String, dynamic>? details,
    FirebaseAuth? auth,
    http.Client? client,
    String? baseUrl,
    String? overrideToken,
  }) async {
    try {
      String? idToken = overrideToken;
      if (idToken == null || idToken.isEmpty) {
        if (Firebase.apps.isEmpty && auth == null) {
          debugPrint('⚠️ AuditLogService: No authenticated user session found for audit event "$action".');
          return false;
        }
        final authClient = auth ?? FirebaseAuth.instance;
        final user = authClient.currentUser;
        if (user == null) {
          debugPrint('⚠️ AuditLogService: No authenticated user session found for audit event "$action".');
          return false;
        }
        idToken = await user.getIdToken();
        if (idToken == null || idToken.isEmpty) {
          debugPrint('⚠️ AuditLogService: Failed to retrieve Firebase ID token for audit event "$action".');
          return false;
        }
      }

      final activeBaseUrl = baseUrl ?? backendUrl;
      final uri = Uri.parse('$activeBaseUrl/api/cases/audit-logs');
      final httpClient = client ?? customHttpClient ?? http.Client();

      final payload = <String, dynamic>{'action': action};
      if (targetId != null) payload['target_id'] = targetId;
      if (caseId != null) payload['case_id'] = caseId;
      if (childId != null) payload['child_id'] = childId;
      if (details != null && details.isNotEmpty) payload['details'] = details;

      final response = await httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint(
          '❌ AuditLogService: Server rejected audit log "$action" '
          '(HTTP ${response.statusCode}): ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ AuditLogService: Failed to dispatch audit log "$action": $e');
      return false;
    }
  }
}
