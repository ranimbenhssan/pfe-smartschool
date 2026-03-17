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
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      classId: data['classId'] ?? '',
      date: data['date'] ?? '',
      status: _parseStatus(data['status']),
      entryTime: (data['entryTime'] as Timestamp?)?.toDate(),
      exitTime: (data['exitTime'] as Timestamp?)?.toDate(),
      note: data['note'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'date': date,
      'status': status.name,
      'entryTime': entryTime != null ? Timestamp.fromDate(entryTime!) : null,
      'exitTime': exitTime != null ? Timestamp.fromDate(exitTime!) : null,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static AttendanceStatus _parseStatus(String? status) {
    switch (status) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      default:
        return AttendanceStatus.absent;
    }
  }

  AttendanceModel copyWith({
    AttendanceStatus? status,
    DateTime? entryTime,
    DateTime? exitTime,
    String? note,
  }) {
    return AttendanceModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      date: date,
      status: status ?? this.status,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'AttendanceModel(studentId: $studentId, date: $date, status: ${status.name})';
}