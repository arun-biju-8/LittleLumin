import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/services/score_ledger_service.dart';
import 'package:littlelumin/services/journey_service.dart';

void main() {
  group('Score Ledger Option C Rules & Journey Constants Tests', () {
    final ledgerService = ScoreLedgerService();

    test('Option C Weight Rules: Level 1 and 2 apply 1.0 to all sources', () {
      expect(ledgerService.getWeight('preset', 1), 1.0);
      expect(ledgerService.getWeight('ai_generated', 1), 1.0);
      expect(ledgerService.getWeight('llg_assigned', 1), 1.0);

      expect(ledgerService.getWeight('preset', 2), 1.0);
      expect(ledgerService.getWeight('ai_generated', 2), 1.0);
      expect(ledgerService.getWeight('llg_assigned', 2), 1.0);
    });

    test('Option C Weight Rules: Level 3 and 4 apply 0.5 to ai_generated, 1.0 to others', () {
      expect(ledgerService.getWeight('ai_generated', 3), 0.5);
      expect(ledgerService.getWeight('preset', 3), 1.0);
      expect(ledgerService.getWeight('llg_assigned', 3), 1.0);

      expect(ledgerService.getWeight('ai_generated', 4), 0.5);
      expect(ledgerService.getWeight('preset', 4), 1.0);
      expect(ledgerService.getWeight('llg_assigned', 4), 1.0);
    });

    test('Journey Constants: Passing score is 70, max level is 4, 6 domains', () {
      expect(JourneyService.PASSING_SCORE, 70);
      expect(JourneyService.MAX_LEVEL, 4);
      expect(JourneyService.DOMAINS, containsAll([
        'cognitive',
        'language',
        'motor',
        'social',
        'emotional',
        'creative',
      ]));
      expect(JourneyService.DOMAINS.length, 6);
    });
  });
}
