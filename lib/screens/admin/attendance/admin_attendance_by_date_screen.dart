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
    final attendance = ref.watch(attendanceByDateProvider(dateString));

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
          // ─── Date Picker ───
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
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

          // ─── Stats ───
          attendance.whenData((list) {
            final present = list
                .where((a) => a.status == AttendanceStatus.present)
                .length;
            final absent = list
                .where((a) => a.status == AttendanceStatus.absent)
                .length;
            final late =
                list.where((a) => a.status == AttendanceStatus.late).length;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _MiniStat(
                      label: 'Present',
                      value: present,
                      color: AppColors.present),
                  const SizedBox(width: 8),
                  _MiniStat(
                      label: 'Absent',
                      value: absent,
                      color: AppColors.absent),
                  const SizedBox(width: 8),
                  _MiniStat(
                      label: 'Late', value: late, color: AppColors.late),
                ],
              ),
            );
          }).value ??
              const SizedBox.shrink(),

          const SizedBox(height: 12),

          // ─── List ───
          Expanded(
            child: attendance.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => EmptyState(
                title: 'Error',
                message: e.toString(),
                icon: Icons.error_outline_rounded,
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      title: 'No Records',
                      message: 'No attendance records for this date',
                      icon: Icons.event_busy_rounded,
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final record = list[index];
                        return GestureDetector(
                          onTap: () => context.push(
                            AppRoutes.adminAttendanceEdit,
                            extra: record,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.studentName,
                                        style: AppTypography.labelLarge
                                            .copyWith(
                                          color: isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText,
                                        ),
                                      ),
                                      if (record.entryTime != null)
                                        Text(
                                          'Entry: ${DateFormat('HH:mm').format(record.entryTime!)}',
                                          style: AppTypography.caption,
                                        ),
                                    ],
                                  ),
                                ),
                                AttendanceBadge(status: record.status),
                              ],
                            ),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
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
              value.toString(),
              style:
                  AppTypography.headingMedium.copyWith(color: color),
            ),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}