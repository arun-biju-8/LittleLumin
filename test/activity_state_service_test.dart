import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/services/activity_state_service.dart';
import 'package:littlelumin/services/reminder_service.dart';

void main() {
  group('ActivityStateService Tests', () {
    late Map<String, Map<String, dynamic>> inMemoryStore;
    late ActivityStateService service;

    setUp(() {
      inMemoryStore = {};
      service = ActivityStateService(inMemoryStore: inMemoryStore);
    });

    test('startActivity creates doc', () async {
      await service.startActivity(
        childId: 'c1',
        activityId: 'act_101',
        activityTitle: 'Shape Hunt',
        skillDomain: 'Cognitive',
      );

      final active = await service.getActiveActivity('c1');
      expect(active, isNotNull);
      expect(active!['childId'], 'c1');
      expect(active['activityId'], 'act_101');
      expect(active['activityTitle'], 'Shape Hunt');
      expect(active['skillDomain'], 'cognitive');
      expect(active['status'], 'in_progress');
      expect(active['reminderCount'], 0);
    });

    test('markCompleted updates status', () async {
      await service.startActivity(
        childId: 'c1',
        activityId: 'act_101',
        activityTitle: 'Shape Hunt',
        skillDomain: 'Cognitive',
      );

      await service.markCompleted('c1');

      final active = await service.getActiveActivity('c1');
      expect(active, isNotNull);
      expect(active!['status'], 'completed_pending_feedback');
      expect(active['completedAt'], isNotNull);
    });

    test('markFeedbackSubmitted updates status', () async {
      await service.startActivity(
        childId: 'c1',
        activityId: 'act_101',
        activityTitle: 'Shape Hunt',
        skillDomain: 'Cognitive',
      );

      await service.markCompleted('c1');
      await service.markFeedbackSubmitted('c1');

      final active = await service.getActiveActivity('c1');
      expect(active, isNotNull);
      expect(active!['status'], 'completed');
    });

    test('getActiveActivity returns null if none', () async {
      final active = await service.getActiveActivity('non_existent');
      expect(active, isNull);
    });

    test('discardActivity removes doc', () async {
      await service.startActivity(
        childId: 'c1',
        activityId: 'act_101',
        activityTitle: 'Shape Hunt',
        skillDomain: 'Cognitive',
      );

      await service.discardActivity('c1');
      final active = await service.getActiveActivity('c1');
      expect(active, isNull);
    });

    test('shouldRemind returns false if < 5h', () async {
      final now = DateTime(2026, 9, 23, 12, 0, 0);
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Shape Hunt',
        'skillDomain': 'cognitive',
        'status': 'in_progress',
        'startedAt': now.subtract(const Duration(hours: 4)),
        'lastReminderAt': null,
        'reminderCount': 0,
      };

      final remind = await service.shouldRemind('c1', nowOverride: now);
      expect(remind, isFalse);
    });

    test('shouldRemind returns true after 5h', () async {
      final now = DateTime(2026, 9, 23, 12, 0, 0);
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Shape Hunt',
        'skillDomain': 'cognitive',
        'status': 'in_progress',
        'startedAt': now.subtract(const Duration(hours: 5, minutes: 1)),
        'lastReminderAt': null,
        'reminderCount': 0,
      };

      final remind = await service.shouldRemind('c1', nowOverride: now);
      expect(remind, isTrue);
    });

    test('shouldRemind escalates properly', () async {
      final now = DateTime(2026, 9, 23, 12, 0, 0);
      // Escalation 1: count is 1, last reminder was 3 hours ago (< 7h) -> false
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Shape Hunt',
        'skillDomain': 'cognitive',
        'status': 'in_progress',
        'startedAt': now.subtract(const Duration(hours: 8)),
        'lastReminderAt': now.subtract(const Duration(hours: 3)),
        'reminderCount': 1,
      };

      expect(await service.shouldRemind('c1', nowOverride: now), isFalse);

      // Escalation 1: count is 1, last reminder was 7.5 hours ago (>= 7h) -> true
      inMemoryStore['c1']!['lastReminderAt'] = now.subtract(const Duration(hours: 7, minutes: 30));
      expect(await service.shouldRemind('c1', nowOverride: now), isTrue);

      // Escalation 2: count is 2, last reminder was 13 hours ago (>= 12h) -> true
      inMemoryStore['c1']!['reminderCount'] = 2;
      inMemoryStore['c1']!['lastReminderAt'] = now.subtract(const Duration(hours: 13));
      expect(await service.shouldRemind('c1', nowOverride: now), isTrue);

      // Max reached: count is 3 -> false
      inMemoryStore['c1']!['reminderCount'] = 3;
      expect(await service.shouldRemind('c1', nowOverride: now), isFalse);
    });

    test('recordReminder increments count', () async {
      final now = DateTime(2026, 9, 23, 12, 0, 0);
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Shape Hunt',
        'skillDomain': 'cognitive',
        'status': 'in_progress',
        'startedAt': now.subtract(const Duration(hours: 5)),
        'lastReminderAt': null,
        'reminderCount': 0,
      };

      await service.recordReminder('c1', nowOverride: now);
      final active = await service.getActiveActivity('c1');
      expect(active!['reminderCount'], 1);
      expect(active['lastReminderAt'], now);

      await service.recordReminder('c1', nowOverride: now);
      final active2 = await service.getActiveActivity('c1');
      expect(active2!['reminderCount'], 2);
    });
  });

  group('ReminderService Tests', () {
    late Map<String, Map<String, dynamic>> inMemoryStore;
    late ActivityStateService stateService;
    late ReminderService reminderService;

    setUp(() {
      inMemoryStore = {};
      stateService = ActivityStateService(inMemoryStore: inMemoryStore);
      reminderService = ReminderService(activityStateService: stateService);
    });

    test('checkReminder returns escalating messages correctly', () async {
      final now = DateTime(2026, 9, 23, 12, 0, 0);

      // No active activity -> null
      expect(await reminderService.checkReminder('c1', 'Leo', nowOverride: now), isNull);

      // Count 0: >= 5 hours
      inMemoryStore['c1'] = {
        'childId': 'c1',
        'activityId': 'act_101',
        'activityTitle': 'Shape Hunt',
        'skillDomain': 'cognitive',
        'status': 'in_progress',
        'startedAt': now.subtract(const Duration(hours: 5, minutes: 30)),
        'lastReminderAt': null,
        'reminderCount': 0,
      };

      final msg1 = await reminderService.checkReminder('c1', 'Leo', nowOverride: now);
      expect(msg1, contains('Have you completed "Shape Hunt" with Leo?'));

      // Count 1: >= 7h since last reminder
      inMemoryStore['c1']!['reminderCount'] = 1;
      inMemoryStore['c1']!['lastReminderAt'] = now.subtract(const Duration(hours: 8));
      final msg2 = await reminderService.checkReminder('c1', 'Leo', nowOverride: now);
      expect(msg2, contains('Leo is waiting to continue "Shape Hunt" 🌟'));

      // Count 2: >= 12h since last reminder
      inMemoryStore['c1']!['reminderCount'] = 2;
      inMemoryStore['c1']!['lastReminderAt'] = now.subtract(const Duration(hours: 13));
      final msg3 = await reminderService.checkReminder('c1', 'Leo', nowOverride: now);
      expect(msg3, contains('Still working on "Shape Hunt"?'));

      // Count 3 -> null
      inMemoryStore['c1']!['reminderCount'] = 3;
      expect(await reminderService.checkReminder('c1', 'Leo', nowOverride: now), isNull);
    });
  });
}
