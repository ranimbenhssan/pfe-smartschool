import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/services.dart';
// ─── Direct import so teacherClassIdsProvider resolves without the barrel ─────
import 'teacher_provider.dart';

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
//  'attendance'        → absent + late records only
//  'attendance_counts' → present records (one doc per student per day)
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
//  STREAM COMBINER
//  Merges N int streams into one sum stream.
//  onCancel cancels all Firestore subscriptions on disposal.
// ─────────────────────────────────────────

Stream<int> _sumStreams(List<Stream<int>> streams) {
  if (streams.isEmpty) return Stream.value(0);
  if (streams.length == 1) return streams.first;

  late StreamController<int> controller;
  final counts = List<int>.filled(streams.length, 0);
  final subs = <StreamSubscription<int>>[];
  int activeSubs = streams.length;

  controller = StreamController<int>(
    onListen: () {
      for (int i = 0; i < streams.length; i++) {
        final idx = i;
        subs.add(
          streams[idx].listen(
            (c) {
              counts[idx] = c;
              if (!controller.isClosed) {
                controller.add(counts.fold(0, (a, b) => a + b));
              }
            },
            onError: (Object e) {
              if (!controller.isClosed) controller.addError(e);
            },
            onDone: () {
              activeSubs--;
              if (activeSubs == 0 && !controller.isClosed) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final sub in subs) {
        await sub.cancel();
      }
      subs.clear();
    },
  );

  return controller.stream;
}

// ─────────────────────────────────────────
//  ADMIN — SCHOOL-WIDE TODAY COUNTS
//  Present : attendance_counts WHERE date == today
//  Absent  : attendance WHERE date == today AND status == 'absent'
//  Late    : attendance WHERE date == today AND status == 'late'
// ─────────────────────────────────────────

final _adminPresentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  return FirebaseFirestore.instance
      .collection('attendance_counts')
      .where('date', isEqualTo: today)
      .snapshots()
      .map((snap) => snap.docs.length);
});

final _adminAbsentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isEqualTo: today)
      .where('status', isEqualTo: 'absent')
      .snapshots()
      .map((snap) => snap.docs.length);
});

final _adminLateStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isEqualTo: today)
      .where('status', isEqualTo: 'late')
      .snapshots()
      .map((snap) => snap.docs.length);
});

/// School-wide present count for today — plain int
final todayPresentCountProvider = Provider<int>((ref) {
  return ref
      .watch(_adminPresentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

/// School-wide absent count for today — plain int
final todayAbsentCountProvider = Provider<int>((ref) {
  return ref
      .watch(_adminAbsentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

/// School-wide late count for today — plain int
final todayLateCountProvider = Provider<int>((ref) {
  return ref
      .watch(_adminLateStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

final teacherTodayAttendanceProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, teacherId) {
      final today = ref.watch(todayStringProvider);
      return FirebaseFirestore.instance
          .collection('attendance')
          .where('teacherId', isEqualTo: teacherId)
          .where('date', isEqualTo: today)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
          );
    });

// ─────────────────────────────────────────
//  TEACHER — CLASS-SCOPED TODAY COUNTS
//
//  teacherClassIdsProvider is defined in teacher_provider.dart (imported above).
//  One Firestore query per classId, combined via _sumStreams.
//  Automatically increments when attendance_counts doc is added (present mark)
//  and decrements when it is deleted (toggled to absent/late).
// ─────────────────────────────────────────

final _teacherPresentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  final classAsync = ref.watch(
    teacherClassIdsProvider,
  ); // teacher_provider.dart

  return classAsync.when(
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
    data: (classIds) {
      if (classIds.isEmpty) return Stream.value(0);
      return _sumStreams(
        classIds
            .map(
              (id) => FirebaseFirestore.instance
                  .collection('attendance_counts')
                  .where('date', isEqualTo: today)
                  .where('classId', isEqualTo: id)
                  .snapshots()
                  .map((snap) => snap.docs.length),
            )
            .toList(),
      );
    },
  );
});

final _teacherAbsentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  final classAsync = ref.watch(teacherClassIdsProvider);

  return classAsync.when(
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
    data: (classIds) {
      if (classIds.isEmpty) return Stream.value(0);
      return _sumStreams(
        classIds
            .map(
              (id) => FirebaseFirestore.instance
                  .collection('attendance')
                  .where('date', isEqualTo: today)
                  .where('classId', isEqualTo: id)
                  .where('status', isEqualTo: 'absent')
                  .snapshots()
                  .map((snap) => snap.docs.length),
            )
            .toList(),
      );
    },
  );
});

final _teacherLateStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  final classAsync = ref.watch(teacherClassIdsProvider);

  return classAsync.when(
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
    data: (classIds) {
      if (classIds.isEmpty) return Stream.value(0);
      return _sumStreams(
        classIds
            .map(
              (id) => FirebaseFirestore.instance
                  .collection('attendance')
                  .where('date', isEqualTo: today)
                  .where('classId', isEqualTo: id)
                  .where('status', isEqualTo: 'late')
                  .snapshots()
                  .map((snap) => snap.docs.length),
            )
            .toList(),
      );
    },
  );
});

/// Teacher class-scoped present count — plain int
final teacherPresentCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(_teacherPresentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

/// Teacher class-scoped absent count — plain int
final teacherAbsentCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(_teacherAbsentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

/// Teacher class-scoped late count — plain int
final teacherLateCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(_teacherLateStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

// ─────────────────────────────────────────
//  DATE + CLASS FILTERED PRESENT COUNTS
//  Used by by-date and by-class admin screens.
// ─────────────────────────────────────────

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
//  ALL-TIME CUMULATIVE (absent + late, never resets)
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
        data: (l) => l.where((a) => a.status == AttendanceStatus.absent).length,
        orElse: () => 0,
      );
});

final allTimeLateCountProvider = Provider<int>((ref) {
  return ref
      .watch(allTimeAttendanceProvider)
      .maybeWhen(
        data: (l) => l.where((a) => a.status == AttendanceStatus.late).length,
        orElse: () => 0,
      );
});

// ─────────────────────────────────────────
//  ADMIN SEARCH FILTER
// ─────────────────────────────────────────

final attendanceSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAttendanceProvider = Provider<AsyncValue<List<AttendanceModel>>>((
  ref,
) {
  final query = ref.watch(attendanceSearchQueryProvider).toLowerCase().trim();
  final allAsync = ref.watch(allTimeAttendanceProvider);

  return allAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (list) {
      if (query.isEmpty) return AsyncValue.data(list);
      return AsyncValue.data(
        list.where((a) => a.studentName.toLowerCase().contains(query)).toList(),
      );
    },
  );
});

// ─────────────────────────────────────────
//  UTILITY
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
