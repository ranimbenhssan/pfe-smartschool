import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─────────────────────────────────────────
//  DATE HELPERS
// ─────────────────────────────────────────

final todayStringProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final selectedDateStringProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM-dd').format(ref.watch(selectedDateProvider));
});

// ─────────────────────────────────────────
//  ATTENDANCE STREAMS
// ─────────────────────────────────────────

final attendanceByDateProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, date) {
      return ref.watch(firestoreServiceProvider).getAttendanceByDate(date);
    });

final attendanceByDateAndClassProvider = StreamProvider.family<
  List<AttendanceModel>,
  ({String date, String classId})
>((ref, params) {
  return ref
      .watch(firestoreServiceProvider)
      .getAttendanceByDateAndClass(params.date, params.classId);
});

final attendanceByStudentProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, studentId) {
      return ref
          .watch(firestoreServiceProvider)
          .getAttendanceByStudent(studentId);
    });

final todayAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  return ref
      .watch(firestoreServiceProvider)
      .getAttendanceByDate(ref.watch(todayStringProvider));
});

// ─────────────────────────────────────────
//  TODAY ATTENDANCE — RAW STREAMS (internal)
//  These are StreamProviders used only to back the int Providers below.
//  DO NOT expose them to UI directly — use the int providers.
// ─────────────────────────────────────────

/// Internal stream: number of attendance_counts docs for today.
/// attendance_counts/{studentId}_{date} is written for every Present mark.
final _todayPresentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  return FirebaseFirestore.instance
      .collection('attendance_counts')
      .where('date', isEqualTo: today)
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Internal stream: absent docs from attendance collection for today.
final _todayAbsentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isEqualTo: today)
      .where('status', isEqualTo: 'absent')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Internal stream: late docs from attendance collection for today.
final _todayLateStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isEqualTo: today)
      .where('status', isEqualTo: 'late')
      .snapshots()
      .map((snap) => snap.docs.length);
});

// ─────────────────────────────────────────
//  TODAY COUNT PROVIDERS — return int (NOT AsyncValue<int>)
//  Safe to call .toString() directly in UI.
// ─────────────────────────────────────────

/// Present count today — reads from attendance_counts collection.
/// Returns 0 while loading or on error.
final todayPresentCountProvider = Provider<int>((ref) {
  return ref
      .watch(_todayPresentStreamProvider)
      .maybeWhen(data: (count) => count, orElse: () => 0);
});

/// Absent count today — reads from attendance collection.
final todayAbsentCountProvider = Provider<int>((ref) {
  return ref
      .watch(_todayAbsentStreamProvider)
      .maybeWhen(data: (count) => count, orElse: () => 0);
});

/// Late count today — reads from attendance collection.
final todayLateCountProvider = Provider<int>((ref) {
  return ref
      .watch(_todayLateStreamProvider)
      .maybeWhen(data: (count) => count, orElse: () => 0);
});

// ─────────────────────────────────────────
//  DATE-FILTERED PRESENT COUNTS (int providers)
// ─────────────────────────────────────────

/// Present count for any specific date.
final presentCountByDateProvider = StreamProvider.family<int, String>((
  ref,
  date,
) {
  if (date.isEmpty) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('attendance_counts')
      .where('date', isEqualTo: date)
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// Present count for a specific date + class combination.
final presentCountByDateAndClassProvider =
    StreamProvider.family<int, ({String date, String classId})>((ref, params) {
      if (params.date.isEmpty || params.classId.isEmpty) return Stream.value(0);
      return FirebaseFirestore.instance
          .collection('attendance_counts')
          .where('date', isEqualTo: params.date)
          .where('classId', isEqualTo: params.classId)
          .snapshots()
          .map((snap) => snap.docs.length);
    });

/// Present count for a class across all dates.
final presentCountByClassProvider = StreamProvider.family<int, String>((
  ref,
  classId,
) {
  if (classId.isEmpty) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('attendance_counts')
      .where('classId', isEqualTo: classId)
      .snapshots()
      .map((snap) => snap.docs.length);
});

// ─────────────────────────────────────────
//  ALL-TIME CUMULATIVE (absent + late only)
// ─────────────────────────────────────────

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

final allTimeAbsentCountProvider = Provider<int>((ref) {
  return ref
      .watch(allTimeAttendanceProvider)
      .maybeWhen(
        data:
            (list) =>
                list.where((a) => a.status == AttendanceStatus.absent).length,
        orElse: () => 0,
      );
});

final allTimeLateCountProvider = Provider<int>((ref) {
  return ref
      .watch(allTimeAttendanceProvider)
      .maybeWhen(
        data:
            (list) =>
                list.where((a) => a.status == AttendanceStatus.late).length,
        orElse: () => 0,
      );
});

// ─────────────────────────────────────────
//  SEARCH FILTER (admin attendance screen)
// ─────────────────────────────────────────

final attendanceSearchQueryProvider = StateProvider<String>((ref) => '');

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

// ─────────────────────────────────────────
//  STUDENT ATTENDANCE STATS (utility)
// ─────────────────────────────────────────

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
