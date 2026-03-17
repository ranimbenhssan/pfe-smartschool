import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Latest Sensor Data Per Room ───
final latestSensorDataProvider = StreamProvider.family<SensorModel?, String>((
  ref,
  roomId,
) {
  return ref.watch(firestoreServiceProvider).getLatestSensorData(roomId);
});

// ─── Sensor History Per Room ───
final sensorHistoryProvider = StreamProvider.family<List<SensorModel>, String>((
  ref,
  roomId,
) {
  return ref.watch(firestoreServiceProvider).getSensorHistory(roomId);
});

// ─── All Rooms Stream ───
final roomsProvider = StreamProvider<List<RoomModel>>((ref) {
  return ref.watch(firestoreServiceProvider).getRooms();
});

// ─── Single Room ───
final roomProvider = FutureProvider.family<RoomModel?, String>((ref, roomId) {
  return ref.watch(firestoreServiceProvider).getRoom(roomId);
});

// ─── Selected Room Id ───
final selectedRoomIdProvider = StateProvider<String?>((ref) => null);

// ─── Comfort Level Label ───
final comfortLevelLabelProvider = Provider.family<String, ComfortLevel>((
  ref,
  level,
) {
  switch (level) {
    case ComfortLevel.good:
      return 'Good';
    case ComfortLevel.average:
      return 'Average';
    case ComfortLevel.bad:
      return 'Poor';
  }
});
