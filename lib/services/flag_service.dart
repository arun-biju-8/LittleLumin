// ignore_for_file: constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum FlagTier { onTrack, watch, concern, flagged }

class FlagDecision {
  final FlagTier tier;
  final double confidence;
  final int aiGenAttempts;
  final bool canGenerateAI;
  final Map<String, dynamic> evidence;

  FlagDecision({
    required this.tier,
    required this.confidence,
    required this.aiGenAttempts,
    required this.canGenerateAI,
    required this.evidence,
  });
}

class FlagService {
  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;

  FlagService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  static const int AI_GEN_CAP = 3;
  static const int AI_GEN_WINDOW_DAYS = 14;
  static const int MIN_ACTIVITIES = 6;
  static const int MIN_STRUGGLES = 4;
  static const int RECENT_STRUGGLE_DAYS = 21;
  static const double SCORE_THRESHOLD_TIER2 = 40;
  static const double AUTO_UNFLAG_SCORE = 50;
  static const int AUTO_UNFLAG_GREAT_COUNT = 3;
  static const int AUTO_UNFLAG_DAYS = 30;

  static const List<String> VALID_DOMAINS = [
    'cognitive',
    'language',
    'motor',
    'social',
    'emotional',
    'creative',
  ];

  static void validateDomain(String domain) {
    if (!VALID_DOMAINS.contains(domain.trim().toLowerCase())) {
      throw ArgumentError('Invalid developmental domain: $domain. Must be one of $VALID_DOMAINS');
    }
  }

  static DateTime? _extractDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  // ============ PERSISTENT LINK TEXT ============
  static String computeLinkText({
    required DateTime? flaggedAt,
    required String? parentResponse,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final daysSinceFlag = flaggedAt != null ? currentTime.difference(flaggedAt).inDays : 0;

    if (parentResponse == 'ignored' || daysSinceFlag > 14) {
      return 'Specialist support available →';
    }
    if (parentResponse == 'pending' && daysSinceFlag < 7) {
      return 'Talk to a specialist anytime →';
    }
    return 'Need extra support? Talk to an expert →';
  }

  // ============ ADAPTIVE THRESHOLD ============
  double computeAdaptiveThreshold({
    required int aiGenAttempts,
    bool isReflag = false,
  }) {
    final base = isReflag ? 85.0 : 75.0;
    return base - (aiGenAttempts * 5.0);
  }

  // ============ CONFIDENCE CALCULATION ============
  double computeConfidence({
    required int activityCount,
    required int struggleCount,
    required double currentScore,
    required List<Map<String, dynamic>> lastThree,
    required int aiGenAttempts,
  }) {
    double score = 0;
    // More struggles = higher confidence (+8 per struggle)
    score += struggleCount * 8;
    // More data = higher confidence (+2 per activity up to 10)
    score += (activityCount.clamp(0, 10)) * 2;
    // Lower score = higher confidence
    if (currentScore < 40) score += (40 - currentScore);
    // Last 3 all struggles = higher confidence
    final allStruggled = lastThree.isNotEmpty &&
        lastThree.every((e) => e['feedback']?['childResponse'] == 'Struggled');
    if (allStruggled) score += 15;
    // More AI attempts = higher confidence (we tried)
    score += aiGenAttempts * 5;
    return score.clamp(0.0, 100.0);
  }

  // ============ MAIN DECISION ============
  Future<FlagDecision> evaluate({
    required String childId,
    required String domain,
    required List<Map<String, dynamic>> events,
    required double currentScore,
    bool isReflag = false,
    DateTime? now,
  }) async {
    validateDomain(domain);

    final currentTime = now ?? DateTime.now();
    final sortedEvents = List<Map<String, dynamic>>.from(events);
    // Sort descending by createdAt
    sortedEvents.sort((a, b) {
      final dtA = _extractDateTime(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dtB = _extractDateTime(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dtB.compareTo(dtA);
    });

    final activityCount = sortedEvents.length;
    final struggleCount = sortedEvents.where((e) => e['feedback']?['childResponse'] == 'Struggled').length;
    final lastThree = sortedEvents.take(3).toList();

    // Check "Great" response reset within 7 days
    DateTime? mostRecentGreatDate;
    for (var e in sortedEvents) {
      if (e['feedback']?['childResponse'] == 'Great') {
        final dt = _extractDateTime(e['createdAt']);
        if (dt != null) {
          if (mostRecentGreatDate == null || dt.isAfter(mostRecentGreatDate)) {
            mostRecentGreatDate = dt;
          }
        }
      }
    }

    final recentGreat = mostRecentGreatDate != null &&
        mostRecentGreatDate.isAfter(currentTime.subtract(const Duration(days: 7)));

    // AI-gen attempts in 14-day window (reset by most recent Great response)
    DateTime effectiveWindowStart = currentTime.subtract(const Duration(days: AI_GEN_WINDOW_DAYS));
    if (mostRecentGreatDate != null && mostRecentGreatDate.isAfter(effectiveWindowStart)) {
      effectiveWindowStart = mostRecentGreatDate;
    }

    final aiGenAttempts = sortedEvents.where((e) {
      final dt = _extractDateTime(e['createdAt']);
      if (dt == null || dt.isBefore(effectiveWindowStart)) return false;
      return e['activitySource'] == 'ai_generated';
    }).length;

    // Compute adaptive threshold
    final adaptiveThreshold = computeAdaptiveThreshold(
      aiGenAttempts: aiGenAttempts,
      isReflag: isReflag,
    );

    // Compute confidence
    final confidence = computeConfidence(
      activityCount: activityCount,
      struggleCount: struggleCount,
      currentScore: currentScore,
      lastThree: lastThree,
      aiGenAttempts: aiGenAttempts,
    );

    // Determine tier
    FlagTier tier;
    if (currentScore >= 70) {
      tier = FlagTier.onTrack;
    } else if (activityCount < MIN_ACTIVITIES || struggleCount < MIN_STRUGGLES) {
      tier = FlagTier.watch;
    } else if (aiGenAttempts < AI_GEN_CAP) {
      tier = FlagTier.concern; // Keep trying AI gen
    } else if (confidence >= adaptiveThreshold) {
      tier = FlagTier.flagged;
    } else {
      tier = FlagTier.concern;
    }

    return FlagDecision(
      tier: tier,
      confidence: confidence,
      aiGenAttempts: aiGenAttempts,
      canGenerateAI: aiGenAttempts < AI_GEN_CAP,
      evidence: {
        'activityCount': activityCount,
        'struggleCount': struggleCount,
        'currentScore': currentScore,
        'aiGenAttempts': aiGenAttempts,
        'recentGreat': recentGreat,
        'lastThreeResponses': lastThree.map((e) => e['feedback']?['childResponse'] ?? 'Okay').toList(),
        'confidence': confidence,
        'adaptiveThreshold': adaptiveThreshold,
        'isReflag': isReflag,
      },
    );
  }

  // ============ WRITE FLAG STATE ============
  Future<void> writeFlagState({
    required String childId,
    required String domain,
    required FlagDecision decision,
  }) async {
    validateDomain(domain);
    final normDomain = domain.trim().toLowerCase();

    try {
      final ref = _firestore.collection('flagState').doc(childId);
      final doc = await ref.get();
      final data = doc.data() ?? {'childId': childId, 'domains': {}};
      final domains = Map<String, dynamic>.from(data['domains'] ?? {});
      final existingDomain = domains[normDomain] as Map<String, dynamic>?;

      final existingParentResponse = existingDomain?['parentResponse'] ?? 'pending';
      final existingLLGNotifiedAt = existingDomain?['llgNotifiedAt'];

      final newDomainState = <String, dynamic>{
        'tier': decision.tier.index,
        'confidence': decision.confidence,
        'flaggedAt': decision.tier == FlagTier.flagged
            ? (existingDomain?['flaggedAt'] ?? FieldValue.serverTimestamp())
            : null,
        'aiGenAttempts': decision.aiGenAttempts,
        'parentNotifiedAt': decision.tier == FlagTier.flagged
            ? (existingDomain?['parentNotifiedAt'] ?? FieldValue.serverTimestamp())
            : null,
        'parentResponse': existingParentResponse,
        'llgNotifiedAt': existingLLGNotifiedAt,
        'evidence': decision.evidence,
        'resolvedAt': decision.tier == FlagTier.onTrack ? FieldValue.serverTimestamp() : existingDomain?['resolvedAt'],
      };

      domains[normDomain] = newDomainState;
      data['domains'] = domains;
      data['updatedAt'] = FieldValue.serverTimestamp();

      final hasApproved = domains.values.any((d) => d is Map && d['parentResponse'] == 'approved');
      data['hasApprovedFlag'] = hasApproved;

      await ref.set(data, SetOptions(merge: true));

      // Synchronize with children collection (isFlagged)
      final anyFlagged = domains.values.any((d) => d is Map && d['tier'] == FlagTier.flagged.index);
      if (anyFlagged) {
        await _firestore.collection('children').doc(childId).update({
          'isFlagged': true,
          'flagReason': 'Personalized specialist support recommended in ${normDomain[0].toUpperCase()}${normDomain.substring(1)}',
          'flaggedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Also write immutable audit when flagged
      if (decision.tier == FlagTier.flagged) {
        await _firestore.collection('flags').add({
          'childId': childId,
          'domain': normDomain,
          'tier': decision.tier.index,
          'confidence': decision.confidence,
          'flaggedAt': FieldValue.serverTimestamp(),
          'parentNotifiedAt': FieldValue.serverTimestamp(),
          'parentResponse': existingParentResponse,
          'llgNotifiedAt': existingLLGNotifiedAt,
          'evidence': decision.evidence,
          'isImmutable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e, stack) {
      debugPrint('⚠️ Error writing flagState: $e\n$stack');
    }
  }

  // ============ PARENT ACTIONS ============
  Future<void> parentApproved(String childId, String domain) async {
    validateDomain(domain);
    final normDomain = domain.trim().toLowerCase();

    final ref = _firestore.collection('flagState').doc(childId);
    await ref.update({
      'domains.$normDomain.parentResponse': 'approved',
      'domains.$normDomain.parentRespondedAt': FieldValue.serverTimestamp(),
      'domains.$normDomain.llgNotifiedAt': FieldValue.serverTimestamp(),
      'hasApprovedFlag': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write immutable audit trail
    await _firestore.collection('flags').add({
      'childId': childId,
      'domain': normDomain,
      'parentResponse': 'approved',
      'parentRespondedAt': FieldValue.serverTimestamp(),
      'llgNotifiedAt': FieldValue.serverTimestamp(),
      'isImmutable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> parentDeclined(String childId, String domain) async {
    validateDomain(domain);
    final normDomain = domain.trim().toLowerCase();

    final ref = _firestore.collection('flagState').doc(childId);
    await ref.update({
      'domains.$normDomain.parentResponse': 'declined',
      'domains.$normDomain.parentRespondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write immutable audit trail
    await _firestore.collection('flags').add({
      'childId': childId,
      'domain': normDomain,
      'parentResponse': 'declined',
      'parentRespondedAt': FieldValue.serverTimestamp(),
      'isImmutable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ============ AUTO-UNFLAG CHECK ============
  Future<bool> shouldAutoUnflag({
    required String childId,
    required String domain,
    required List<Map<String, dynamic>> events,
    required double currentScore,
  }) async {
    validateDomain(domain);

    if (currentScore > AUTO_UNFLAG_SCORE) return true;

    final sortedEvents = List<Map<String, dynamic>>.from(events);
    sortedEvents.sort((a, b) {
      final dtA = _extractDateTime(a['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dtB = _extractDateTime(b['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dtB.compareTo(dtA);
    });

    final lastThree = sortedEvents.take(3).toList();
    if (lastThree.length >= AUTO_UNFLAG_GREAT_COUNT &&
        lastThree.every((e) => e['feedback']?['childResponse'] == 'Great')) {
      return true;
    }
    return false;
  }

  // ============ RESOLVE AUTO-UNFLAG ============
  Future<void> resolveAutoUnflag({
    required String childId,
    required String domain,
  }) async {
    validateDomain(domain);
    final normDomain = domain.trim().toLowerCase();

    try {
      final ref = _firestore.collection('flagState').doc(childId);
      await ref.update({
        'domains.$normDomain.tier': FlagTier.onTrack.index,
        'domains.$normDomain.resolvedAt': FieldValue.serverTimestamp(),
        'domains.$normDomain.parentResponse': 'resolved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write immutable audit trail
      await _firestore.collection('flags').add({
        'childId': childId,
        'domain': normDomain,
        'tier': FlagTier.onTrack.index,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolution': 'auto_recovered',
        'isImmutable': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Check if any other domains are still flagged; if none, clear child.isFlagged
      final doc = await ref.get();
      final domains = doc.data()?['domains'] as Map<String, dynamic>? ?? {};
      final anyStillFlagged = domains.values.any((d) => d is Map && d['tier'] == FlagTier.flagged.index);
      if (!anyStillFlagged) {
        await _firestore.collection('children').doc(childId).update({
          'isFlagged': false,
          'flagReason': null,
          'unflaggedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Placeholder for parent success message — update later after specialist consultation
      debugPrint('🎉 Flag resolved for $normDomain');
    } catch (e, stack) {
      debugPrint('⚠️ Error resolving auto-unflag: $e\n$stack');
    }
  }
}
