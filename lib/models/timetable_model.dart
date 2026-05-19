import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TIMETABLE MODEL  (updated — adds weekType)
//
//  weekType = 'A' | 'B' | ''
//  '' means the entry applies to BOTH weeks (legacy / no rotation).
// ─────────────────────────────────────────────────────────────────────────────
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
  final String weekType; // 'A', 'B', or '' (both)
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
    this.weekType = '',
    required this.createdAt,
  });

  factory TimetableModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;

    // Safe string extractor — returns '' if value is Map/List/null
    String s(String key) {
      final v = raw[key];
      if (v == null || v is Map || v is List) return '';
      return v.toString().trim();
    }

    return TimetableModel(
      id: doc.id,
      classId: s('classId'),
      className: s('className'),
      teacherId: s('teacherId'),
      teacherName: s('teacherName'),
      subject: s('subject'),
      dayOfWeek: s('dayOfWeek').isNotEmpty ? s('dayOfWeek') : s('day'),
      startTime: s('startTime'),
      endTime: s('endTime'),
      roomId: s('roomId'),
      roomName: s('roomName'),
      createdAt: (raw['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      weekType: raw['weekType']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
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
    'weekType': weekType,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  String get day => dayOfWeek;

  String get scheduledTimeRange =>
      startTime.isNotEmpty && endTime.isNotEmpty ? '$startTime – $endTime' : '';

  // Whether this entry matches the given week type
  bool matchesWeek(String currentWeekType) =>
      weekType.isEmpty || weekType == currentWeekType;

  bool get isRattrapage => weekType.toLowerCase() == 'rattrapage';

  // For rattrapage entries, only show on the exact date stored in createdAt.
  bool occursOnDate(DateTime date) {
    if (!isRattrapage) return true;
    return createdAt.year == date.year &&
        createdAt.month == date.month &&
        createdAt.day == date.day;
  }

  String get effectiveDayOfWeek {
    if (!isRattrapage) return dayOfWeek;
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[createdAt.weekday];
  }
}
