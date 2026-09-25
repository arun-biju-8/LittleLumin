import 'package:cloud_firestore/cloud_firestore.dart';
import 'activity_state_service.dart';

class ReminderService {
  // Escalating intervals
  static const List<Duration> reminderIntervals = [
    Duration(hours: 5),   // First reminder
    Duration(hours: 12),  // Second reminder
    Duration(hours: 24),  // Third reminder
  ];

  final ActivityStateService _activityStateService;

  ReminderService({ActivityStateService? activityStateService})
      : _activityStateService = activityStateService ?? ActivityStateService();

  /// Called when app opens
  /// Returns a reminder message if needed, or null
  Future<String?> checkReminder(String childId, String childName, {DateTime? nowOverride}) async {
    final active = await _activityStateService.getActiveActivity(childId);
    if (active == null) return null;
    if (active['status'] == 'completed') return null;

    final startedAtRaw = active['startedAt'];
    DateTime startedAt;
    if (startedAtRaw is Timestamp) {
      startedAt = startedAtRaw.toDate();
    } else if (startedAtRaw is DateTime) {
      startedAt = startedAtRaw;
    } else if (startedAtRaw is String) {
      startedAt = DateTime.tryParse(startedAtRaw) ?? DateTime.now();
    } else {
      return null;
    }

    final lastReminderRaw = active['lastReminderAt'];
    DateTime? lastReminder;
    if (lastReminderRaw is Timestamp) {
      lastReminder = lastReminderRaw.toDate();
    } else if (lastReminderRaw is DateTime) {
      lastReminder = lastReminderRaw;
    } else if (lastReminderRaw is String) {
      lastReminder = DateTime.tryParse(lastReminderRaw);
    }

    final reminderCount = active['reminderCount'] as int? ?? 0;
    if (reminderCount >= reminderIntervals.length) return null;

    final now = nowOverride ?? DateTime.now();
    final sinceStart = now.difference(startedAt);
    final sinceLastReminder = lastReminder == null ? sinceStart : now.difference(lastReminder);

    // Check if enough time has passed since last reminder
    if (reminderCount == 0 && sinceStart >= reminderIntervals[0]) {
      return "Hey! Have you completed \"${active['activityTitle']}\" with $childName?";
    }
    if (reminderCount == 1 && sinceLastReminder >= const Duration(hours: 7)) {
      return "$childName is waiting to continue \"${active['activityTitle']}\" 🌟";
    }
    if (reminderCount == 2 && sinceLastReminder >= const Duration(hours: 12)) {
      return "Still working on \"${active['activityTitle']}\"? Complete it or start a new one.";
    }
    return null;
  }
}
