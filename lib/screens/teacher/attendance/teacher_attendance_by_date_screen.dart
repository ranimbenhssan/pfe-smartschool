import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class TeacherAttendanceByDateScreen extends ConsumerWidget {
  const TeacherAttendanceByDateScreen({super.key});

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
                color: AppColors.teacherColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.teacherColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.teacherColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy')
                        .format(selectedDate),
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.teacherColor,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppColors.teacherColor,
                  ),
                ],
              ),
            ),
          ),

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
                      message: 'No attendance for this date',
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
                            AppRoutes.teacherAttendanceEdit,
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