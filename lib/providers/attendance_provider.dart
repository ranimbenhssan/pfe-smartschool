import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'teacher_provider.dart';

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
      return FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isEqualTo: date)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
          );
    });

// ─── Attendance By Date And Class ───
final attendanceByDateAndClassProvider = StreamProvider.family<
  List<AttendanceModel>,
  ({String date, String classId})
>((ref, params) {
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isEqualTo: params.date)
      .where('classId', isEqualTo: params.classId)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
      );
});

// ─── Stream combiner (sum of int streams) ───
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

// ─── Present Count By Date ───
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

// ─── Present Count By Date And Class ───
final presentCountByDateAndClassProvider =
    StreamProvider.family<int, ({String date, String classId})>((ref, params) {
      if (params.date.isEmpty || params.classId.isEmpty) {
        return Stream.value(0);
      }
      return FirebaseFirestore.instance
          .collection('attendance_counts')
          .where('date', isEqualTo: params.date)
          .where('classId', isEqualTo: params.classId)
          .snapshots()
          .map((snap) => snap.docs.length);
    });

// ─── Attendance By Student (all time) ───
final attendanceByStudentProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, studentId) {
      return FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .map((snap) {
            final list =
                snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList();
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return list;
          });
    });

// ─── Today's Attendance — uses FirebaseFirestore.instance directly ───
// This MUST match the instance used in teacher_namecall_screen.dart
final todayAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('date', isEqualTo: today)
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList(),
      );
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

// ─── Teacher today attendance (scoped to teacherId) ───
final teacherTodayAttendanceProvider =
    StreamProvider.family<List<AttendanceModel>, String>((ref, teacherId) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

// ─── All-time counts per student ───
final allTimePresentCountProvider = StreamProvider.family<int, String>((
  ref,
  studentId,
) {
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'present')
      .snapshots()
      .map((snap) => snap.docs.length);
});

final allTimeAbsentCountProvider = StreamProvider.family<int, String>((
  ref,
  studentId,
) {
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'absent')
      .snapshots()
      .map((snap) => snap.docs.length);
});

final allTimeLateCountProvider = StreamProvider.family<int, String>((
  ref,
  studentId,
) {
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('studentId', isEqualTo: studentId)
      .where('status', isEqualTo: 'late')
      .snapshots()
      .map((snap) => snap.docs.length);
});

// ─── Teacher class-scoped today counts ───
final _teacherPresentStreamProvider = StreamProvider<int>((ref) {
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

final teacherPresentCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(_teacherPresentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

final teacherAbsentCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(_teacherAbsentStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

final teacherLateCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(_teacherLateStreamProvider)
      .maybeWhen(data: (c) => c, orElse: () => 0);
});

// ─── Admin all-time attendance (absent + late) ───
final allTimeAttendanceProvider = StreamProvider<List<AttendanceModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('attendance')
      .where('status', whereIn: ['absent', 'late'])
      .snapshots()
      .map((snap) {
        final list =
            snap.docs.map((d) => AttendanceModel.fromFirestore(d)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
});

final allTimeAbsentCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(allTimeAttendanceProvider)
      .maybeWhen(
        data: (l) => l.where((a) => a.status == AttendanceStatus.absent).length,
        orElse: () => 0,
      );
});

final allTimeLateCountIntProvider = Provider<int>((ref) {
  return ref
      .watch(allTimeAttendanceProvider)
      .maybeWhen(
        data: (l) => l.where((a) => a.status == AttendanceStatus.late).length,
        orElse: () => 0,
      );
});

// ─── Admin search filter ───
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
