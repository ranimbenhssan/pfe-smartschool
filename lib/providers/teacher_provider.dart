import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── All Teachers Stream ───────────────────────────────────────────────────────
final teachersProvider = StreamProvider<List<TeacherModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getTeachers();
});

// ─── Single Teacher (by doc ID) ───────────────────────────────────────────────
final teacherProvider = FutureProvider.family<TeacherModel?, String>((
  ref,
  teacherId,
) {
  return ref.watch(firestoreServiceProvider).getTeacherById(teacherId);
});

// ─── Teacher Search Query ─────────────────────────────────────────────────────
final teacherSearchQueryProvider = StateProvider<String>((ref) => '');

// ─── Filtered Teachers ────────────────────────────────────────────────────────
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

// ─── Teacher Count ────────────────────────────────────────────────────────────
final teacherCountProvider = Provider<int>((ref) {
  return ref
      .watch(teachersProvider)
      .maybeWhen(data: (list) => list.length, orElse: () => 0);
});

// ─────────────────────────────────────────────────────────────────────────────
//  CURRENT TEACHER
//  Streams teachers/{auth_uid} — the teacher document for the logged-in user.
//  Teacher doc ID == Firebase Auth UID in this app.
//  Lives here (not in attendance_provider) to avoid dual-export conflicts.
// ─────────────────────────────────────────────────────────────────────────────
final currentTeacherProvider = StreamProvider<TeacherModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      // Fetch by doc ID (= auth UID).  Falls back to userId field query
      // for older teacher documents created before the doc-ID convention.
      return FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.id)
          .snapshots()
          .asyncMap((doc) async {
            if (doc.exists) return TeacherModel.fromFirestore(doc);
            // Fallback: query by userId field
            final snap =
                await FirebaseFirestore.instance
                    .collection('teachers')
                    .where('userId', isEqualTo: user.id)
                    .limit(1)
                    .get();
            if (snap.docs.isEmpty) return null;
            return TeacherModel.fromFirestore(snap.docs.first);
          });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
//  TEACHER CLASS IDs
//  Primary:  teacher.assignedClassIds (admin-assigned array on teacher doc)
//  Fallback: timetable WHERE teacherId == uid (for timetable-only assignments)
//  Deduplicates and returns a List<String> of classIds.
// ─────────────────────────────────────────────────────────────────────────────
final teacherClassIdsProvider = StreamProvider<List<String>>((ref) {
  final teacherAsync = ref.watch(currentTeacherProvider);
  final userAsync = ref.watch(currentUserProvider);

  return teacherAsync.when(
    loading: () => Stream.value(<String>[]),
    error: (_, __) => Stream.value(<String>[]),
    data: (teacher) {
      if (teacher == null) return Stream.value(<String>[]);

      // Primary: assignedClassIds set by admin
      if (teacher.assignedClassIds.isNotEmpty) {
        return Stream.value(teacher.assignedClassIds);
      }

      // Fallback: timetable entries for this teacher
      return userAsync.when(
        data: (user) {
          if (user == null) return Stream.value(<String>[]);
          return FirebaseFirestore.instance
              .collection('timetable')
              .where('teacherId', isEqualTo: user.id)
              .snapshots()
              .map((snap) {
                final ids =
                    snap.docs
                        .map((d) => d.data()['classId']?.toString() ?? '')
                        .where((id) => id.isNotEmpty)
                        .toSet()
                        .toList();
                return ids;
              });
        },
        loading: () => Stream.value(<String>[]),
        error: (_, __) => Stream.value(<String>[]),
      );
    },
  );
});
