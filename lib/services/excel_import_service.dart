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

// ─── Import result ───
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

  // ─── Generate random password ───
  String _generatePassword({int length = 10}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
    final rng = Random.secure();
    return List.generate(
      length,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
  }

  // ─── Parse Excel bytes ───
  Future<ImportResult> importFromBytes(Uint8List bytes) async {
    int studentsCreated = 0;
    int teachersCreated = 0;
    int classesCreated = 0;
    final errors = <String>[];
    final credentials = <ImportedCredential>[];

    try {
      final excel = Excel.decodeBytes(bytes);

      // ─── Secondary Firebase app for user creation ───
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

      // ─── Process each sheet ───
      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName]!;
        final rows = sheet.rows;
        if (rows.isEmpty) continue;

        final sheetLower = sheetName.toLowerCase().trim();

        if (sheetLower.contains('class')) {
          final result = await _importClasses(rows, errors);
          classesCreated += result;
        } else if (sheetLower.contains('teacher')) {
          final result = await _importTeachers(
            rows,
            errors,
            credentials,
            secondaryAuth,
          );
          teachersCreated += result;
        } else if (sheetLower.contains('student')) {
          final result = await _importStudents(
            rows,
            errors,
            credentials,
            secondaryAuth,
          );
          studentsCreated += result;
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

  // ─── Import Classes sheet ───
  // Expected columns: Name | Grade | Level
  Future<int> _importClasses(
    List<List<Data?>> rows,
    List<String> errors,
  ) async {
    int count = 0;
    final headers = _getHeaders(rows[0]);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;

      try {
        final name =
            _cell(row, headers, 'name') ?? _cell(row, headers, 'class') ?? '';
        final grade = _cell(row, headers, 'grade') ?? '';
        final level = _cell(row, headers, 'level') ?? '';

        if (name.isEmpty) {
          errors.add('Row ${i + 1} (Classes): Missing class name');
          continue;
        }

        // ─── Check if class already exists ───
        final existing =
            await _db
                .collection('classes')
                .where('name', isEqualTo: name)
                .where('grade', isEqualTo: grade)
                .limit(1)
                .get();

        if (existing.docs.isNotEmpty) {
          errors.add('Class "$name" already exists — skipped');
          continue;
        }

        final classId = _db.collection('classes').doc().id;
        await _db.collection('classes').doc(classId).set({
          'name': name,
          'grade': grade,
          'level': level,
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

  // ─── Import Teachers sheet ───
  // Expected columns: Name | Email | Class | Subject | RfidTag (optional)
  Future<int> _importTeachers(
    List<List<Data?>> rows,
    List<String> errors,
    List<ImportedCredential> credentials,
    FirebaseAuth secondaryAuth,
  ) async {
    int count = 0;
    final headers = _getHeaders(rows[0]);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;

      try {
        final name = _cell(row, headers, 'name') ?? '';
        final email = _cell(row, headers, 'email') ?? '';
        final className = _cell(row, headers, 'class') ?? '';
        final subject = _cell(row, headers, 'subject') ?? '';
        final rfidTag =
            _cell(row, headers, 'rfid') ?? _cell(row, headers, 'rfidtag') ?? '';

        if (name.isEmpty || email.isEmpty) {
          errors.add('Row ${i + 1} (Teachers): Missing name or email');
          continue;
        }

        final password = _generatePassword();

        // ─── Create Firebase Auth user ───
        UserCredential cred;
        try {
          cred = await secondaryAuth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } catch (e) {
          errors.add('Teacher "$name" ($email): Auth error — $e');
          continue;
        }

        final uid = cred.user!.uid;

        // ─── Find assigned class ───
        List<String> classIds = [];
        List<String> classNames = [];

        if (className.isNotEmpty) {
          final classSnap =
              await _db
                  .collection('classes')
                  .where('name', isEqualTo: className)
                  .limit(1)
                  .get();
          if (classSnap.docs.isNotEmpty) {
            classIds = [classSnap.docs.first.id];
            classNames = [className];

            // ─── Update class with teacher ───
            final classData = classSnap.docs.first.data();
            final existingIds = List<String>.from(
              classData['teacherIds'] ?? [],
            );
            final existingNames = List<String>.from(
              classData['teacherNames'] ?? [],
            );
            if (!existingIds.contains(uid)) {
              await classSnap.docs.first.reference.update({
                'teacherIds': [...existingIds, uid],
                'teacherNames': [...existingNames, name],
              });
            }
          }
        }

        // ─── Create user doc ───
        await _db.collection('users').doc(uid).set({
          'name': name,
          'email': email.trim(),
          'role': 'teacher',
          'first_login': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ─── Create teacher doc with RFID support ───
        await _db.collection('teachers').doc(uid).set({
          'userId': uid,
          'name': name,
          'email': email.trim(),
          'assignedClassIds': classIds,
          'assignedClassNames': classNames,
          'subject': subject,
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
            className: className,
          ),
        );

        count++;
      } catch (e) {
        errors.add('Row ${i + 1} (Teachers): $e');
      }
    }
    return count;
  }

  // ─── Import Students sheet ───
  // Expected columns: Name | Email | Class | RfidTag (optional)
  Future<int> _importStudents(
    List<List<Data?>> rows,
    List<String> errors,
    List<ImportedCredential> credentials,
    FirebaseAuth secondaryAuth,
  ) async {
    int count = 0;
    final headers = _getHeaders(rows[0]);

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;

      try {
        final name = _cell(row, headers, 'name') ?? '';
        final email = _cell(row, headers, 'email') ?? '';
        final className = _cell(row, headers, 'class') ?? '';
        final rfidTag =
            _cell(row, headers, 'rfid') ?? _cell(row, headers, 'rfidtag') ?? '';

        if (name.isEmpty || email.isEmpty) {
          errors.add('Row ${i + 1} (Students): Missing name or email');
          continue;
        }

        final password = _generatePassword();

        // ─── Create Firebase Auth user ───
        UserCredential cred;
        try {
          cred = await secondaryAuth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } catch (e) {
          errors.add('Student "$name" ($email): Auth error — $e');
          continue;
        }

        final uid = cred.user!.uid;

        // ─── Find class ───
        String classId = '';
        String resolvedClassName = className;
        String level = '';

        if (className.isNotEmpty) {
          final classSnap =
              await _db
                  .collection('classes')
                  .where('name', isEqualTo: className)
                  .limit(1)
                  .get();
          if (classSnap.docs.isNotEmpty) {
            classId = classSnap.docs.first.id;
            final data = classSnap.docs.first.data();
            resolvedClassName = data['name'] ?? className;
            level = data['level']?.toString() ?? '';

            // ─── Increment student count ───
            await classSnap.docs.first.reference.update({
              'studentCount': FieldValue.increment(1),
            });
          } else {
            errors.add('Student "$name": Class "$className" not found');
          }
        }

        // ─── Create user doc ───
        await _db.collection('users').doc(uid).set({
          'name': name,
          'email': email.trim(),
          'role': 'student',
          'first_login': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // ─── Create student doc ───
        await _db.collection('students').doc(uid).set({
          'userId': uid,
          'name': name,
          'email': email.trim(),
          'classId': classId,
          'className': resolvedClassName,
          'level': level,
          'rfidTag': rfidTag,
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

  // ─── Helpers ───
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

  bool _isRowEmpty(List<Data?> row) {
    return row.every(
      (c) => c == null || c.value == null || c.value.toString().trim().isEmpty,
    );
  }
}
