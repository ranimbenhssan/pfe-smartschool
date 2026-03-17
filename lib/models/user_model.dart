import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, teacher, student, unknown }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? photoUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: _parseRole(data['role']),
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      default:
        return UserRole.unknown;
    }
  }

  UserModel copyWith({
    String? name,
    String? email,
    UserRole? role,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'UserModel(id: $id, name: $name, role: ${role.name})';
}
