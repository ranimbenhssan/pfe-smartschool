import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String rfidTag;
  final String classId;
  final String className;
  final String? photoUrl;
  final DateTime createdAt;

  const StudentModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.rfidTag,
    required this.classId,
    required this.className,
    this.photoUrl,
    required this.createdAt,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      rfidTag: data['rfidTag'] ?? '',
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'rfidTag': rfidTag,
      'classId': classId,
      'className': className,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  StudentModel copyWith({
    String? name,
    String? email,
    String? rfidTag,
    String? classId,
    String? className,
    String? photoUrl,
  }) {
    return StudentModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      rfidTag: rfidTag ?? this.rfidTag,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'StudentModel(id: $id, name: $name, classId: $classId)';
}