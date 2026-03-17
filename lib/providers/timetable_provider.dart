import 'package:flutter_riverpod/flutter_riverpod.dart';
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

// ─── Selected Day Filter ───
final selectedDayProvider = StateProvider<int?>((ref) => null);

// ─── Filtered Timetable ───
final filteredTimetableProvider =
    Provider.family<AsyncValue<List<TimetableModel>>, String>((ref, classId) {
      final timetable = ref.watch(timetableByClassProvider(classId));
      final selectedDay = ref.watch(selectedDayProvider);

      return timetable.whenData((list) {
        if (selectedDay == null) return list;
        return list.where((t) => t.dayOfWeek == selectedDay).toList();
      });
    });

// ─── Today's Timetable For Class ───
final todayTimetableProvider =
    Provider.family<AsyncValue<List<TimetableModel>>, String>((ref, classId) {
      final timetable = ref.watch(timetableByClassProvider(classId));
      final todayWeekday = DateTime.now().weekday;

      return timetable.whenData((list) {
        return list.where((t) => t.dayOfWeek == todayWeekday).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
      });
    });
