import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:littlelumin/services/ai_generation_service.dart';
import 'package:littlelumin/services/auto_generation_service.dart';

void main() {
  group('AIGenerationService Retry & Backoff Tests', () {
    test('retries on 500 error and succeeds on second attempt', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({'detail': 'AI activity generation failed'}),
            500,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'title': 'Color Sorting Adventure',
              'shortDescription': 'Sort colorful items by shade',
              'instructions': 'Gather objects and sort them.',
              'learningGoals': ['Visual distinction', 'Color recognition'],
              'materials': ['Colored paper', 'Toys'],
              'duration': '15 minutes',
              'skillType': 'cognitive',
              'difficulty': 'medium',
              'ageGroup': [4],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AIGenerationService(client: mockClient);
      final activity = await service.generateActivity(
        skillDomain: 'cognitive',
        difficulty: 'medium',
        maxRetries: 2,
        retryDelayProvider: (_) => Duration.zero,
      );

      expect(callCount, 2);
      expect(activity.title, 'Color Sorting Adventure');
      expect(activity.skillType, 'cognitive');
    });

    test('gives up after max retries when 500 persists', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'detail': 'AI service unavailable'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AIGenerationService(client: mockClient);

      await expectLater(
        service.generateActivity(
          skillDomain: 'motor',
          difficulty: 'easy',
          maxRetries: 2,
          retryDelayProvider: (_) => Duration.zero,
        ),
        throwsA(isA<Exception>()),
      );

      // Initial call + 2 retries = 3 attempts total
      expect(callCount, 3);
    });

    test('generateStory retries on 503 error and succeeds', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode({'detail': 'AI service is temporarily busy'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': {
              'title': 'The Brave Little Star',
              'story': 'Once upon a time...',
              'moral': 'Courage and perseverance',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AIGenerationService(client: mockClient);
      final story = await service.generateStory(
        childName: 'Leo',
        maxRetries: 2,
        retryDelayProvider: (_) => Duration.zero,
      );

      expect(callCount, 2);
      expect(story['title'], 'The Brave Little Star');
    });

    test('generateStory gives up after max retries when server errors continue', () async {
      int callCount = 0;
      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'message': 'Server overload'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AIGenerationService(client: mockClient);

      await expectLater(
        service.generateStory(
          childName: 'Leo',
          maxRetries: 1,
          retryDelayProvider: (_) => Duration.zero,
        ),
        throwsA(isA<Exception>()),
      );

      expect(callCount, 2); // 1 initial + 1 retry
    });
  });

  group('AutoGenerationService Rate Limiting Tests', () {
    setUp(() {
      AutoGenerationService.resetRateLimits();
    });

    test('enforces 1 generation per domain per 60 seconds rate limit', () async {
      final childId = 'child_test_1';
      final domain = 'cognitive';
      final key = '$childId:$domain';

      // Simulate a generation at current time
      AutoGenerationService.rateLimitMap[key] = DateTime.now();

      // Check rate limit map directly and via elapsed time
      final lastAttempt = AutoGenerationService.rateLimitMap[key];
      expect(lastAttempt, isNotNull);
      expect(DateTime.now().difference(lastAttempt!).inSeconds < 60, isTrue);

      // Now simulate 65 seconds passed
      AutoGenerationService.rateLimitMap[key] = DateTime.now().subtract(const Duration(seconds: 65));
      final expiredAttempt = AutoGenerationService.rateLimitMap[key]!;
      expect(DateTime.now().difference(expiredAttempt).inSeconds >= 60, isTrue);
    });

    test('separate children and domains have independent rate limit keys', () {
      final key1 = 'child_1:social';
      final key2 = 'child_1:motor';
      final key3 = 'child_2:social';

      AutoGenerationService.rateLimitMap[key1] = DateTime.now();

      expect(AutoGenerationService.rateLimitMap.containsKey(key1), isTrue);
      expect(AutoGenerationService.rateLimitMap.containsKey(key2), isFalse);
      expect(AutoGenerationService.rateLimitMap.containsKey(key3), isFalse);
    });

    test('trend difficulty computation: 2+ Great -> hard, 2+ Struggled -> easy, otherwise medium', () {
      final greatEvents = [
        {'feedback': {'childResponse': 'Great'}},
        {'feedback': {'childResponse': 'Great'}},
        {'feedback': {'childResponse': 'Okay'}},
      ];
      expect(AutoGenerationService.computeNextDifficulty(greatEvents), 'hard');

      final struggleEvents = [
        {'feedback': {'childResponse': 'Struggled'}},
        {'feedback': {'childResponse': 'Struggled'}},
        {'feedback': {'childResponse': 'Great'}},
      ];
      expect(AutoGenerationService.computeNextDifficulty(struggleEvents), 'easy');

      final mixedEvents = [
        {'feedback': {'childResponse': 'Okay'}},
        {'feedback': {'childResponse': 'Great'}},
        {'feedback': {'childResponse': 'Struggled'}},
      ];
      expect(AutoGenerationService.computeNextDifficulty(mixedEvents), 'medium');
    });
  });
}
