import 'package:cloud_firestore/cloud_firestore.dart';

class TimetableModel {
  final String id;
  final String classId;
  final String className;
  final String teacherId;
  final String teacherName;
  final String subject;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String roomId;
  final String roomName;
  final DateTime createdAt;

  const TimetableModel({
    required this.id,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.subject,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.roomName,
    required this.createdAt,
  });

  factory TimetableModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;
    return TimetableModel(
      id: doc.id,
      classId: raw['classId']?.toString() ?? '',
      className: raw['className']?.toString() ?? '',
      teacherId: raw['teacherId']?.toString() ?? '',
      teacherName: raw['teacherName']?.toString() ?? '',
      subject: raw['subject']?.toString() ?? '',
      dayOfWeek: raw['dayOfWeek']?.toString() ?? raw['day']?.toString() ?? '',
      startTime: raw['startTime']?.toString() ?? '',
      endTime: raw['endTime']?.toString() ?? '',
      roomId: raw['roomId']?.toString() ?? '',
      roomName: raw['roomName']?.toString() ?? '',
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'className': className,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'subject': subject,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'roomId': roomId,
      'roomName': roomName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Keep backward compat with 'day' field
  String get day => dayOfWeek;
}
