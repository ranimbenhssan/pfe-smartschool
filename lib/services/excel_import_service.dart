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

// ─────────────────────────────────────────
//  RESULT TYPES
// ─────────────────────────────────────────
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

// ─────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────
class ExcelImportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Replicates ClassModel.getFullName() without importing the model ───
  // Structure: level + name + grade → "3 IOT 1"
  String _buildClassName(String level, String name, String grade) {
    final parts = <String>[];
    if (level.trim().isNotEmpty) parts.add(level.trim());
    if (name.trim().isNotEmpty) parts.add(name.trim());
    if (grade.trim().isNotEmpty) parts.add(grade.trim());
    return parts.isNotEmpty ? parts.join(' ') : name.trim();
  }

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

  // ─────────────────────────────────────────
  //  ENTRY POINT
  // ─────────────────────────────────────────
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
          classesCreated += await _importClasses(rows, errors);
        } else if (sheetLower.contains('teacher')) {
          teachersCreated += await _importTeachers(
            rows,
            errors,
            credentials,
            secondaryAuth,
          );
        } else if (sheetLower.contains('student')) {
          studentsCreated += await _importStudents(
            rows,
            errors,
            credentials,
            secondaryAuth,
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

  // ─────────────────────────────────────────
  //  IMPORT CLASSES
  //  Expected columns: Name | Grade | Level
  // ─────────────────────────────────────────
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

        // ─── FIX: build combined displayName = "3 IOT 1" ───
        final displayName = _buildClassName(level, name, grade);

        final classId = _db.collection('classes').doc().id;
        await _db.collection('classes').doc(classId).set({
          'name': name,
          'grade': grade,
          'level': level,
          'displayName': displayName, // ← "3 IOT 1"
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

  // ─────────────────────────────────────────
  //  IMPORT TEACHERS
  //  Expected columns: Name | Email | Class | Subject | RfidTag (optional)
  // ─────────────────────────────────────────
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
        final rawClassName = _cell(row, headers, 'class') ?? '';
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

        // ─── Resolve class → combined className ───
        List<String> classIds = [];
        List<String> classNames = [];

        if (rawClassName.isNotEmpty) {
          final classSnap =
              await _db
                  .collection('classes')
                  .where('name', isEqualTo: rawClassName)
                  .limit(1)
                  .get();

          if (classSnap.docs.isNotEmpty) {
            final classDoc = classSnap.docs.first;
            final classData = classDoc.data();

            // ─── FIX: build combined displayName for assignedClassNames ───
            final lvl = classData['level']?.toString() ?? '';
            final nm = classData['name']?.toString() ?? rawClassName;
            final gr = classData['grade']?.toString() ?? '';
            final combinedName = _buildClassName(lvl, nm, gr); // "3 IOT 1"

            classIds = [classDoc.id];
            classNames = [combinedName];

            // ─── Update class document with this teacher ───
            final existingIds = List<String>.from(
              classData['teacherIds'] ?? [],
            );
            final existingNames = List<String>.from(
              classData['teacherNames'] ?? [],
            );
            if (!existingIds.contains(uid)) {
              await classDoc.reference.update({
                'teacherIds': [...existingIds, uid],
                'teacherNames': [...existingNames, name],
              });
            }
          } else {
            errors.add(
              'Teacher "$name": Class "$rawClassName" not found — teacher saved without class',
            );
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

        // ─── Create teacher doc ───
        await _db.collection('teachers').doc(uid).set({
          'userId': uid,
          'name': name,
          'email': email.trim(),
          'assignedClassIds': classIds,
          'assignedClassNames': classNames, // ← ["3 IOT 1"] not ["IOT"]
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
            className: classNames.isNotEmpty ? classNames.first : rawClassName,
          ),
        );

        count++;
      } catch (e) {
        errors.add('Row ${i + 1} (Teachers): $e');
      }
    }
    return count;
  }

  // ─────────────────────────────────────────
  //  IMPORT STUDENTS
  //  Expected columns: Name | Email | Class | RfidTag (optional)
  // ─────────────────────────────────────────
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
        final rawClassName = _cell(row, headers, 'class') ?? '';
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

        // ─── Resolve class → combined className ───
        String resolvedClassId = '';
        String resolvedClassName = rawClassName; // fallback if class not found
        String resolvedLevel = '';

        if (rawClassName.isNotEmpty) {
          final classSnap =
              await _db
                  .collection('classes')
                  .where('name', isEqualTo: rawClassName)
                  .limit(1)
                  .get();

          if (classSnap.docs.isNotEmpty) {
            final classDoc = classSnap.docs.first;
            final classData = classDoc.data();

            // ─── FIX: build combined displayName for className field ───
            final lvl = classData['level']?.toString() ?? '';
            final nm = classData['name']?.toString() ?? rawClassName;
            final gr = classData['grade']?.toString() ?? '';
            resolvedClassId = classDoc.id;
            resolvedClassName = _buildClassName(lvl, nm, gr); // "3 IOT 1"
            resolvedLevel = lvl;

            // ─── Increment student count ───
            await classDoc.reference.update({
              'studentCount': FieldValue.increment(1),
            });
          } else {
            errors.add(
              'Student "$name": Class "$rawClassName" not found — student saved without class',
            );
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
          'classId': resolvedClassId,
          'className': resolvedClassName, // ← "3 IOT 1" not just "IOT"
          'level': resolvedLevel,
          'rfidTag': rfidTag,
          'presenceCount': 0,
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

  // ─────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────
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
