import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/activity_model.dart';

class AIGenerationService {
  // ✅ Cloud backend URL
  static const String baseUrl = 'https://littlelumin-backend.onrender.com';
  
  // ✅ Increase timeout for slower networks
  static const Duration _timeout = Duration(seconds: 60);

  Future<ActivityModel> generateActivity({
    required String skillDomain,
    required String difficulty,
    int ageYears = 4,
    String childName = '',
  }) async {
    final url = '$baseUrl/api/ai/generate-activity';
    final requestBody = {
      'skill_domain': skillDomain,
      'difficulty': difficulty,
      'age_years': ageYears,
      'child_name': childName,
    };

    debugPrint('[AIGenerationService] POST $url');
    debugPrint('[AIGenerationService] Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('[AIGenerationService] Status: ${response.statusCode}');
      debugPrint('[AIGenerationService] Response: ${response.body}');

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == 'success' && body['data'] != null) {
        final data = Map<String, dynamic>.from(body['data']);
        final generatedId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
        return ActivityModel.fromMap(generatedId, data);
      } else {
        final errorMessage = body['detail'] ?? body['message'] ?? 'Backend error (${response.statusCode})';
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      debugPrint('[AIGenerationService] Network error: $e');
      throw Exception('Network error. Please check your internet connection.');
    } catch (e) {
      debugPrint('[AIGenerationService] Error: $e');
      throw Exception('Failed to generate activity: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<Map<String, dynamic>> generateStory({
    required String childName,
    String topicOrMoral = 'Sharing and Kindness',
    int ageYears = 4,
  }) async {
    final effectiveName = childName.trim().isEmpty ? 'Little Explorer' : childName.trim();
    final url = '$baseUrl/api/ai/generate-story';
    final requestBody = {
      'child_name': effectiveName,
      'topic_or_moral': topicOrMoral,
      'age_years': ageYears,
    };

    debugPrint('[AIGenerationService] POST $url');
    debugPrint('[AIGenerationService] Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('[AIGenerationService] Status: ${response.statusCode}');
      debugPrint('[AIGenerationService] Response: ${response.body}');

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == 'success' && body['data'] != null) {
        return Map<String, dynamic>.from(body['data']);
      } else {
        final errorMessage = body['detail'] ?? body['message'] ?? 'Backend error (${response.statusCode})';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[AIGenerationService] Story error: $e');
      throw Exception('Failed to generate story: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }
}