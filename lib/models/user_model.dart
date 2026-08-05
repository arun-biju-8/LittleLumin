// lib/models/user_model.dart
class UserModel {
  String uid;
  String name;
  String email;
  String userType; // 'parent', 'llg', 'admin'
  String status; // 'active', 'inactive'
  DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.userType = 'parent',
    this.status = 'active',
    required this.createdAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'userType': userType,
      'status': status,
      'createdAt': createdAt,
    };
  }

  // Create from Firestore Document
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      userType: data['userType'] ?? 'parent',
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as DateTime?) ?? DateTime.now(),
    );
  }
}