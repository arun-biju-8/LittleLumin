// lib/services/growth_messaging_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/child_model.dart';
import '../models/journey_model.dart';
import '../models/learning_update_model.dart';
import 'ai_generation_service.dart';

class GrowthMessage {
  final String headline;
  final String message;
  final String suggestedAction;
  final String source; // 'gemini' | 'fallback'
  final String stateFingerprint;
  final DateTime generatedAt;

  const GrowthMessage({
    required this.headline,
    required this.message,
    required this.suggestedAction,
    this.source = 'gemini',
    required this.stateFingerprint,
    required this.generatedAt,
  });

  bool get isFallback => source == 'fallback';

  Map<String, dynamic> toMap() {
    return {
      'headline': headline,
      'message': message,
      'suggestedAction': suggestedAction,
      'source': source,
      'stateFingerprint': stateFingerprint,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  factory GrowthMessage.fromMap(Map<String, dynamic> map) {
    return GrowthMessage(
      headline: map['headline'] ?? '',
      message: map['message'] ?? '',
      suggestedAction: map['suggestedAction'] ?? 'Continue Learning',
      source: map['source'] ?? 'gemini',
      stateFingerprint: map['stateFingerprint'] ?? '',
      generatedAt: DateTime.tryParse(map['generatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class GrowthMessagingService {
  final http.Client? client;
  static final Map<String, GrowthMessage> _messageCache = {};
  static final Map<String, Future<GrowthMessage>> _inFlightRequests = {};

  GrowthMessagingService({this.client});

  /// Visible for testing to clear cache between test runs
  static void clearCache() {
    _messageCache.clear();
    _inFlightRequests.clear();
  }

  /// Resolve learning state category strictly from verified facts
  String determineLearningState({
    required JourneyProgress journey,
    required int completedActivitiesCount,
    required int masteredDomainsCount,
    required int totalDomainsCount,
  }) {
    final curLevel = journey.currentLevel;
    final lvlProg = journey.levelProgress[curLevel];
    final isLevelMastered = (lvlProg != null && lvlProg.isCompleted) ||
        masteredDomainsCount >= totalDomainsCount ||
        journey.isLevelUnlocked(curLevel + 1);

    if (isLevelMastered) {
      return 'level_mastered'; // State E
    }

    if (completedActivitiesCount >= 6 && masteredDomainsCount < totalDomainsCount) {
      return 'initial_activities_completed_mastery_pending'; // State A
    }

    final lowestPending = journey.lowestScoringPendingDomain;
    if (lowestPending != null && lowestPending.activitiesDone > 0 && lowestPending.score < 70.0) {
      return 'domain_practice_needed'; // State B
    }

    if (masteredDomainsCount > 0 && masteredDomainsCount < totalDomainsCount) {
      return 'milestone_achieved'; // State C
    }

    if (completedActivitiesCount == 0 || journey.currentLevelDomains.isEmpty) {
      return 'assessment_pending'; // State D
    }

    return 'learning_in_progress';
  }

  /// Generate fingerprint uniquely identifying the child's current progression facts
  String computeFingerprint({
    required String childId,
    required int currentLevel,
    required int completedActivitiesCount,
    required int masteredDomainsCount,
    required List<String> pendingDomains,
    required String recommendedDomain,
    required String learningState,
  }) {
    final pendingKey = (List<String>.from(pendingDomains)..sort()).join(',');
    return '$childId:lvl$currentLevel:act$completedActivitiesCount:m$masteredDomainsCount:p[$pendingKey]:rec$recommendedDomain:state$learningState';
  }

  /// Get cached or generate a new personalised parent encouragement message
  Future<GrowthMessage> getOrGenerateMessage({
    required ChildModel child,
    required JourneyProgress journey,
    Map<String, dynamic>? recommendation,
    bool forceRefresh = false,
  }) async {
    final childId = child.childId;
    final currentLevel = journey.currentLevel;
    final lvlProg = journey.levelProgress[currentLevel];
    final masteredCount = lvlProg?.masteredDomainCount ?? journey.masteredDomainCount;
    final totalDomains = lvlProg?.totalDomains ?? 6;
    final completedActivitiesCount = journey.completedActivities.length;

    final pendingDomains = journey.pendingDomainKeys;
    final recommendedDomain = (recommendation?['domain'] ??
            journey.lowestScoringPendingDomain?.domain ??
            'cognitive')
        .toString()
        .toLowerCase();
    final recActivityTitle = recommendation?['activity'] != null
        ? (recommendation!['activity'] as dynamic).title?.toString()
        : null;

    final learningState = determineLearningState(
      journey: journey,
      completedActivitiesCount: completedActivitiesCount,
      masteredDomainsCount: masteredCount,
      totalDomainsCount: totalDomains,
    );

    final fingerprint = computeFingerprint(
      childId: childId,
      currentLevel: currentLevel,
      completedActivitiesCount: completedActivitiesCount,
      masteredDomainsCount: masteredCount,
      pendingDomains: pendingDomains,
      recommendedDomain: recommendedDomain,
      learningState: learningState,
    );

    // Check memory cache: if valid, matches child and fingerprint, not forced
    if (!forceRefresh && _messageCache.containsKey(childId)) {
      final cached = _messageCache[childId]!;
      if (cached.stateFingerprint == fingerprint) {
        final age = DateTime.now().difference(cached.generatedAt);
        if (age.inHours < 4) {
          debugPrint('✅ Returning cached growth message for $childId ($learningState)');
          return cached;
        }
      }
    }

    // Deduplicate in-flight requests for the same child
    if (_inFlightRequests.containsKey(childId)) {
      debugPrint('⏳ Reusing in-flight growth message request for $childId');
      return _inFlightRequests[childId]!;
    }

    // Prepare non-identifying request payload
    final safeChildName = child.name.trim().isNotEmpty
        ? child.name.trim().split(' ').first // only first name, never full name
        : 'Your child';

    final domainScores = <String, double>{};
    journey.currentLevelDomains.forEach((k, v) {
      domainScores[k] = v.score;
    });

    final masteredList = journey.currentLevelDomains.entries
        .where((e) => e.value.isMastered)
        .map((e) => e.key)
        .toList();

    final requestFuture = _executeGeneration(
      childId: childId,
      childAge: child.age,
      safeChildName: safeChildName,
      currentLevel: currentLevel,
      completedActivitiesCount: completedActivitiesCount,
      assessedDomainsCount: journey.currentLevelDomains.values.where((d) => d.score > 0).length,
      masteredDomainsCount: masteredCount,
      totalDomainsCount: totalDomains,
      learningState: learningState,
      domainScores: domainScores,
      masteredDomains: masteredList,
      pendingDomains: pendingDomains,
      recommendedDomain: recommendedDomain,
      recommendedActivityTitle: recActivityTitle,
      fingerprint: fingerprint,
    );

    _inFlightRequests[childId] = requestFuture;

    try {
      final message = await requestFuture;
      _messageCache[childId] = message;
      return message;
    } finally {
      _inFlightRequests.remove(childId);
    }
  }

  Future<GrowthMessage> _executeGeneration({
    required String childId,
    required int childAge,
    required String safeChildName,
    required int currentLevel,
    required int completedActivitiesCount,
    required int assessedDomainsCount,
    required int masteredDomainsCount,
    required int totalDomainsCount,
    required String learningState,
    required Map<String, double> domainScores,
    required List<String> masteredDomains,
    required List<String> pendingDomains,
    required String recommendedDomain,
    required String? recommendedActivityTitle,
    required String fingerprint,
  }) async {
    final url = '${AIGenerationService.baseUrl}/api/ai/generate-growth-message';
    final payload = {
      'child_age': childAge,
      'child_name': safeChildName,
      'current_level': currentLevel,
      'completed_activities_count': completedActivitiesCount,
      'assessed_domains_count': assessedDomainsCount,
      'mastered_domains_count': masteredDomainsCount,
      'total_domains_count': totalDomainsCount,
      'learning_state': learningState,
      'domain_scores': domainScores,
      'mastered_domains': masteredDomains,
      'pending_domains': pendingDomains,
      'recommended_domain': recommendedDomain,
      'recommended_activity_title': recommendedActivityTitle,
    };

    try {
      final uri = Uri.parse(url);
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final clientToUse = client;
      final response = await (clientToUse != null
              ? clientToUse.post(uri, headers: headers, body: jsonEncode(payload))
              : http.post(uri, headers: headers, body: jsonEncode(payload)))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && (body['status'] == 'success' || body['success'] == true) && body['data'] is Map) {
          final data = Map<String, dynamic>.from(body['data']);
          final headline = data['headline']?.toString().trim() ?? '';
          String message = data['message']?.toString().trim() ?? '';
          final suggestedAction = data['suggested_action']?.toString().trim() ?? 'Continue Practice';

          // Clean duplicate headline prefix if repeated in message
          if (headline.isNotEmpty && message.toLowerCase().startsWith(headline.toLowerCase())) {
            message = message.substring(headline.length).trim();
            if (message.startsWith(':') || message.startsWith('-') || message.startsWith('–')) {
              message = message.substring(1).trim();
            }
          }

          if (headline.isNotEmpty && message.isNotEmpty && message.length >= 20) {
            return GrowthMessage(
              headline: headline,
              message: message,
              suggestedAction: suggestedAction,
              source: data['source'] ?? 'gemini',
              stateFingerprint: fingerprint,
              generatedAt: DateTime.now(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ AI Growth message network request failed: $e. Using verified fallback.');
    }

    // Deterministic state-specific fallback
    return _buildFallbackMessage(
      safeChildName: safeChildName,
      currentLevel: currentLevel,
      completedActivitiesCount: completedActivitiesCount,
      masteredDomainsCount: masteredDomainsCount,
      totalDomainsCount: totalDomainsCount,
      learningState: learningState,
      recommendedDomain: recommendedDomain,
      fingerprint: fingerprint,
    );
  }

  GrowthMessage _buildFallbackMessage({
    required String safeChildName,
    required int currentLevel,
    required int completedActivitiesCount,
    required int masteredDomainsCount,
    required int totalDomainsCount,
    required String learningState,
    required String recommendedDomain,
    required String fingerprint,
  }) {
    final capDomain = recommendedDomain.isNotEmpty
        ? recommendedDomain[0].toUpperCase() + recommendedDomain.substring(1)
        : 'Developmental';

    final hasName = safeChildName.trim().isNotEmpty &&
        safeChildName.trim().toLowerCase() != 'your child' &&
        safeChildName.trim().toLowerCase() != 'child';
    final childSubject = hasName ? safeChildName.trim() : 'Your child';
    final childObject = hasName ? safeChildName.trim() : 'your child';
    final childPossessive = hasName ? "${safeChildName.trim()}'s" : 'their';

    String headline;
    String message;
    String action;

    if (learningState == 'level_mastered' || masteredDomainsCount >= totalDomainsCount) {
      // State E: Level mastery achieved
      headline = 'Level $currentLevel Mastered! 🏆';
      message = 'Incredible effort! $childSubject has achieved mastery across all 6 developmental domains. Level ${currentLevel + 1} is now unlocked and ready for new discoveries.';
      action = 'Explore Level ${currentLevel + 1}';
    } else if (learningState == 'initial_activities_completed_mastery_pending') {
      // State A: Initial Level activities completed, mastery still in progress
      headline = 'Level $currentLevel · Learning in progress';
      message = 'The first set of activities is complete — a lovely milestone! $childSubject can continue building these skills through more practice. Let\'s explore the next activity in $childPossessive learning journey. To unlock Level ${currentLevel + 1}, let\'s practise a few activities again and build your skills. $childSubject has mastered $masteredDomainsCount of $totalDomainsCount domains so far — you\'re getting closer!';
      action = 'Continue Learning';
    } else if (learningState == 'domain_practice_needed') {
      // State B: A particular domain needs more practice
      headline = 'Building $capDomain Skills';
      message = '$childSubject is making great progress. A little extra playful practice in $capDomain will help strengthen foundational confidence and achieve $childPossessive next milestone.';
      action = 'Start Practice';
    } else if (learningState == 'milestone_achieved') {
      // State C: Meaningful achievement occurred
      headline = 'Lovely Milestone Achieved! 🌟';
      message = 'Great work celebrating each learning step together. $childSubject has demonstrated mastery in $masteredDomainsCount of $totalDomainsCount core domains. Let\'s keep the momentum going!';
      action = 'Next Activity';
    } else if (learningState == 'assessment_pending' || completedActivitiesCount == 0) {
      // State D: Assessment pending or initial journey
      headline = 'Welcome to Level $currentLevel Workspace';
      message = 'Every learning adventure begins with play. Choose an activity for $childObject to begin discovering new developmental strengths together.';
      action = 'Begin Activity';
    } else {
      headline = 'Level $currentLevel · Learning in progress';
      message = '$childSubject is actively exploring Level $currentLevel. With $completedActivitiesCount activities completed and $masteredDomainsCount of $totalDomainsCount domains mastered, playful practice is paving the way to Level ${currentLevel + 1}.';
      action = 'Continue Practice';
    }

    return GrowthMessage(
      headline: headline,
      message: message,
      suggestedAction: action,
      source: 'fallback',
      stateFingerprint: fingerprint,
      generatedAt: DateTime.now(),
    );
  }

  /// Generate a tailored parent encouragement message for a completed learning update
  Future<GrowthMessage> getOrGenerateLearningUpdateMessage({
    required LearningUpdateModel update,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'update_${update.childId}_${update.activityId}_${update.completedAt.millisecondsSinceEpoch}';
    if (!forceRefresh && _messageCache.containsKey(cacheKey)) {
      return _messageCache[cacheKey]!;
    }

    final hasName = update.childName.trim().isNotEmpty &&
        update.childName.trim().toLowerCase() != 'your child' &&
        update.childName.trim().toLowerCase() != 'child';
    final childSubject = hasName ? update.childName.trim() : 'Your child';
    final capDomain = update.domain.isNotEmpty
        ? update.domain[0].toUpperCase() + update.domain.substring(1).toLowerCase()
        : 'Developmental';

    // 1. Try backend generation if possible
    try {
      final safeChildName = hasName ? update.childName.trim().split(' ').first : 'Your child';
      final payload = {
        'child_age': 4,
        'child_name': safeChildName,
        'current_level': update.level,
        'completed_activities_count': 1,
        'assessed_domains_count': 1,
        'mastered_domains_count': update.isMastered ? 1 : 0,
        'total_domains_count': 6,
        'learning_state': update.levelCompleted
            ? 'level_mastered'
            : (update.isMastered ? 'milestone_achieved' : 'learning_in_progress'),
        'domain_scores': {update.domain.toLowerCase(): update.scoreAfter},
        'mastered_domains': update.isMastered ? [update.domain.toLowerCase()] : <String>[],
        'pending_domains': update.isMastered ? <String>[] : [update.domain.toLowerCase()],
        'recommended_domain': update.domain.toLowerCase(),
        'recommended_activity_title': update.activityTitle,
      };

      final url = '${AIGenerationService.baseUrl}/api/ai/generate-growth-message';
      final clientToUse = client;
      final uri = Uri.parse(url);
      final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};

      final response = await (clientToUse != null
              ? clientToUse.post(uri, headers: headers, body: jsonEncode(payload))
              : http.post(uri, headers: headers, body: jsonEncode(payload)))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map && (body['status'] == 'success' || body['success'] == true) && body['data'] is Map) {
          final data = Map<String, dynamic>.from(body['data']);
          final headline = data['headline']?.toString().trim() ?? 'Learning Progress Recorded 🌱';
          String msgText = data['message']?.toString().trim() ?? '';
          if (headline.isNotEmpty && msgText.toLowerCase().startsWith(headline.toLowerCase())) {
            msgText = msgText.substring(headline.length).trim();
            if (msgText.startsWith(':') || msgText.startsWith('-') || msgText.startsWith('–')) {
              msgText = msgText.substring(1).trim();
            }
          }
          if (msgText.isNotEmpty) {
            final msg = GrowthMessage(
              headline: headline,
              message: msgText,
              suggestedAction: 'View All Growth',
              source: 'gemini',
              stateFingerprint: cacheKey,
              generatedAt: DateTime.now(),
            );
            _messageCache[cacheKey] = msg;
            return msg;
          }
        }
      }
    } catch (_) {
      // Fallback below
    }

    // 2. High-quality contextual fallback
    String headline;
    String message;

    if (update.levelCompleted) {
      headline = 'Level ${update.level} Mastered! 🏆';
      message = 'Incredible milestone for $childSubject! All 6 core developmental domains have achieved mastery. Level ${update.nextLevel ?? (update.level + 1)} is now unlocked and ready for new discoveries.';
    } else if (update.isMastered) {
      headline = '$capDomain Mastery Achieved! 🌟';
      message = '$childSubject has reached the 70% milestone in $capDomain! Practicing "${update.activityTitle}" reinforced key strengths and built lasting confidence.';
    } else if (update.scoreDelta > 0) {
      headline = 'Growing in $capDomain! 🌱';
      message = '$childSubject had a wonderful learning session with "${update.activityTitle}". Every playful practice builds foundational coordination and joy in discovery.';
    } else {
      headline = 'Practice Recorded! 🌱';
      message = '$childSubject completed "${update.activityTitle}". Playful repetition strengthens skills step by step in $capDomain.';
    }

    final fallback = GrowthMessage(
      headline: headline,
      message: message,
      suggestedAction: 'View All Growth',
      source: 'fallback',
      stateFingerprint: cacheKey,
      generatedAt: DateTime.now(),
    );
    _messageCache[cacheKey] = fallback;
    return fallback;
  }
}
