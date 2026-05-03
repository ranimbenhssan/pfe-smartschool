import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Full Timetable (Admin) ───
final fullTimetableProvider = StreamProvider<List<TimetableModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getFullTimetable();
});

// ─── Timetable By Class ───
final timetableByClassProvider =
    StreamProvider.family<List<TimetableModel>, String>((ref, classId) {
      return ref.watch(firestoreServiceProvider).getTimetableByClass(classId);
    });

// ─── Timetable By Teacher ───
final timetableByTeacherProvider =
    StreamProvider.family<List<TimetableModel>, String>((ref, teacherId) {
      return ref
          .watch(firestoreServiceProvider)
          .getTimetableByTeacher(teacherId);
    });

// ─────────────────────────────────────────
//  Classes by Teacher — derived from timetable.teacherId
//
//  This is the correct source of truth for "which classes does this
//  teacher teach?". It does NOT rely on classes.teacherIds arrays
//  or teachers.assignedClassIds, which can be stale.
// ─────────────────────────────────────────
final classesByTeacherProvider =
    StreamProvider.family<List<ClassModel>, String>((ref, teacherId) {
      if (teacherId.isEmpty) return Stream.value([]);
      return ref.watch(firestoreServiceProvider).getClassesByTeacher(teacherId);
    });

// ─────────────────────────────────────────
//  Current Teacher — fetched directly by Auth UID
//
//  Avoids scanning all teachers. The teachers/{uid} doc id IS the uid.
// ─────────────────────────────────────────
final currentTeacherProvider = StreamProvider<TeacherModel?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(firestoreServiceProvider).getTeacherStream(user.uid);
    },
  );
});

// ─── Selected Day Filter ───
final selectedDayProvider = StateProvider<int?>((ref) => null);

// ─── Filtered Timetable (by class + optional day) ───
final filteredTimetableProvider =
    Provider.family<AsyncValue<List<TimetableModel>>, String>((ref, classId) {
      final timetable = ref.watch(timetableByClassProvider(classId));
      final selectedDay = ref.watch(selectedDayProvider);

      return timetable.whenData((list) {
        if (selectedDay == null) return list;
        return list
            .where((t) => t.dayOfWeek == selectedDay.toString())
            .toList();
      });
    });

// ─── Real-time current timetable slot for a class ───
final currentTimetableSlotProvider = StreamProvider.family<
  TimetableModel?,
  String
>((ref, classId) {
  if (classId.isEmpty) return Stream.value(null);

  final now = DateTime.now();
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
  final dayName = days[now.weekday];

  return FirebaseFirestore.instance
      .collection('timetable')
      .where('classId', isEqualTo: classId)
      .where('dayOfWeek', isEqualTo: dayName)
      .snapshots()
      .map((snap) {
        final currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

        for (final doc in snap.docs) {
          final data = doc.data();
          final start = data['startTime']?.toString() ?? '';
          final end = data['endTime']?.toString() ?? '';
          if (start.isEmpty || end.isEmpty) continue;
          if (currentTime.compareTo(start) >= 0 &&
              currentTime.compareTo(end) <= 0) {
            return TimetableModel.fromFirestore(doc);
          }
        }
        return null;
      });
});
