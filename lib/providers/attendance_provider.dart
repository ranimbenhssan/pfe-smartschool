import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'teacher_provider.dart';
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
//  TEACHER'S ASSIGNED CLASS IDs
//
//  Primary source: TeacherModel.assignedClassIds (from teacher doc).
//  Fallback:       timetable WHERE teacherId == u.id  (for teachers
//                  whose assignedClassIds array is empty or stale).
//
//  Both sources are live streams so new assignments appear immediately.
// ─────────────────────────────────────────

final teacherClassIdsProvider = StreamProvider<List<String>>((ref) {
  final teacherAsync = ref.watch(currentTeacherProvider);
  final user = ref.watch(currentUserProvider);

  return teacherAsync.when(
    loading: () => Stream.value(<String>[]),
    error: (_, __) => Stream.value(<String>[]),
    data: (teacher) {
      if (teacher == null) return Stream.value(<String>[]);

      // If assignedClassIds is populated, use it directly
      if (teacher.assignedClassIds.isNotEmpty) {
        return Stream.value(teacher.assignedClassIds);
      }

      // Fallback: derive from timetable entries for this teacher
      return user.when(
        data: (u) {
          if (u == null) return Stream.value(<String>[]);
          return FirebaseFirestore.instance
              .collection('timetable')
              .where('teacherId', isEqualTo: u.id)
              .snapshots()
              .map(
                (snap) =>
                    snap.docs
                        .map((d) => d.data()['classId']?.toString() ?? '')
                        .where((id) => id.isNotEmpty)
                        .toSet()
                        .toList(),
              );
        },
        loading: () => Stream.value(<String>[]),
        error: (_, __) => Stream.value(<String>[]),
      );
    },
  );
});

// ─────────────────────────────────────────
//  PRESENT COUNT HELPERS
//  attendance_counts/{studentId}_{date} — one doc per present student per day
//  Queried by date (+ optional classId) to get live present counts.
// ─────────────────────────────────────────

/// Merges multiple count streams into a single sum stream.
/// Clean implementation using StreamController with proper cleanup.
Stream<int> _sumStreams(List<Stream<int>> streams) {
  if (streams.isEmpty) return Stream.value(0);
  if (streams.length == 1) return streams.first;

  late StreamController<int> controller;
  final counts = List<int>.filled(streams.length, 0);
  final subs = <StreamSubscription>[];
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
            onError: (e) {
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
    onCancel: () {
      for (final sub in subs) {
        sub.cancel();
      }
    },
  );

  return controller.stream;
}

// ─────────────────────────────────────────
//  ADMIN — GLOBAL TODAY COUNTS
//  Present: attendance_counts WHERE date == today (all school)
//  Absent/Late: attendance WHERE date == today AND status == x
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

/// Plain int — safe to use directly in UI (no .maybeWhen needed)
final todayPresentCountProvider = Provider<int>(
  (ref) => ref
      .watch(_adminPresentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0),
);

final todayAbsentCountProvider = Provider<int>(
  (ref) => ref
      .watch(_adminAbsentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0),
);

final todayLateCountProvider = Provider<int>(
  (ref) => ref
      .watch(_adminLateStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0),
);

// ─────────────────────────────────────────
//  TEACHER — CLASS-SCOPED TODAY COUNTS
//  Filtered to the teacher's assigned classIds only.
// ─────────────────────────────────────────

final _teacherPresentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  final classIds = ref.watch(teacherClassIdsProvider);

  return classIds.when(
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
    data: (ids) {
      if (ids.isEmpty) return Stream.value(0);
      // One stream per class, summed
      final streams =
          ids
              .map(
                (id) => FirebaseFirestore.instance
                    .collection('attendance_counts')
                    .where('date', isEqualTo: today)
                    .where('classId', isEqualTo: id)
                    .snapshots()
                    .map((snap) => snap.docs.length),
              )
              .toList();
      return _sumStreams(streams);
    },
  );
});

final _teacherAbsentStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  final classIds = ref.watch(teacherClassIdsProvider);

  return classIds.when(
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
    data: (ids) {
      if (ids.isEmpty) return Stream.value(0);
      final streams =
          ids
              .map(
                (id) => FirebaseFirestore.instance
                    .collection('attendance')
                    .where('date', isEqualTo: today)
                    .where('classId', isEqualTo: id)
                    .where('status', isEqualTo: 'absent')
                    .snapshots()
                    .map((snap) => snap.docs.length),
              )
              .toList();
      return _sumStreams(streams);
    },
  );
});

final _teacherLateStreamProvider = StreamProvider<int>((ref) {
  final today = ref.watch(todayStringProvider);
  final classIds = ref.watch(teacherClassIdsProvider);

  return classIds.when(
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
    data: (ids) {
      if (ids.isEmpty) return Stream.value(0);
      final streams =
          ids
              .map(
                (id) => FirebaseFirestore.instance
                    .collection('attendance')
                    .where('date', isEqualTo: today)
                    .where('classId', isEqualTo: id)
                    .where('status', isEqualTo: 'late')
                    .snapshots()
                    .map((snap) => snap.docs.length),
              )
              .toList();
      return _sumStreams(streams);
    },
  );
});

/// Plain int wrappers for teacher counts
final teacherPresentCountIntProvider = Provider<int>(
  (ref) => ref
      .watch(_teacherPresentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0),
);

final teacherAbsentCountIntProvider = Provider<int>(
  (ref) => ref
      .watch(_teacherAbsentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0),
);

final teacherLateCountIntProvider = Provider<int>(
  (ref) => ref
      .watch(_teacherLateStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0),
);

// ─────────────────────────────────────────
//  DATE-FILTERED PRESENT COUNTS (for by-date / by-class screens)
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
