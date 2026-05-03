import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── All Teachers Stream ───
final teachersProvider = StreamProvider<List<TeacherModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getTeachers();
});

// ─── Single Teacher ───
final teacherProvider = FutureProvider.family<TeacherModel?, String>((
  ref,
  teacherId,
) {
  return ref.watch(firestoreServiceProvider).getTeacherById(teacherId);
});

// ─── Current logged-in teacher (matches auth UID against teachers collection) ───
// Fixes: avoids scanning all teachers in every screen that needs the teacher doc.
// The teachers/{uid} doc id IS the uid, so we fetch directly by doc id.
final currentTeacherProvider = StreamProvider<TeacherModel?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
    data: (user) {
      if (user == null) return Stream.value(null);
      // teachers/{uid} — doc id equals the Firebase Auth uid
      return ref.watch(firestoreServiceProvider).getTeacherStream(user.uid);
    },
  );
});

// ─── Teacher Search Query ───
final teacherSearchQueryProvider = StateProvider<String>((ref) => '');

// ─── Filtered Teachers ───
final filteredTeachersProvider = Provider<AsyncValue<List<TeacherModel>>>((
  ref,
) {
  final teachers = ref.watch(teachersProvider);
  final query = ref.watch(teacherSearchQueryProvider).toLowerCase();

  return teachers.whenData((list) {
    if (query.isEmpty) return list;
    return list
        .where(
          (t) =>
              t.name.toLowerCase().contains(query) ||
              t.email.toLowerCase().contains(query),
        )
        .toList();
  });
});

// ─── Teacher Count ───
final teacherCountProvider = Provider<int>((ref) {
  return ref
      .watch(teachersProvider)
      .maybeWhen(data: (list) => list.length, orElse: () => 0);
});
