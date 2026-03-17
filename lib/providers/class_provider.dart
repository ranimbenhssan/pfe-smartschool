import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── All Classes Stream ───
final classesProvider = StreamProvider<List<ClassModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getClasses();
});

// ─── Single Class ───
final classProvider = FutureProvider.family<ClassModel?, String>((
  ref,
  classId,
) {
  return ref.watch(firestoreServiceProvider).getClass(classId);
});

// ─── Class Count ───
final classCountProvider = Provider<int>((ref) {
  return ref
      .watch(classesProvider)
      .maybeWhen(data: (list) => list.length, orElse: () => 0);
});

// ─── Selected Class (for filters) ───
final selectedClassIdProvider = StateProvider<String?>((ref) => null);
