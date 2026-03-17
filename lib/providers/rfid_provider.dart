import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── All RFID Logs Stream ───
final rfidLogsProvider = StreamProvider<List<RfidLogModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getRfidLogs();
});

// ─── RFID Logs By Student ───
final rfidLogsByStudentProvider =
    StreamProvider.family<List<RfidLogModel>, String>((ref, studentId) {
      return ref
          .watch(firestoreServiceProvider)
          .getRfidLogsByStudent(studentId);
    });

// ─── Unrecognized RFID Logs ───
final unrecognizedRfidLogsProvider = StreamProvider<List<RfidLogModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getUnrecognizedRfidLogs();
});

// ─── RFID Filter State ───
final rfidFilterDateProvider = StateProvider<DateTime?>((ref) => null);
final rfidFilterStudentIdProvider = StateProvider<String?>((ref) => null);

// ─── Filtered RFID Logs ───
final filteredRfidLogsProvider = Provider<AsyncValue<List<RfidLogModel>>>((
  ref,
) {
  final logs = ref.watch(rfidLogsProvider);
  final filterDate = ref.watch(rfidFilterDateProvider);
  final filterStudentId = ref.watch(rfidFilterStudentIdProvider);

  return logs.whenData((list) {
    var filtered = list;

    if (filterDate != null) {
      filtered =
          filtered.where((log) {
            return log.timestamp.year == filterDate.year &&
                log.timestamp.month == filterDate.month &&
                log.timestamp.day == filterDate.day;
          }).toList();
    }

    if (filterStudentId != null && filterStudentId.isNotEmpty) {
      filtered =
          filtered.where((log) => log.studentId == filterStudentId).toList();
    }

    return filtered;
  });
});
