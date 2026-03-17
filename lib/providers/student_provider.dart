import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── All Students Stream ───
final studentsProvider = StreamProvider<List<StudentModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getStudents();
});

// ─── Students By Class Stream ───
final studentsByClassProvider =
    StreamProvider.family<List<StudentModel>, String>((ref, classId) {
  return ref.watch(firestoreServiceProvider).getStudentsByClass(classId);
});

// ─── Single Student ───
final studentProvider =
    FutureProvider.family<StudentModel?, String>((ref, studentId) {
  return ref.watch(firestoreServiceProvider).getStudent(studentId);
});

// ─── Search Query State ───
final studentSearchQueryProvider = StateProvider<String>((ref) => '');

// ─── Filtered Students ───
final filteredStudentsProvider = Provider<AsyncValue<List<StudentModel>>>((ref) {
  final students = ref.watch(studentsProvider);
  final query = ref.watch(studentSearchQueryProvider).toLowerCase();

  return students.whenData((list) {
    if (query.isEmpty) return list;
    return list
        .where((s) =>
            s.name.toLowerCase().contains(query) ||
            s.email.toLowerCase().contains(query) ||
            s.rfidTag.toLowerCase().contains(query) ||
            s.className.toLowerCase().contains(query))
        .toList();
  });
});

// ─── Student Count ───
final studentCountProvider = Provider<int>((ref) {
  return ref.watch(studentsProvider).maybeWhen(
        data: (list) => list.length,
        orElse: () => 0,
      );
});