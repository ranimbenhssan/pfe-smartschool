import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late }

class AttendanceModel {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String className;
  final String date;
  final AttendanceStatus status;
  final DateTime? entryTime;
  final DateTime? exitTime;

  // ─── New detailed fields ───
  final String teacherId;
  final String teacherName;
  final String subject;
  final String roomId;
  final String roomName;
  final String sessionName;
  final DateTime? recordedAt;
  final String? note;
  final DateTime createdAt;

  const AttendanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.date,
    required this.status,
    this.entryTime,
    this.exitTime,
    this.teacherId = '',
    this.teacherName = '',
    this.subject = '',
    this.roomId = '',
    this.roomName = '',
    this.sessionName = '',
    this.recordedAt,
    this.note,
    required this.createdAt,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;

    AttendanceStatus parseStatus(String? s) {
      switch (s?.trim().toLowerCase()) {
        case 'present':
          return AttendanceStatus.present;
        case 'late':
          return AttendanceStatus.late;
        default:
          return AttendanceStatus.absent;
      }
    }

    return AttendanceModel(
      id: doc.id,
      studentId: raw['studentId']?.toString() ?? '',
      studentName: raw['studentName']?.toString() ?? '',
      classId: raw['classId']?.toString() ?? '',
      className: raw['className']?.toString() ?? '',
      date: raw['date']?.toString() ?? '',
      status: parseStatus(raw['status']?.toString()),
      entryTime: (raw['entryTime'] as Timestamp?)?.toDate(),
      exitTime: (raw['exitTime'] as Timestamp?)?.toDate(),
      teacherId: raw['teacherId']?.toString() ?? '',
      teacherName: raw['teacherName']?.toString() ?? '',
      subject: raw['subject']?.toString() ?? '',
      roomId: raw['roomId']?.toString() ?? '',
      roomName: raw['roomName']?.toString() ?? '',
      sessionName: raw['sessionName']?.toString() ?? '',
      recordedAt: (raw['recordedAt'] as Timestamp?)?.toDate(),
      note: raw['note']?.toString(),
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'className': className,
      'date': date,
      'status': status.name,
      'entryTime': entryTime != null ? Timestamp.fromDate(entryTime!) : null,
      'exitTime': exitTime != null ? Timestamp.fromDate(exitTime!) : null,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'subject': subject,
      'roomId': roomId,
      'roomName': roomName,
      'sessionName': sessionName,
      'recordedAt':
          recordedAt != null
              ? Timestamp.fromDate(recordedAt!)
              : FieldValue.serverTimestamp(),
      'note': note ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ─── Human readable summary ───
  String get summary {
    final parts = <String>[];
    if (sessionName.isNotEmpty) parts.add(sessionName);
    if (teacherName.isNotEmpty) parts.add('recorded by $teacherName');
    if (recordedAt != null) {
      final time =
          '${recordedAt!.hour.toString().padLeft(2, '0')}:${recordedAt!.minute.toString().padLeft(2, '0')}';
      final date2 =
          '${recordedAt!.day.toString().padLeft(2, '0')}/${recordedAt!.month.toString().padLeft(2, '0')}/${recordedAt!.year}';
      parts.add('at $time on $date2');
    }
    return parts.join(' ');
  }
}
