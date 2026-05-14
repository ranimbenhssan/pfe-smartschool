// lib/screens/admin/import/super_admin_import_screen.dart
//
// SuperAdmin only — imports HR and Registrar staff accounts.
// Excel format: one sheet named "Staff"
// Columns: Name | Role
//   Role values: "RH" / "HR" / "admin_rh"   → creates adminRH account
//                "Scolarite" / "admin_scolarite" → creates adminScolarite account
//
// Returns a downloadable credentials file with:
// Name | Role | Email | Generated Password

import 'dart:math';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../firebase_options.dart';

// ─────────────────────────────────────────────────────────────────────────────
class SuperAdminImportScreen extends ConsumerStatefulWidget {
  const SuperAdminImportScreen({super.key});

  @override
  ConsumerState<SuperAdminImportScreen> createState() =>
      _SuperAdminImportScreenState();
}

class _SuperAdminImportScreenState
    extends ConsumerState<SuperAdminImportScreen> {
  bool _isImporting = false;
  _StaffImportResult? _result;

  Future<void> _pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null) return;

    setState(() {
      _isImporting = true;
      _result = null;
    });

    final result = await _importStaff(bytes);

    setState(() {
      _isImporting = false;
      _result = result;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  IMPORT STAFF
  // ─────────────────────────────────────────────────────────────────────────
  Future<_StaffImportResult> _importStaff(Uint8List bytes) async {
    final credentials = <_StaffCredential>[];
    final errors = <String>[];
    int created = 0;

    try {
      // Secondary Firebase app for user creation
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('staff_import');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'staff_import',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final db = FirebaseFirestore.instance;

      final excel = Excel.decodeBytes(bytes);

      // Find the staff sheet
      final sheetName = excel.tables.keys.firstWhere(
        (k) =>
            k.toLowerCase().contains('staff') ||
            k.toLowerCase().contains('personnel'),
        orElse: () => excel.tables.keys.first,
      );
      final sheet = excel.tables[sheetName]!;
      if (sheet.rows.isEmpty) {
        return _StaffImportResult(
          created: 0,
          errors: ['Empty sheet'],
          credentials: [],
        );
      }

      // Parse headers
      final headers = <String, int>{};
      for (int i = 0; i < sheet.rows[0].length; i++) {
        final val = sheet.rows[0][i]?.value?.toString().toLowerCase().trim();
        if (val != null && val.isNotEmpty) headers[val] = i;
      }

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.every((c) => c?.value == null)) continue;

        final name = _cell(row, headers, 'name') ?? '';
        final roleRaw =
            (_cell(row, headers, 'role') ?? _cell(row, headers, 'poste') ?? '')
                .toLowerCase()
                .trim();

        if (name.isEmpty) {
          errors.add('Row ${i + 1}: Missing name');
          continue;
        }
        if (roleRaw.isEmpty) {
          errors.add('Row ${i + 1} ($name): Missing role');
          continue;
        }

        // Resolve role
        String firestoreRole;
        String roleLabel;
        if (roleRaw.contains('rh') ||
            roleRaw.contains('hr') ||
            roleRaw == 'admin_rh') {
          firestoreRole = 'admin_rh';
          roleLabel = 'HR Staff';
        } else if (roleRaw.contains('scol') ||
            roleRaw.contains('registrar') ||
            roleRaw == 'admin_scolarite') {
          firestoreRole = 'admin_scolarite';
          roleLabel = 'Registrar';
        } else {
          errors.add(
            'Row ${i + 1} ($name): Unknown role "$roleRaw" — use "RH" or "Scolarite"',
          );
          continue;
        }

        // Generate email from name
        final emailBase = name
            .toLowerCase()
            .replaceAll(' ', '.')
            .replaceAll(RegExp(r'[^a-z.]'), '');
        final email = '$emailBase@smartschool.com';
        final password = _generatePassword();

        // Check if email already exists
        final existing =
            await db
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
        if (existing.docs.isNotEmpty) {
          errors.add(
            'Row ${i + 1} ($name): Email $email already exists — skipped',
          );
          continue;
        }

        try {
          // Create Firebase Auth account
          final credential = await secondaryAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          final uid = credential.user!.uid;
          await secondaryAuth.signOut();

          // Create user doc
          await db.collection('users').doc(uid).set({
            'name': name,
            'email': email,
            'role': firestoreRole,
            'first_login': true,
            'temp_password': password,
            'createdAt': FieldValue.serverTimestamp(),
          });

          credentials.add(
            _StaffCredential(
              name: name,
              role: roleLabel,
              email: email,
              password: password,
            ),
          );
          created++;
        } catch (e) {
          errors.add('Row ${i + 1} ($name): $e');
        }
      }

      await secondaryAuth.signOut();
    } catch (e) {
      errors.add('Fatal error: $e');
    }

    return _StaffImportResult(
      created: created,
      errors: errors,
      credentials: credentials,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EXPORT credentials to Excel
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _downloadCredentials(List<_StaffCredential> creds) async {
    final excel = Excel.createExcel();
    final sheet = excel['Staff Credentials'];

    // Header
    const headers = ['Name', 'Role', 'Email', 'Password'];
    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[c]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('FF1565C0'),
        fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      );
    }

    for (int r = 0; r < creds.length; r++) {
      final c = creds[r];
      final bg = ExcelColor.fromHexString(r.isOdd ? 'FFF5F5F5' : 'FFFFFFFF');
      void w(int col, String val) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: r + 1),
        );
        cell.value = TextCellValue(val);
        cell.cellStyle = CellStyle(backgroundColorHex: bg);
      }

      w(0, c.name);
      w(1, c.role);
      w(2, c.email);
      w(3, c.password);
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 14);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 16);
    excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/staff_credentials.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: 'Staff Credentials');
  }

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

  String? _cell(List<Data?> row, Map<String, int> headers, String key) {
    final idx = headers[key];
    if (idx == null || idx >= row.length) return null;
    return row[idx]?.value?.toString().trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Import Staff Accounts'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Instructions ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.info,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Excel File Format',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sheet name: "Staff" or "Personnel"',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Columns: Name | Role', style: AppTypography.caption),
                  const SizedBox(height: 8),
                  _ExampleRow('Sana Trabelsi', 'RH'),
                  _ExampleRow('Karim Boughdiri', 'Scolarite'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Role values accepted:',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '• HR / RH / admin_rh  → HR Staff account',
                          style: AppTypography.caption,
                        ),
                        Text(
                          '• Scolarite / Registrar / admin_scolarite  → Registrar account',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Email is auto-generated: firstname.lastname@smartschool.com\n'
                    '• Password is auto-generated (10 chars)\n'
                    '• Staff must change password on first login',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Upload button ────────────────────────────────────────────
            AppButton(
              label: _isImporting ? 'Importing...' : 'Select Excel File',
              onPressed: _isImporting ? () {} : _pickAndImport,
              isLoading: _isImporting,
              width: double.infinity,
              icon: Icons.upload_file_rounded,
            ),

            // ── Results ──────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 24),
              _ResultCard(
                result: _result!,
                isDark: isDark,
                onDownload: () => _downloadCredentials(_result!.credentials),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
class _ExampleRow extends StatelessWidget {
  final String name, role;
  const _ExampleRow(this.name, this.role);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        const Icon(Icons.arrow_right_rounded, size: 14),
        Text(
          '$name  |  $role',
          style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final _StaffImportResult result;
  final bool isDark;
  final VoidCallback onDownload;
  const _ResultCard({
    required this.result,
    required this.isDark,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: 10),
              Text(
                '${result.created} account${result.created == 1 ? '' : 's'} created',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),

        // Errors
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.errors.length} issue${result.errors.length == 1 ? '' : 's'}',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                ...result.errors.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('• $e', style: AppTypography.caption),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Credentials list + download
        if (result.credentials.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Generated Credentials', style: AppTypography.headingMedium),
              TextButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download Excel'),
                onPressed: onDownload,
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Header row
          _CredRow(
            name: 'Name',
            role: 'Role',
            email: 'Email',
            password: 'Password',
            isHeader: true,
          ),
          ...result.credentials.map(
            (c) => _CredRow(
              name: c.name,
              role: c.role,
              email: c.email,
              password: c.password,
              isHeader: false,
              isDark: isDark,
            ),
          ),
        ],
      ],
    );
  }
}

class _CredRow extends StatelessWidget {
  final String name, role, email, password;
  final bool isHeader;
  final bool isDark;
  const _CredRow({
    required this.name,
    required this.role,
    required this.email,
    required this.password,
    this.isHeader = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final style =
        isHeader
            ? AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold)
            : AppTypography.caption;
    final bg =
        isHeader
            ? AppColors.accent.withValues(alpha: 0.12)
            : isDark
            ? AppColors.darkCard
            : AppColors.lightCard;

    return GestureDetector(
      onTap:
          isHeader
              ? null
              : () {
                Clipboard.setData(
                  ClipboardData(text: '$name | $role | $email | $password'),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Copied!')));
              },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(name, style: style, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(role, style: style, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 3,
              child: Text(email, style: style, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(
                password,
                style: style.copyWith(fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Models ──────────────────────────────
class _StaffImportResult {
  final int created;
  final List<String> errors;
  final List<_StaffCredential> credentials;
  const _StaffImportResult({
    required this.created,
    required this.errors,
    required this.credentials,
  });
}

class _StaffCredential {
  final String name, role, email, password;
  const _StaffCredential({
    required this.name,
    required this.role,
    required this.email,
    required this.password,
  });
}
