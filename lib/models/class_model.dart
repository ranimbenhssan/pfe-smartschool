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

  String get teacherId =>
      teacherIds.isNotEmpty ? teacherIds.first : '';
  String get teacherName =>
      teacherNames.isNotEmpty ? teacherNames.first : '';
  String get displayName => '$grade $name';

  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;

    List<String> safeList(String field) {
      final val = raw[field];
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return ClassModel(
      id: doc.id,
      name: raw['name']?.toString().trim() ?? '',
      grade: raw['grade']?.toString().trim() ?? '',
      teacherIds: safeList('teacherIds'),
      teacherNames: safeList('teacherNames'),
      roomId: raw['roomId']?.toString() ?? '',
      roomName: raw['roomName']?.toString() ?? '',
      studentCount: (raw['studentCount'] as num?)?.toInt() ?? 0,
      createdAt:
          (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
}