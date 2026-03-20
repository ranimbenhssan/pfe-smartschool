import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';
import '../../../services/auth_service.dart';

class StudentAttendanceScreen extends ConsumerWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () =>
                context.push(AppRoutes.studentAttendanceStats),
          ),
        ],
      ),
      body: currentUser.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => EmptyState(
          title: 'Error',
          message: e.toString(),
          icon: Icons.error_outline_rounded,
        ),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          final attendance =
              ref.watch(attendanceByStudentProvider(user.id));
          return attendance.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'No Attendance Records',
                  message: 'No attendance data yet',
                  icon: Icons.event_busy_rounded,
                );
              }

              final present = list
                  .where((a) => a.status == AttendanceStatus.present)
                  .length;
              final absent = list
                  .where((a) => a.status == AttendanceStatus.absent)
                  .length;
              final late = list
                  .where((a) => a.status == AttendanceStatus.late)
                  .length;
              final total = list.length;
              final rate =
                  total > 0 ? ((present / total) * 100).toInt() : 0;

              return Column(
                children: [
                  // ─── Stats Row ───
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _MiniStat('Present', present, AppColors.present),
                        const SizedBox(width: 8),
                        _MiniStat('Absent', absent, AppColors.absent),
                        const SizedBox(width: 8),
                        _MiniStat('Late', late, AppColors.late),
                        const SizedBox(width: 8),
                        _MiniStat('Rate', rate, AppColors.info,
                            suffix: '%'),
                      ],
                    ),
                  ),

                  // ─── List ───
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final record = list[index];
                        return Container(
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
                                      record.date,
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
                                    if (record.note != null &&
                                        record.note!.isNotEmpty)
                                      Text(
                                        'Note: ${record.note}',
                                        style: AppTypography.caption,
                                      ),
                                  ],
                                ),
                              ),
                              AttendanceBadge(status: record.status),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String suffix;

  const _MiniStat(
    this.label,
    this.value,
    this.color, {
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
              style: AppTypography.headingSmall.copyWith(color: color),
            ),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}