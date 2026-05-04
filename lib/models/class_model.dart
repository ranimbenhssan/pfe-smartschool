import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name; // e.g. "IOT"
  final String grade; // e.g. "1"
  final String level; // e.g. "3"
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
    required this.level,
    required this.teacherIds,
    required this.teacherNames,
    required this.roomId,
    required this.roomName,
    required this.studentCount,
    required this.createdAt,
  });

  // ─────────────────────────────────────────
  //  DISPLAY GETTERS
  //  level="3" + name="IOT" + grade="1"  →  "3 IOT 1"
  // ─────────────────────────────────────────

  /// Primary identifier used across the app: "3 IOT 1"
  String getFullName() {
    final parts = <String>[];
    if (level.isNotEmpty) parts.add(level);
    if (name.isNotEmpty) parts.add(name);
    if (grade.isNotEmpty) parts.add(grade);
    return parts.isNotEmpty ? parts.join(' ') : name;
  }

  /// Alias — used in UI labels
  String get displayName => getFullName();

  /// Short form without grade — used in badges
  String get shortName {
    final parts = <String>[];
    if (level.isNotEmpty) parts.add(level);
    if (name.isNotEmpty) parts.add(name);
    return parts.isNotEmpty ? parts.join(' ') : name;
  }

  String get fullDisplay => getFullName();
  String get teacherId => teacherIds.isNotEmpty ? teacherIds.first : '';
  String get teacherName => teacherNames.isNotEmpty ? teacherNames.first : '';

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
      level: raw['level']?.toString().trim() ?? '',
      teacherIds: safeList('teacherIds'),
      teacherNames: safeList('teacherNames'),
      roomId: raw['roomId']?.toString() ?? '',
      roomName: raw['roomName']?.toString() ?? '',
      studentCount: (raw['studentCount'] as num?)?.toInt() ?? 0,
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'grade': grade,
      'level': level,
      'displayName': getFullName(), // denormalized for Firestore console
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
    String? level,
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
      level: level ?? this.level,
      teacherIds: teacherIds ?? this.teacherIds,
      teacherNames: teacherNames ?? this.teacherNames,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      studentCount: studentCount ?? this.studentCount,
      createdAt: createdAt,
    );
  }
}
