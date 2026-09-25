// lib/services/ai_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_model.dart';
import 'score_ledger_service.dart';
import 'journey_service.dart';

import 'flag_service.dart';
import 'auto_generation_service.dart';

class ProcessFeedbackResult {
  final String domain;
  final double scoreChange;
  final double newScore;
  final bool isFlagged;
  final String? flagReason;
  final ActivityModel? nextActivity;
  final Map<String, dynamic>? ledgerResult;
  final Map<String, dynamic>? journeyResult;

  ProcessFeedbackResult({
    required this.domain,
    required this.scoreChange,
    required this.newScore,
    required this.isFlagged,
    this.flagReason,
    this.nextActivity,
    this.ledgerResult,
    this.journeyResult,
  });

  double get delta => scoreChange;
  double get scoreAfter => newScore;
  double get scoreBefore {
    if (ledgerResult != null && ledgerResult!['previousScore'] is num) {
      return (ledgerResult!['previousScore'] as num).toDouble();
    }
    return newScore - scoreChange;
  }
}

class AIService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScoreLedgerService _scoreLedgerService = ScoreLedgerService();
  final JourneyService _journeyService = JourneyService();
  final FlagService _flagService = FlagService();
  final AutoGenerationService _autoGenService = AutoGenerationService();

  /// Main AI entry point: processes parent feedback, writes immutable score event,
  /// updates journey progression, checks struggle counts, auto-flags if needed, and recommends next activity.
  Future<ProcessFeedbackResult> processFeedback({
    required String childId,
    required String activityId,
    required String childResponse,
    required String engagement,
    required String difficulty,
    required String confidence,
    String? timeEstimate,
    String? notes,
    String? activityTitle,
    String? parentId,
  }) async {
    try {
      // 1. Fetch Activity & Map Skill Domain
      String skillType = 'Cognitive';
      String resolvedTitle = activityTitle ?? 'Activity';
      String activityDifficulty = difficulty;
      String source = 'preset';

      if (activityId.isNotEmpty) {
        try {
          final actDoc = await _firestore.collection('activities').doc(activityId).get();
          if (actDoc.exists && actDoc.data() != null) {
            final data = actDoc.data()!;
            skillType = data['skillType'] ?? 'Cognitive';
            resolvedTitle = data['title'] ?? resolvedTitle;
            activityDifficulty = data['difficulty'] ?? activityDifficulty;

            final isAi = (data['isAIGenerated'] == true) ||
                activityId.startsWith('ai_') ||
                (data['createdBy'] == 'ai');
            final isPreset = data['isPreset'] == true;

            source = isAi ? 'ai_generated' : (isPreset ? 'preset' : 'llg_assigned');
          }
        } catch (e, stack) {
          debugPrint('⚠️ Warning fetching activity $activityId: $e\n$stack');
        }
      }

      final String domain = _mapSkillToDomain(skillType);

      // 2. Calculate Score Change
      final double scoreChange = _calculateScoreChange(
        childResponse: childResponse,
        engagement: engagement,
        difficulty: difficulty,
        confidence: confidence,
      );

      // 3. Determine current level for child
      final progressData = await _journeyService.getProgress(childId);
      final int levelAtTime = (progressData?['currentLevel'] is num)
          ? (progressData!['currentLevel'] as num).toInt()
          : 1;

      // 4. Record Immutable Score Event (Strict Option C Ledger)
      final ledgerResult = await _scoreLedgerService.recordScoreEvent(
        childId: childId,
        activityId: activityId,
        activityTitle: resolvedTitle,
        activitySource: source,
        skillDomain: domain,
        difficulty: activityDifficulty,
        levelAtTime: levelAtTime,
        rawScoreDelta: scoreChange,
        feedback: {
          'childResponse': childResponse,
          'engagement': engagement,
          'difficulty': difficulty,
          'confidence': confidence,
          'timeEstimate': timeEstimate ?? '',
          'notes': notes ?? '',
        },
        submittedByParentId: parentId,
      );

      final double newDomainScore = (ledgerResult['scoreAfter'] is num)
          ? (ledgerResult['scoreAfter'] as num).toDouble()
          : 0.0;

      // 5. Update Journey Progression
      final journeyResult = await _journeyService.processActivityCompletion(
        childId: childId,
        skillDomain: domain,
        newDomainScore: newDomainScore,
      );

      // 6. Ethical Tiered Flag Evaluation & Auto-Unflagging
      List<Map<String, dynamic>> recentEvents = [];
      try {
        final eventsSnap = await _firestore
            .collection('scoreEvents')
            .where('childId', isEqualTo: childId)
            .get();
        recentEvents = eventsSnap.docs
            .map((d) => d.data())
            .where((d) => (d['skillDomain']?.toString().toLowerCase() == domain.toLowerCase()))
            .toList();
      } catch (e) {
        debugPrint('⚠️ Warning querying scoreEvents for flag evaluation: $e');
      }

      final flagDecision = await _flagService.evaluate(
        childId: childId,
        domain: domain,
        events: recentEvents,
        currentScore: newDomainScore,
      );

      await _flagService.writeFlagState(
        childId: childId,
        domain: domain,
        decision: flagDecision,
      );

      final shouldUnflag = await _flagService.shouldAutoUnflag(
        childId: childId,
        domain: domain,
        events: recentEvents,
        currentScore: newDomainScore,
      );

      if (shouldUnflag) {
        await _flagService.resolveAutoUnflag(
          childId: childId,
          domain: domain,
        );
      }

      final bool isFlagged = (flagDecision.tier == FlagTier.flagged && !shouldUnflag);
      final String? flagReason = isFlagged
          ? 'Personalized specialist support recommended in ${domain[0].toUpperCase()}${domain.substring(1)}'
          : null;

      // 7. Auto-generation recommendation (enforcing 3-attempt cap)
      String childName = 'Your child';
      try {
        final childDoc = await _firestore.collection('children').doc(childId).get();
        if (childDoc.exists && childDoc.data() != null) {
          childName = childDoc.data()!['name'] ?? childName;
        }
      } catch (_) {}

      // Background auto-generation (fire-and-forget, never block feedback flow)
      _autoGenService.maybeGenerate(
        childId: childId,
        domain: domain,
        currentScore: newDomainScore,
        childName: childName,
        recentEvents: recentEvents,
      ).catchError((err) {
        debugPrint('⚠️ Background generation failed silently: $err');
        return null;
      });

      // 8. Generate Next Activity Recommendation (for immediate UI display)
      final nextActivity = await _generateNextActivity(
        childId: childId,
        domain: domain,
        currentActivityId: activityId,
        scoreChange: scoreChange,
      );

      return ProcessFeedbackResult(
        domain: domain,
        scoreChange: scoreChange,
        newScore: newDomainScore,
        isFlagged: isFlagged,
        flagReason: flagReason,
        nextActivity: nextActivity,
        ledgerResult: ledgerResult,
        journeyResult: journeyResult,
      );
    } catch (e, stack) {
      debugPrint('❌ Error in AIService.processFeedback: $e\n$stack');
      rethrow;
    }
  }

  /// Calculates score change based on structured feedback parameters
  double _calculateScoreChange({
    required String childResponse,
    required String engagement,
    required String difficulty,
    required String confidence,
  }) {
    // Specific requested rules
    if (childResponse == 'Great' && difficulty == 'Just Right') return 3.0;
    if (childResponse == 'Great' && difficulty == 'Too Easy') return 1.5;
    if (childResponse == 'Okay' && engagement == 'Somewhat Engaged') return 1.0;
    if (childResponse == 'Struggled' && difficulty == 'Too Hard') return -1.5;
    if (childResponse == 'Struggled' && engagement == 'Not Engaged') return -2.5;

    // General composite fallbacks
    double score = 0.0;
    if (childResponse == 'Great') {
      score += 2.0;
    } else if (childResponse == 'Okay') {
      score += 1.0;
    } else if (childResponse == 'Struggled') {
      score -= 1.5;
    }

    if (confidence == 'Very Confident') score += 0.5;
    if (confidence == 'Not Confident') score -= 0.5;

    return score;
  }

  /// Maps skill types to canonical skill profile domain keys
  String _mapSkillToDomain(String skillType) {
    final s = skillType.trim().toLowerCase();
    if (s.contains('cog')) return 'cognitive';
    if (s.contains('lang') || s.contains('speech') || s.contains('talk')) return 'language';
    if (s.contains('motor') || s.contains('phys')) return 'motor';
    if (s.contains('soc')) return 'social';
    if (s.contains('emo')) return 'emotional';
    if (s.contains('creat') || s.contains('art')) return 'creative';
    return 'cognitive';
  }


  /// Selects next recommended activity
  Future<ActivityModel?> _generateNextActivity({
    required String childId,
    required String domain,
    required String currentActivityId,
    required double scoreChange,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('activities')
          .where('isActive', isEqualTo: true)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) return null;

      List<ActivityModel> matches = [];

      for (var doc in snapshot.docs) {
        if (doc.id == currentActivityId) continue;

        final act = ActivityModel.fromMap(doc.id, doc.data());
        if (_mapSkillToDomain(act.skillType) == domain) {
          matches.add(act);
        }
      }

      if (matches.isEmpty) {
        for (var doc in snapshot.docs) {
          if (doc.id != currentActivityId) {
            return ActivityModel.fromMap(doc.id, doc.data());
          }
        }
        return null;
      }

      if (scoreChange < 0) {
        final easier = matches.where((a) => a.difficulty.toLowerCase() == 'easy').toList();
        if (easier.isNotEmpty) return easier.first;
      } else {
        final harder = matches.where((a) => a.difficulty.toLowerCase() == 'medium' || a.difficulty.toLowerCase() == 'hard').toList();
        if (harder.isNotEmpty) return harder.first;
      }

      return matches.first;
    } catch (e, stack) {
      debugPrint('⚠️ Error selecting next activity: $e\n$stack');
      return null;
    }
  }
}
