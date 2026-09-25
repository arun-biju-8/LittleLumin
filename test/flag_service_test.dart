import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/services/flag_service.dart';
import 'package:littlelumin/services/auto_generation_service.dart';

void main() {
  group('FlagService & Ethical Flag System Tests', () {
    final flagService = FlagService();
    final now = DateTime(2026, 9, 22, 10, 0, 0);

    Map<String, dynamic> makeEvent({
      required String response,
      String source = 'preset',
      required DateTime createdAt,
      String domain = 'cognitive',
      String title = 'Activity',
    }) {
      return {
        'skillDomain': domain,
        'activityTitle': title,
        'activitySource': source,
        'feedback': {'childResponse': response},
        'createdAt': createdAt,
      };
    }

    // 1. New child, 1 struggle -> Tier Watch
    test('1. New child, 1 struggle -> Tier Watch', () async {
      final events = [
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 1))),
      ];

      final decision = await flagService.evaluate(
        childId: 'c1',
        domain: 'cognitive',
        events: events,
        currentScore: 55.0,
        now: now,
      );

      expect(decision.tier, FlagTier.watch);
      expect(decision.canGenerateAI, isTrue);
    });

    // 2. Child with 6 activities, 4 struggles, score 35 -> check AI-gen eligibility (Tier Concern)
    test('2. Child with 6 activities, 4 struggles, score 35 -> Tier Concern (canGenerateAI: true)', () async {
      final events = [
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 1))),
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 2))),
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 3))),
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 4))),
        makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 5))),
        makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 6))),
      ];

      final decision = await flagService.evaluate(
        childId: 'c2',
        domain: 'cognitive',
        events: events,
        currentScore: 35.0,
        now: now,
      );

      // aiGenAttempts is 0 < AI_GEN_CAP (3) -> Tier Concern
      expect(decision.tier, FlagTier.concern);
      expect(decision.canGenerateAI, isTrue);
      expect(decision.aiGenAttempts, 0);
    });

    // 3. Child with 6 activities, 4 struggles, score 35, 3 AI attempts -> flagged
    test('3. Child with 6 activities, 4 struggles, score 35, 3 AI attempts -> Tier Flagged', () async {
      final events = [
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 1))),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 2))),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 3))),
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 4))),
        makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 5))),
        makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 6))),
      ];

      final decision = await flagService.evaluate(
        childId: 'c3',
        domain: 'cognitive',
        events: events,
        currentScore: 35.0,
        now: now,
      );

      expect(decision.tier, FlagTier.flagged);
      expect(decision.aiGenAttempts, 3);
      expect(decision.canGenerateAI, isFalse);
      expect(decision.confidence, greaterThanOrEqualTo(60.0));
    });

    // 4. Child with score >= 70 -> Tier On Track
    test('4. Child with score >= 70 -> Tier On Track', () async {
      final events = [
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 1))),
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 2))),
      ];

      final decision = await flagService.evaluate(
        childId: 'c4',
        domain: 'cognitive',
        events: events,
        currentScore: 75.0,
        now: now,
      );

      expect(decision.tier, FlagTier.onTrack);
    });

    // 5. Child with 2 "Great" responses -> confidence reduced
    test('5. Child with 2 "Great" responses -> confidence reduced', () {
      final confidenceStrugglesOnly = flagService.computeConfidence(
        activityCount: 6,
        struggleCount: 4,
        currentScore: 35.0,
        lastThree: [
          {'feedback': {'childResponse': 'Struggled'}},
          {'feedback': {'childResponse': 'Struggled'}},
          {'feedback': {'childResponse': 'Struggled'}},
        ],
        aiGenAttempts: 1,
      );

      final confidenceWithGreats = flagService.computeConfidence(
        activityCount: 6,
        struggleCount: 2,
        currentScore: 50.0,
        lastThree: [
          {'feedback': {'childResponse': 'Great'}},
          {'feedback': {'childResponse': 'Great'}},
          {'feedback': {'childResponse': 'Okay'}},
        ],
        aiGenAttempts: 1,
      );

      expect(confidenceWithGreats, lessThan(confidenceStrugglesOnly));
    });

    // 6. AI-gen cap reached -> no more generation (canGenerateAI: false)
    test('6. AI-gen cap reached -> canGenerateAI: false', () async {
      final events = [
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 1))),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 2))),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 3))),
      ];

      final decision = await flagService.evaluate(
        childId: 'c6',
        domain: 'cognitive',
        events: events,
        currentScore: 45.0,
        now: now,
      );

      expect(decision.aiGenAttempts, 3);
      expect(decision.canGenerateAI, isFalse);
    });

    // 7. "Great" response resets AI-gen window
    test('7. "Great" response resets AI-gen window', () async {
      final events = [
        // 2 AI attempts 10 and 12 days ago
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 12))),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 10))),
        // Then child scored "Great" 5 days ago!
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 5))),
        // Only 1 AI attempt after "Great"
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 2))),
      ];

      final decision = await flagService.evaluate(
        childId: 'c7',
        domain: 'cognitive',
        events: events,
        currentScore: 48.0,
        now: now,
      );

      // Attempts prior to the Great response are reset, only 1 attempt remains in the current window!
      expect(decision.aiGenAttempts, 1);
      expect(decision.canGenerateAI, isTrue);
    });

    // 8. Auto-unflag on score > 50
    test('8. Auto-unflag on score > 50', () async {
      final events = [
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 1))),
      ];

      final shouldUnflag = await flagService.shouldAutoUnflag(
        childId: 'c8',
        domain: 'cognitive',
        events: events,
        currentScore: 55.0,
      );

      expect(shouldUnflag, isTrue);
    });

    // 9. Auto-unflag on 3 consecutive Great
    test('9. Auto-unflag on 3 consecutive Great', () async {
      final events = [
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 1))),
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 2))),
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 3))),
      ];

      final shouldUnflag = await flagService.shouldAutoUnflag(
        childId: 'c9',
        domain: 'cognitive',
        events: events,
        currentScore: 45.0, // score < 50 but 3 consecutive Great
      );

      expect(shouldUnflag, isTrue);
    });

    // 10. Auto-unflag returns false when score <= 50 and last 3 not all Great
    test('10. Auto-unflag returns false when conditions not met', () async {
      final events = [
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 1))),
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 2))),
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 3))),
      ];

      final shouldUnflag = await flagService.shouldAutoUnflag(
        childId: 'c10',
        domain: 'cognitive',
        events: events,
        currentScore: 42.0,
      );

      expect(shouldUnflag, isFalse);
    });

    // 11. Re-flag requires higher confidence
    test('11. Re-flag requires higher confidence', () {
      final normalThreshold = flagService.computeAdaptiveThreshold(aiGenAttempts: 2, isReflag: false);
      final reflagThreshold = flagService.computeAdaptiveThreshold(aiGenAttempts: 2, isReflag: true);

      expect(normalThreshold, 65.0); // 75 - 10
      expect(reflagThreshold, 75.0); // 85 - 10
      expect(reflagThreshold, greaterThan(normalThreshold));
    });

    // 12. Confidence computation accuracy
    test('12. Confidence computation accuracy formula', () {
      // 4 struggles = 32, 6 activities = 12, score 35 = 5, all 3 struggles = 15, 3 AI attempts = 15 -> Total = 79
      final confidence = flagService.computeConfidence(
        activityCount: 6,
        struggleCount: 4,
        currentScore: 35.0,
        lastThree: [
          {'feedback': {'childResponse': 'Struggled'}},
          {'feedback': {'childResponse': 'Struggled'}},
          {'feedback': {'childResponse': 'Struggled'}},
        ],
        aiGenAttempts: 3,
      );

      expect(confidence, 79.0);
    });

    // 13. Multi-domain flagging
    test('13. Multi-domain flagging evaluates domains independently', () async {
      final cogEvents = [
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 1)), domain: 'cognitive'),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 2)), domain: 'cognitive'),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 3)), domain: 'cognitive'),
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 4)), domain: 'cognitive'),
        makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 5)), domain: 'cognitive'),
        makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 6)), domain: 'cognitive'),
      ];

      final motEvents = [
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 1)), domain: 'motor'),
        makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 2)), domain: 'motor'),
      ];

      final cogDecision = await flagService.evaluate(
        childId: 'c13',
        domain: 'cognitive',
        events: cogEvents,
        currentScore: 32.0,
        now: now,
      );

      final motDecision = await flagService.evaluate(
        childId: 'c13',
        domain: 'motor',
        events: motEvents,
        currentScore: 88.0,
        now: now,
      );

      expect(cogDecision.tier, FlagTier.flagged);
      expect(motDecision.tier, FlagTier.onTrack);
    });

    // 14. Cap reset after 14 days
    test('14. Cap reset after 14 days', () async {
      final events = [
        // 3 AI attempts 20, 22, 25 days ago (outside 14-day window)
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 25))),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 22))),
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 20))),
        // Only 1 attempt 2 days ago
        makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 2))),
      ];

      final decision = await flagService.evaluate(
        childId: 'c14',
        domain: 'cognitive',
        events: events,
        currentScore: 40.0,
        now: now,
      );

      expect(decision.aiGenAttempts, 1);
      expect(decision.canGenerateAI, isTrue);
    });

    // 15. Tier transitions Watch -> Concern -> Flag
    test('15. Tier transitions Watch -> Concern -> Flag', () async {
      // Step A: Watch (few events)
      final d1 = await flagService.evaluate(
        childId: 'c15',
        domain: 'language',
        events: [
          makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 1))),
          makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 2))),
        ],
        currentScore: 45.0,
        now: now,
      );
      expect(d1.tier, FlagTier.watch);

      // Step B: Concern (6 activities, 4 struggles, but attempts < 3)
      final d2 = await flagService.evaluate(
        childId: 'c15',
        domain: 'language',
        events: List.generate(6, (i) => makeEvent(
          response: i < 4 ? 'Struggled' : 'Okay',
          createdAt: now.subtract(Duration(days: i + 1)),
        )),
        currentScore: 35.0,
        now: now,
      );
      expect(d2.tier, FlagTier.concern);

      // Step C: Flag (3 AI attempts added)
      final d3 = await flagService.evaluate(
        childId: 'c15',
        domain: 'language',
        events: [
          makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 1))),
          makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 2))),
          makeEvent(response: 'Struggled', source: 'ai_generated', createdAt: now.subtract(const Duration(days: 3))),
          makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 4))),
          makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 5))),
          makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 6))),
        ],
        currentScore: 35.0,
        now: now,
      );
      expect(d3.tier, FlagTier.flagged);
    });

    // 16. Tier demotion Flag -> On Track
    test('16. Tier demotion Flag -> On Track when score reaches >= 70', () async {
      final decision = await flagService.evaluate(
        childId: 'c16',
        domain: 'cognitive',
        events: [
          makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 1))),
          makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 2))),
        ],
        currentScore: 72.0,
        now: now,
      );

      expect(decision.tier, FlagTier.onTrack);
    });

    // 17. Evidence completeness
    test('17. Evidence completeness contains all required metrics', () async {
      final decision = await flagService.evaluate(
        childId: 'c17',
        domain: 'social',
        events: [
          makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 1))),
          makeEvent(response: 'Great', createdAt: now.subtract(const Duration(days: 2))),
        ],
        currentScore: 60.0,
        now: now,
      );

      expect(decision.evidence.containsKey('activityCount'), isTrue);
      expect(decision.evidence.containsKey('struggleCount'), isTrue);
      expect(decision.evidence.containsKey('currentScore'), isTrue);
      expect(decision.evidence.containsKey('aiGenAttempts'), isTrue);
      expect(decision.evidence.containsKey('recentGreat'), isTrue);
      expect(decision.evidence.containsKey('lastThreeResponses'), isTrue);
      expect(decision.evidence.containsKey('confidence'), isTrue);
      expect(decision.evidence.containsKey('adaptiveThreshold'), isTrue);
    });

    // 18. Idempotency
    test('18. Idempotency: multiple evaluations on identical input produce identical FlagDecision', () async {
      final events = [
        makeEvent(response: 'Struggled', createdAt: now.subtract(const Duration(days: 1))),
        makeEvent(response: 'Okay', createdAt: now.subtract(const Duration(days: 2))),
      ];

      final d1 = await flagService.evaluate(
        childId: 'c18',
        domain: 'emotional',
        events: events,
        currentScore: 50.0,
        now: now,
      );

      final d2 = await flagService.evaluate(
        childId: 'c18',
        domain: 'emotional',
        events: events,
        currentScore: 50.0,
        now: now,
      );

      expect(d1.tier, d2.tier);
      expect(d1.confidence, d2.confidence);
      expect(d1.aiGenAttempts, d2.aiGenAttempts);
      expect(d1.canGenerateAI, d2.canGenerateAI);
    });

    // 19. Firestore guard rejects invalid domain
    test('19. Firestore guard rejects invalid domain', () {
      expect(
        () => FlagService.validateDomain('telepathy'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => FlagService.validateDomain('astrology'),
        throwsA(isA<ArgumentError>()),
      );

      expect(() => FlagService.validateDomain('cognitive'), returnsNormally);
      expect(() => FlagService.validateDomain('Language'), returnsNormally);
    });

    // 20. Persistent link text rotation
    test('20. Persistent link text rotates based on timing and response state', () {
      final t1 = FlagService.computeLinkText(
        flaggedAt: now.subtract(const Duration(days: 3)),
        parentResponse: 'pending',
        now: now,
      );
      expect(t1, 'Talk to a specialist anytime →');

      final t2 = FlagService.computeLinkText(
        flaggedAt: now.subtract(const Duration(days: 16)),
        parentResponse: 'pending',
        now: now,
      );
      expect(t2, 'Specialist support available →');

      final t3 = FlagService.computeLinkText(
        flaggedAt: now.subtract(const Duration(days: 2)),
        parentResponse: 'ignored',
        now: now,
      );
      expect(t3, 'Specialist support available →');

      final t4 = FlagService.computeLinkText(
        flaggedAt: now.subtract(const Duration(days: 9)),
        parentResponse: 'approved',
        now: now,
      );
      expect(t4, 'Need extra support? Talk to an expert →');
    });

    // 21. Difficulty trend computation
    test('21. AutoGenerationService computeNextDifficulty', () {
      final hardEvents = [
        {'feedback': {'childResponse': 'Great'}},
        {'feedback': {'childResponse': 'Great'}},
        {'feedback': {'childResponse': 'Okay'}},
      ];
      expect(AutoGenerationService.computeNextDifficulty(hardEvents), 'hard');

      final easyEvents = [
        {'feedback': {'childResponse': 'Struggled'}},
        {'feedback': {'childResponse': 'Struggled'}},
        {'feedback': {'childResponse': 'Okay'}},
      ];
      expect(AutoGenerationService.computeNextDifficulty(easyEvents), 'easy');

      final mediumEvents = [
        {'feedback': {'childResponse': 'Great'}},
        {'feedback': {'childResponse': 'Struggled'}},
        {'feedback': {'childResponse': 'Okay'}},
      ];
      expect(AutoGenerationService.computeNextDifficulty(mediumEvents), 'medium');
    });
  });
}
