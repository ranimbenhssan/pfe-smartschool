import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase_options.dart';

final excelImportServiceProvider = Provider<ExcelImportService>((ref) {
  return ExcelImportService();
});

class ImportResult {
  final int studentsCreated;
  final int teachersCreated;
  final int classesCreated;
  final List<String> errors;
  final List<ImportedCredential> credentials;

  const ImportResult({
    required this.studentsCreated,
    required this.teachersCreated,
    required this.classesCreated,
    required this.errors,
    required this.credentials,
  });
}

class ImportedCredential {
  final String name;
  final String email;
  final String password;
  final String role;
  final String className;

  const ImportedCredential({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.className,
  });
}

class ExcelImportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _domain = 'smartschool.com';

  // ─────────────────────────────────────────────────────────────────────────
  //  EMAIL GENERATION
  //  "Ranim Ben Hassan" → "ranim.ben.hassan@smartschool.com"
  //  Handles accented chars, removes special chars, dots instead of spaces.
  //  Appends _N suffix if email already taken in the batch.
  // ─────────────────────────────────────────────────────────────────────────
  String _generateEmail(String fullName, Set<String> usedEmails) {
    final base = fullName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '.');

    String email = '$base@$_domain';
    int suffix = 1;
    while (usedEmails.contains(email)) {
      email = '${base}_$suffix@$_domain';
      suffix++;
    }
    usedEmails.add(email);
    return email;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  PASSWORD GENERATION — 10 chars, mixed
  // ─────────────────────────────────────────────────────────────────────────
  String _generatePassword({int length = 10}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EXPORT CREDENTIALS TO EXCEL BYTES
  //  Call this after importFromBytes to get the credentials file.
  //  Columns: Role | Full Name | Email | Password | Class
  // ─────────────────────────────────────────────────────────────────────────
  Uint8List exportCredentials(List<ImportedCredential> credentials) {
    final excel = Excel.createExcel();
    final sheet = excel['Credentials'];
    excel.setDefaultSheet('Credentials');

    // Header
    final headers = ['Role', 'Full Name', 'Email', 'Password', 'Class'];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(bold: true);
    }

    // Data
    for (int r = 0; r < credentials.length; r++) {
      final cr = credentials[r];
      final row = [cr.role, cr.name, cr.email, cr.password, cr.className];
      for (int c = 0; c < row.length; c++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
            .value = TextCellValue(row[c]);
      }
    }

    sheet.setColumnWidth(0, 12);
    sheet.setColumnWidth(1, 26);
    sheet.setColumnWidth(2, 36);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 20);

    return Uint8List.fromList(excel.encode()!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MAIN IMPORT
  // ─────────────────────────────────────────────────────────────────────────
  Future<ImportResult> importFromBytes(Uint8List bytes) async {
    int studentsCreated = 0;
    int teachersCreated = 0;
    int classesCreated = 0;
    final errors = <String>[];
    final credentials = <ImportedCredential>[];
    final usedEmails = <String>{};

    try {
      final excel = Excel.decodeBytes(bytes);

      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('import_secondary');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'import_secondary',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;
        final rows = sheet.rows;
        if (rows.isEmpty) continue;

        final lower = sheetName.toLowerCase().trim();

        if (lower.contains('class')) {
          classesCreated += await _importClasses(rows, errors);
        } else if (lower.contains('teacher')) {
          teachersCreated += await _importTeachers(
            rows,
            errors,
            credentials,
            secondaryAuth,
            usedEmails,
          );
        } else if (lower.contains('student')) {
          studentsCreated += await _importStudents(
            rows,
            errors,
            credentials,
            secondaryAuth,
            usedEmails,
          );
        }
      }

      await secondaryAuth.signOut();
    } catch (e) {
      errors.add('Fatal error: $e');
      debugPrint('Excel import error: $e');
    }

    return ImportResult(
      studentsCreated: studentsCreated,
      teachersCreated: teachersCreated,
      classesCreated: classesCreated,
      errors: errors,
      credentials: credentials,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  IMPORT CLASSES — Name | Grade | Level (header optional, positional ok)
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> _importClasses(
    List<List<Data?>> rows,
    List<String> errors,
  ) async {
    int count = 0;
    if (rows.isEmpty) return 0;

    final firstVals =
        rows[0]
            .map((c) => c?.value?.toString().toLowerCase().trim() ?? '')
            .toList();
    final known = {'name', 'grade', 'level', 'class', 'nom'};
    final isHeader = firstVals.any((v) => known.contains(v));

    final Map<String, int> headers;
    final int start;
    if (isHeader) {
      headers = _getHeaders(rows[0]);
      start = 1;
    } else {
      headers = {'name': 0, 'grade': 1, 'level': 2};
      start = 0;
    }

    for (int i = start; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      try {
        final name =
            _cell(row, headers, 'name') ?? _cell(row, headers, 'class') ?? '';
        final grade = _cell(row, headers, 'grade') ?? '';
        final level = _cell(row, headers, 'level') ?? '';
        // Group is optional — e.g. "TP 1", "TP 2"
        final group =
            _cell(row, headers, 'group') ??
            _cell(row, headers, 'tp') ??
            _cell(row, headers, 'groupe') ??
            '';

        if (name.isEmpty) {
          errors.add('Row ${i + 1} (Classes): Missing class name');
          continue;
        }

        final existing =
            await _db
                .collection('classes')
                .where(
                  'displayName',
                  isEqualTo: _buildDisplayName(level, name, grade, group),
                )
                .limit(1)
                .get();

        if (existing.docs.isNotEmpty) {
          errors.add(
            'Class "${_buildDisplayName(level, name, grade, group)}" already exists — skipped',
          );

          if (existing.docs.isNotEmpty) {
            errors.add('Class "$level $name $grade" already exists — skipped');
            continue;
          }

          final id = _db.collection('classes').doc().id;
          await _db.collection('classes').doc(id).set({
            'name': name,
            'grade': grade,
            'level': level,
            'displayName': _buildDisplayName(level, name, grade, group),
            'group': group,
            'teacherIds': [],
            'teacherNames': [],
            'roomId': '',
            'roomName': '',
            'studentCount': 0,
            'createdAt': FieldValue.serverTimestamp(),
          });
          count++;
        }
      } catch (e) {
        errors.add('Row ${i + 1} (Classes): $e');
      }
    }
    return count;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  IMPORT TEACHERS — Name | RfidTag (optional)
  //  Email auto-generated from name. Subject/classes assigned by admin later.
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> _importTeachers(
    List<List<Data?>> rows,
    List<String> errors,
    List<ImportedCredential> credentials,
    FirebaseAuth secondaryAuth,
    Set<String> usedEmails,
  ) async {
    int count = 0;
    if (rows.isEmpty) return 0;

    final firstVals =
        rows[0]
            .map((c) => c?.value?.toString().toLowerCase().trim() ?? '')
            .toList();
    final known = {'name', 'nom', 'rfid', 'rfidtag'};
    final isHeader = firstVals.any((v) => known.contains(v));

    final Map<String, int> headers;
    final int start;
    if (isHeader) {
      headers = _getHeaders(rows[0]);
      start = 1;
    } else {
      headers = {'name': 0, 'rfidtag': 1};
      start = 0;
    }

    for (int i = start; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      try {
        final name =
            _cell(row, headers, 'name') ?? _cell(row, headers, 'nom') ?? '';
        final rfidTag =
            _cell(row, headers, 'rfidtag') ?? _cell(row, headers, 'rfid') ?? '';

        if (name.isEmpty) {
          errors.add('Row ${i + 1} (Teachers): Missing name');
          continue;
        }

        final email = _generateEmail(name, usedEmails);
        final password = _generatePassword();

        UserCredential cred;
        try {
          cred = await secondaryAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          errors.add('Teacher "$name" ($email): Auth error — $e');
          continue;
        }

        final uid = cred.user!.uid;

        await _db.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'role': 'teacher',
          'first_login': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _db.collection('teachers').doc(uid).set({
          'userId': uid,
          'name': name,
          'email': email,
          'subject': '',
          'assignedClassIds': [],
          'assignedClassNames': [],
          'rfidTag': rfidTag,
          'rfidEnabled': rfidTag.isNotEmpty,
          'createdAt': FieldValue.serverTimestamp(),
        });

        credentials.add(
          ImportedCredential(
            name: name,
            email: email,
            password: password,
            role: 'Teacher',
            className: '',
          ),
        );
        count++;
      } catch (e) {
        errors.add('Row ${i + 1} (Teachers): $e');
      }
    }
    return count;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  IMPORT STUDENTS — Name | Class | RfidTag (optional)
  //  Email auto-generated from name.
  //  Class matched by displayName ("1 DNI 2") or name field.
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> _importStudents(
    List<List<Data?>> rows,
    List<String> errors,
    List<ImportedCredential> credentials,
    FirebaseAuth secondaryAuth,
    Set<String> usedEmails,
  ) async {
    int count = 0;
    if (rows.isEmpty) return 0;

    final firstVals =
        rows[0]
            .map((c) => c?.value?.toString().toLowerCase().trim() ?? '')
            .toList();
    final known = {'name', 'nom', 'class', 'classe', 'rfid', 'rfidtag'};
    final isHeader = firstVals.any((v) => known.contains(v));

    final Map<String, int> headers;
    final int start;
    if (isHeader) {
      headers = _getHeaders(rows[0]);
      start = 1;
    } else {
      headers = {'name': 0, 'class': 1, 'rfidtag': 2};
      start = 0;
    }

    for (int i = start; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      try {
        final name =
            _cell(row, headers, 'name') ?? _cell(row, headers, 'nom') ?? '';
        final className =
            _cell(row, headers, 'class') ?? _cell(row, headers, 'classe') ?? '';
        final rfidTag =
            _cell(row, headers, 'rfidtag') ?? _cell(row, headers, 'rfid') ?? '';

        if (name.isEmpty) {
          errors.add('Row ${i + 1} (Students): Missing name');
          continue;
        }

        final email = _generateEmail(name, usedEmails);
        final password = _generatePassword();

        UserCredential cred;
        try {
          cred = await secondaryAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          errors.add('Student "$name" ($email): Auth error — $e');
          continue;
        }

        final uid = cred.user!.uid;

        // Resolve class — displayName first ("1 DNI 2"), then name field
        String classId = '';
        String resolvedClassName = className;
        String level = '';

        if (className.isNotEmpty) {
          // Attempt 1: exact displayName match e.g. "1 DNI 2"
          var snap =
              await _db
                  .collection('classes')
                  .where('displayName', isEqualTo: className)
                  .limit(1)
                  .get();

          // Attempt 2: exact name match (class name only e.g. "DNI")
          if (snap.docs.isEmpty) {
            snap =
                await _db
                    .collection('classes')
                    .where('name', isEqualTo: className)
                    .limit(1)
                    .get();
          }

          // Attempt 3: split "Level Name Grade" into parts and query individually
          // Handles "1 DNI 2" → level="1", name="DNI", grade="2"
          if (snap.docs.isEmpty) {
            final parts = className.trim().split(RegExp(r'\s+'));
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
            } else if (parts.length == 2) {
              // "DNI 1" → name="DNI", grade="1"
              snap =
                  await _db
                      .collection('classes')
                      .where('name', isEqualTo: parts[0])
                      .where('grade', isEqualTo: parts[1])
                      .limit(1)
                      .get();
            }
          }

          if (snap.docs.isNotEmpty) {
            classId = snap.docs.first.id;
            final d = snap.docs.first.data();
            resolvedClassName =
                d['displayName']?.toString() ??
                d['name']?.toString() ??
                className;
            level = d['level']?.toString() ?? '';
            await snap.docs.first.reference.update({
              'studentCount': FieldValue.increment(1),
            });
          } else {
            errors.add(
              'Student "$name": Class "$className" not found — imported without class',
            );
          }
        }

        await _db.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'role': 'student',
          'first_login': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await _db.collection('students').doc(uid).set({
          'userId': uid,
          'name': name,
          'email': email,
          'classId': classId,
          'className': resolvedClassName,
          'level': level,
          'rfidTag': rfidTag,
          'totalPresence': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });

        credentials.add(
          ImportedCredential(
            name: name,
            email: email,
            password: password,
            role: 'Student',
            className: resolvedClassName,
          ),
        );
        count++;
      } catch (e) {
        errors.add('Row ${i + 1} (Students): $e');
      }
    }
    return count;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Map<String, int> _getHeaders(List<Data?> headerRow) {
    final map = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      final val = headerRow[i]?.value?.toString().toLowerCase().trim();
      if (val != null && val.isNotEmpty) map[val] = i;
    }
    return map;
  }

  String? _cell(List<Data?> row, Map<String, int> headers, String key) {
    final idx = headers[key];
    if (idx == null || idx >= row.length) return null;
    return row[idx]?.value?.toString().trim();
  }

  bool _isRowEmpty(List<Data?> row) => row.every(
    (c) => c == null || c.value == null || c.value.toString().trim().isEmpty,
  );
  String _buildDisplayName(
    String level,
    String name,
    String grade,
    String group,
  ) {
    final base = '$level $name $grade'.trim();
    final g = group.trim();
    return g.isEmpty ? base : '$base $g';
  }
}
