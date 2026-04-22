import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String name;
  final String email;
  final String classId;
  final String className;
  final String level; // ← NEW
  final String rfidTag;
  final String userId;
  final DateTime createdAt;

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
  });

  // ─── Full display: "Ranim BenHssan – 3Iot1" ───
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
    };
  }
}
