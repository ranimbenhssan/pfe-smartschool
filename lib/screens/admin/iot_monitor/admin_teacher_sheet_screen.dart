import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../providers/iot_provider.dart';

class AdminTeacherSheetScreen extends ConsumerWidget {
  const AdminTeacherSheetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teachers = ref.watch(teachersProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Teacher Attendance Sheet'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: teachers.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data:
            (list) =>
                list.isEmpty
                    ? const EmptyState(
                      title: 'No Teachers',
                      message: 'No teachers found.',
                      icon: Icons.person_off_rounded,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      itemBuilder:
                          (ctx, i) => _TeacherSheetCard(
                            teacher: list[i],
                            isDark: isDark,
                          ),
                    ),
      ),
    );
  }
}

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
          // ── Teacher header ──────────────────────────────────────────────
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
                                '${s.length} sessions recorded',
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

          // ── Sessions list (expanded) ────────────────────────────────────
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
                              // Header row
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
                                    _Col('Min', flex: 2, bold: true),
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
                              // Session rows
                              ...list.map((session) {
                                final entryTs = session['entryTime'];
                                final exitTs = session['exitTime'];
                                final entry =
                                    entryTs is Timestamp
                                        ? entryTs.toDate()
                                        : null;
                                final exit =
                                    exitTs is Timestamp
                                        ? exitTs.toDate()
                                        : null;
                                final dur = session['duration'] as int? ?? 0;
                                final dayName =
                                    session['dayName']?.toString() ?? '';
                                final date = session['date']?.toString() ?? '';

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        widget.isDark
                                            ? AppColors.darkBackground
                                                .withValues(alpha: 0.3)
                                            : AppColors.lightBackground
                                                .withValues(alpha: 0.5),
                                  ),
                                  child: Row(
                                    children: [
                                      _Col(
                                        dayName.substring(
                                          0,
                                          dayName.length > 3
                                              ? 3
                                              : dayName.length,
                                        ),
                                        flex: 2,
                                      ),
                                      _Col(date, flex: 3),
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
                                      _Col('${dur}m', flex: 2),
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
