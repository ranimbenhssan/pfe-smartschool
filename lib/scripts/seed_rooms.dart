// lib/scripts/seed_rooms.dart
//
// ── HOW TO RUN ──────────────────────────────────────────────────────────────
// This is a standalone Dart script. Run it ONCE from the terminal:
//
//   flutter run lib/scripts/seed_rooms.dart
//
// Or call seedRooms() from a temporary button in the admin dashboard:
//
//   ElevatedButton(
//     onPressed: () async => await seedRooms(),
//     child: Text('Seed Rooms'),
//   )
//
// It is idempotent — if a room already exists (same name + floor) it skips it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// ─── Room definitions grouped by floor ───────────────────────────────────────
const _rooms = {
  0: [
    {'name': 'A10', 'capacity': 30},
    {'name': 'ED10', 'capacity': 30},
    {'name': 'Amphi I', 'capacity': 120},
    {'name': 'Amphi T', 'capacity': 130},
    {'name': 'LEAD1', 'capacity': 30},
    {'name': 'LEAD2', 'capacity': 30},
  ],
  1: [
    {'name': 'A11', 'capacity': 30},
    {'name': 'A12', 'capacity': 40},
    {'name': 'A13', 'capacity': 40},
    {'name': 'ED11', 'capacity': 40},
    {'name': 'L.RES', 'capacity': 30},
    {'name': 'LI11', 'capacity': 40},
    {'name': 'LI12', 'capacity': 40},
    {'name': 'LLNG', 'capacity': 40},
    {'name': 'LP11', 'capacity': 40},
    {'name': 'LP12', 'capacity': 40},
  ],
  2: [
    {'name': 'A21', 'capacity': 40},
    {'name': 'A22', 'capacity': 40},
    {'name': 'A23', 'capacity': 40},
    {'name': 'S.LEC', 'capacity': 50},
    {'name': 'LP21', 'capacity': 40},
    {'name': 'ED22', 'capacity': 40},
    {'name': 'ED23', 'capacity': 40},
    {'name': 'ED24', 'capacity': 40},
    {'name': 'ED25', 'capacity': 40},
    {'name': 'ED26', 'capacity': 40},
  ],
  3: [
    {'name': 'A31', 'capacity': 40},
    {'name': 'A32', 'capacity': 40},
    {'name': 'A33', 'capacity': 40},
    {'name': 'LI31', 'capacity': 40},
    {'name': 'LI32', 'capacity': 40},
    {'name': 'LI33', 'capacity': 40},
    {'name': 'LI34', 'capacity': 40},
    {'name': 'PAQ1', 'capacity': 40},
    {'name': 'PAQ2', 'capacity': 40},
    {'name': 'PAQ3', 'capacity': 40},
  ],
  4: [
    {'name': 'A41', 'capacity': 40},
  ],
};

Future<void> seedRooms() async {
  final db = FirebaseFirestore.instance;
  final uuid = const Uuid();
  int created = 0, skipped = 0;

  debugPrint('[SeedRooms] Starting — ${_totalRooms()} rooms across 5 floors');

  for (final entry in _rooms.entries) {
    final floor = entry.key;
    final rooms = entry.value;

    for (final room in rooms) {
      final name = room['name'] as String;

      // Check if room already exists
      final existing =
          await db
              .collection('rooms')
              .where('name', isEqualTo: name)
              .where('floor', isEqualTo: floor)
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty) {
        debugPrint('[SeedRooms] Skip: $name (floor $floor) — already exists');
        skipped++;
        continue;
      }

      final id = uuid.v4();
      await db.collection('rooms').doc(id).set({
        'name': name,
        'floor': floor,
        'capacity': room['capacity'] as int,
        'comfortScore': 100.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[SeedRooms] Created: $name (floor $floor)');
      created++;
    }
  }

  debugPrint('[SeedRooms] Done — $created created, $skipped skipped');
}

int _totalRooms() => _rooms.values.fold(0, (sum, list) => sum + list.length);
