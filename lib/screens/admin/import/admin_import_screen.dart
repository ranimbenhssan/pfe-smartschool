import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../services/excel_import_service.dart';

class AdminImportScreen extends ConsumerStatefulWidget {
  const AdminImportScreen({super.key});

  @override
  ConsumerState<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends ConsumerState<AdminImportScreen> {
  bool _isImporting = false;
  ImportResult? _result;

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

    final result = await ref
        .read(excelImportServiceProvider)
        .importFromBytes(bytes);

    setState(() {
      _isImporting = false;
      _result = result;
    });
  }

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
            // ─── Instructions card ───
            Container(
              width: double.infinity,
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
                  _SheetInfo(
                    sheetName: 'Classes',
                    columns: 'Name | Grade | Level',
                    example: 'IoT1 | Grade 3 | 3',
                  ),
                  const SizedBox(height: 8),
                  _SheetInfo(
                    sheetName: 'Teachers',
                    columns: 'Name | Email | Class | Subject | RfidTag',
                    example:
                        'John Doe | john@school.com | IoT1 | Network | A1B2C3',
                  ),
                  const SizedBox(height: 8),
                  _SheetInfo(
                    sheetName: 'Students',
                    columns: 'Name | Email | Class | RfidTag',
                    example: 'Ranim B | ranim@school.com | IoT1 | D4E5F6',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Sheet names must contain: "Classes", "Teachers", "Students"\n'
                    '• Passwords are auto-generated\n'
                    '• Users must change password on first login\n'
                    '• Classes must be imported before Teachers/Students',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Upload button ───
            AppButton(
              label: _isImporting ? 'Importing...' : 'Select Excel File',
              onPressed: _isImporting ? () {} : _pickAndImport,
              isLoading: _isImporting,
              width: double.infinity,
              icon: Icons.upload_file_rounded,
            ),

            // ─── Results ───
            if (_result != null) ...[
              const SizedBox(height: 24),
              _ResultCard(result: _result!, isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetInfo extends StatelessWidget {
  final String sheetName;
  final String columns;
  final String example;

  const _SheetInfo({
    required this.sheetName,
    required this.columns,
    required this.example,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📋 Sheet: "$sheetName"',
          style: AppTypography.labelSmall.copyWith(color: AppColors.accent),
        ),
        Text('  Columns: $columns', style: AppTypography.caption),
        Text(
          '  Example: $example',
          style: AppTypography.caption.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ImportResult result;
  final bool isDark;

  const _ResultCard({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Summary ───
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
                style: AppTypography.headingMedium.copyWith(
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 8),
              _SummaryRow('📚 Classes created', result.classesCreated),
              _SummaryRow('👨‍🏫 Teachers created', result.teachersCreated),
              _SummaryRow('👨‍🎓 Students created', result.studentsCreated),
            ],
          ),
        ),

        // ─── Errors ───
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

        // ─── Credentials list ───
        if (result.credentials.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Generated Credentials', style: AppTypography.headingMedium),
              // ─── Copy all button ───
              TextButton.icon(
                onPressed: () {
                  final text = result.credentials
                      .map(
                        (c) =>
                            '${c.role} | ${c.name} | ${c.email} | ${c.password} | ${c.className}',
                      )
                      .join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All credentials copied to clipboard'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...result.credentials.map(
            (c) => _CredentialCard(credential: c, isDark: isDark),
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
  Widget build(BuildContext context) {
    return Padding(
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
}

class _CredentialCard extends StatelessWidget {
  final ImportedCredential credential;
  final bool isDark;

  const _CredentialCard({required this.credential, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color =
        credential.role == 'Teacher'
            ? AppColors.teacherColor
            : AppColors.studentColor;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              credential.role == 'Teacher'
                  ? Icons.person_pin_rounded
                  : Icons.person_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(credential.name, style: AppTypography.labelMedium),
                Text(credential.email, style: AppTypography.caption),
                Row(
                  children: [
                    Text('Password: ', style: AppTypography.caption),
                    Text(
                      credential.password,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
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
