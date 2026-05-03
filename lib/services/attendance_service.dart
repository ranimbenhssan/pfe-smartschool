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

  // ─────────────────────────────────────────
  //  RFID LISTENER
  // ─────────────────────────────────────────
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

  // ─────────────────────────────────────────
  //  MARK ATTENDANCE FROM RFID DATA
  // ─────────────────────────────────────────
  Future<void> _markAttendanceFromData(
    String studentId,
    Map<String, dynamic> studentData,
  ) async {
    final now = DateTime.now();
    final dateStr = _formatDate(now);

    // Skip if already recorded today
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

    // ─── Resolve timetable slot for all 5 context fields ───
    final classId = studentData['classId']?.toString() ?? '';

    // className is already stored in the combined format "3 IOT 1"
    // (written by ExcelImportService._buildClassName or ClassModel.getFullName())
    final className = studentData['className']?.toString() ?? '';

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
        final d = doc.data();
        final start = d['startTime']?.toString() ?? '';
        final end = d['endTime']?.toString() ?? '';
        if (start.isEmpty || end.isEmpty) continue;
        if (currentTime.compareTo(start) >= 0 &&
            currentTime.compareTo(end) <= 0) {
          teacherId = d['teacherId']?.toString() ?? '';
          teacherName = d['teacherName']?.toString() ?? '';
          subject = d['subject']?.toString() ?? '';
          roomId = d['roomId']?.toString() ?? '';
          roomName = d['roomName']?.toString() ?? '';
          scheduledStartTime = start;
          scheduledEndTime = end;
          // sessionName uses combined className + subject + window
          sessionName = '$subject ($start – $end)';
          break;
        }
      }
    }

    // ─────────────────────────────────────────
    //  TWO DATA PATHS
    //  present → increment counter, no document
    //  absent / late → full 5-field document
    // ─────────────────────────────────────────
    if (status == 'present') {
      await _db.collection('students').doc(studentId).update({
        'presenceCount': FieldValue.increment(1),
      });
    } else {
      // absent or late
      await _db.collection('attendance').add({
        'studentId': studentId,
        'studentName': studentData['name'] ?? '',
        'classId': classId,
        'className': className, // "3 IOT 1"
        'date': dateStr,
        'status': status, // 'absent' | 'late'
        // ── Field 1: Subject ──
        'subject': subject,
        // ── Field 2: Teacher ──
        'teacherId': teacherId,
        'teacherName': teacherName,
        // ── Field 3: Room ──
        'roomId': roomId,
        'roomName': roomName,
        // ── Field 4: Scheduled Time ──
        'scheduledStartTime': scheduledStartTime,
        'scheduledEndTime': scheduledEndTime,
        'sessionName': sessionName,
        // ── Field 5: Time of Absence ──
        'recordedAt': Timestamp.fromDate(now),
        'entryTime': Timestamp.fromDate(now),
        'exitTime': null,
        'note': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─────────────────────────────────────────
  //  MARK EXIT
  // ─────────────────────────────────────────
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

  // ─────────────────────────────────────────
  //  AI FLAG CHECK
  // ─────────────────────────────────────────
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

    final existingFlag =
        await _db
            .collection('ai_flags')
            .where('studentId', isEqualTo: studentId)
            .where('type', isEqualTo: flagType)
            .where('resolved', isEqualTo: false)
            .limit(1)
            .get();
    if (existingFlag.docs.isNotEmpty) return;

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
