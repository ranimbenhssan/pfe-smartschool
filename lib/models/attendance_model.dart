import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late }

class AttendanceModel {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String date;
  final AttendanceStatus status;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final String? note;
  final DateTime createdAt;

  const AttendanceModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.date,
    required this.status,
    this.entryTime,
    this.exitTime,
    this.note,
    required this.createdAt,
  });

  factory AttendanceModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;

    AttendanceStatus parseStatus(String? s) {
      switch (s?.trim().toLowerCase()) {
        case 'present': return AttendanceStatus.present;
        case 'late':    return AttendanceStatus.late;
        default:        return AttendanceStatus.absent;
      }
    }

    return AttendanceModel(
      id: doc.id,
      studentId: raw['studentId']?.toString() ?? '',
      studentName: raw['studentName']?.toString() ?? '',
      classId: raw['classId']?.toString() ?? '',
      date: raw['date']?.toString() ?? '',
      status: parseStatus(raw['status']?.toString()),
      entryTime: (raw['entryTime'] as Timestamp?)?.toDate(),
      exitTime: (raw['exitTime'] as Timestamp?)?.toDate(),
      note: raw['note']?.toString(),
      createdAt:
          (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'date': date,
      'status': status.name,
      'entryTime':
          entryTime != null ? Timestamp.fromDate(entryTime!) : null,
      'exitTime':
          exitTime != null ? Timestamp.fromDate(exitTime!) : null,
      'note': note ?? '',
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}