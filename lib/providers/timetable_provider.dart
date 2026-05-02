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

// ─── Selected Day Filter ───
final selectedDayProvider = StateProvider<int?>((ref) => null);

// ─── Filtered Timetable ───
final filteredTimetableProvider =
    Provider.family<AsyncValue<List<TimetableModel>>, String>((ref, classId) {
      final timetable = ref.watch(timetableByClassProvider(classId));
      final selectedDay = ref.watch(selectedDayProvider);

      return timetable.whenData((list) {
        if (selectedDay == null) return list;
        return list.where((t) => t.dayOfWeek == selectedDay.toString()).toList();
      });
    });

// ─── Today's Timetable For Class ───
// ─── Real-time current timetable slot ───
final currentTimetableSlotProvider =
    StreamProvider.family<TimetableModel?, String>((ref, classId) {
  if (classId.isEmpty) return Stream.value(null);

  final now = DateTime.now();
  const days = [
    '', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  final dayName = days[now.weekday];

  // ─── Real-time stream filtered by class and day ───
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
      if (data == null) continue;

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