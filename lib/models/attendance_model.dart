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

  // ─── Timetable-mapped fields ───
  final String teacherId;
  final String teacherName;
  final String subject;
  final String roomId;
  final String roomName;
  final String sessionName;

  /// Actual timestamp when the teacher recorded this entry
  final DateTime? recordedAt;

  /// Scheduled window from the timetable (e.g. "08:00" / "09:30")
  final String scheduledStartTime;
  final String scheduledEndTime;

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
    this.scheduledStartTime = '',
    this.scheduledEndTime = '',
    this.note,
    required this.createdAt,
  });

  // ─── Convenience getter ───
  String get scheduledTimeRange =>
      (scheduledStartTime.isNotEmpty && scheduledEndTime.isNotEmpty)
          ? '$scheduledStartTime – $scheduledEndTime'
          : sessionName.isNotEmpty
          ? sessionName
          : '';

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
      scheduledStartTime: raw['scheduledStartTime']?.toString() ?? '',
      scheduledEndTime: raw['scheduledEndTime']?.toString() ?? '',
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
      'scheduledStartTime': scheduledStartTime,
      'scheduledEndTime': scheduledEndTime,
      'note': note ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ─── Human-readable summary ───
  String get summary {
    final parts = <String>[];
    if (subject.isNotEmpty) parts.add(subject);
    if (teacherName.isNotEmpty) parts.add('with $teacherName');
    if (scheduledTimeRange.isNotEmpty) parts.add('($scheduledTimeRange)');
    if (roomName.isNotEmpty) parts.add('in $roomName');
    if (recordedAt != null) {
      final t =
          '${recordedAt!.hour.toString().padLeft(2, '0')}:${recordedAt!.minute.toString().padLeft(2, '0')}';
      parts.add('• recorded at $t');
    }
    return parts.join(' ');
  }
}
