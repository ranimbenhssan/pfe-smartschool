import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// ─── All students ───
final studentsProvider = StreamProvider<List<StudentModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('students')
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => StudentModel.fromFirestore(d)).toList(),
      );
});

// ─── Single student ───
final studentProvider = StreamProvider.family<StudentModel?, String>((
  ref,
  studentId,
) {
  return FirebaseFirestore.instance
      .collection('students')
      .doc(studentId)
      .snapshots()
      .map((d) => d.exists ? StudentModel.fromFirestore(d) : null);
});

// ─── Search query ───
final studentSearchQueryProvider = StateProvider<String>((ref) => '');

// ─── Filtered students ───
final filteredStudentsProvider = StreamProvider<List<StudentModel>>((
  ref,
) async* {
  final query = ref.watch(studentSearchQueryProvider).toLowerCase();
  final students = ref.watch(studentsProvider);
  yield* students.when(
    loading: () => const Stream.empty(),
    error: (e, _) => const Stream.empty(),
    data:
        (list) => Stream.value(
          query.isEmpty
              ? list
              : list
                  .where(
                    (s) =>
                        s.name.toLowerCase().contains(query) ||
                        s.className.toLowerCase().contains(query),
                  )
                  .toList(),
        ),
  );
});

// ─── Students by classId ───
final studentsByClassIdProvider =
    StreamProvider.family<List<StudentModel>, String>((ref, classId) {
      return FirebaseFirestore.instance
          .collection('students')
          .where('classId', isEqualTo: classId)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => StudentModel.fromFirestore(d)).toList(),
          );
    });

// ─── Students in same class as current user ───
// Students in same class as current user
final studentsByClassProvider =
    StreamProvider.family<List<StudentModel>, String>((ref, userId) {
      // First get the student's classId
      return FirebaseFirestore.instance
          .collection('students')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .snapshots()
          .asyncExpand((snap) {
            if (snap.docs.isEmpty) return Stream.value([]);
            final classId = snap.docs.first.data()['classId'] as String? ?? '';
            if (classId.isEmpty) return Stream.value([]);
            return FirebaseFirestore.instance
                .collection('students')
                .where('classId', isEqualTo: classId)
                .snapshots()
                .map(
                  (s) =>
                      s.docs.map((d) => StudentModel.fromFirestore(d)).toList(),
                );
          });
    });
