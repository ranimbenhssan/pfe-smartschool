import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String grade;
  final List<String> teacherIds;
  final List<String> teacherNames;
  final String roomId;
  final String roomName;
  final int studentCount;
  final DateTime createdAt;

  const ClassModel({
    required this.id,
    required this.name,
    required this.grade,
    required this.teacherIds,
    required this.teacherNames,
    required this.roomId,
    required this.roomName,
    required this.studentCount,
    required this.createdAt,
  });

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      name: data['name'] ?? '',
      grade: data['grade'] ?? '',
      teacherIds: List<String>.from(data['teacherIds'] ?? []),
      teacherNames: List<String>.from(data['teacherNames'] ?? []),
      roomId: data['roomId'] ?? '',
      roomName: data['roomName'] ?? '',
      studentCount: data['studentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'grade': grade,
      'teacherIds': teacherIds,
      'teacherNames': teacherNames,
      'roomId': roomId,
      'roomName': roomName,
      'studentCount': studentCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ─── Keep backward compatibility ───
  String get teacherId => teacherIds.isNotEmpty ? teacherIds.first : '';
  String get teacherName => teacherNames.isNotEmpty ? teacherNames.first : '';

  ClassModel copyWith({
    String? name,
    String? grade,
    List<String>? teacherIds,
    List<String>? teacherNames,
    String? roomId,
    String? roomName,
    int? studentCount,
  }) {
    return ClassModel(
      id: id,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      teacherIds: teacherIds ?? this.teacherIds,
      teacherNames: teacherNames ?? this.teacherNames,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'ClassModel(id: $id, name: $name, grade: $grade)';
}
