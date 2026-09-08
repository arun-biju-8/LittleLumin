// lib/services/ai_generation_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../models/activity_model.dart';

class AIGenerationService {
  // Primary host IP address of computer running backend (Wi-Fi: 192.168.1.2)
  static const String _hostComputerIp = '192.168.53.228';

  /// Dynamically resolves base URL for Web, Desktop, Android Emulator, or Physical Device
  static Future<String> _getBaseUrl() async {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final info = NetworkInfo();
        final deviceIp = await info.getWifiIP();
        debugPrint('[AIGenerationService] Device Wi-Fi IP: $deviceIp');

        if (deviceIp != null && deviceIp.isNotEmpty && deviceIp != '0.0.0.0' && deviceIp != '127.0.0.1') {
          // Physical device connected to Wi-Fi subnet (e.g. 192.168.1.X)
          return 'http://$_hostComputerIp:8000';
        }
      } catch (e) {
        debugPrint('[AIGenerationService] Error getting Wi-Fi IP: $e');
      }

      // Fallback for Android Emulator or physical device fallback
      return 'http://$_hostComputerIp:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static const Duration _timeout = Duration(seconds: 25);

  /// Generates a screen-free activity via FastAPI backend (OpenAI)
  /// Throws an Exception if the API request fails or OpenAI backend error occurs.
  Future<ActivityModel> generateActivity({
    required String skillDomain,
    required String difficulty,
    int ageYears = 4,
    String childName = '',
  }) async {
    final baseUrl = await _getBaseUrl();
    final url = '$baseUrl/api/ai/generate-activity';
    final requestBody = {
      'skill_domain': skillDomain,
      'difficulty': difficulty,
      'age_years': ageYears,
      'child_name': childName,
    };

    debugPrint('[AIGenerationService] POST $url => ${jsonEncode(requestBody)}');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('[AIGenerationService] Response status: ${response.statusCode}');
      debugPrint('[AIGenerationService] Response body: ${response.body}');

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == 'success' && body['data'] != null) {
        final data = Map<String, dynamic>.from(body['data']);
        final generatedId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
        return ActivityModel.fromMap(generatedId, data);
      } else {
        final errorMessage = body['detail'] ?? body['message'] ?? 'Backend returned error (status ${response.statusCode})';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[AIGenerationService] Activity generation error: $e');
      throw Exception('Failed to generate AI activity: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  /// Generates a personalized story via FastAPI backend (OpenAI)
  /// Throws an Exception if the API request fails or OpenAI backend error occurs.
  Future<Map<String, dynamic>> generateStory({
    required String childName,
    String topicOrMoral = 'Sharing and Kindness',
    int ageYears = 4,
  }) async {
    final effectiveName = childName.trim().isEmpty ? 'Little Explorer' : childName.trim();
    final baseUrl = await _getBaseUrl();
    final url = '$baseUrl/api/ai/generate-story';
    final requestBody = {
      'child_name': effectiveName,
      'topic_or_moral': topicOrMoral,
      'age_years': ageYears,
    };

    debugPrint('[AIGenerationService] POST $url => ${jsonEncode(requestBody)}');

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('[AIGenerationService] Response status: ${response.statusCode}');
      debugPrint('[AIGenerationService] Response body: ${response.body}');

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == 'success' && body['data'] != null) {
        return Map<String, dynamic>.from(body['data']);
      } else {
        final errorMessage = body['detail'] ?? body['message'] ?? 'Backend returned error (status ${response.statusCode})';
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('[AIGenerationService] Story generation error: $e');
      throw Exception('Failed to generate AI story: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }
}
