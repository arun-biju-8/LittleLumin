// lib/services/reward_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RewardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Get Rewards for Child
  Future<Map<String, dynamic>> getRewards(String childId) async {
    try {
      final doc = await _firestore.collection('rewards').doc(childId).get();
      if (doc.exists) {
        return doc.data()!;
      }
      return {
        'stars': 0,
        'streak': 0,
        'badges': <String>[],
        'milestones': <String>[],
      };
    } catch (e) {
      return {
        'stars': 0,
        'streak': 0,
        'badges': <String>[],
        'milestones': <String>[],
      };
    }
  }

  // ✅ Add Stars
  Future<void> addStars(String childId, int stars) async {
    await _firestore.collection('rewards').doc(childId).set({
      'stars': FieldValue.increment(stars),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ✅ Update Streak
  Future<void> updateStreak(String childId, int streak) async {
    await _firestore.collection('rewards').doc(childId).set({
      'streak': streak,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ✅ Add Badge
  Future<void> addBadge(String childId, String badge) async {
    await _firestore.collection('rewards').doc(childId).set({
      'badges': FieldValue.arrayUnion([badge]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
