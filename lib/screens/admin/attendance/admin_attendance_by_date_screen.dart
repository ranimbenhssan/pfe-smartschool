import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminAttendanceByDateScreen extends ConsumerWidget {
  const AdminAttendanceByDateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = ref.watch(selectedDateProvider);
    final dateString = ref.watch(selectedDateStringProvider);

    // ── Absent/Late docs from attendance collection ─────────────────────
    final attendance = ref.watch(attendanceByDateProvider(dateString));

    // ── Present count from attendance_counts collection ─────────────────
    // This is the fix: present records live in attendance_counts, not attendance
    final presentCount = ref.watch(presentCountByDateProvider(dateString));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance by Date'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Column(
        children: [
          // ─── Date picker ──────────────────────────────────────────────
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
                builder:
                    (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(
                          context,
                        ).colorScheme.copyWith(primary: AppColors.accent),
                      ),
                      child: child!,
                    ),
              );
              if (date != null) {
                ref.read(selectedDateProvider.notifier).state = date;
              }
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(selectedDate),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ),

          // ─── Stats row ────────────────────────────────────────────────
          // Present from attendance_counts; absent/late from attendance
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: attendance.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (list) {
                final absent =
                    list
                        .where((a) => a.status == AttendanceStatus.absent)
                        .length;
                final late =
                    list.where((a) => a.status == AttendanceStatus.late).length;
                final present = presentCount.when(
                  data: (c) => c,
                  loading: () => 0,
                  error: (_, __) => 0,
                );
                final total = present + absent + late;
                final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

                return Column(
                  children: [
                    // ── Four-chip stats row ──
                    Row(
                      children: [
                        _MiniStat(
                          label: 'Present',
                          value: present,
                          color: AppColors.present,
                        ),
                        const SizedBox(width: 8),
                        _MiniStat(
                          label: 'Absent',
                          value: absent,
                          color: AppColors.absent,
                        ),
                        const SizedBox(width: 8),
                        _MiniStat(
                          label: 'Late',
                          value: late,
                          color: AppColors.late,
                        ),
                        const SizedBox(width: 8),
                        _MiniStat(
                          label: 'Rate',
                          value: rate,
                          color: AppColors.info,
                          suffix: '%',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ── Attendance rate progress bar ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? present / total : 0,
                        backgroundColor: AppColors.present.withValues(
                          alpha: 0.1,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.present,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // ─── Absent / Late record list ────────────────────────────────
          Expanded(
            child: attendance.when(
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
                          ? EmptyState(
                            title: 'No Absence Records',
                            message:
                                'No absent or late records for ${DateFormat('d MMM').format(selectedDate)}',
                            icon: Icons.event_available_rounded,
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              final record = list[index];
                              return _RecordCard(
                                record: record,
                                isDark: isDark,
                                onTap:
                                    () => context.push(
                                      AppRoutes.adminAttendanceEdit,
                                      extra: record,
                                    ),
                              );
                            },
                          ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MINI STAT CHIP
// ─────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String suffix;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$value$suffix',
              style: AppTypography.headingMedium.copyWith(color: color),
            ),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  RECORD CARD
// ─────────────────────────────────────────
class _RecordCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;
  final VoidCallback onTap;

  const _RecordCard({
    required this.record,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc =
        record.status == AttendanceStatus.late
            ? AppColors.late
            : AppColors.absent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sc.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                record.status == AttendanceStatus.late
                    ? Icons.watch_later_rounded
                    : Icons.cancel_rounded,
                color: sc,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  Text(
                    '${record.className}'
                    '${record.subject.isNotEmpty ? "  ·  ${record.subject}" : ""}',
                    style: AppTypography.caption,
                  ),
                  if (record.scheduledTimeRange.isNotEmpty)
                    Text(
                      record.scheduledTimeRange,
                      style: AppTypography.caption.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AttendanceBadge(status: record.status),
                if (record.recordedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(record.recordedAt!),
                    style: AppTypography.caption,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
