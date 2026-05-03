import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String name;
  final String email;
  final String classId;
  final String className;
  final String level;
  final String rfidTag;
  final String userId;
  final DateTime createdAt;

  /// Running total of sessions marked Present.
  /// Incremented atomically via FieldValue.increment(1) — never stored
  /// in the `attendance` collection for present records.
  final int presenceCount;

  const StudentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.classId,
    required this.className,
    required this.level,
    required this.rfidTag,
    required this.userId,
    required this.createdAt,
    this.presenceCount = 0,
  });

  String get fullDisplay => '$name — $level $className';
  String get classDisplay => '$level $className';

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      name: raw['name']?.toString() ?? '',
      email: raw['email']?.toString() ?? '',
      classId: raw['classId']?.toString() ?? '',
      className: raw['className']?.toString() ?? '',
      level: raw['level']?.toString() ?? '',
      rfidTag: raw['rfidTag']?.toString() ?? '',
      userId: raw['userId']?.toString() ?? '',
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      presenceCount: (raw['presenceCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'classId': classId,
      'className': className,
      'level': level,
      'rfidTag': rfidTag,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      // presenceCount is NOT included here — it is always written via
      // FieldValue.increment to avoid race conditions on concurrent saves.
    };
  }
}
