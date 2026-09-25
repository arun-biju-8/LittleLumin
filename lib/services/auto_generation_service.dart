import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/flag_service.dart';
import '../services/ai_generation_service.dart';

class AutoGenerationService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  final FlagService _flagService;
  final AIGenerationService _aiGenService;

  // Rate-limiting: 1 generation per child domain per 60 seconds
  static final Map<String, DateTime> _lastGenerationAttempt = {};

  @visibleForTesting
  static void resetRateLimits() => _lastGenerationAttempt.clear();

  @visibleForTesting
  static Map<String, DateTime> get rateLimitMap => _lastGenerationAttempt;

  AutoGenerationService({
    FirebaseFirestore? firestore,
    FlagService? flagService,
    AIGenerationService? aiGenService,
  })  : _customFirestore = firestore,
        _flagService = flagService ?? FlagService(firestore: firestore),
        _aiGenService = aiGenService ?? AIGenerationService();

  /// Called after every feedback submission.
  /// Returns the newly recommended activity, or null if not needed or capped.
  Future<Map<String, dynamic>?> maybeGenerate({
    required String childId,
    required String domain,
    required double currentScore,
    required String childName,
    required List<Map<String, dynamic>> recentEvents,
  }) async {
    final normDomain = domain.trim().toLowerCase();

    // 1. Only generate if score < 70
    if (currentScore >= 70) {
      await clearRecommendation(childId, normDomain);
      return null;
    }

    // Rate limiting: 1 generation per domain per 60 seconds
    final key = '$childId:$normDomain';
    final lastAttempt = _lastGenerationAttempt[key];
    if (lastAttempt != null && DateTime.now().difference(lastAttempt).inSeconds < 60) {
      debugPrint('⏳ [AutoGeneration] Skipped — generated $normDomain for $childId less than 60s ago');
      return null;
    }

    // 2. Check AI-gen cap via FlagService
    final decision = await _flagService.evaluate(
      childId: childId,
      domain: normDomain,
      events: recentEvents,
      currentScore: currentScore,
    );

    if (!decision.canGenerateAI) {
      debugPrint('⚠️ AI-gen cap reached for $normDomain ($childName). Not generating.');
      return null;
    }

    _lastGenerationAttempt[key] = DateTime.now();

    // 3. Determine next difficulty from trend
    final difficulty = computeNextDifficulty(recentEvents);

    // 4. Call AI Generation backend
    final response = await _callBackendGenerate(
      skillDomain: normDomain,
      difficulty: difficulty,
      childName: childName,
      previousActivities: recentEvents
          .take(3)
          .map((e) => (e['activityTitle'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toList(),
      rateLimitKey: key,
    );

    if (response == null) return null;

    // 5. Save recommendation under recommendedActivities/{childId}/domains/{domain}
    try {
      await _firestore
          .collection('recommendedActivities')
          .doc(childId)
          .collection('domains')
          .doc(normDomain)
          .set({
        'childId': childId,
        'domain': normDomain,
        'difficulty': difficulty,
        'activityData': response,
        'generatedAt': FieldValue.serverTimestamp(),
        'reason': 'Score is ${currentScore.round()} — needs more practice in $normDomain',
      });
    } catch (e) {
      debugPrint('⚠️ Error saving recommended activity: $e');
    }

    return response;
  }

  /// Trend-based difficulty computation:
  /// - 2+ "Great" in last 3 -> "hard"
  /// - 2+ "Struggled" in last 3 -> "easy"
  /// - otherwise -> "medium"
  static String computeNextDifficulty(List<Map<String, dynamic>> events) {
    final lastThree = events.take(3).toList();
    final greatCount = lastThree.where((e) => e['feedback']?['childResponse'] == 'Great').length;
    final struggledCount = lastThree.where((e) => e['feedback']?['childResponse'] == 'Struggled').length;

    if (greatCount >= 2) return 'hard';
    if (struggledCount >= 2) return 'easy';
    return 'medium';
  }

  Future<Map<String, dynamic>?> _callBackendGenerate({
    required String skillDomain,
    required String difficulty,
    required String childName,
    required List<String> previousActivities,
    String? rateLimitKey,
  }) async {
    try {
      final activityModel = await _aiGenService.generateActivity(
        skillDomain: skillDomain,
        difficulty: difficulty,
        childName: childName,
      );
      return activityModel.toMap();
    } catch (e) {
      // Silent failure — do NOT crash the feedback flow
      debugPrint('⚠️ [AutoGeneration] Could not generate activity (will retry on next feedback): $e');
      if (rateLimitKey != null) {
        _lastGenerationAttempt.remove(rateLimitKey); // Allow retry sooner since this failed
      }
      return null;
    }
  }

  Future<void> clearRecommendation(String childId, String domain) async {
    try {
      await _firestore
          .collection('recommendedActivities')
          .doc(childId)
          .collection('domains')
          .doc(domain.trim().toLowerCase())
          .delete();
    } catch (e) {
      debugPrint('⚠️ Error clearing recommendation: $e');
    }
  }
}
