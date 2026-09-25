import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ActivityStateService {
  final FirebaseFirestore? firestore;
  final Map<String, Map<String, dynamic>>? inMemoryStore;
  final Map<String, StreamController<DocumentSnapshot<Map<String, dynamic>>>> _streamControllers = {};

  ActivityStateService({
    this.firestore,
    @visibleForTesting this.inMemoryStore,
  });

  CollectionReference<Map<String, dynamic>> get _collection =>
      (firestore ?? FirebaseFirestore.instance).collection('activeActivities');

  /// Called when parent taps "Start Activity"
  Future<void> startActivity({
    required String childId,
    required String activityId,
    required String activityTitle,
    required String skillDomain,
  }) async {
    final now = DateTime.now();
    final store = inMemoryStore;
    final data = <String, dynamic>{
      'childId': childId,
      'activityId': activityId,
      'activityTitle': activityTitle,
      'skillDomain': skillDomain.trim().toLowerCase(),
      'status': 'in_progress',
      'startedAt': store != null ? now : FieldValue.serverTimestamp(),
      'completedAt': null,
      'lastReminderAt': null,
      'reminderCount': 0,
      'updatedAt': store != null ? now : FieldValue.serverTimestamp(),
    };

    if (store != null) {
      store[childId] = Map<String, dynamic>.from(data);
      _notifyStream(childId);
      return;
    }

    await _collection.doc(childId).set(data);
  }

  /// Called when parent taps "Mark as Completed"
  Future<void> markCompleted(String childId) async {
    final now = DateTime.now();
    final store = inMemoryStore;
    if (store != null) {
      final active = store[childId];
      if (active != null) {
        active['status'] = 'completed_pending_feedback';
        active['completedAt'] = now;
        active['updatedAt'] = now;
        _notifyStream(childId);
      }
      return;
    }

    await _collection.doc(childId).update({
      'status': 'completed_pending_feedback',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Called when parent submits feedback
  Future<void> markFeedbackSubmitted(String childId) async {
    final now = DateTime.now();
    final store = inMemoryStore;
    if (store != null) {
      final active = store[childId];
      if (active != null) {
        active['status'] = 'completed';
        active['updatedAt'] = now;
        _notifyStream(childId);
      }
      return;
    }

    await _collection.doc(childId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get current active activity for a child
  Future<Map<String, dynamic>?> getActiveActivity(String childId) async {
    final store = inMemoryStore;
    if (store != null) {
      final active = store[childId];
      if (active == null) return null;
      return Map<String, dynamic>.from(active);
    }

    final doc = await _collection.doc(childId).get();
    if (!doc.exists || doc.data() == null) return null;
    return doc.data();
  }

  /// Stream of active activity
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchActiveActivity(String childId) {
    final store = inMemoryStore;
    if (store != null) {
      final controller = _streamControllers.putIfAbsent(
        childId,
        () => StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast(),
      );
      return Stream.multi((sink) {
        sink.add(_FakeDocumentSnapshot<Map<String, dynamic>>(childId, store[childId]));
        final sub = controller.stream.listen(sink.add, onError: sink.addError, onDone: sink.close);
        sink.onCancel = () => sub.cancel();
      });
    }

    return _collection.doc(childId).snapshots();
  }

  void _notifyStream(String childId) {
    if (_streamControllers.containsKey(childId)) {
      final data = inMemoryStore?[childId];
      final controller = _streamControllers[childId]!;
      if (!controller.isClosed) {
        controller.add(_FakeDocumentSnapshot<Map<String, dynamic>>(childId, data));
      }
    }
  }

  /// Discard the active activity
  Future<void> discardActivity(String childId) async {
    final store = inMemoryStore;
    if (store != null) {
      store.remove(childId);
      _notifyStream(childId);
      return;
    }

    await _collection.doc(childId).delete();
  }

  /// Check if reminder is needed (5h, 12h, 24h escalation)
  Future<bool> shouldRemind(String childId, {DateTime? nowOverride}) async {
    final active = await getActiveActivity(childId);
    if (active == null) return false;
    if (active['status'] == 'completed') return false;

    final startedAtRaw = active['startedAt'];
    DateTime startedAt;
    if (startedAtRaw is Timestamp) {
      startedAt = startedAtRaw.toDate();
    } else if (startedAtRaw is DateTime) {
      startedAt = startedAtRaw;
    } else if (startedAtRaw is String) {
      startedAt = DateTime.tryParse(startedAtRaw) ?? DateTime.now();
    } else {
      return false;
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
    if (reminderCount >= 3) return false;

    final now = nowOverride ?? DateTime.now();
    final sinceStart = now.difference(startedAt);
    final sinceLastReminder = lastReminder == null ? sinceStart : now.difference(lastReminder);

    if (reminderCount == 0) {
      return sinceStart >= const Duration(hours: 5);
    } else if (reminderCount == 1) {
      return sinceLastReminder >= const Duration(hours: 7);
    } else if (reminderCount == 2) {
      return sinceLastReminder >= const Duration(hours: 12);
    }

    return false;
  }

  /// Update last reminder timestamp
  Future<void> recordReminder(String childId, {DateTime? nowOverride}) async {
    final now = nowOverride ?? DateTime.now();
    final store = inMemoryStore;
    if (store != null) {
      final active = store[childId];
      if (active != null) {
        final currentCount = active['reminderCount'] as int? ?? 0;
        active['reminderCount'] = currentCount + 1;
        active['lastReminderAt'] = now;
        active['updatedAt'] = now;
        _notifyStream(childId);
      }
      return;
    }

    await _collection.doc(childId).update({
      'lastReminderAt': FieldValue.serverTimestamp(),
      'reminderCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot<T> implements DocumentSnapshot<T> {
  final T? _data;
  final String _id;
  _FakeDocumentSnapshot(this._id, this._data);

  @override
  T? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  String get id => _id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

