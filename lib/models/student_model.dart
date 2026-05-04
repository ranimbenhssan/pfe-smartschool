import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String name;
  final String email;
  final String classId;

  /// Combined "Level Name Grade" e.g. "3 IOT 1"
  final String className;

  final String level;
  final String rfidTag;
  final String userId;
  final DateTime createdAt;

  /// Summary counter — kept in sync with presence_tracking sub-collection
  /// via FieldValue.increment. Never written via toFirestore() to prevent
  /// overwriting incremental updates.
  final int totalPresence;

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
    this.totalPresence = 0,
  });

  // ── Display getters ──────────────────────────────────────────────────────
  String get fullDisplay => '$name — $level $className';
  String get classDisplay => '$level $className';

  /// Alias for totalPresence — resolves the compile error:
  /// "The getter 'presenceCount' isn't defined for the type 'StudentModel'"
  int get presenceCount => totalPresence;

  // ── Firestore ────────────────────────────────────────────────────────────
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
      // Read either field name — supports both old and new Firestore docs
      totalPresence:
          (raw['totalPresence'] as num?)?.toInt() ??
          (raw['presenceCount'] as num?)?.toInt() ??
          0,
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
      // totalPresence intentionally omitted — always written via
      // FieldValue.increment to prevent overwriting concurrent updates.
    };
  }
}
