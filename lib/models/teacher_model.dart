import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final List<String> assignedClassIds;
  final List<String> assignedClassNames;
  final String? photoUrl;
  final DateTime createdAt;

  const TeacherModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.assignedClassIds,
    required this.assignedClassNames,
    this.photoUrl,
    required this.createdAt,
  });

  factory TeacherModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      assignedClassIds: List<String>.from(data['assignedClassIds'] ?? []),
      assignedClassNames: List<String>.from(data['assignedClassNames'] ?? []),
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'assignedClassIds': assignedClassIds,
      'assignedClassNames': assignedClassNames,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  TeacherModel copyWith({
    String? name,
    String? email,
    List<String>? assignedClassIds,
    List<String>? assignedClassNames,
    String? photoUrl,
  }) {
    return TeacherModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      assignedClassIds: assignedClassIds ?? this.assignedClassIds,
      assignedClassNames: assignedClassNames ?? this.assignedClassNames,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'TeacherModel(id: $id, name: $name)';
}