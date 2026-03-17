import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Today's Date String ───
final todayStringProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
});

// ─── Selected Date ───
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

// ─── Selected Date String ───
final selectedDateStringProvider = Provider<String>((ref) {
  final date = ref.watch(selectedDateProvider);
  return DateFormat('yyyy-MM-dd').format(date);
});

// ─── Attendance By Date ───
final attendanceByDateProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, date) {
      return ref.watch(firestoreServiceProvider).getAttendanceByDate(date);
    });

// ─── Attendance By Date And Class ───
final attendanceByDateAndClassProvider = StreamProvider.family<
  List<AttendanceModel>,
  ({String date, String classId})
>((ref, params) {
  return ref
      .watch(firestoreServiceProvider)
      .getAttendanceByDateAndClass(params.date, params.classId);
});

// ─── Attendance By Student ───
final attendanceByStudentProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, studentId) {
      return ref
          .watch(firestoreServiceProvider)
          .getAttendanceByStudent(studentId);
    });

// ─── Today's Attendance ───
final todayAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final today = ref.watch(todayStringProvider);
  return ref.watch(firestoreServiceProvider).getAttendanceByDate(today);
});

// ─── Today's Present Count ───
final todayPresentCountProvider = Provider<int>((ref) {
  return ref
      .watch(todayAttendanceProvider)
      .maybeWhen(
        data:
            (list) =>
                list.where((a) => a.status == AttendanceStatus.present).length,
        orElse: () => 0,
      );
});

// ─── Today's Absent Count ───
final todayAbsentCountProvider = Provider<int>((ref) {
  return ref
      .watch(todayAttendanceProvider)
      .maybeWhen(
        data:
            (list) =>
                list.where((a) => a.status == AttendanceStatus.absent).length,
        orElse: () => 0,
      );
});

// ─── Today's Late Count ───
final todayLateCountProvider = Provider<int>((ref) {
  return ref
      .watch(todayAttendanceProvider)
      .maybeWhen(
        data:
            (list) =>
                list.where((a) => a.status == AttendanceStatus.late).length,
        orElse: () => 0,
      );
});

// ─── Attendance Stats For Student ───
final studentAttendanceStatsProvider =
    Provider.family<Map<String, int>, List<AttendanceModel>>((ref, list) {
      return {
        'present':
            list.where((a) => a.status == AttendanceStatus.present).length,
        'absent': list.where((a) => a.status == AttendanceStatus.absent).length,
        'late': list.where((a) => a.status == AttendanceStatus.late).length,
        'total': list.length,
      };
    });
