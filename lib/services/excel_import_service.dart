import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../firebase_options.dart';

final excelImportServiceProvider = Provider<ExcelImportService>(
  (ref) => ExcelImportService(),
);

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
  final _db = FirebaseFirestore.instance;
  static const _domain = 'smartschool.com';

  // ─────────────────────────────────────────────────────────────────────────
  //  EMAIL — "Ranim Ben Hassan" → "ranim.ben.hassan@smartschool.com"
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
    int n = 1;
    while (usedEmails.contains(email)) email = '${base}_${n++}@$_domain';
    usedEmails.add(email);
    return email;
  }

  String _generatePassword({int length = 10}) {
    const c =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    final rng = Random.secure();
    return List.generate(length, (_) => c[rng.nextInt(c.length)]).join();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EXPORT CREDENTIALS
  // ─────────────────────────────────────────────────────────────────────────
  Uint8List exportCredentials(List<ImportedCredential> credentials) {
    final excel = Excel.createExcel();
    final sheet = excel['Credentials'];
    excel.setDefaultSheet('Credentials');
    final headers = ['Role', 'Full Name', 'Email', 'Password', 'Class'];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(bold: true);
    }
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
    sheet.setColumnWidth(4, 22);
    return Uint8List.fromList(excel.encode()!);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  MAIN IMPORT
  // ─────────────────────────────────────────────────────────────────────────
  Future<ImportResult> importFromBytes(Uint8List bytes) async {
    int studentsCreated = 0, teachersCreated = 0, classesCreated = 0;
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
  //  IMPORT CLASSES
  //
  //  Supported formats:
  //  A) With header row:    Name | Grade | Level | Group (optional)
  //  B) No header row:      DNI  | 1     | 3     | TP 2  (positional)
  //
  //  Group column is OPTIONAL — if empty/absent the class is "3 DNI 1"
  //  If present (e.g. "TP 2") the class is "3 DNI 1 TP 2"
  //
  //  Duplicate check: full displayName (level + name + grade [+ group])
  // ─────────────────────────────────────────────────────────────────────────
  Future<int> _importClasses(
    List<List<Data?>> rows,
    List<String> errors,
  ) async {
    int count = 0;
    if (rows.isEmpty) return 0;

    // Detect header row
    final firstVals =
        rows[0]
            .map((c) => c?.value?.toString().toLowerCase().trim() ?? '')
            .toList();
    const knownHeaders = {
      'name',
      'grade',
      'level',
      'class',
      'nom',
      'groupe',
      'group',
    };
    final isHeader = firstVals.any((v) => knownHeaders.contains(v));

    final Map<String, int> headers;
    final int start;
    if (isHeader) {
      headers = _getHeaders(rows[0]);
      start = 1;
    } else {
      // Positional: col0=Name, col1=Grade, col2=Level, col3=Group(optional)
      headers = {'name': 0, 'grade': 1, 'level': 2, 'group': 3};
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
        // Group is optional — "TP 1", "TP 2" etc.
        final group =
            _cell(row, headers, 'group') ?? _cell(row, headers, 'groupe') ?? '';

        if (name.isEmpty) {
          errors.add('Row ${i + 1} (Classes): Missing class name');
          continue;
        }

        // Build the full display name
        final displayName = _buildDisplayName(level, name, grade, group);

        // Duplicate check on full displayName
        final existing =
            await _db
                .collection('classes')
                .where('displayName', isEqualTo: displayName)
                .limit(1)
                .get();

        if (existing.docs.isNotEmpty) {
          errors.add('Class "$displayName" already exists — skipped');
          continue;
        }

        final classId = _db.collection('classes').doc().id;
        await _db.collection('classes').doc(classId).set({
          'name': name,
          'grade': grade,
          'level': level,
          'group': group,
          'displayName': displayName,
          'teacherIds': [],
          'teacherNames': [],
          'roomId': '',
          'roomName': '',
          'studentCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      } catch (e) {
        errors.add('Row ${i + 1} (Classes): $e');
      }
    }
    return count;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  IMPORT TEACHERS — Name | RfidTag (optional)
  //  Email and password are AUTO-GENERATED.
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
    final isHeader = firstVals.any(
      (v) => {'name', 'nom', 'rfid', 'rfidtag'}.contains(v),
    );

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
          'email': email.trim(),
          'role': 'teacher',
          'first_login': true,
          'temp_password': password, // ← ADD: stored for admin password reset
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
  //
  //  The Class column contains the FULL class name as displayed:
  //    • Without group: "3 DNI 1"
  //    • With group:    "3 IOT 1 TP 2"
  //
  //  Class resolution order:
  //  1. Exact match on displayName field (e.g. "3 IOT 1 TP 2")
  //  2. Exact match on name field (e.g. "IOT")
  //  3. Split into parts → query level + name + grade separately
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
    final isHeader = firstVals.any(
      (v) => {'name', 'nom', 'class', 'classe', 'rfid', 'rfidtag'}.contains(v),
    );

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

        // ── Resolve class by FULL displayName ──────────────────────────────
        String classId = '';
        String resolvedClassName = className;
        String level = '';

        if (className.isNotEmpty) {
          final snap = await _resolveClass(className);
          if (snap != null) {
            classId = snap.id;
            final d = snap.data();
            resolvedClassName =
                d?['displayName']?.toString() ??
                d?['name']?.toString() ??
                className;
            level = d?['level']?.toString() ?? '';
            await snap.reference.update({
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
          'email': email.trim(),
          'role': 'student',
          'first_login': true,
          'temp_password': password, // ← ADD: stored for admin password reset
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

  // ─────────────────────────────────────────────────────────────────────────
  //  CLASS RESOLUTION
  //
  //  Tries three strategies in order:
  //  1. displayName == "3 IOT 1 TP 2"   (full match including group)
  //  2. name == className                (plain name match)
  //  3. Split by spaces → level + name + grade parts query
  // ─────────────────────────────────────────────────────────────────────────
  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveClass(
    String className,
  ) async {
    // 1. Exact displayName
    var snap =
        await _db
            .collection('classes')
            .where('displayName', isEqualTo: className)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // 2. Exact name
    snap =
        await _db
            .collection('classes')
            .where('name', isEqualTo: className)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) return snap.docs.first;

    // 3. Split "level name grade [group]" — try level + name + grade
    final parts = className.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      // Try: parts[0]=level, parts[1]=name, parts[2]=grade
      snap =
          await _db
              .collection('classes')
              .where('level', isEqualTo: parts[0])
              .where('name', isEqualTo: parts[1])
              .where('grade', isEqualTo: parts[2])
              .limit(1)
              .get();
      if (snap.docs.isNotEmpty) return snap.docs.first;

      // Try: parts[0]=level, parts[1..n-1]=name, parts[n]=grade
      if (parts.length >= 4) {
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
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD DISPLAY NAME
  //  "3" + "IOT" + "1" + "TP 2" → "3 IOT 1 TP 2"
  //  "3" + "DNI" + "2" + ""     → "3 DNI 2"
  // ─────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────
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
}
