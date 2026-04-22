import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
final todayTimetableProvider =
    Provider.family<AsyncValue<List<TimetableModel>>, String>((ref, classId) {
      final timetable = ref.watch(timetableByClassProvider(classId));
      final todayWeekday = DateTime.now().weekday;

      return timetable.whenData((list) {
        return list.where((t) => t.dayOfWeek == todayWeekday.toString()).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
      });
    });
    final currentTimetableSlotProvider =
    FutureProvider.family<TimetableModel?, String>((ref, classId) async {
  if (classId.isEmpty) return null;  // ← guard

  try {
    final now = DateTime.now();
    const days = [
      '', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final dayName = days[now.weekday];
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final snap = await FirebaseFirestore.instance
        .collection('timetable')
        .where('classId', isEqualTo: classId)
        .where('dayOfWeek', isEqualTo: dayName)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final start = data['startTime']?.toString() ?? '';
      final end = data['endTime']?.toString() ?? '';
      if (start.isNotEmpty &&
          end.isNotEmpty &&
          currentTime.compareTo(start) >= 0 &&
          currentTime.compareTo(end) <= 0) {
        return TimetableModel.fromFirestore(doc);
      }
    }
    return null;
  } catch (e) {
    debugPrint('currentTimetableSlotProvider error: $e');
    return null;
  }
});
