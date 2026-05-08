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
  //  [startDate]     — semester start date (used to calculate A/B week)
  //  [firstWeekType] — 'A' or 'B': which week type the start date belongs to
  //
  //  After import:
  //  1. Replaces existing Week A / B entries for the class.
  //  2. Updates teacher assignedClassIds.
  //  3. Creates / updates the active semester in Firestore with the given
  //     startDate and firstWeekType so all dashboards auto-calculate week type.
  // ─────────────────────────────────────────────────────────────────────────
  Future<TimetableImportResult> importFromBytes(
    Uint8List bytes, {
    DateTime? startDate,
    String firstWeekType = 'A',
    bool replaceExisting = true,
  }) async {
    int created = 0;
    int skipped = 0;
    String className = '';
    final warnings = <String>[];

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
            'Sheet "$sheetName": Class "$classNameRaw" not found — skipped',
          );
          continue;
        }
        resolvedClassId = classSnap.id;
        resolvedClassName =
            classSnap.data()?['displayName']?.toString() ?? classNameRaw;

        // ── Delete existing entries ───────────────────────────────────────
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

          String teacherId = '';
          String teacherName = teacherRaw;
          if (teacherRaw.isNotEmpty) {
            final tSnap = await _resolveTeacher(teacherRaw);
            if (tSnap != null) {
              teacherId = tSnap.id;
              teacherName = tSnap.data()?['name']?.toString() ?? teacherRaw;
              teacherIdToName[teacherId] = teacherName;
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
      if (resolvedClassId.isNotEmpty && teacherIdToName.isNotEmpty) {
        await _updateTeacherAssignments(
          teacherIdToName: teacherIdToName,
          classId: resolvedClassId,
          className: resolvedClassName,
          warnings: warnings,
        );
      }

      // ── Create / update active semester with startDate ────────────────────
      // This is the core of the auto-rotation: every dashboard reads
      // activeSemesterProvider → weekTypeFor(today) to determine A or B.
      if (startDate != null) {
        await _upsertActiveSemester(
          startDate: startDate,
          firstWeekType: firstWeekType,
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
  //  UPSERT ACTIVE SEMESTER
  //
  //  If an active semester already exists → update its startDate and
  //  firstWeekType (admin may just be updating after seeing the wrong week).
  //  If no active semester exists → create one.
  //  End date is set to the standard semester end (May 30 or Dec 30).
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _upsertActiveSemester({
    required DateTime startDate,
    required String firstWeekType,
    required List<String> warnings,
  }) async {
    try {
      // Standard end dates
      final endDate =
          startDate.month <= 6
              ? DateTime(startDate.year, 5, 30) // Semester 2: → May 30
              : DateTime(startDate.year, 12, 30); // Semester 1: → Dec 30

      final semName =
          startDate.month <= 6
              ? 'Semester 2 ${startDate.year - 1}-${startDate.year}'
              : 'Semester 1 ${startDate.year}-${startDate.year + 1}';

      // Check if an active semester exists
      final existing =
          await _db
              .collection('semesters')
              .where('isActive', isEqualTo: true)
              .limit(1)
              .get();

      if (existing.docs.isNotEmpty) {
        // Update existing
        await existing.docs.first.reference.update({
          'startDate': Timestamp.fromDate(startDate),
          'firstWeekType': firstWeekType,
          'endDate': Timestamp.fromDate(endDate),
          'name': semName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
          '[TimetableImport] Updated active semester: $semName '
          '(starts $startDate, Week $firstWeekType first)',
        );
      } else {
        // Create new active semester
        final id = _db.collection('semesters').doc().id;
        await _db.collection('semesters').doc(id).set({
          'name': semName,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'firstWeekType': firstWeekType,
          'isActive': true,
          'fixedHolidays':
              SemesterModel.defaultFixedHolidays.map((h) => h.toMap()).toList(),
          'schoolClosures': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[TimetableImport] Created active semester: $semName');
      }
    } catch (e) {
      warnings.add('Could not update semester config: $e');
      debugPrint('[TimetableImport] semester upsert error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UPDATE TEACHER ASSIGNMENTS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _updateTeacherAssignments({
    required Map<String, String> teacherIdToName,
    required String classId,
    required String className,
    required List<String> warnings,
  }) async {
    for (final entry in teacherIdToName.entries) {
      try {
        await _db.collection('teachers').doc(entry.key).update({
          'assignedClassIds': FieldValue.arrayUnion([classId]),
          'assignedClassNames': FieldValue.arrayUnion([className]),
        });
      } catch (e) {
        warnings.add('Could not update teacher "${entry.value}": $e');
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
      'lun': 'Monday',
      'lundi': 'Monday',
      'tue': 'Tuesday',
      'tuesday': 'Tuesday',
      'mar': 'Tuesday',
      'mardi': 'Tuesday',
      'wed': 'Wednesday',
      'wednesday': 'Wednesday',
      'mer': 'Wednesday',
      'mercredi': 'Wednesday',
      'thu': 'Thursday',
      'thursday': 'Thursday',
      'jeu': 'Thursday',
      'jeudi': 'Thursday',
      'fri': 'Friday',
      'friday': 'Friday',
      'ven': 'Friday',
      'vendredi': 'Friday',
    };
    final lower = raw.toLowerCase().trim();
    if (map.containsKey(lower)) return map[lower]!;
    for (final k in map.keys) {
      if (lower.startsWith(k.substring(0, k.length.clamp(0, 3))))
        return map[k]!;
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
    final p = t.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveClass(
    String name,
  ) async {
    var snap =
        await _db
            .collection('classes')
            .where('displayName', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;
    snap =
        await _db
            .collection('classes')
            .where('name', isEqualTo: name)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      snap =
          await _db
              .collection('classes')
              .where('level', isEqualTo: parts[0])
              .where('name', isEqualTo: parts[1])
              .where('grade', isEqualTo: parts[2])
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
    final all = await _db.collection('teachers').get();
    for (final doc in all.docs) {
      final n = doc.data()['name']?.toString().toLowerCase() ?? '';
      if (n.contains(name.toLowerCase()) || name.toLowerCase().contains(n))
        return doc;
    }
    return null;
  }
}
