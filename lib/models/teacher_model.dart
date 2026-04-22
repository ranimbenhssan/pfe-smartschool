import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String subject;
  final List<String> assignedClassIds;
  final List<String> assignedClassNames;

  // ─── RFID fields for future tracking ───
  final String rfidTag;
  final bool rfidEnabled;
  final DateTime? lastRfidScan;

  final DateTime createdAt;

  const TeacherModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.subject = '',
    required this.assignedClassIds,
    required this.assignedClassNames,
    this.rfidTag = '',
    this.rfidEnabled = false,
    this.lastRfidScan,
    required this.createdAt,
  });

  factory TeacherModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;

    List<String> safeList(String field) {
      final val = raw[field];
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return TeacherModel(
      id: doc.id,
      userId: raw['userId']?.toString() ?? '',
      name: raw['name']?.toString() ?? '',
      email: raw['email']?.toString() ?? '',
      subject: raw['subject']?.toString() ?? '',
      assignedClassIds: safeList('assignedClassIds'),
      assignedClassNames: safeList('assignedClassNames'),
      rfidTag: raw['rfidTag']?.toString() ?? '',
      rfidEnabled: raw['rfidEnabled'] as bool? ?? false,
      lastRfidScan: (raw['lastRfidScan'] as Timestamp?)?.toDate(),
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'subject': subject,
      'assignedClassIds': assignedClassIds,
      'assignedClassNames': assignedClassNames,
      'rfidTag': rfidTag,
      'rfidEnabled': rfidEnabled,
      'lastRfidScan':
          lastRfidScan != null ? Timestamp.fromDate(lastRfidScan!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
