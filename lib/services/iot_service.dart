// lib/services/iot_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final iotServiceProvider = Provider<IotService>((ref) => IotService());

// ─────────────────────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────────────────────
class DhtReading {
  final String sensorId; // e.g. "dht22_ED26"
  final int pin;
  final int floor;
  final double temperature;
  final double humidity;
  final DateTime updatedAt;

  const DhtReading({
    required this.sensorId,
    required this.pin,
    required this.floor,
    required this.temperature,
    required this.humidity,
    required this.updatedAt,
  });

  factory DhtReading.fromMap(String id, Map<dynamic, dynamic> m, int floor) =>
      DhtReading(
        sensorId: id,
        pin: (m['pin'] as num?)?.toInt() ?? 0,
        floor: floor,
        temperature: (m['temperature'] as num?)?.toDouble() ?? 0,
        humidity: (m['humidity'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0,
        ),
      );
}

class TeacherPresence {
  final String teacherId, teacherName, date, status;
  final DateTime entryTime;
  final DateTime? exitTime;

  const TeacherPresence({
    required this.teacherId,
    required this.teacherName,
    required this.date,
    required this.entryTime,
    required this.status,
    this.exitTime,
  });

  factory TeacherPresence.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TeacherPresence(
      teacherId: doc.id,
      teacherName: d['teacherName']?.toString() ?? '',
      date: d['date']?.toString() ?? '',
      entryTime: (d['entryTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      exitTime: (d['exitTime'] as Timestamp?)?.toDate(),
      status: d['status']?.toString() ?? 'in',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FLOOR ID HELPER
//  RTDB path: /iot/temperature/floor_0, /floor_1 … /floor_4
// ─────────────────────────────────────────────────────────────────────────────
String floorId(int floor) => 'floor_$floor';

// ─────────────────────────────────────────────────────────────────────────────
//  IOT SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class IotService {
  final _rtdb = FirebaseDatabase.instance;
  final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  //  PROTOTYPE MODE — single DHT22 broadcasts to all floors (0–4)
  //
  //  The one physical DHT22 writes to /iot/temperature/floor_2/dht22_ED26.
  //  Flutter listens to that path and copies the reading to all other floors
  //  so every room in the app shows live temperature.
  //
  //  When adding more ESP32 units per floor:
  //  → Remove startPrototypeBroadcast() call
  //  → Each ESP32 writes to its own floor path independently
  // ─────────────────────────────────────────────────────────────────────────
  void startPrototypeBroadcast({
    String sourceSensor = 'dht22_ED26',
    String sourceFloor = 'floor_2',
  }) {
    // Listen to the single sensor and mirror its readings to all floors
    _rtdb.ref('iot/temperature/$sourceFloor/$sourceSensor').onValue.listen((
      event,
    ) async {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return;

      final data = Map<dynamic, dynamic>.from(raw);

      // Mirror to all other floors under the same sensor name
      for (int floor = 0; floor <= 4; floor++) {
        final floorKey = 'floor_$floor';
        if (floorKey == sourceFloor)
          continue; // skip source — already written by ESP32

        await _rtdb.ref('iot/temperature/$floorKey/$sourceSensor').update({
          'temperature': data['temperature'],
          'humidity': data['humidity'],
          'pin': data['pin'] ?? 2,
          'floor': floor,
          'updatedAt': data['updatedAt'],
          'prototype': true, // flag so you know this is mirrored data
        });
      }
    });

    debugPrint(
      '[IoT] Prototype broadcast started: '
      '$sourceSensor@$sourceFloor → all floors',
    );
  }

  /// Stream DHT22 readings for a specific floor from RTDB.
  /// RTDB path: /iot/temperature/floor_{n}
  Stream<List<DhtReading>> temperatureStreamForFloor(int floor) {
    return _rtdb.ref('iot/temperature/${floorId(floor)}').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return [];
      return (raw as Map).entries
          .map(
            (e) => DhtReading.fromMap(
              e.key.toString(),
              Map<dynamic, dynamic>.from(e.value as Map),
              floor,
            ),
          )
          .toList()
        ..sort((a, b) => a.sensorId.compareTo(b.sensorId));
    });
  }

  /// Stream DHT22 readings for ALL floors (0–4) combined.
  Stream<Map<int, List<DhtReading>>> allFloorsTemperatureStream() {
    // Merge 5 floor streams into one map keyed by floor number
    final streams = List.generate(5, (i) => temperatureStreamForFloor(i));

    return StreamZip(streams).map((readings) {
      final map = <int, List<DhtReading>>{};
      for (int i = 0; i < readings.length; i++) {
        if ((readings[i] as List).isNotEmpty) {
          map[i] = List<DhtReading>.from(readings[i] as List);
        }
      }
      return map;
    });
  }

  /// Today's teacher presence
  Stream<List<TeacherPresence>> todayTeacherPresenceStream() {
    final today = _fmtDate(DateTime.now());
    return _db
        .collection('teacher_daily_presence')
        .where('date', isEqualTo: today)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map(TeacherPresence.fromFirestore).toList()
                ..sort((a, b) => a.entryTime.compareTo(b.entryTime)),
        );
  }

  /// Teacher attendance sheet history
  Stream<List<Map<String, dynamic>>> teacherAttendanceHistory(
    String teacherId,
  ) {
    return _db
        .collection('teacher_attendance')
        .doc(teacherId)
        .collection('sessions')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  STREAM ZIP HELPER  (merges N streams into one)
// ─────────────────────────────────────────────────────────────────────────────
class StreamZip<T> extends Stream<List<T>> {
  final List<Stream<T>> streams;
  StreamZip(this.streams);

  @override
  StreamSubscription<List<T>> listen(
    void Function(List<T>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final values = List<T?>.filled(streams.length, null);
    final received = List<bool>.filled(streams.length, false);
    final controller = StreamController<List<T>>();
    final subs = <StreamSubscription>[];

    for (int i = 0; i < streams.length; i++) {
      final idx = i;
      subs.add(
        streams[idx].listen((value) {
          values[idx] = value;
          received[idx] = true;
          if (received.every((r) => r)) {
            controller.add(List<T>.from(values.map((v) => v as T)));
          }
        }, onError: controller.addError),
      );
    }

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: () {
        for (final s in subs) s.cancel();
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RFID SCAN LISTENER  (university entry only)
// ─────────────────────────────────────────────────────────────────────────────
class RfidScanListener {
  RfidScanListener._();
  static final instance = RfidScanListener._();

  final _rtdb = FirebaseDatabase.instance;
  final _db = FirebaseFirestore.instance;

  StreamSubscription<DatabaseEvent>? _subscription;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    debugPrint('[RFID Listener] Started — watching /iot/rfid_scans');

    _subscription = _rtdb
        .ref('iot/rfid_scans')
        .onChildAdded
        .listen(
          (DatabaseEvent event) async {
            final scanId = event.snapshot.key;
            final raw = event.snapshot.value;
            if (scanId == null || raw == null || raw is! Map) return;
            final data = Map<String, dynamic>.from(raw);
            if (data['processed'] == true) return;
            await _handleScan(scanId, data);
          },
          onError: (e) {
            debugPrint('[RFID Listener] Error: $e');
            _running = false;
          },
        );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _running = false;
    debugPrint('[RFID Listener] Stopped');
  }

  Future<void> _handleScan(String scanId, Map<String, dynamic> data) async {
    final tag = (data['tag'] as String? ?? '').toUpperCase().trim();
    final floor = (data['floor'] as String? ?? 'floor_0');
    if (tag.isEmpty) return;

    debugPrint('[RFID] Scan: $tag (id: $scanId)');
    await _rtdb.ref('iot/rfid_scans/$scanId').update({'processed': true});

    bool authorized = false;

    // ── Check students ────────────────────────────────────────────────────
    final studentSnap =
        await _db
            .collection('students')
            .where('rfidTag', isEqualTo: tag)
            .limit(1)
            .get();

    if (studentSnap.docs.isNotEmpty) {
      authorized = true;
      final doc = studentSnap.docs.first;
      await _processStudentEntry(doc.id, doc.data(), tag, floor);
    }

    // ── Check teachers ────────────────────────────────────────────────────
    if (!authorized) {
      final teacherSnap =
          await _db
              .collection('teachers')
              .where('rfidTag', isEqualTo: tag)
              .limit(1)
              .get();

      if (teacherSnap.docs.isNotEmpty) {
        authorized = true;
        final doc = teacherSnap.docs.first;
        await _processTeacherEntry(doc.id, doc.data(), tag, floor);
      }
    }

    // ── Write response to RTDB ────────────────────────────────────────────
    final response = authorized ? 'authorized' : 'denied';
    await _rtdb.ref('iot/rfid_scans/$scanId').update({'response': response});

    debugPrint('[RFID] $tag → $response');

    if (!authorized) {
      await _db.collection('rfid_logs').add({
        'rfidTag': tag,
        'studentId': '',
        'studentName': 'Unknown',
        'isRecognized': false,
        'direction': 'in',
        'role': 'unknown',
        'floor': floor,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _processStudentEntry(
    String studentId,
    Map<String, dynamic> d,
    String tag,
    String floor,
  ) async {
    final now = DateTime.now();
    final dateStr = _fmtDate(now);
    final existing =
        await _db
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .where('date', isEqualTo: dateStr)
            .limit(1)
            .get();

    if (existing.docs.isEmpty) {
      final schoolStart = DateTime(now.year, now.month, now.day, 8, 0);
      final status =
          now.difference(schoolStart).inMinutes > 15 ? 'late' : 'present';
      await _db.collection('attendance').add({
        'studentId': studentId,
        'studentName': d['name'] ?? '',
        'classId': d['classId'] ?? '',
        'className': d['className'] ?? '',
        'date': dateStr,
        'status': status,
        'entryTime': Timestamp.fromDate(now),
        'exitTime': null,
        'teacherId': '',
        'teacherName': '',
        'subject': 'Entry',
        'sessionName': 'University Entry',
        'roomId': '',
        'roomName': '',
        'recordedAt': FieldValue.serverTimestamp(),
        'note': 'RFID — $floor',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _db.collection('rfid_logs').add({
      'rfidTag': tag,
      'studentId': studentId,
      'studentName': d['name'] ?? '',
      'isRecognized': true,
      'direction': 'in',
      'role': 'student',
      'floor': floor,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _processTeacherEntry(
    String teacherId,
    Map<String, dynamic> d,
    String tag,
    String floor,
  ) async {
    final now = DateTime.now();
    final dateStr = _fmtDate(now);
    final teacherName = d['name']?.toString() ?? '';

    final ref = _db.collection('teacher_daily_presence').doc(teacherId);
    final doc = await ref.get();
    final isFirst = !doc.exists || doc.data()?['date'] != dateStr;

    if (isFirst) {
      await ref.set({
        'teacherId': teacherId,
        'teacherName': teacherName,
        'date': dateStr,
        'entryTime': Timestamp.fromDate(now),
        'exitTime': null,
        'status': 'in',
      });
    } else {
      final entryTime =
          (doc.data()?['entryTime'] as Timestamp?)?.toDate() ?? now;
      await ref.update({'exitTime': Timestamp.fromDate(now), 'status': 'out'});
      await _db
          .collection('teacher_attendance')
          .doc(teacherId)
          .collection('sessions')
          .doc(dateStr)
          .set({
            'teacherId': teacherId,
            'teacherName': teacherName,
            'date': dateStr,
            'dayName': _dayName(now.weekday),
            'entryTime': Timestamp.fromDate(entryTime),
            'exitTime': Timestamp.fromDate(now),
            'duration': now.difference(entryTime).inMinutes,
            'recordedAt': FieldValue.serverTimestamp(),
          });
    }

    await _db.collection('rfid_logs').add({
      'rfidTag': tag,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'isRecognized': true,
      'direction': isFirst ? 'in' : 'out',
      'role': 'teacher',
      'floor': floor,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dayName(int w) {
    const n = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return n[w];
  }
}
