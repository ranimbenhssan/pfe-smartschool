import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../services/excel_import_service.dart';
import '../../../services/timetable_excel_import_service.dart';

class AdminImportScreen extends ConsumerStatefulWidget {
  const AdminImportScreen({super.key});

  @override
  ConsumerState<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends ConsumerState<AdminImportScreen> {
  // ── Users import state ─────────────────────────────────────────────────────
  bool _isImportingUsers = false;
  ImportResult? _usersResult;

  // ── Timetable import state ─────────────────────────────────────────────────
  bool _isImportingTimetable = false;
  TimetableImportResult? _timetableResult;

  // ─────────────────────────────────────────────────────────────────────────
  //  USERS IMPORT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickAndImportUsers() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    Uint8List? bytes = picked.files.first.bytes;
    if (bytes == null && picked.files.first.path != null) {
      bytes = await File(picked.files.first.path!).readAsBytes();
    }
    if (bytes == null) return;

    setState(() {
      _isImportingUsers = true;
      _usersResult = null;
    });
    final result = await ref
        .read(excelImportServiceProvider)
        .importFromBytes(bytes);
    setState(() {
      _isImportingUsers = false;
      _usersResult = result;
    });
  }

  Future<void> _downloadCredentials(
    List<ImportedCredential> credentials,
  ) async {
    try {
      final bytes = ExcelImportService().exportCredentials(credentials);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/smartschool_credentials.xlsx';
      await File(path).writeAsBytes(bytes);
      final res = await OpenFile.open(path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot open: ${res.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TIMETABLE IMPORT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickAndImportTimetable() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    Uint8List? bytes = picked.files.first.bytes;
    if (bytes == null && picked.files.first.path != null) {
      bytes = await File(picked.files.first.path!).readAsBytes();
    }
    if (bytes == null) return;

    setState(() {
      _isImportingTimetable = true;
      _timetableResult = null;
    });
    final result = await ref
        .read(timetableImportServiceProvider)
        .importFromBytes(bytes);
    setState(() {
      _isImportingTimetable = false;
      _timetableResult = result;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Bulk Import'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ════════════════════════════════════════════════════════════════
            //  SECTION 1 — USERS (Classes, Teachers, Students)
            // ════════════════════════════════════════════════════════════════
            _SectionHeader(
              icon: Icons.people_rounded,
              title: 'Import Users',
              subtitle: 'Classes · Teachers · Students',
              color: AppColors.accent,
            ),
            const SizedBox(height: 12),

            // Format info
            _FormatCard(
              isDark: isDark,
              color: AppColors.accent,
              items: const [
                _FormatItem(
                  sheetName: 'Classes',
                  columns: 'Name | Grade | Level',
                  example: 'DNI | 1 | 1',
                ),
                _FormatItem(
                  sheetName: 'Teachers',
                  columns: 'Name | RfidTag (optional)',
                  example: 'Moez Hachem | A1B2C3',
                ),
                _FormatItem(
                  sheetName: 'Students',
                  columns: 'Name | Class | RfidTag (optional)',
                  example: 'Ranim Ben Hassan | 1 DNI 2 | D4E5F6',
                ),
              ],
              notes: const [
                'Sheet names must contain: "Classes", "Teachers", "Students"',
                'Email & password are auto-generated from the full name',
                'Classes must be imported before Teachers/Students',
                'Download credentials Excel after import to share logins',
              ],
            ),
            const SizedBox(height: 16),

            AppButton(
              label:
                  _isImportingUsers
                      ? 'Importing...'
                      : 'Select Users Excel File',
              onPressed: _isImportingUsers ? () {} : _pickAndImportUsers,
              isLoading: _isImportingUsers,
              width: double.infinity,
              icon: Icons.upload_file_rounded,
            ),

            if (_usersResult != null) ...[
              const SizedBox(height: 16),
              _UsersResultCard(
                result: _usersResult!,
                isDark: isDark,
                onDownload:
                    () => _downloadCredentials(_usersResult!.credentials),
              ),
            ],

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // ════════════════════════════════════════════════════════════════
            //  SECTION 2 — TIMETABLE
            // ════════════════════════════════════════════════════════════════
            _SectionHeader(
              icon: Icons.calendar_today_rounded,
              title: 'Import Timetable',
              subtitle: 'Week A & Week B per class',
              color: AppColors.teacherColor,
            ),
            const SizedBox(height: 12),

            _FormatCard(
              isDark: isDark,
              color: AppColors.teacherColor,
              items: const [
                _FormatItem(
                  sheetName: 'Week A',
                  columns: 'Day | Time Slot | Subject | Teacher | Room',
                  example:
                      'Monday | 08:30-09:25 | Maths | Mohamed Hachem | Salle 7',
                ),
                _FormatItem(
                  sheetName: 'Week B',
                  columns: 'Day | Time Slot | Subject | Teacher | Room',
                  example:
                      'Tuesday | 10:30-11:25 | Networks | Moez Ben Ali | Salle 3',
                ),
              ],
              notes: const [
                'Row 1: Class name  (e.g. "1 DNI 2")  ← identifies the class',
                'Row 2: Column headers (Day, Time Slot, Subject, Teacher, Room)',
                'Row 3+: Session data',
                'Time format: "08:30-09:25"  (French: "8h30-9h25" also works)',
                'Days: Monday / Mon / Lundi / Lun',
                'Standard morning slots: 08:30 · 09:25 · 10:30 · 11:25',
                'Break: 12:20 – 13:00  (rows with this slot are ignored)',
                'Standard afternoon slots: 13:00 · 13:55 · 15:00 · 15:55 · 16:50 · 17:45',
                'One file per class — existing Week A / B entries are replaced',
              ],
            ),
            const SizedBox(height: 16),

            AppButton(
              label:
                  _isImportingTimetable
                      ? 'Importing...'
                      : 'Select Timetable Excel File',
              onPressed:
                  _isImportingTimetable ? () {} : _pickAndImportTimetable,
              isLoading: _isImportingTimetable,
              width: double.infinity,
              icon: Icons.calendar_today_rounded,
              color: AppColors.teacherColor,
            ),

            if (_timetableResult != null) ...[
              const SizedBox(height: 16),
              _TimetableResultCard(result: _timetableResult!, isDark: isDark),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.headingSmall),
            Text(subtitle, style: AppTypography.caption),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  FORMAT CARD
// ─────────────────────────────────────────
class _FormatItem {
  final String sheetName;
  final String columns;
  final String example;
  const _FormatItem({
    required this.sheetName,
    required this.columns,
    required this.example,
  });
}

class _FormatCard extends StatelessWidget {
  final bool isDark;
  final Color color;
  final List<_FormatItem> items;
  final List<String> notes;

  const _FormatCard({
    required this.isDark,
    required this.color,
    required this.items,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                'Excel File Format',
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Sheet: "${item.sheetName}"',
                    style: AppTypography.labelSmall.copyWith(color: color),
                  ),
                  Text(
                    '  Columns: ${item.columns}',
                    style: AppTypography.caption,
                  ),
                  Text(
                    '  e.g. ${item.example}',
                    style: AppTypography.caption.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16),
          ...notes.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $n', style: AppTypography.caption),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  USERS RESULT CARD
// ─────────────────────────────────────────
class _UsersResultCard extends StatelessWidget {
  final ImportResult result;
  final bool isDark;
  final VoidCallback onDownload;

  const _UsersResultCard({
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
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import Complete ✅',
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 6),
              _Row('📚 Classes created', result.classesCreated),
              _Row('👨‍🏫 Teachers created', result.teachersCreated),
              _Row('👨‍🎓 Students created', result.studentsCreated),
            ],
          ),
        ),

        // Warnings
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 10),
          _WarningsBox(warnings: result.errors),
        ],

        // Credentials
        if (result.credentials.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Generated Credentials', style: AppTypography.headingSmall),
              TextButton.icon(
                onPressed: () {
                  final text = result.credentials
                      .map(
                        (c) =>
                            '${c.role} | ${c.name} | ${c.email} | ${c.password}',
                      )
                      .join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy All'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...result.credentials.map(
            (c) => _CredCard(credential: c, isDark: isDark),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Download Credentials Excel',
            icon: Icons.download_rounded,
            width: double.infinity,
            onPressed: onDownload,
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int count;
  const _Row(this.label, this.count);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
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

class _CredCard extends StatelessWidget {
  final ImportedCredential credential;
  final bool isDark;
  const _CredCard({required this.credential, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color =
        credential.role == 'Teacher'
            ? AppColors.teacherColor
            : AppColors.studentColor;
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              credential.role == 'Teacher'
                  ? Icons.person_pin_rounded
                  : Icons.person_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(credential.name, style: AppTypography.labelSmall),
                Text(credential.email, style: AppTypography.caption),
                Row(
                  children: [
                    Text('Password: ', style: AppTypography.caption),
                    Flexible(
                      child: Text(
                        credential.password,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.accent,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: '${credential.email} / ${credential.password}',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Credentials copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TIMETABLE RESULT CARD
// ─────────────────────────────────────────
class _TimetableResultCard extends StatelessWidget {
  final TimetableImportResult result;
  final bool isDark;

  const _TimetableResultCard({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Timetable Import Complete ✅',
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 6),
              if (result.className.isNotEmpty)
                Text(
                  'Class: ${result.className}',
                  style: AppTypography.bodySmall,
                ),
              Row(
                children: [
                  Text('📅 Sessions created', style: AppTypography.bodySmall),
                  const Spacer(),
                  Text(
                    '${result.created}',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              if (result.skipped > 0)
                Text(
                  '${result.skipped} rows skipped',
                  style: AppTypography.caption,
                ),
            ],
          ),
        ),
        if (result.warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          _WarningsBox(warnings: result.warnings),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────
//  WARNINGS BOX  (shared)
// ─────────────────────────────────────────
class _WarningsBox extends StatelessWidget {
  final List<String> warnings;
  const _WarningsBox({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${warnings.length} Warning(s)',
            style: AppTypography.labelSmall.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: 6),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠ ', style: TextStyle(fontSize: 11)),
                  Expanded(child: Text(w, style: AppTypography.caption)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
