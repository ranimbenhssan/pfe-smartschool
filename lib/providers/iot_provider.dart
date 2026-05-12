// lib/providers/iot_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/iot_service.dart';

// ─── Temperature per floor ─────────────────────────────────────────────────
final temperatureByFloorProvider = StreamProvider.family<List<DhtReading>, int>(
  (ref, floor) {
    return ref.watch(iotServiceProvider).temperatureStreamForFloor(floor);
  },
);

// ─── All floors combined (0–4) ─────────────────────────────────────────────
final allFloorsTemperatureProvider = StreamProvider<Map<int, List<DhtReading>>>(
  (ref) {
    return ref.watch(iotServiceProvider).allFloorsTemperatureStream();
  },
);

// ─── Today's teacher presence ───────────────────────────────────────────────
final todayTeacherPresenceProvider = StreamProvider<List<TeacherPresence>>((
  ref,
) {
  return ref.watch(iotServiceProvider).todayTeacherPresenceStream();
});

// ─── Teacher attendance history ─────────────────────────────────────────────
final teacherAttendanceHistoryProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, teacherId) {
      return ref.watch(iotServiceProvider).teacherAttendanceHistory(teacherId);
    });

// ─── Prototype broadcast ───────────────────────────────────────────────────
// Starts once and mirrors floor_2 DHT22 readings to all other floors.
// REMOVE this provider when adding individual ESP32 units per floor.
final prototypeBroadcastProvider = Provider<void>((ref) {
  ref
      .watch(iotServiceProvider)
      .startPrototypeBroadcast(sourceSensor: 'dht22', sourceFloor: 'floor_2');
});
