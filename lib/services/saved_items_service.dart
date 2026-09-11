import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_model.dart';

class SavedItemsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // ============ SAVE ACTIVITY ============
  Future<String?> saveActivity({
    required ActivityModel activity,
    required String childId,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not logged in');

      debugPrint('💾 Attempting to save activity...');
      debugPrint('   userId: $userId');
      debugPrint('   childId: $childId');
      debugPrint('   title: ${activity.title}');

      final docRef = await _firestore.collection('savedActivities').add({
        'userId': userId,
        'childId': childId,
        'title': activity.title,
        'shortDescription': activity.shortDescription,
        'instructions': activity.instructions,
        'learningGoals': activity.learningGoals,
        'materials': activity.materials,
        'duration': activity.duration,
        'skillType': activity.skillType,
        'difficulty': activity.difficulty,
        'ageGroup': activity.ageGroup,
        'isAIGenerated': true,
        'savedAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Save timed out'),
      );

      debugPrint('✅ Activity saved successfully: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error saving activity: ${e.code} - ${e.message}');
      throw Exception('Firestore error: ${e.code}');
    } catch (e) {
      debugPrint('❌ Save activity error: $e');
      throw Exception('Failed to save: $e');
    }
  }

  // ============ SAVE STORY ============
  Future<String?> saveStory({
    required Map<String, dynamic> story,
    required String childId,
  }) async {
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not logged in');

      debugPrint('💾 Attempting to save story...');
      debugPrint('   userId: $userId');
      debugPrint('   childId: $childId');
      debugPrint('   title: ${story['title']}');

      final docRef = await _firestore.collection('savedStories').add({
        'userId': userId,
        'childId': childId,
        'title': story['title'] ?? 'Untitled Story',
        'story': story['story'] ?? story['storyContent'] ?? '',
        'characters': story['characters'] ?? [],
        'moral': story['moral'] ?? story['moralLesson'] ?? '',
        'readingTime': story['readingTime'] ?? '5-7 minutes',
        'isAIGenerated': true,
        'savedAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Save timed out'),
      );

      debugPrint('✅ Story saved successfully: ${docRef.id}');
      return docRef.id;
    } on FirebaseException catch (e) {
      debugPrint('❌ Firebase error saving story: ${e.code} - ${e.message}');
      throw Exception('Firestore error: ${e.code}');
    } catch (e) {
      debugPrint('❌ Save story error: $e');
      throw Exception('Failed to save: $e');
    }
  }

  // ============ GET SAVED ACTIVITIES ============
  Stream<QuerySnapshot> getSavedActivities({String? childId}) {
    final userId = _userId;
    if (userId == null) return const Stream.empty();

    Query query = _firestore
        .collection('savedActivities')
        .where('userId', isEqualTo: userId);

    if (childId != null) {
      query = query.where('childId', isEqualTo: childId);
    }

    return query.orderBy('savedAt', descending: true).snapshots();
  }

  // ============ GET SAVED STORIES ============
  Stream<QuerySnapshot> getSavedStories({String? childId}) {
    final userId = _userId;
    if (userId == null) return const Stream.empty();

    Query query = _firestore
        .collection('savedStories')
        .where('userId', isEqualTo: userId);

    if (childId != null) {
      query = query.where('childId', isEqualTo: childId);
    }

    return query.orderBy('savedAt', descending: true).snapshots();
  }

  // ============ DELETE ============
  Future<bool> deleteSavedActivity(String id) async {
    try {
      await _firestore.collection('savedActivities').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  Future<bool> deleteSavedStory(String id) async {
    try {
      await _firestore.collection('savedStories').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }
}
