// lib/services/activity_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/activity_model.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Create Activity (Admin/LLG only)
  Future<String?> createActivity(ActivityModel activity) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not logged in';

      final docRef = await _firestore.collection('activities').add({
        ...activity.toMap(),
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return docRef.id; // Success
    } catch (e) {
      return 'Failed to create activity: $e';
    }
  }

  // ✅ Get All Activities (Admin only)
  Stream<List<ActivityModel>> getAllActivities() {
    return _firestore
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // ✅ Get Active Activities (For Parents)
  Stream<List<ActivityModel>> getActiveActivities({int? ageGroup}) {
    var query = _firestore
        .collection('activities')
        .where('isActive', isEqualTo: true);

    if (ageGroup != null) {
      query = query.where('ageGroup', isEqualTo: ageGroup);
    }

    return query.limit(10).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // ✅ Get Activity by ID
  Future<ActivityModel?> getActivity(String id) async {
    try {
      final doc = await _firestore.collection('activities').doc(id).get();
      if (doc.exists) {
        return ActivityModel.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ Update Activity (Admin/LLG only)
  Future<String?> updateActivity(String id, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not logged in';

      await _firestore.collection('activities').doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null; // Success
    } catch (e) {
      return 'Failed to update activity: $e';
    }
  }

  // ✅ Delete Activity (Admin only)
  Future<String?> deleteActivity(String id) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not logged in';

      await _firestore.collection('activities').doc(id).delete();
      return null; // Success
    } catch (e) {
      return 'Failed to delete activity: $e';
    }
  }
}