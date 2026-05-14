import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../providers/iot_provider.dart';

class AdminTeacherSheetScreen extends ConsumerStatefulWidget {
  const AdminTeacherSheetScreen({super.key});

  @override
  ConsumerState<AdminTeacherSheetScreen> createState() =>
      _AdminTeacherSheetScreenState();
}

class _AdminTeacherSheetScreenState
    extends ConsumerState<AdminTeacherSheetScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teachers = ref.watch(teachersProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Teacher Attendance Sheet'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export to Excel',
            onPressed: () => _exportToExcel(context, ref),
          ),
        ],
      ),
      body: teachers.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No Teachers',
              message: 'No teachers found.',
              icon: Icons.person_off_rounded,
            );
          }

          final filtered =
              _query.isEmpty
                  ? list
                  : list
                      .where(
                        (t) => (t.name ?? '').toLowerCase().contains(
                          _query.toLowerCase(),
                        ),
                      )
                      .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search teachers...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon:
                        _query.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                            : null,
                    filled: true,
                    fillColor:
                        isDark ? AppColors.darkCard : AppColors.lightCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                child:
                    filtered.isEmpty
                        ? const EmptyState(
                          title: 'No Results',
                          message: '',
                          icon: Icons.search_off_rounded,
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder:
                              (ctx, i) => _TeacherSheetCard(
                                teacher: filtered[i],
                                isDark: isDark,
                              ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EXPORT → Excel
  //  Columns: Day | Date | Teacher Name | In | Out | Hours | Minutes
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _exportToExcel(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Preparing Excel file...')));

    try {
      final teachers = ref.read(teachersProvider).value ?? [];
      final excel = Excel.createExcel();
      final sheet = excel['Teacher Attendance'];

      // ── Header ──────────────────────────────────────────────────────────
      const headers = [
        'Day',
        'Date',
        'Teacher Name',
        'In',
        'Out',
        'Hours',
        'Minutes',
      ];
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('FF1565C0'),
          fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // ── Rows ─────────────────────────────────────────────────────────────
      int row = 1;
      for (final teacher in teachers) {
        final snap =
            await FirebaseFirestore.instance
                .collection('teacher_attendance')
                .doc(teacher.userId)
                .collection('sessions')
                .orderBy('date', descending: false)
                .get();

        for (final doc in snap.docs) {
          final d = doc.data();
          final dayName = d['dayName']?.toString() ?? '';
          final date = d['date']?.toString() ?? '';
          final teacherName =
              d['teacherName']?.toString() ?? teacher.name ?? '';
          final entryTs = d['entryTime'] as Timestamp?;
          final exitTs = d['exitTime'] as Timestamp?;
          final durationMin = d['duration'] as int? ?? 0;

          final entryStr =
              entryTs != null
                  ? DateFormat('HH:mm').format(entryTs.toDate())
                  : '--';
          final exitStr =
              exitTs != null
                  ? DateFormat('HH:mm').format(exitTs.toDate())
                  : '--';
          final hours = durationMin ~/ 60;
          final minutes = durationMin % 60;

          final bgHex = row.isOdd ? 'FFF5F5F5' : 'FFFFFFFF';

          void w(int col, dynamic value) {
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
            );
            cell.value =
                value is int
                    ? IntCellValue(value)
                    : TextCellValue(value.toString());
            cell.cellStyle = CellStyle(
              backgroundColorHex: ExcelColor.fromHexString(bgHex),
            );
          }

          w(0, dayName);
          w(1, date);
          w(2, teacherName);
          w(3, entryStr);
          w(4, exitStr);
          w(5, hours);
          w(6, minutes);

          row++;
        }
      }

      // ── Column widths ────────────────────────────────────────────────────
      sheet.setColumnWidth(0, 12);
      sheet.setColumnWidth(1, 14);
      sheet.setColumnWidth(2, 24);
      sheet.setColumnWidth(3, 10);
      sheet.setColumnWidth(4, 10);
      sheet.setColumnWidth(5, 8);
      sheet.setColumnWidth(6, 10);

      // ── Remove default empty sheet ───────────────────────────────────────
      excel.delete('Sheet1');

      // ── Save to temp dir + share ─────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode');

      final dir = await getTemporaryDirectory();
      final name =
          'teacher_attendance_'
          '${DateFormat('yyyy-MM-dd').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Teacher Attendance Sheet');

      if (context.mounted) ScaffoldMessenger.of(context).clearSnackBars();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────
//  TEACHER EXPANDABLE CARD
// ─────────────────────────────────────────
class _TeacherSheetCard extends ConsumerStatefulWidget {
  final dynamic teacher;
  final bool isDark;
  const _TeacherSheetCard({required this.teacher, required this.isDark});

  @override
  ConsumerState<_TeacherSheetCard> createState() => _TeacherSheetCardState();
}

class _TeacherSheetCardState extends ConsumerState<_TeacherSheetCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(
      teacherAttendanceHistoryProvider(widget.teacher.userId as String),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.teacherColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.teacherColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.teacher.name ?? '',
                          style: AppTypography.labelLarge.copyWith(
                            color:
                                widget.isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                          ),
                        ),
                        sessions.when(
                          data:
                              (s) => Text(
                                '${s.length} sessions',
                                style: AppTypography.caption,
                              ),
                          loading:
                              () => const Text(
                                'Loading...',
                                style: TextStyle(fontSize: 11),
                              ),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.teacherColor,
                  ),
                ],
              ),
            ),
          ),

          // Sessions
          if (_expanded)
            sessions.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: LoadingWidget(),
                  ),
              error:
                  (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $e', style: AppTypography.caption),
                  ),
              data:
                  (list) =>
                      list.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No sessions yet.',
                              style: AppTypography.caption,
                            ),
                          )
                          : Column(
                            children: [
                              Divider(
                                height: 1,
                                color:
                                    widget.isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                              ),
                              // Table header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    _Col('Day', flex: 2, bold: true),
                                    _Col('Date', flex: 3, bold: true),
                                    _Col('In', flex: 2, bold: true),
                                    _Col('Out', flex: 2, bold: true),
                                    _Col('Dur', flex: 2, bold: true),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                color:
                                    widget.isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                              ),
                              // Rows
                              ...list.map((s) {
                                final entryTs = s['entryTime'];
                                final exitTs = s['exitTime'];
                                final entry =
                                    entryTs is Timestamp
                                        ? entryTs.toDate()
                                        : null;
                                final exit =
                                    exitTs is Timestamp
                                        ? exitTs.toDate()
                                        : null;
                                final dur = s['duration'] as int? ?? 0;
                                final h = dur ~/ 60;
                                final m = dur % 60;
                                final day = s['dayName']?.toString() ?? '';

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  color:
                                      widget.isDark
                                          ? AppColors.darkBackground.withValues(
                                            alpha: 0.3,
                                          )
                                          : AppColors.lightBackground
                                              .withValues(alpha: 0.5),
                                  child: Row(
                                    children: [
                                      _Col(
                                        day.length > 3
                                            ? day.substring(0, 3)
                                            : day,
                                        flex: 2,
                                      ),
                                      _Col(
                                        s['date']?.toString() ?? '',
                                        flex: 3,
                                      ),
                                      _Col(
                                        entry != null
                                            ? DateFormat('HH:mm').format(entry)
                                            : '--',
                                        flex: 2,
                                        color: AppColors.success,
                                      ),
                                      _Col(
                                        exit != null
                                            ? DateFormat('HH:mm').format(exit)
                                            : '--',
                                        flex: 2,
                                        color: AppColors.info,
                                      ),
                                      _Col('${h}h ${m}m', flex: 2),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                          ),
            ),
        ],
      ),
    );
  }
}

class _Col extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;
  const _Col(this.text, {this.flex = 1, this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(
      text,
      style: AppTypography.caption.copyWith(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: color,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
}
