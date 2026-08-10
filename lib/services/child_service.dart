// lib/services/child_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/child_model.dart';
import '../models/skill_profile_model.dart';

class ChildService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Add Child
  Future<String?> addChild({
    required String name,
    required int age,
    required String gender,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'User not logged in';

      final childRef = _firestore.collection('children').doc();
      final childId = childRef.id;

      final child = ChildModel(
        childId: childId,
        parentId: user.uid,
        name: name,
        age: age,
        gender: gender,
        createdAt: DateTime.now(),
      );

      // Save child
      await childRef.set(child.toMap());

      // Create skill profile
      await _firestore.collection('skillProfiles').doc(childId).set({
        'childId': childId,
        'cognitive': 0.0,
        'language': 0.0,
        'motor': 0.0,
        'social': 0.0,
        'emotional': 0.0,
        'creative': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return null; // Success
    } catch (e) {
      return 'Failed to add child: $e';
    }
  }

  // ✅ Get All Children for Parent
  Stream<List<ChildModel>> getChildren() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('children')
        .where('parentId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChildModel.fromMap(doc.data());
          }).toList();
        });
  }

  // ✅ Get Child by ID
  Future<ChildModel?> getChild(String childId) async {
    try {
      final doc = await _firestore.collection('children').doc(childId).get();
      if (doc.exists) {
        return ChildModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ Get Skill Profile
  Future<SkillProfileModel?> getSkillProfile(String childId) async {
    try {
      final doc = await _firestore
          .collection('skillProfiles')
          .doc(childId)
          .get();
      if (doc.exists) {
        return SkillProfileModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ✅ Update Skill Profile
  Future<void> updateSkillProfile(
    String childId,
    Map<String, double> skills,
  ) async {
    await _firestore.collection('skillProfiles').doc(childId).update({
      ...skills,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Flag Child
  Future<void> flagChild(String childId, String reason) async {
    await _firestore.collection('children').doc(childId).update({
      'isFlagged': true,
      'flagReason': reason,
      'flaggedAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Unflag Child
  Future<void> unflagChild(String childId) async {
    await _firestore.collection('children').doc(childId).update({
      'isFlagged': false,
      'flagReason': null,
      'flaggedAt': null,
    });
  }

  //update child details
  Future<String?> updateChild(ChildModel child) async {
    try {
      await _firestore.collection('children').doc(child.childId).update({
        ...child.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null; // Success
    } catch (e) {
      return 'Failed to update child: $e';
    }
  }


  // ✅ Delete Child and all associated data
Future<String?> deleteChild(String childId) async {
  try {
    final user = _auth.currentUser;
    if (user == null) return 'User not logged in';

    // 1. Delete child document
    await _firestore.collection('children').doc(childId).delete();

    // 2. Delete skill profile
    await _firestore.collection('skillProfiles').doc(childId).delete();

    // 3. Delete all activities for this child
    final activities = await _firestore
        .collection('activities')
        .where('childId', isEqualTo: childId)
        .get();
    for (var doc in activities.docs) {
      await doc.reference.delete();
    }

    // 4. Delete all feedback for this child
    final feedback = await _firestore
        .collection('feedback')
        .where('childId', isEqualTo: childId)
        .get();
    for (var doc in feedback.docs) {
      await doc.reference.delete();
    }

    return null; // Success
  } catch (e) {
    return 'Failed to delete child: $e';
  }
}

// ✅ Get All Flagged Children
Stream<List<ChildModel>> getFlaggedChildren() {
  return _firestore
      .collection('children')
      .where('isFlagged', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      return ChildModel.fromMap(doc.data());
    }).toList();
  });
}

// ✅ Get Child with Skill Profile
Future<Map<String, dynamic>?> getChildWithProfile(String childId) async {
  try {
    final childDoc = await _firestore.collection('children').doc(childId).get();
    if (!childDoc.exists) return null;

    final skillDoc = await _firestore.collection('skillProfiles').doc(childId).get();
    final childData = childDoc.data()!;
    final skillData = skillDoc.exists ? skillDoc.data() : null;

    return {
      'child': childData,
      'skillProfile': skillData,
    };
  } catch (e) {
    return null;
  }
}

// ✅ Resolve Flag
Future<void> resolveFlag(String childId) async {
  await _firestore.collection('children').doc(childId).update({
    'isFlagged': false,
    'flagReason': null,
    'flaggedAt': null,
  });
}

}
