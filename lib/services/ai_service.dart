// lib/services/ai_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';

class ProcessFeedbackResult {
  final String domain;
  final double scoreChange;
  final double newScore;
  final bool isFlagged;
  final String? flagReason;
  final ActivityModel? nextActivity;

  ProcessFeedbackResult({
    required this.domain,
    required this.scoreChange,
    required this.newScore,
    required this.isFlagged,
    this.flagReason,
    this.nextActivity,
  });
}

class AIService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Main AI entry point: processes parent feedback, updates skill profiles,
  /// checks struggle counts, auto-flags if needed, and recommends the next activity.
  Future<ProcessFeedbackResult> processFeedback({
    required String childId,
    required String activityId,
    required String childResponse,
    required String engagement,
    required String difficulty,
    required String confidence,
  }) async {
    // 1. Fetch Activity & Map Skill Domain
    String skillType = 'Cognitive';
    if (activityId.isNotEmpty) {
      try {
        final actDoc = await _firestore.collection('activities').doc(activityId).get();
        if (actDoc.exists && actDoc.data() != null) {
          skillType = actDoc.data()!['skillType'] ?? 'Cognitive';
        }
      } catch (_) {
        // Fallback to default domain
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

    // 3. Parallelize independent steps: update skill profile, check struggle count, & generate next activity
    final results = await Future.wait([
      _updateSkillProfile(childId, domain, scoreChange),
      _getStruggleCount(childId, domain),
      _generateNextActivity(
        childId: childId,
        domain: domain,
        currentActivityId: activityId,
        scoreChange: scoreChange,
      ),
    ]);

    final double newScore = results[0] as double;
    final int struggleCount = results[1] as int;
    final ActivityModel? nextActivity = results[2] as ActivityModel?;

    bool isFlagged = false;
    String? flagReason;

    if (struggleCount >= 3) {
      isFlagged = true;
      flagReason = await _flagChild(childId, domain, struggleCount);
    }

    return ProcessFeedbackResult(
      domain: domain,
      scoreChange: scoreChange,
      newScore: newScore,
      isFlagged: isFlagged,
      flagReason: flagReason,
      nextActivity: nextActivity,
    );
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

  /// Updates domain score in `skillProfiles` collection
  Future<double> _updateSkillProfile(String childId, String domain, double scoreChange) async {
    if (childId.isEmpty) return 50.0;

    try {
      final docRef = _firestore.collection('skillProfiles').doc(childId);
      final docSnap = await docRef.get();

      Map<String, dynamic> data = {};
      if (docSnap.exists && docSnap.data() != null) {
        data = docSnap.data()!;
      }

      double currentScore = (data[domain] as num?)?.toDouble() ?? 50.0;
      double updatedScore = (currentScore + scoreChange).clamp(0.0, 100.0);

      data[domain] = updatedScore;
      data['childId'] = childId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
      return updatedScore;
    } catch (_) {
      return 50.0;
    }
  }

  /// Counts struggles for a child in a specific domain from feedback history (Optimized parallel fetching)
  Future<int> _getStruggleCount(String childId, String domain) async {
    if (childId.isEmpty) return 0;

    try {
      final snapshot = await _firestore
          .collection('feedback')
          .where('childId', isEqualTo: childId)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      int struggles = 0;
      final List<String> actIds = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['childResponse'] == 'Struggled') {
          final actId = data['activityId'] as String?;
          if (actId != null && actId.isNotEmpty) {
            actIds.add(actId);
          } else {
            struggles++;
          }
        }
      }

      if (actIds.isNotEmpty) {
        final actFutures = actIds.take(10).map((id) => _firestore.collection('activities').doc(id).get());
        final actDocs = await Future.wait(actFutures);
        for (var actDoc in actDocs) {
          if (actDoc.exists && actDoc.data() != null) {
            final skillType = actDoc.data()!['skillType'] ?? 'Cognitive';
            if (_mapSkillToDomain(skillType) == domain) {
              struggles++;
            }
          } else {
            struggles++;
          }
        }
      }

      return struggles;
    } catch (_) {
      return 0;
    }
  }

  /// Flags a child for LLG review in Firestore
  Future<String> _flagChild(String childId, String domain, int struggleCount) async {
    if (childId.isEmpty) return 'Child flagged for LLG review due to struggles.';

    final domainName = domain[0].toUpperCase() + domain.substring(1);
    final reason = '3+ struggles ($struggleCount) in $domainName domain';

    try {
      await _firestore.collection('children').doc(childId).update({
        'isFlagged': true,
        'flagReason': reason,
        'flaggedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    return reason;
  }

  /// Selects next recommended activity (preset for Mini Project)
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
    } catch (_) {
      return null;
    }
  }
}
