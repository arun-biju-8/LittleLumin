// lib/services/tip_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ Get tip of the day
  Future<String> getTipOfTheDay() async {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;

    final snapshot = await _firestore
        .collection('tips')
        .orderBy('createdAt')
        .limit(1)
        .startAfter([dayOfYear % await _getTipCount()])
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first['message'] ?? 'Every child develops at their own pace.';
    }

    // Fallback tips
    final fallbackTips = [
      'Encourage your child with specific praise like "I love how hard you tried!"',
      'Every child develops at their own pace. Celebrate small wins!',
      'Screen-free play builds creativity and problem-solving skills.',
      'Reading together for just 10 minutes a day builds language skills.',
      'Children learn best through play and exploration.',
    ];

    return fallbackTips[dayOfYear % fallbackTips.length];
  }

  Future<int> _getTipCount() async {
    final snapshot = await _firestore.collection('tips').get();
    return snapshot.docs.length;
  }
}