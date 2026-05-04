import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Today's Date String ───
final todayStringProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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

// ─── Today's Present Count Stream ───
final todayPresentCountStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  return ref.watch(firestoreServiceProvider).getPresentCountByDate(today);
});

// ─── Today's Present Count ───
final todayPresentCountProvider = Provider<int>((ref) {
  return ref
      .watch(todayPresentCountStreamProvider)
      .maybeWhen(data: (count) => count, orElse: () => 0);
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

/// Stream of ALL absence records across all dates (no date filter).
final allTimeAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('status', whereIn: ['absent', 'late'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
      );
});

/// Total absent records across ALL time.
final allTimeAbsentCountProvider = Provider<int>((ref) {
  final all = ref.watch(allTimeAttendanceProvider);
  return all.when(
    data:
        (list) => list.where((a) => a.status == AttendanceStatus.absent).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Total late records across ALL time.
final allTimeLateCountProvider = Provider<int>((ref) {
  final all = ref.watch(allTimeAttendanceProvider);
  return all.when(
    data: (list) => list.where((a) => a.status == AttendanceStatus.late).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// ─────────────────────────────────────────
//  STUDENT NAME SEARCH FILTER
//  Applied client-side on allTimeAttendanceProvider.
//  Empty query → full list.
// ─────────────────────────────────────────

/// The current search query for attendance student filter.
final attendanceSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtered all-time attendance records by student name.
final filteredAttendanceProvider = Provider<AsyncValue<List<AttendanceModel>>>((
  ref,
) {
  final query = ref.watch(attendanceSearchQueryProvider).toLowerCase().trim();
  final allAsync = ref.watch(allTimeAttendanceProvider);

  return allAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
    data: (list) {
      if (query.isEmpty) return AsyncValue.data(list);
      return AsyncValue.data(
        list.where((a) => a.studentName.toLowerCase().contains(query)).toList(),
      );
    },
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
