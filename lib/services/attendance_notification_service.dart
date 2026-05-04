import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Writes an in-app notification to the student's notifications feed
/// whenever their attendance status is marked or toggled.
///
/// Call this from teacher_namecall_screen after every successful batch.commit().
class AttendanceNotificationService {
  static Future<void> notify({
    required String studentUserId, // users/{id} — the student's auth uid
    required String studentName,
    required String newStatus, // 'present' | 'absent' | 'late'
    required String previousStatus, // '' = first mark, non-empty = toggle
    required String subject,
    required String className, // "3 IOT 1" — Level + Name + Grade
    required String scheduledStart,
    required String scheduledEnd,
    required String teacherName,
    required String teacherId,
    required String date,
  }) async {
    if (studentUserId.isEmpty) return;

    final isToggle = previousStatus.isNotEmpty && previousStatus != newStatus;

    final emoji =
        newStatus == 'present'
            ? '✅'
            : newStatus == 'late'
            ? '⚠️'
            : '❌';

    final statusLabel =
        newStatus == 'present'
            ? 'Present'
            : newStatus == 'late'
            ? 'Late'
            : 'Absent';

    final title =
        isToggle ? 'Attendance Updated $emoji' : 'Attendance Marked $emoji';

    final session =
        subject.isNotEmpty
            ? '$subject ($scheduledStart – $scheduledEnd)'
            : 'Current session';

    final body =
        isToggle
            ? 'Your status for $session in $className has been '
                'updated to $statusLabel by $teacherName.'
            : 'You have been marked $statusLabel for $session in $className.';

    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': studentUserId,
        'senderId': teacherId,
        'senderName': teacherName,
        'senderRole': 'teacher',
        'title': title,
        'message': body,
        'messageType': 'attendance',
        'attachments': [],
        'recipientLabel': className,
        'replyToId': '',
        'replyToTitle': '',
        'isRead': false,
        // Metadata — lets the dashboard read status without re-querying attendance
        'attendanceStatus': newStatus,
        'attendanceSubject': subject,
        'attendanceDate': date,
        'attendanceSession': session,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AttendanceNotificationService.notify: $e');
    }
  }
}
