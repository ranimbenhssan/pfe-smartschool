import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String grade;
  final String level;
  final String group; // optional, e.g. "TP 1", "TP 2" — empty = no group
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
    this.group = '',
    required this.teacherIds,
    required this.teacherNames,
    required this.roomId,
    required this.roomName,
    required this.studentCount,
    required this.createdAt,
  });

  // ─────────────────────────────────────────────────────────────────────────
  //  DISPLAY NAME
  //
  //  Without group:  "3 IOT 1"        (level + name + grade)
  //  With group:     "3 IOT 1 TP 2"   (level + name + grade + group)
  //
  //  The group value is stored exactly as entered (e.g. "TP 1", "TP 2").
  //  If group is empty, nothing is appended.
  // ─────────────────────────────────────────────────────────────────────────
  String get displayName {
    final base = '$level $name $grade'.trim();
    if (group.trim().isEmpty) return base;
    return '$base ${group.trim()}';
  }

  /// Alias used in some screens
  String get getFullName => displayName;

  // Short display without grade — used in compact chips
  String get shortDisplay {
    final base = '$level $name'.trim();
    if (group.trim().isEmpty) return base;
    return '$base ${group.trim()}';
  }

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
      group:
          raw['group']?.toString().trim() ??
          '', // backward compat — empty if missing
      teacherIds: safeList('teacherIds'),
      teacherNames: safeList('teacherNames'),
      roomId: raw['roomId']?.toString() ?? '',
      roomName: raw['roomName']?.toString() ?? '',
      studentCount: (raw['studentCount'] as num?)?.toInt() ?? 0,
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'grade': grade,
    'level': level,
    'group': group,
    'displayName': displayName, // denormalised for query/display performance
    'teacherIds': teacherIds,
    'teacherNames': teacherNames,
    'roomId': roomId,
    'roomName': roomName,
    'studentCount': studentCount,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  ClassModel copyWith({
    String? name,
    String? grade,
    String? level,
    String? group,
    List<String>? teacherIds,
    List<String>? teacherNames,
    String? roomId,
    String? roomName,
    int? studentCount,
  }) => ClassModel(
    id: id,
    name: name ?? this.name,
    grade: grade ?? this.grade,
    level: level ?? this.level,
    group: group ?? this.group,
    teacherIds: teacherIds ?? this.teacherIds,
    teacherNames: teacherNames ?? this.teacherNames,
    roomId: roomId ?? this.roomId,
    roomName: roomName ?? this.roomName,
    studentCount: studentCount ?? this.studentCount,
    createdAt: createdAt,
  );
}
