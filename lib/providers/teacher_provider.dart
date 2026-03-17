import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── All Teachers Stream ───
final teachersProvider = StreamProvider<List<TeacherModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getTeachers();
});

// ─── Single Teacher ───
final teacherProvider =
    FutureProvider.family<TeacherModel?, String>((ref, teacherId) {
  return ref.watch(firestoreServiceProvider).getTeacher(teacherId);
});

// ─── Teacher Search Query ───
final teacherSearchQueryProvider = StateProvider<String>((ref) => '');

// ─── Filtered Teachers ───
final filteredTeachersProvider =
    Provider<AsyncValue<List<TeacherModel>>>((ref) {
  final teachers = ref.watch(teachersProvider);
  final query = ref.watch(teacherSearchQueryProvider).toLowerCase();

  return teachers.whenData((list) {
    if (query.isEmpty) return list;
    return list
        .where((t) =>
            t.name.toLowerCase().contains(query) ||
            t.email.toLowerCase().contains(query))
        .toList();
  });
});

// ─── Teacher Count ───
final teacherCountProvider = Provider<int>((ref) {
  return ref.watch(teachersProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});