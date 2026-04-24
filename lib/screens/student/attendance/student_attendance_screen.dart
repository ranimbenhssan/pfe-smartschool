import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class StudentAttendanceScreen extends ConsumerWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final today = ref.watch(todayStringProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('My Attendance'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
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
              final todayRecord =
                  list.where((a) => a.date == today).firstOrNull;

              final present = list
                  .where(
                      (a) => a.status == AttendanceStatus.present)
                  .toList();
              final absent = list
                  .where(
                      (a) => a.status == AttendanceStatus.absent)
                  .toList();
              final late = list
                  .where((a) => a.status == AttendanceStatus.late)
                  .toList();
              final total = list.length;
              final rate = total > 0
                  ? ((present.length / total) * 100).toInt()
                  : 0;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ─── Today status ───
                    _TodayStatusCard(
                      record: todayRecord,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),

                    // ─── Stats with drill-down ───
                    Text(
                      'Attendance Overview',
                      style: AppTypography.headingMedium
                          .copyWith(
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Rate bar ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.studentColor
                              .withValues(alpha: 0.7),
                          AppColors.studentColor,
                        ]),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$rate%',
                            style: AppTypography.displayLarge
                                .copyWith(
                              color: Colors.white,
                              fontSize: 40,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Attendance\nRate',
                            style: AppTypography.bodySmall
                                .copyWith(
                                    color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Clickable stat cards ───
                    Row(
                      children: [
                        Expanded(
                          child: _DrillDownCard(
                            label: 'Present',
                            count: present.length,
                            color: AppColors.present,
                            icon: Icons.check_circle_rounded,
                            onTap: () => context.push(
                              AppRoutes.studentAttendanceStats,
                              extra: {
                                'filter': 'present',
                                'records': present,
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DrillDownCard(
                            label: 'Absent',
                            count: absent.length,
                            color: AppColors.absent,
                            icon: Icons.cancel_rounded,
                            onTap: () => context.push(
                              AppRoutes.studentAttendanceStats,
                              extra: {
                                'filter': 'absent',
                                'records': absent,
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DrillDownCard(
                            label: 'Late',
                            count: late.length,
                            color: AppColors.late,
                            icon: Icons.watch_later_rounded,
                            onTap: () => context.push(
                              AppRoutes.studentAttendanceStats,
                              extra: {
                                'filter': 'late',
                                'records': late,
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ─── View all ───
                    AppButton(
                      label: 'View Full History',
                      onPressed: () => context.push(
                        AppRoutes.studentAttendanceStats,
                        extra: {
                          'filter': 'all',
                          'records': list,
                        },
                      ),
                      isOutlined: true,
                      width: double.infinity,
                      icon: Icons.history_rounded,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DrillDownCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _DrillDownCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: AppTypography.headingLarge
                  .copyWith(color: color),
            ),
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: color)),
            const SizedBox(height: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 10, color: color),
          ],
        ),
      ),
    );
  }
}

class _TodayStatusCard extends StatelessWidget {
  final AttendanceModel? record;
  final bool isDark;

  const _TodayStatusCard(
      {this.record, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final status = record?.status;
    final color = status == AttendanceStatus.present
        ? AppColors.success
        : status == AttendanceStatus.late
            ? AppColors.warning
            : status == AttendanceStatus.absent
                ? AppColors.error
                : AppColors.info;
    final label = status == AttendanceStatus.present
        ? 'Present Today ✅'
        : status == AttendanceStatus.late
            ? 'Late Today ⚠️'
            : status == AttendanceStatus.absent
                ? 'Absent Today ❌'
                : 'Not Recorded Yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.headingMedium
                .copyWith(color: color),
          ),
          Text(
            DateFormat('EEEE, dd MMMM yyyy')
                .format(DateTime.now()),
            style: AppTypography.caption,
          ),
          if (record != null) ...[
            const SizedBox(height: 10),
            if (record!.sessionName.isNotEmpty)
              Text('📚 ${record!.sessionName}',
                  style: AppTypography.bodySmall),
            if (record!.teacherName.isNotEmpty)
              Text('👤 ${record!.teacherName}',
                  style: AppTypography.bodySmall),
            if (record!.roomName.isNotEmpty)
              Text('📍 ${record!.roomName}',
                  style: AppTypography.bodySmall),
            if (record!.recordedAt != null)
              Text(
                '🕐 ${DateFormat('HH:mm').format(record!.recordedAt!)}',
                style: AppTypography.bodySmall,
              ),
          ],
        ],
      ),
    );
  }
}