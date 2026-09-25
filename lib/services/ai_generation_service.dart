import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/activity_model.dart';

class AIGenerationService {
  // ✅ Cloud backend URL
  static const String baseUrl = 'https://littlelumin-backend.onrender.com';
  
  final http.Client? client;

  AIGenerationService({this.client});

  Future<ActivityModel> generateActivity({
    required String skillDomain,
    required String difficulty,
    int ageYears = 4,
    String childName = '',
    int maxRetries = 2,
    Duration Function(int attempt)? retryDelayProvider,
  }) async {
    final url = '$baseUrl/api/ai/generate-activity';
    final requestBody = {
      'skill_domain': skillDomain,
      'difficulty': difficulty,
      'age_years': ageYears,
      'child_name': childName,
    };

    Exception? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[AIGenerationService] POST $url (attempt ${attempt + 1}/${maxRetries + 1})');

        final uri = Uri.parse(url);
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };
        final bodyJson = jsonEncode(requestBody);

        final httpClient = client;
        final response = await (httpClient != null
                ? httpClient.post(uri, headers: headers, body: bodyJson)
                : http.post(uri, headers: headers, body: bodyJson))
            .timeout(const Duration(seconds: 90));

        dynamic body;
        try {
          body = jsonDecode(response.body);
        } catch (_) {
          body = null;
        }

        if (response.statusCode == 200 &&
            body is Map &&
            body['status'] == 'success' &&
            body['data'] != null) {
          debugPrint('[AIGenerationService] ✅ Success on attempt ${attempt + 1}');
          final data = Map<String, dynamic>.from(body['data']);
          final generatedId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
          return ActivityModel.fromMap(generatedId, data);
        }

        // 500 error — retry if we have attempts left
        if (response.statusCode >= 500 && attempt < maxRetries) {
          final waitSeconds = (attempt + 1) * 3; // 3s, 6s
          final delay = retryDelayProvider != null
              ? retryDelayProvider(attempt)
              : Duration(seconds: waitSeconds);
          debugPrint('[AIGenerationService] ⚠️ Got ${response.statusCode}, retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
          continue;
        }

        // Non-retryable error
        final errorMessage = body is Map
            ? (body['detail'] is Map
                ? body['detail']['message'] ?? 'Backend error'
                : body['detail'] ?? body['message'] ?? 'Backend error (${response.statusCode})')
            : 'Backend error (${response.statusCode})';
        throw Exception(errorMessage);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          final waitSeconds = (attempt + 1) * 3;
          final delay = retryDelayProvider != null
              ? retryDelayProvider(attempt)
              : Duration(seconds: waitSeconds);
          debugPrint('[AIGenerationService] ⚠️ Attempt ${attempt + 1} failed. Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('[AIGenerationService] ❌ All attempts failed');
    throw lastError ?? Exception('Failed to generate activity after retries');
  }

  Future<Map<String, dynamic>> generateStory({
    required String childName,
    String topicOrMoral = 'Sharing and Kindness',
    int ageYears = 4,
    int maxRetries = 2,
    Duration Function(int attempt)? retryDelayProvider,
  }) async {
    final effectiveName = childName.trim().isEmpty ? 'Little Explorer' : childName.trim();
    final url = '$baseUrl/api/ai/generate-story';
    final requestBody = {
      'child_name': effectiveName,
      'topic_or_moral': topicOrMoral,
      'age_years': ageYears,
    };

    Exception? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[AIGenerationService] POST $url (attempt ${attempt + 1}/${maxRetries + 1})');

        final uri = Uri.parse(url);
        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };
        final bodyJson = jsonEncode(requestBody);

        final httpClient = client;
        final response = await (httpClient != null
                ? httpClient.post(uri, headers: headers, body: bodyJson)
                : http.post(uri, headers: headers, body: bodyJson))
            .timeout(const Duration(seconds: 90));

        dynamic body;
        try {
          body = jsonDecode(response.body);
        } catch (_) {
          body = null;
        }

        if (response.statusCode == 200 &&
            body is Map &&
            body['status'] == 'success' &&
            body['data'] != null) {
          debugPrint('[AIGenerationService] ✅ Success on attempt ${attempt + 1}');
          return Map<String, dynamic>.from(body['data']);
        }

        // 500 error — retry if we have attempts left
        if (response.statusCode >= 500 && attempt < maxRetries) {
          final waitSeconds = (attempt + 1) * 3;
          final delay = retryDelayProvider != null
              ? retryDelayProvider(attempt)
              : Duration(seconds: waitSeconds);
          debugPrint('[AIGenerationService] ⚠️ Got ${response.statusCode}, retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
          continue;
        }

        // Non-retryable error
        final errorMessage = body is Map
            ? (body['detail'] is Map
                ? body['detail']['message'] ?? 'Backend error'
                : body['detail'] ?? body['message'] ?? 'Backend error (${response.statusCode})')
            : 'Backend error (${response.statusCode})';
        throw Exception(errorMessage);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries) {
          final waitSeconds = (attempt + 1) * 3;
          final delay = retryDelayProvider != null
              ? retryDelayProvider(attempt)
              : Duration(seconds: waitSeconds);
          debugPrint('[AIGenerationService] ⚠️ Story attempt ${attempt + 1} failed. Retrying in ${delay.inSeconds}s...');
          await Future.delayed(delay);
        }
      }
    }

    debugPrint('[AIGenerationService] ❌ All attempts failed');
    throw lastError ?? Exception('Failed to generate story after retries');
  }
}