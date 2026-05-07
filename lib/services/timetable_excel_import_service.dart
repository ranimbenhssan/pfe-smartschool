import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

final timetableImportServiceProvider = Provider<TimetableImportService>(
  (ref) => TimetableImportService(),
);

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
  //  Sheet 1: "Week A"  |  Sheet 2: "Week B"
  //  Row 1: Class name  (e.g. "3 IOT 1 TP 2")
  //  Row 2: Headers — Day | Time Slot | Subject | Teacher | Room
  //  Row 3+: Data
  //
  //  After import:
  //  • Replaces all existing Week A / B entries for the class.
  //  • Updates every teacher's assignedClassIds / assignedClassNames
  //    to include this class (if not already there).
  // ─────────────────────────────────────────────────────────────────────────
  Future<TimetableImportResult> importFromBytes(
    Uint8List bytes, {
    bool replaceExisting = true,
  }) async {
    int created = 0;
    int skipped = 0;
    String className = '';
    final warnings = <String>[];

    // Track teachers referenced in this file so we can update their classes
    final Map<String, String> teacherIdToName = {};
    String resolvedClassId = '';
    String resolvedClassName = '';

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

        // ── Resolve classId ───────────────────────────────────────────────
        final classSnap = await _resolveClass(classNameRaw);
        if (classSnap == null) {
          warnings.add(
            'Sheet "$sheetName": Class "$classNameRaw" not found in Firestore — skipped',
          );
          continue;
        }
        resolvedClassId = classSnap.id;
        resolvedClassName =
            classSnap.data()?['displayName']?.toString() ?? classNameRaw;

        // ── Delete existing entries for this class + weekType ─────────────
        if (replaceExisting) {
          final existing =
              await _db
                  .collection('timetable')
                  .where('classId', isEqualTo: resolvedClassId)
                  .where('weekType', isEqualTo: weekType)
                  .get();
          if (existing.docs.isNotEmpty) {
            final batch = _db.batch();
            for (final doc in existing.docs) batch.delete(doc.reference);
            await batch.commit();
          }
        }

        // ── Row 2: headers ────────────────────────────────────────────────
        final headers = _parseHeaders(rows[1]);

        // ── Data rows ─────────────────────────────────────────────────────
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

          final dayName = _normaliseDay(dayRaw);
          if (dayName.isEmpty) {
            warnings.add('Row ${i + 1}: Unrecognised day "$dayRaw" — skipped');
            skipped++;
            continue;
          }

          final times = _parseTimeSlot(timeRaw);
          if (times == null) {
            warnings.add(
              'Row ${i + 1}: Unrecognised time "$timeRaw" — skipped',
            );
            skipped++;
            continue;
          }

          // ── Resolve teacher ───────────────────────────────────────────
          String teacherId = '';
          String teacherName = teacherRaw;
          if (teacherRaw.isNotEmpty) {
            final tSnap = await _resolveTeacher(teacherRaw);
            if (tSnap != null) {
              teacherId = tSnap.id;
              teacherName = tSnap.data()?['name']?.toString() ?? teacherRaw;
              teacherIdToName[teacherId] = teacherName; // track for later
            } else {
              warnings.add(
                'Row ${i + 1}: Teacher "$teacherRaw" not found — saved by name only',
              );
            }
          }

          final entry = TimetableModel(
            id: _uuid.v4(),
            classId: resolvedClassId,
            className: resolvedClassName,
            teacherId: teacherId,
            teacherName: teacherName,
            subject: subject,
            dayOfWeek: dayName,
            startTime: times.$1,
            endTime: times.$2,
            roomId: '',
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

          if (batchCount >= 400) {
            await writeBatch.commit();
            batchCount = 0;
          }
        }

        if (batchCount > 0) await writeBatch.commit();
      }

      // ── Update teacher assignments ────────────────────────────────────────
      // For every teacher found in the timetable, add the class to their
      // assignedClassIds / assignedClassNames if not already there.
      if (resolvedClassId.isNotEmpty && teacherIdToName.isNotEmpty) {
        await _updateTeacherAssignments(
          teacherIdToName: teacherIdToName,
          classId: resolvedClassId,
          className: resolvedClassName,
          warnings: warnings,
        );
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

  // ─────────────────────────────────────────────────────────────────────────
  //  UPDATE TEACHER ASSIGNMENTS
  //  Adds the class to each teacher's assignedClassIds/assignedClassNames
  //  using FieldValue.arrayUnion (idempotent — safe to call multiple times).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _updateTeacherAssignments({
    required Map<String, String> teacherIdToName,
    required String classId,
    required String className,
    required List<String> warnings,
  }) async {
    for (final entry in teacherIdToName.entries) {
      final teacherId = entry.key;
      final teacherName = entry.value;
      try {
        await _db.collection('teachers').doc(teacherId).update({
          'assignedClassIds': FieldValue.arrayUnion([classId]),
          'assignedClassNames': FieldValue.arrayUnion([className]),
        });
        debugPrint(
          '[TimetableImport] Updated teacher $teacherName → $className',
        );
      } catch (e) {
        warnings.add('Could not update teacher "$teacherName" assignments: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

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
      if (headers.containsKey(key)) {
        final idx = headers[key]!;
        if (idx < row.length) return row[idx]?.value?.toString().trim();
      }
      for (final h in headers.keys) {
        if (h.contains(key) || key.contains(h)) {
          final idx = headers[h]!;
          if (idx < row.length) return row[idx]?.value?.toString().trim();
        }
      }
    }
    return null;
  }

  bool _isRowEmpty(List<Data?> row) => row.every(
    (c) => c == null || c.value == null || c.value.toString().trim().isEmpty,
  );

  String _normaliseDay(String raw) {
    const map = {
      'mon': 'Monday',
      'monday': 'Monday',
      'tue': 'Tuesday',
      'tuesday': 'Tuesday',
      'wed': 'Wednesday',
      'wednesday': 'Wednesday',
      'thu': 'Thursday',
      'thursday': 'Thursday',
      'fri': 'Friday',
      'friday': 'Friday',
      'lun': 'Monday',
      'lundi': 'Monday',
      'mar': 'Tuesday',
      'mardi': 'Tuesday',
      'mer': 'Wednesday',
      'mercredi': 'Wednesday',
      'jeu': 'Thursday',
      'jeudi': 'Thursday',
      'ven': 'Friday',
      'vendredi': 'Friday',
    };
    final lower = raw.toLowerCase().trim();
    if (map.containsKey(lower)) return map[lower]!;
    for (final k in map.keys) {
      if (lower.startsWith(k.substring(0, k.length.clamp(0, 3)))) {
        return map[k]!;
      }
    }
    return '';
  }

  (String, String)? _parseTimeSlot(String raw) {
    final n = raw.replaceAll(' ', '').replaceAll('h', ':').replaceAll('H', ':');
    final parts = n.split('-');
    if (parts.length != 2) return null;
    final s = _normTime(parts[0]);
    final e = _normTime(parts[1]);
    if (s == null || e == null) return null;
    return (s, e);
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
    // 1. exact displayName
    var snap =
        await _db
            .collection('classes')
            .where('displayName', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // 2. exact name field
    snap =
        await _db
            .collection('classes')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // 3. split "level name grade [group]"
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final lvl = parts.first;
      final gr = parts[1]; // might be grade
      final nm = parts.sublist(2).join(' ');
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
    var snap =
        await _db
            .collection('teachers')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // partial match
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
