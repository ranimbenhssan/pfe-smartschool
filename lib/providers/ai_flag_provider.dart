import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Active AI Flags ───
final activeAiFlagsProvider = StreamProvider<List<AiFlagModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getActiveAiFlags();
});

// ─── AI Flags By Class ───
final aiFlagsByClassProvider = StreamProvider.family<List<AiFlagModel>, String>(
  (ref, classId) {
    return ref.watch(firestoreServiceProvider).getAiFlagsByClass(classId);
  },
);

// ─── AI Flags By Student ───
final aiFlagsByStudentProvider =
    StreamProvider.family<List<AiFlagModel>, String>((ref, studentId) {
      return ref.watch(firestoreServiceProvider).getAiFlagsByStudent(studentId);
    });

// ─── Resolved AI Flags ───
final resolvedAiFlagsProvider = StreamProvider<List<AiFlagModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getResolvedAiFlags();
});

// ─── Active Flags Count ───
final activeFlagsCountProvider = Provider<int>((ref) {
  return ref
      .watch(activeAiFlagsProvider)
      .maybeWhen(data: (list) => list.length, orElse: () => 0);
});

// ─── Filter Type State ───
final flagFilterTypeProvider = StateProvider<FlagType?>((ref) => null);

// ─── Filtered Active Flags ───
final filteredActiveFlagsProvider = Provider<AsyncValue<List<AiFlagModel>>>((
  ref,
) {
  final flags = ref.watch(activeAiFlagsProvider);
  final filterType = ref.watch(flagFilterTypeProvider);

  return flags.whenData((list) {
    if (filterType == null) return list;
    return list.where((f) => f.type == filterType).toList();
  });
});
