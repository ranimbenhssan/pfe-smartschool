// lib/screens/admin/import/super_admin_import_screen.dart
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

class SuperAdminImportScreen extends ConsumerStatefulWidget {
  const SuperAdminImportScreen({super.key});

  @override
  ConsumerState<SuperAdminImportScreen> createState() =>
      _SuperAdminImportScreenState();
}

class _SuperAdminImportScreenState
    extends ConsumerState<SuperAdminImportScreen> {
  bool _isImporting = false;
  _ImportResult? _result;

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

  Future<_ImportResult> _importStaff(Uint8List bytes) async {
    final credentials = <_Credential>[];
    final errors = <String>[];
    int created = 0;

    try {
      // Secondary Firebase app for account creation
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
      final sheetName = excel.tables.keys.firstWhere(
        (k) =>
            k.toLowerCase().contains('staff') ||
            k.toLowerCase().contains('personnel'),
        orElse: () => excel.tables.keys.first,
      );
      final sheet = excel.tables[sheetName]!;
      if (sheet.rows.isEmpty) {
        return _ImportResult(
          created: 0,
          errors: ['Empty sheet'],
          credentials: [],
        );
      }

      // Parse headers
      final headers = <String, int>{};
      for (int i = 0; i < sheet.rows[0].length; i++) {
        final v =
            sheet.rows[0][i]?.value?.toString().toLowerCase().trim() ?? '';
        if (v.isNotEmpty) headers[v] = i;
      }

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.every((c) => c?.value == null)) continue;

        final name = _cell(row, headers, 'name') ?? '';
        final roleRaw =
            (_cell(row, headers, 'role') ?? _cell(row, headers, 'poste') ?? '')
                .toLowerCase()
                .trim();
        final rfidTag =
            (_cell(row, headers, 'rfid tag') ??
                    _cell(row, headers, 'rfid') ??
                    _cell(row, headers, 'tag') ??
                    '')
                .toUpperCase()
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
            'Row ${i + 1} ($name): Unknown role "$roleRaw"'
            ' — use "RH" or "Scolarite"',
          );
          continue;
        }

        // Generate email
        final emailBase = name
            .toLowerCase()
            .replaceAll(' ', '.')
            .replaceAll(RegExp(r'[^a-z.]'), '');
        final email = '$emailBase@faccna.tn';
        final password = _generatePassword();

        // Check existing email
        final existing =
            await db
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
        if (existing.docs.isNotEmpty) {
          errors.add('Row ${i + 1} ($name): $email already exists — skipped');
          continue;
        }

        try {
          final cred = await secondaryAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          final uid = cred.user!.uid;
          await secondaryAuth.signOut();

          // Create user doc
          await db.collection('users').doc(uid).set({
            'name': name,
            'email': email,
            'role': firestoreRole,
            'first_login': true,
            'temp_password': password,
            'rfidTag': rfidTag.isNotEmpty ? rfidTag : null,
            'createdAt': FieldValue.serverTimestamp(),
          });

          credentials.add(
            _Credential(
              name: name,
              role: roleLabel,
              email: email,
              password: password,
              rfidTag: rfidTag,
            ),
          );
          created++;
        } catch (e) {
          errors.add('Row ${i + 1} ($name): $e');
        }
      }

      await secondaryAuth.signOut();
    } catch (e) {
      errors.add('Fatal: $e');
    }

    return _ImportResult(
      created: created,
      errors: errors,
      credentials: credentials,
    );
  }

  Future<void> _downloadCredentials(List<_Credential> creds) async {
    final excel = Excel.createExcel();
    final sheet = excel['Staff Credentials'];

    const headers = ['Name', 'Role', 'Email', 'Password', 'RFID Tag'];
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
      w(4, c.rfidTag);
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 14);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 16);
    sheet.setColumnWidth(4, 14);
    excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/staff_credentials.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: 'Staff Credentials');
  }

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
            // ── Format info ──────────────────────────────────────────
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
                        'Excel Format',
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
                  const SizedBox(height: 6),
                  // Column header example
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderRow(isDark: isDark),
                        const Divider(height: 8),
                        _DataRow('Sana Trabelsi', 'RH', 'A1B2C3D4', isDark),
                        _DataRow(
                          'Karim Boughdiri',
                          'Scolarite',
                          'E5F6G7H8',
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
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
                          'Role values:',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '• RH / HR / admin_rh  → HR Staff',
                          style: AppTypography.caption,
                        ),
                        Text(
                          '• Scolarite / Registrar  → Registrar',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• RFID Tag: leave blank if not assigned',
                          style: AppTypography.caption.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Email auto-generated: firstname.lastname@faccna.tn\n'
                    '• Password auto-generated (10 chars)\n'
                    '• Staff must change password on first login',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            AppButton(
              label: _isImporting ? 'Importing...' : 'Select Excel File',
              onPressed: _isImporting ? () {} : _pickAndImport,
              isLoading: _isImporting,
              width: double.infinity,
              icon: Icons.upload_file_rounded,
            ),

            if (_result != null) ...[
              const SizedBox(height: 24),
              _ResultSection(
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
//  FORMAT PREVIEW WIDGETS
// ─────────────────────────────────────────
class _HeaderRow extends StatelessWidget {
  final bool isDark;
  const _HeaderRow({required this.isDark});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Cell('Name', bold: true),
      _Cell('Role', bold: true),
      _Cell('RFID Tag', bold: true),
    ],
  );
}

class _DataRow extends StatelessWidget {
  final String name, role, rfid;
  final bool isDark;
  const _DataRow(this.name, this.role, this.rfid, this.isDark);
  @override
  Widget build(BuildContext context) =>
      Row(children: [_Cell(name), _Cell(role), _Cell(rfid)]);
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  const _Cell(this.text, {this.bold = false});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

// ─────────────────────────────────────────
//  RESULT SECTION
// ─────────────────────────────────────────
class _ResultSection extends StatelessWidget {
  final _ImportResult result;
  final bool isDark;
  final VoidCallback onDownload;
  const _ResultSection({
    required this.result,
    required this.isDark,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final rhCount =
        result.credentials.where((c) => c.role == 'HR Staff').length;
    final scCount =
        result.credentials.where((c) => c.role == 'Registrar').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary ────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import Complete ✅',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 10),
              _SummaryRow('👔 HR Staff created', rhCount),
              _SummaryRow('📋 Registrar created', scCount),
            ],
          ),
        ),

        // ── Errors ─────────────────────────────────────────────────────
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.errors.length} Warning(s)',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.errors.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                        Expanded(child: Text(e, style: AppTypography.caption)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Download credentials ────────────────────────────────────────
        if (result.credentials.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppButton(
            label: 'Download Credentials Excel',
            onPressed: onDownload,
            icon: Icons.download_rounded,
            width: double.infinity,
            isOutlined: true,
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int count;
  const _SummaryRow(this.label, this.count);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text(label, style: AppTypography.bodySmall),
        const Spacer(),
        Text(
          '$count',
          style: AppTypography.labelLarge.copyWith(color: AppColors.success),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────
class _ImportResult {
  final int created;
  final List<String> errors;
  final List<_Credential> credentials;
  const _ImportResult({
    required this.created,
    required this.errors,
    required this.credentials,
  });
}

class _Credential {
  final String name, role, email, password, rfidTag;
  const _Credential({
    required this.name,
    required this.role,
    required this.email,
    required this.password,
    required this.rfidTag,
  });
}
