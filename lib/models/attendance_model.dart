import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late }

class AttendanceModel {
  final String id;
  final String studentId;
  final String studentName;

  /// Firestore class document id
  final String classId;

  /// Combined display name — always "3 IOT 1" format via ClassModel.getFullName()
  final String className;

  final String date;
  final AttendanceStatus status;
  final DateTime? entryTime;
  final DateTime? exitTime;

  // ─── Timetable context fields (absent / late records only) ───
  final String teacherId;
  final String teacherName;
  final String subject;
  final String roomId;
  final String roomName;
  final String sessionName;

  /// Scheduled class start — "08:00"
  final String scheduledStartTime;

  /// Scheduled class end   — "09:30"
  final String scheduledEndTime;

  /// Timestamp when the teacher recorded this entry (time of absence)
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
    this.scheduledStartTime = '',
    this.scheduledEndTime = '',
    this.recordedAt,
    this.note,
    required this.createdAt,
  });

  /// "08:00 – 09:30"
  /// Falls back to regex-parsing sessionName for legacy records.
  String get scheduledTimeRange {
    if (scheduledStartTime.isNotEmpty && scheduledEndTime.isNotEmpty) {
      return '$scheduledStartTime – $scheduledEndTime';
    }
    final match = RegExp(
      r'(\d{2}:\d{2})\s*[–\-]\s*(\d{2}:\d{2})',
    ).firstMatch(sessionName);
    if (match != null) return '${match.group(1)} – ${match.group(2)}';
    return '';
  }

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
      scheduledStartTime: raw['scheduledStartTime']?.toString() ?? '',
      scheduledEndTime: raw['scheduledEndTime']?.toString() ?? '',
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
      'scheduledStartTime': scheduledStartTime,
      'scheduledEndTime': scheduledEndTime,
      'recordedAt':
          recordedAt != null
              ? Timestamp.fromDate(recordedAt!)
              : FieldValue.serverTimestamp(),
      'note': note ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get summary {
    final parts = <String>[];
    if (subject.isNotEmpty) parts.add(subject);
    if (teacherName.isNotEmpty) parts.add('by $teacherName');
    if (scheduledTimeRange.isNotEmpty) parts.add('($scheduledTimeRange)');
    if (roomName.isNotEmpty) parts.add('in $roomName');
    if (recordedAt != null) {
      final t =
          '${recordedAt!.hour.toString().padLeft(2, '0')}:${recordedAt!.minute.toString().padLeft(2, '0')}';
      parts.add('· recorded $t');
    }
    return parts.join(' ');
  }
}
