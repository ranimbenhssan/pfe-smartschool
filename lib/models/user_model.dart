import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  superAdmin, // Director — sees everything
  adminRH, // HR staff — manages teachers
  adminScolarite, // Registrar — manages students + timetables
  teacher,
  student,
  unknown,
}

extension UserRoleX on UserRole {
  bool get isAnyAdmin =>
      this == UserRole.superAdmin ||
      this == UserRole.adminRH ||
      this == UserRole.adminScolarite;

  bool get canManageTeachers =>
      this == UserRole.superAdmin || this == UserRole.adminRH;

  bool get canManageStudents =>
      this == UserRole.superAdmin || this == UserRole.adminScolarite;

  bool get canManageTimetable =>
      this == UserRole.superAdmin || this == UserRole.adminScolarite;

  bool get canSeeAllNotifications => this == UserRole.superAdmin;

  bool get canSendMessages =>
      this == UserRole.superAdmin ||
      this == UserRole.adminRH ||
      this == UserRole.adminScolarite;

  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Director';
      case UserRole.adminRH:
        return 'HR Staff';
      case UserRole.adminScolarite:
        return 'Registrar';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      default:
        return 'Unknown';
    }
  }

  String get firestoreValue {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.adminRH:
        return 'admin_rh';
      case UserRole.adminScolarite:
        return 'admin_scolarite';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.student:
        return 'student';
      default:
        return 'unknown';
    }
  }
}

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
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin_rh':
        return UserRole.adminRH;
      case 'admin_scolarite':
        return UserRole.adminScolarite;
      // Legacy: existing 'admin' accounts map to superAdmin
      case 'admin':
        return UserRole.superAdmin;
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

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'role': role.firestoreValue,
    'first_login': firstLogin,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
