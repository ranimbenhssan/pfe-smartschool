import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Latest Sensor Data Per Room (Firestore) ───
final latestSensorDataProvider = StreamProvider.family<SensorModel?, String>((
  ref,
  roomId,
) {
  return ref.watch(firestoreServiceProvider).getLatestSensorData(roomId);
});

// ─── Sensor History Per Room (Firestore) ───
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

// ─────────────────────────────────────────────────────────────────────────────
//  RTDB — Live DHT22 temperature from ESP32
//  Path: /iot/temperature/floor_2/dht22_ED26
//  All rooms share this single reading (prototype — one sensor for all floors)
// ─────────────────────────────────────────────────────────────────────────────

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

final rtdbTemperatureProvider = StreamProvider<DhtData?>((ref) {
  return FirebaseDatabase.instance
      .ref('iot/temperature/floor_2/dht22')
      .onValue
      .map((event) {
        final raw = event.snapshot.value;
        if (raw == null || raw is! Map) return null;
        final m = Map<String, dynamic>.from(raw as Map);
        final temp = (m['temperature'] as num?)?.toDouble();
        final hum = (m['humidity'] as num?)?.toDouble();
        if (temp == null || hum == null) return null;
        return DhtData(
          temperature: temp,
          humidity: hum,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (m['updatedAt'] as num?)?.toInt() ?? 0,
          ),
        );
      });
});
