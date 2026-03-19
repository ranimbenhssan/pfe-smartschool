import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class TeacherAttendanceTodayScreen extends ConsumerWidget {
  const TeacherAttendanceTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = ref.watch(todayStringProvider);
    final attendance = ref.watch(attendanceByDateProvider(today));

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Today's Attendance"),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: attendance.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => EmptyState(
          title: 'Error',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                title: 'No Records',
                message: 'No attendance recorded today yet',
                icon: Icons.event_busy_rounded,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
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
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.teacherColor
                                .withValues(alpha: 0.15),
                            child: Text(
                              record.studentName.isNotEmpty
                                  ? record.studentName[0].toUpperCase()
                                  : '?',
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.teacherColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
    );
  }
}