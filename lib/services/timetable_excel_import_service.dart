import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

final timetableImportServiceProvider = Provider<TimetableImportService>(
  (ref) => TimetableImportService(),
);

// ─── Import result ────────────────────────────────────────────────────────────
class TimetableImportResult {
  final int created;
  final int skipped;
  final String className;
  final List<String> warnings;

  const TimetableImportResult({
    required this.created,
    required this.skipped,
    required this.className,
    required this.warnings,
  });
}

class TimetableImportService {
  final _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // ─────────────────────────────────────────────────────────────────────────
  //  IMPORT FROM BYTES
  //
  //  Expected Excel structure:
  //  • Sheet 1: "Week A"  (or any name containing 'a')
  //  • Sheet 2: "Week B"  (or any name containing 'b')
  //
  //  Row 1: Class name (e.g. "1 DNI 2") — used to resolve classId
  //  Row 2: Column headers:
  //         Day | Time Slot | Subject | Teacher | Room
  //         (case-insensitive, partial match ok)
  //  Row 3+: Data rows
  //
  //  Time Slot format: "HH:MM-HH:MM"  e.g. "08:30-09:25"
  //  Day: full name or 3-letter abbreviation (Monday / Mon)
  //
  //  If a class already has entries for the same weekType, they are REPLACED
  //  (deleted then re-created) unless replaceExisting=false.
  // ─────────────────────────────────────────────────────────────────────────
  Future<TimetableImportResult> importFromBytes(
    Uint8List bytes, {
    bool replaceExisting = true,
  }) async {
    int created = 0;
    int skipped = 0;
    String className = '';
    final warnings = <String>[];

    try {
      final excel = Excel.decodeBytes(bytes);

      for (final sheetName in excel.tables.keys) {
        final lower = sheetName.toLowerCase().trim();
        final weekType = lower.contains('b') ? 'B' : 'A';
        final sheet = excel.tables[sheetName]!;
        final rows = sheet.rows;
        if (rows.length < 3) {
          warnings.add('Sheet "$sheetName": too few rows — skipped');
          continue;
        }

        // ── Row 1: class name ─────────────────────────────────────────────
        final classNameRaw = rows[0]
            .map((c) => c?.value?.toString().trim() ?? '')
            .firstWhere((v) => v.isNotEmpty, orElse: () => '');
        if (classNameRaw.isEmpty) {
          warnings.add('Sheet "$sheetName": Row 1 must contain the class name');
          continue;
        }
        className = classNameRaw;

        // ── Resolve classId from Firestore ─────────────────────────────────
        String classId = '';
        final classSnap = await _resolveClass(classNameRaw);
        if (classSnap == null) {
          warnings.add(
            'Sheet "$sheetName": Class "$classNameRaw" not found in Firestore — entries skipped',
          );
          continue;
        }
        classId = classSnap.id;
        final classData = classSnap.data();
        final resolvedClassName =
            classData?['displayName']?.toString() ?? classNameRaw;

        // ── Row 2: headers ────────────────────────────────────────────────
        final headerRow = rows[1];
        final headers = _parseHeaders(headerRow);

        // ── Delete existing entries for this class + weekType ──────────────
        if (replaceExisting) {
          final existing =
              await _db
                  .collection('timetable')
                  .where('classId', isEqualTo: classId)
                  .where('weekType', isEqualTo: weekType)
                  .get();
          if (existing.docs.isNotEmpty) {
            final batch = _db.batch();
            for (final doc in existing.docs) {
              batch.delete(doc.reference);
            }
            await batch.commit();
            debugPrint(
              '[TimetableImport] Deleted ${existing.docs.length} '
              'existing entries for $classNameRaw $weekType',
            );
          }
        }

        // ── Process data rows ─────────────────────────────────────────────
        final writeBatch = _db.batch();
        int batchCount = 0;

        for (int i = 2; i < rows.length; i++) {
          final row = rows[i];
          if (_isRowEmpty(row)) continue;

          final dayRaw = _cell(row, headers, ['day', 'jour'])?.trim() ?? '';
          final timeRaw =
              _cell(row, headers, [
                'time',
                'time slot',
                'slot',
                'horaire',
              ])?.trim() ??
              '';
          final subject =
              _cell(row, headers, [
                'subject',
                'matière',
                'matiere',
                'module',
              ])?.trim() ??
              '';
          final teacherRaw =
              _cell(row, headers, ['teacher', 'enseignant', 'prof'])?.trim() ??
              '';
          final roomRaw =
              _cell(row, headers, ['room', 'salle', 'labo'])?.trim() ?? '';

          if (dayRaw.isEmpty || timeRaw.isEmpty || subject.isEmpty) {
            skipped++;
            continue;
          }

          // Normalise day name
          final dayName = _normaliseDay(dayRaw);
          if (dayName.isEmpty) {
            warnings.add('Row ${i + 1}: Unrecognised day "$dayRaw" — skipped');
            skipped++;
            continue;
          }

          // Parse time slot "08:30-09:25"
          final times = _parseTimeSlot(timeRaw);
          if (times == null) {
            warnings.add(
              'Row ${i + 1}: Unrecognised time slot "$timeRaw" — skipped',
            );
            skipped++;
            continue;
          }

          // Resolve teacher (optional)
          String teacherId = '';
          String teacherName = teacherRaw;
          if (teacherRaw.isNotEmpty) {
            final t = await _resolveTeacher(teacherRaw);
            if (t != null) {
              teacherId = t.id;
              final teacherData = t.data();
              teacherName = teacherData?['name']?.toString() ?? teacherRaw;
            } else {
              warnings.add(
                'Row ${i + 1}: Teacher "$teacherRaw" not found — entry saved without teacher link',
              );
            }
          }

          final entry = TimetableModel(
            id: _uuid.v4(),
            classId: classId,
            className: resolvedClassName,
            teacherId: teacherId,
            teacherName: teacherName,
            subject: subject,
            dayOfWeek: dayName,
            startTime: times.$1,
            endTime: times.$2,
            roomId: '', // rooms resolved by name only for now
            roomName: roomRaw,
            weekType: weekType,
            createdAt: DateTime.now(),
          );

          writeBatch.set(
            _db.collection('timetable').doc(entry.id),
            entry.toFirestore(),
          );
          batchCount++;
          created++;

          // Firestore batch limit = 500
          if (batchCount >= 400) {
            await writeBatch.commit();
            batchCount = 0;
          }
        }

        if (batchCount > 0) await writeBatch.commit();
      }
    } catch (e) {
      warnings.add('Fatal error: $e');
      debugPrint('[TimetableImport] error: $e');
    }

    return TimetableImportResult(
      created: created,
      skipped: skipped,
      className: className,
      warnings: warnings,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Map<String, int> _parseHeaders(List<Data?> row) {
    final map = <String, int>{};
    for (int i = 0; i < row.length; i++) {
      final v = row[i]?.value?.toString().toLowerCase().trim();
      if (v != null && v.isNotEmpty) map[v] = i;
    }
    return map;
  }

  String? _cell(List<Data?> row, Map<String, int> headers, List<String> keys) {
    for (final key in keys) {
      // Exact match
      if (headers.containsKey(key)) {
        final idx = headers[key]!;
        if (idx < row.length) {
          return row[idx]?.value?.toString().trim();
        }
      }
      // Partial match
      for (final h in headers.keys) {
        if (h.contains(key) || key.contains(h)) {
          final idx = headers[h]!;
          if (idx < row.length) {
            return row[idx]?.value?.toString().trim();
          }
        }
      }
    }
    return null;
  }

  bool _isRowEmpty(List<Data?> row) => row.every(
    (c) => c == null || c.value == null || c.value.toString().trim().isEmpty,
  );

  /// Normalise day name — accepts full name or 3-letter prefix (any case)
  String _normaliseDay(String raw) {
    const map = {
      'mon': 'Monday', 'monday': 'Monday',
      'tue': 'Tuesday', 'tuesday': 'Tuesday',
      'wed': 'Wednesday', 'wednesday': 'Wednesday',
      'thu': 'Thursday', 'thursday': 'Thursday',
      'fri': 'Friday', 'friday': 'Friday',
      // French
      'lun': 'Monday', 'lundi': 'Monday',
      'mar': 'Tuesday', 'mardi': 'Tuesday',
      'mer': 'Wednesday', 'mercredi': 'Wednesday',
      'jeu': 'Thursday', 'jeudi': 'Thursday',
      'ven': 'Friday', 'vendredi': 'Friday',
    };
    final key = raw.toLowerCase().substring(0, raw.length.clamp(0, 9));
    // Try prefix match
    for (final entry in map.entries) {
      if (key.startsWith(entry.key) || entry.key.startsWith(key)) {
        return entry.value;
      }
    }
    return map[raw.toLowerCase().trim()] ?? '';
  }

  /// Parse "08:30-09:25" → ('08:30', '09:25')
  (String, String)? _parseTimeSlot(String raw) {
    // Handles: "08:30-09:25", "8h30-9h25", "08:30 - 09:25"
    final normalised = raw
        .replaceAll(' ', '')
        .replaceAll('h', ':')
        .replaceAll('H', ':');
    final parts = normalised.split('-');
    if (parts.length != 2) return null;
    final start = _normTime(parts[0]);
    final end = _normTime(parts[1]);
    if (start == null || end == null) return null;
    return (start, end);
  }

  String? _normTime(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveClass(
    String name,
  ) async {
    // Try displayName first
    var snap =
        await _db
            .collection('classes')
            .where('displayName', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // Try name field
    snap =
        await _db
            .collection('classes')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // Try splitting "level name grade"
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final lvl = parts.first;
      final gr = parts.last;
      final nm = parts.sublist(1, parts.length - 1).join(' ');
      snap =
          await _db
              .collection('classes')
              .where('level', isEqualTo: lvl)
              .where('name', isEqualTo: nm)
              .where('grade', isEqualTo: gr)
              .limit(1)
              .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;
    }
    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveTeacher(
    String name,
  ) async {
    // Exact name match
    var snap =
        await _db
            .collection('teachers')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // Case-insensitive partial (Firestore doesn't support ILIKE, so fetch and filter)
    final all = await _db.collection('teachers').get();
    for (final doc in all.docs) {
      final n = doc.data()['name']?.toString().toLowerCase() ?? '';
      if (n.contains(name.toLowerCase()) || name.toLowerCase().contains(n)) {
        return doc;
      }
    }
    return null;
  }
}
