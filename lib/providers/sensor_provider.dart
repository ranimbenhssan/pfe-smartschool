import 'package:firebase_database/firebase_database.dart';
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

/// Live DHT22 reading from RTDB — single sensor, shared by all rooms.
/// Path: /iot/temperature/floor_2/dht22_ED26
/// Returns null when no data is available yet.
final rtdbTemperatureProvider = StreamProvider<DhtData?>((ref) {
  return FirebaseDatabase.instance
      .ref('iot/temperature/floor_2/dht22_ED26')
      .onValue
      .map((event) {
    final raw = event.snapshot.value;
    if (raw == null || raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw as Map);
    return DhtData(
      temperature: (m['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (m['humidity'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['updatedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  });
});

class DhtData {
  final double temperature;
  final double humidity;
  final DateTime updatedAt;
  const DhtData({
    required this.temperature,
    required this.humidity,
    required this.updatedAt,
  });
}
