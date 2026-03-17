import 'package:cloud_firestore/cloud_firestore.dart';

class TimetableModel {
  final String id;
  final String classId;
  final String className;
  final String teacherId;
  final String teacherName;
  final String roomId;
  final String roomName;
  final String subject;
  final int dayOfWeek; // 1=Monday, 2=Tuesday ... 5=Friday
  final String startTime; // "08:00"
  final String endTime;   // "09:00"
  final DateTime createdAt;

  const TimetableModel({
    required this.id,
    required this.classId,
    required this.className,
    required this.teacherId,
    required this.teacherName,
    required this.roomId,
    required this.roomName,
    required this.subject,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
  });

  factory TimetableModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimetableModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? '',
      roomId: data['roomId'] ?? '',
      roomName: data['roomName'] ?? '',
      subject: data['subject'] ?? '',
      dayOfWeek: data['dayOfWeek'] ?? 1,
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'className': className,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'roomId': roomId,
      'roomName': roomName,
      'subject': subject,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get dayName {
    switch (dayOfWeek) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      default: return '';
    }
  }

  TimetableModel copyWith({
    String? subject,
    String? teacherId,
    String? teacherName,
    String? roomId,
    String? roomName,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
  }) {
    return TimetableModel(
      id: id,
      classId: classId,
      className: className,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      subject: subject ?? this.subject,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'TimetableModel(subject: $subject, day: $dayName, time: $startTime-$endTime)';
}