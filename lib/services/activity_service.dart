// lib/services/activity_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';

class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'activities';

  // 1. Get all activities (Stream)
  Stream<List<ActivityModel>> getAllActivities() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // 2. Get activities created by a specific LLG
  Stream<List<ActivityModel>> getActivitiesByLLG(String llgId) {
    return _firestore
        .collection(_collection)
        .where('createdBy', isEqualTo: llgId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // 3. Get preset activities
  Stream<List<ActivityModel>> getPresetActivities() {
    return _firestore
        .collection(_collection)
        .where('isPreset', isEqualTo: true)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // 4. Get activities assigned to or suitable for a specific child
  Stream<List<ActivityModel>> getActivitiesForChild(String childId) {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      final all = snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();

      return all.where((activity) {
        return activity.isActive &&
            (activity.childId == childId || activity.isPreset || activity.childId == null);
      }).toList();
    });
  }

  // 4b. Get activities strictly matching a child's age (No overlap between age 3 and 6)
  Stream<List<ActivityModel>> getActivitiesForAge(int age) {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
      final all = snapshot.docs
          .map((doc) => ActivityModel.fromMap(doc.id, doc.data()))
          .where((activity) => activity.isActive)
          .toList();

      if (age < 3) {
        // Under 3: 1-2 gentle, sensory activities
        final under3 = all.where((a) => a.ageGroup.any((g) => g < 3)).toList();
        if (under3.isEmpty) {
          final fallback = all.where((a) => a.difficulty == 'Easy' && (a.skillType == 'Motor' || a.skillType == 'Social' || a.skillType == 'Listening' || a.skillType == 'Emotional')).toList();
          return fallback.take(2).toList();
        }
        return under3.take(2).toList();
      } else {
        // Ages 3, 4, 5, 6: strictly filter where ageGroup contains [age]
        return all.where((a) => a.ageGroup.contains(age)).toList();
      }
    });
  }

  // Backwards compatibility helper
  Stream<List<ActivityModel>> getAgeAppropriateActivities(int childAge) {
    return getActivitiesForAge(childAge);
  }


  // 5. Get filtered activities
  Stream<List<ActivityModel>> getFilteredActivities({
    String? searchQuery,
    String? skillType,
    String? difficulty,
    int? ageGroup,
    String? createdBy,
    bool? isActive,
  }) {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      var activities = snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        activities = activities.where((a) {
          return a.title.toLowerCase().contains(query) ||
              a.skillType.toLowerCase().contains(query) ||
              a.category.toLowerCase().contains(query) ||
              a.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }

      if (skillType != null && skillType != 'All' && skillType.isNotEmpty) {
        activities = activities.where((a) => a.skillType == skillType).toList();
      }

      if (difficulty != null && difficulty != 'All' && difficulty.isNotEmpty) {
        activities = activities.where((a) => a.difficulty == difficulty).toList();
      }

      if (ageGroup != null && ageGroup > 0) {
        activities = activities.where((a) => a.ageGroup.contains(ageGroup)).toList();
      }

      if (createdBy != null && createdBy.isNotEmpty) {
        activities = activities.where((a) => a.createdBy == createdBy).toList();
      }

      if (isActive != null) {
        activities = activities.where((a) => a.isActive == isActive).toList();
      }

      activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return activities;
    });
  }

  // 6. Get a single activity by ID
  Future<ActivityModel?> getActivity(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists && doc.data() != null) {
        return ActivityModel.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 7. Create activity
  Future<String?> createActivity(ActivityModel activity) async {
    try {
      final docRef = await _firestore.collection(_collection).add(activity.toMap());
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // 8. Update activity
  Future<bool> updateActivity(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_collection).doc(id).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 9. Delete activity
  Future<bool> deleteActivity(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 10. Toggle active/inactive status
  Future<bool> toggleActivityStatus(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final currentStatus = doc.data()?['isActive'] ?? true;
        await _firestore.collection(_collection).doc(id).update({
          'isActive': !currentStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 11. Get today's activity for a child
  Future<ActivityModel?> getTodayActivity(String childId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .limit(20)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docs = snapshot.docs.map((doc) => ActivityModel.fromMap(doc.id, doc.data())).toList();
        final childSpecific = docs.where((a) => a.childId == childId).toList();
        if (childSpecific.isNotEmpty) return childSpecific.first;
        return docs.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 12. Get completed activities for a child
  Stream<List<ActivityModel>> getCompletedActivities(String childId) {
    return _firestore
        .collection(_collection)
        .where('isCompleted', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityModel.fromMap(doc.id, doc.data());
      }).toList();
    });
  }
}