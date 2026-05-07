// lib/providers/semester_provider.dart
//
// This file REPLACES timetable_provider.dart entirely.
// After adding this file:
//   1. DELETE lib/providers/timetable_provider.dart
//   2. In providers.dart: REMOVE the timetable_provider.dart export line
//      and ADD: export 'semester_provider.dart';
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SEMESTER PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final semestersProvider = StreamProvider<List<SemesterModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('semesters')
      .orderBy('startDate', descending: true)
      .snapshots()
      .map((s) => s.docs.map(SemesterModel.fromFirestore).toList());
});

final activeSemesterProvider = StreamProvider<SemesterModel?>((ref) {
  return FirebaseFirestore.instance
      .collection('semesters')
      .where('isActive', isEqualTo: true)
      .limit(1)
      .snapshots()
      .map(
        (s) =>
            s.docs.isEmpty ? null : SemesterModel.fromFirestore(s.docs.first),
      );
});

final currentWeekTypeProvider = Provider<String>((ref) {
  return ref
      .watch(activeSemesterProvider)
      .maybeWhen(
        data: (sem) => sem?.weekTypeFor(DateTime.now()) ?? '',
        orElse: () => '',
      );
});

final weekTypeForDateProvider = Provider.family<String, DateTime>((ref, date) {
  return ref
      .watch(activeSemesterProvider)
      .maybeWhen(data: (sem) => sem?.weekTypeFor(date) ?? '', orElse: () => '');
});

/// The active school closure covering today, or null.
final todaySchoolClosureProvider = Provider<SchoolClosure?>((ref) {
  return ref
      .watch(activeSemesterProvider)
      .maybeWhen(
        data: (sem) => sem?.closureFor(DateTime.now()),
        orElse: () => null,
      );
});

/// The fixed holiday matching today, or null.
final todayFixedHolidayProvider = Provider<FixedHoliday?>((ref) {
  return ref
      .watch(activeSemesterProvider)
      .maybeWhen(
        data: (sem) => sem?.fixedHolidayFor(DateTime.now()),
        orElse: () => null,
      );
});

/// True when today is a normal school day (not weekend / holiday / closure).
final isTodaySchoolDayProvider = Provider<bool>((ref) {
  final today = DateTime.now();
  if (today.weekday == DateTime.saturday) return false;
  if (today.weekday == DateTime.sunday) return false;
  if (ref.watch(todaySchoolClosureProvider) != null) return false;
  if (ref.watch(todayFixedHolidayProvider) != null) return false;
  return true;
});

// ─────────────────────────────────────────────────────────────────────────────
//  TIMETABLE PROVIDERS  (week-type + closure aware)
//  These replace the identical providers that were in timetable_provider.dart.
// ─────────────────────────────────────────────────────────────────────────────

/// Class timetable filtered to the current week type.
/// Returns empty list on school closures / holidays.
final timetableByClassProvider =
    StreamProvider.family<List<TimetableModel>, String>((ref, classId) {
      if (!ref.watch(isTodaySchoolDayProvider)) return Stream.value([]);
      final weekType = ref.watch(currentWeekTypeProvider);

      return FirebaseFirestore.instance
          .collection('timetable')
          .where('classId', isEqualTo: classId)
          .snapshots()
          .map(
            (snap) =>
                snap.docs
                    .map(TimetableModel.fromFirestore)
                    .where((t) => t.matchesWeek(weekType))
                    .toList(),
          );
    });

/// Teacher timetable filtered to the current week type.
final timetableByTeacherProvider =
    StreamProvider.family<List<TimetableModel>, String>((ref, teacherId) {
      if (!ref.watch(isTodaySchoolDayProvider)) return Stream.value([]);
      final weekType = ref.watch(currentWeekTypeProvider);

      return FirebaseFirestore.instance
          .collection('timetable')
          .where('teacherId', isEqualTo: teacherId)
          .snapshots()
          .map(
            (snap) =>
                snap.docs
                    .map(TimetableModel.fromFirestore)
                    .where((t) => t.matchesWeek(weekType))
                    .toList(),
          );
    });

/// Full timetable for admin (all entries, all weeks, no filtering).
final fullTimetableProvider = StreamProvider<List<TimetableModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getFullTimetable();
});

/// Week A template for a class.
final weekATemplateProvider =
    StreamProvider.family<List<TimetableModel>, String>((ref, classId) {
      return FirebaseFirestore.instance
          .collection('timetable')
          .where('classId', isEqualTo: classId)
          .where('weekType', isEqualTo: 'A')
          .snapshots()
          .map((s) => s.docs.map(TimetableModel.fromFirestore).toList());
    });

/// Week B template for a class.
final weekBTemplateProvider =
    StreamProvider.family<List<TimetableModel>, String>((ref, classId) {
      return FirebaseFirestore.instance
          .collection('timetable')
          .where('classId', isEqualTo: classId)
          .where('weekType', isEqualTo: 'B')
          .snapshots()
          .map((s) => s.docs.map(TimetableModel.fromFirestore).toList());
    });

/// Selected day filter (used on admin timetable screen).
final selectedDayProvider = StateProvider<int?>((ref) => null);
final selectedDayNameProvider = StateProvider<String?>((ref) => null);

/// Filtered timetable by class + selected day.
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

/// Real-time current timetable slot for a class (the session active right now).
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
  final weekType = ref.watch(currentWeekTypeProvider);

  return FirebaseFirestore.instance
      .collection('timetable')
      .where('classId', isEqualTo: classId)
      .where('dayOfWeek', isEqualTo: dayName)
      .snapshots()
      .map((snap) {
        final curr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        for (final doc in snap.docs) {
          final t = TimetableModel.fromFirestore(doc);
          if (!t.matchesWeek(weekType)) continue;
          if (curr.compareTo(t.startTime) >= 0 &&
              curr.compareTo(t.endTime) <= 0) {
            return t;
          }
        }
        return null;
      });
});
