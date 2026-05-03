import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

class AttendanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getDayName(int weekday) {
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
    return days[weekday];
  }

  Stream<void> listenForRfidLogs() {
    return _db
        .collection('rfid_logs')
        .where('isRecognized', isEqualTo: false)
        .snapshots()
        .asyncMap((snap) async {
          for (final doc in snap.docs) {
            await _processRfidLog(doc.id, doc.data());
          }
        });
  }

  Future<void> _processRfidLog(
    String logId,
    Map<String, dynamic> logData,
  ) async {
    try {
      final rfidTag = logData['rfidTag'] as String? ?? '';
      final direction = logData['direction'] as String? ?? '';
      if (rfidTag.isEmpty) return;

      final studentSnap =
          await _db
              .collection('students')
              .where('rfidTag', isEqualTo: rfidTag)
              .limit(1)
              .get();

      if (studentSnap.docs.isEmpty) return;

      final studentDoc = studentSnap.docs.first;
      final studentData = studentDoc.data();

      await _db.collection('rfid_logs').doc(logId).update({
        'isRecognized': true,
        'studentId': studentDoc.id,
        'studentName': studentData['name'] ?? '',
      });

      if (direction.toUpperCase() == 'IN') {
        await _markAttendanceFromData(studentDoc.id, studentData);
        await _checkAIFlags(
          studentDoc.id,
          studentData['name'] ?? '',
          studentData['classId'] ?? '',
        );
      } else if (direction.toUpperCase() == 'OUT') {
        await _markExit(studentDoc.id);
      }
    } catch (e) {
      debugPrint('Error processing RFID log: $e');
    }
  }

  Future<void> _markAttendanceFromData(
    String studentId,
    Map<String, dynamic> studentData,
  ) async {
    final now = DateTime.now();
    final dateStr = _formatDate(now);

    final existing =
        await _db
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .where('date', isEqualTo: dateStr)
            .limit(1)
            .get();

    if (existing.docs.isNotEmpty) return;

    final schoolStart = DateTime(now.year, now.month, now.day, 8, 0);
    final diffMinutes = now.difference(schoolStart).inMinutes;
    final status = diffMinutes > 15 ? 'late' : 'present';

    // ─── Find matching timetable entry ───
    final classId = studentData['classId']?.toString() ?? '';
    final dayName = _getDayName(now.weekday);
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    String teacherId = '';
    String teacherName = '';
    String subject = '';
    String roomId = '';
    String roomName = '';
    String sessionName = '';
    String scheduledStartTime = '';
    String scheduledEndTime = '';

    if (classId.isNotEmpty) {
      final timetableSnap =
          await _db
              .collection('timetable')
              .where('classId', isEqualTo: classId)
              .where('dayOfWeek', isEqualTo: dayName)
              .get();

      for (final doc in timetableSnap.docs) {
        final data = doc.data();
        final start = data['startTime']?.toString() ?? '';
        final end = data['endTime']?.toString() ?? '';
        if (start.isEmpty || end.isEmpty) continue;

        if (currentTime.compareTo(start) >= 0 &&
            currentTime.compareTo(end) <= 0) {
          teacherId = data['teacherId']?.toString() ?? '';
          teacherName = data['teacherName']?.toString() ?? '';
          subject = data['subject']?.toString() ?? '';
          roomId = data['roomId']?.toString() ?? '';
          roomName = data['roomName']?.toString() ?? '';
          scheduledStartTime = start;
          scheduledEndTime = end;
          sessionName =
              '${data['subject'] ?? ''} ($scheduledStartTime – $scheduledEndTime)';
          break;
        }
      }
    }

    if (status == 'present') {
      // Present → counter only, no document
      await _db.collection('students').doc(studentId).update({
        'presenceCount': FieldValue.increment(1),
      });
    } else {
      // Absent / Late → full document with all 5 fields
      await _db.collection('attendance').add({
        'studentId': studentId,
        'studentName': studentData['name'] ?? '',
        'classId': classId,
        'className': studentData['className'] ?? '',
        'date': dateStr,
        'status': status,
        'entryTime': Timestamp.fromDate(now),
        'exitTime': null,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'subject': subject,
        'roomId': roomId,
        'roomName': roomName,
        'sessionName': sessionName,
        'scheduledStartTime': scheduledStartTime,
        'scheduledEndTime': scheduledEndTime,
        'recordedAt': Timestamp.fromDate(now),
        'note': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _markExit(String studentId) async {
    final dateStr = _formatDate(DateTime.now());
    final snap =
        await _db
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .where('date', isEqualTo: dateStr)
            .limit(1)
            .get();
    if (snap.docs.isEmpty) return;
    await snap.docs.first.reference.update({
      'exitTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _checkAIFlags(
    String studentId,
    String studentName,
    String classId,
  ) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final snap =
        await _db
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
            )
            .get();

    final records = snap.docs.map((d) => d.data()).toList();
    final absent = records.where((r) => r['status'] == 'absent').length;
    final late = records.where((r) => r['status'] == 'late').length;

    String? flagType;
    String details = '';
    double riskScore = 0;

    if (absent >= 3) {
      flagType = 'frequentAbsent';
      details =
          '$studentName has been absent $absent times in the last 30 days';
      riskScore = (absent / 30).clamp(0, 1);
    } else if (late >= 4) {
      flagType = 'latePattern';
      details = '$studentName has arrived late $late times in the last 30 days';
      riskScore = (late / 30).clamp(0, 1);
    }

    if (flagType == null) return;

    final existing =
        await _db
            .collection('ai_flags')
            .where('studentId', isEqualTo: studentId)
            .where('type', isEqualTo: flagType)
            .where('resolved', isEqualTo: false)
            .limit(1)
            .get();

    if (existing.docs.isNotEmpty) return;

    await _db.collection('ai_flags').add({
      'studentId': studentId,
      'studentName': studentName,
      'classId': classId,
      'type': flagType,
      'details': details,
      'riskScore': riskScore,
      'resolved': false,
      'detectedAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
    });
  }
}
