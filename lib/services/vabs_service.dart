// lib/services/vabs_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vabs_question.dart';

class VABSResult {
  final Map<String, double> domainScores; // normalized 0-100
  final bool isFlagged;
  final String? flagReason;

  VABSResult({
    required this.domainScores,
    required this.isFlagged,
    this.flagReason,
  });
}

class VABSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit VABS-II answers, calculate normalized scores (0-100), update skillProfiles,
  /// check for auto-flagging on low scores (<40), and update child document.
  Future<VABSResult> submitSurvey({
    required String childId,
    required Map<String, int> answers, // questionId -> selected score (0-3)
  }) async {
    try {
      final List<VABSQuestion> questions = VABSQuestion.defaultQuestions;

      // 1. Group earned scores and max possible per domain
      final Map<String, int> earnedPerDomain = {};
      final Map<String, int> maxPerDomain = {};

      for (final q in questions) {
        final score = answers[q.id] ?? 0;
        earnedPerDomain[q.domain] = (earnedPerDomain[q.domain] ?? 0) + score;
        maxPerDomain[q.domain] = (maxPerDomain[q.domain] ?? 0) + 3; // max score 3
      }

      // 2. Normalize domain scores to 0-100 scale
      final Map<String, double> normalizedScores = {};
      bool isFlagged = false;
      List<String> lowScoreDomains = [];

      earnedPerDomain.forEach((domain, earned) {
        final maxPoss = maxPerDomain[domain] ?? 12;
        final double scorePercent = maxPoss > 0 ? (earned / maxPoss * 100.0) : 0.0;
        normalizedScores[domain] = double.parse(scorePercent.toStringAsFixed(1));

        if (scorePercent < 40.0) {
          isFlagged = true;
          lowScoreDomains.add(VABSDomain.getDisplayName(domain));
        }
      });

      String? flagReason;
      if (isFlagged && lowScoreDomains.isNotEmpty) {
        flagReason = 'Low VABS-II score (<40) in ${lowScoreDomains.join(', ')}';
      }

      // 3. Update skillProfiles document in Firestore
      await _updateSkillProfile(childId, normalizedScores);

      // 4. Update child document in Firestore with VABS results
      final Map<String, dynamic> childUpdate = {
        'vabsCompleted': true,
        'vabsSkipped': false,
        'vabsCompletedAt': FieldValue.serverTimestamp(),
        'vabsScores': normalizedScores,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isFlagged) {
        childUpdate['isFlagged'] = true;
        childUpdate['flagReason'] = flagReason;
        childUpdate['flaggedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('children').doc(childId).update(childUpdate);

      return VABSResult(
        domainScores: normalizedScores,
        isFlagged: isFlagged,
        flagReason: flagReason,
      );
    } catch (e) {
      debugPrint('Error submitting VABS survey: $e');
      rethrow;
    }
  }

  /// Updates the `skillProfiles` collection with normalized VABS domain scores
  Future<void> _updateSkillProfile(String childId, Map<String, double> vabsScores) async {
    if (childId.isEmpty) return;

    try {
      final docRef = _firestore.collection('skillProfiles').doc(childId);
      final docSnap = await docRef.get();

      Map<String, dynamic> data = {};
      if (docSnap.exists && docSnap.data() != null) {
        data = docSnap.data()!;
      }

      // Map VABS domains to canonical skill profile keys
      final commScore = vabsScores[VABSDomain.communication] ?? 50.0;
      final dailyScore = vabsScores[VABSDomain.dailyLiving] ?? 50.0;
      final socialScore = vabsScores[VABSDomain.socialization] ?? 50.0;
      final motorScore = vabsScores[VABSDomain.motor] ?? 50.0;

      data['language'] = commScore;
      data['cognitive'] = double.parse(((commScore + dailyScore) / 2.0).toStringAsFixed(1));
      data['social'] = socialScore;
      data['emotional'] = socialScore;
      data['motor'] = motorScore;
      data['creative'] = dailyScore;
      data['childId'] = childId;
      data['vabsScores'] = vabsScores;
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating skill profile from VABS: $e');
    }
  }

  /// Permanently skips the VABS survey for a child
  Future<void> skipSurvey(String childId) async {
    if (childId.isEmpty) return;

    try {
      await _firestore.collection('children').doc(childId).update({
        'vabsSkipped': true,
        'vabsCompleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error skipping VABS survey: $e');
    }
  }
}
