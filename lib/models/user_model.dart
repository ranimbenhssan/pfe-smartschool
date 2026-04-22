import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, teacher, student, unknown }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool firstLogin;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.firstLogin = false,
    required this.createdAt,
  });

  static UserRole _parseRole(String? role) {
    switch (role?.trim().toLowerCase()) {
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

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: raw['name']?.toString().trim() ?? '',
      email: raw['email']?.toString().trim() ?? '',
      role: _parseRole(raw['role']?.toString()),
      firstLogin: raw['first_login'] as bool? ?? false,
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'first_login': firstLogin,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
