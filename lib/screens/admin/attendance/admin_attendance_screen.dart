import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class AdminAttendanceScreen extends ConsumerWidget {
  const AdminAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = ref.watch(todayStringProvider);
    final todayAttendance = ref.watch(todayAttendanceProvider);
    final presentCount = ref.watch(todayPresentCountProvider);
    final absentCount = ref.watch(todayAbsentCountProvider);
    final lateCount = ref.watch(todayLateCountProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.push(AppRoutes.adminAttendanceStats),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Today Stats ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today — $today',
                    style: AppTypography.labelMedium.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Present',
                          value: presentCount.toString(),
                          color: AppColors.success,
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Absent',
                          value: absentCount.toString(),
                          color: AppColors.error,
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Late',
                          value: lateCount.toString(),
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Quick Actions ───
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    label: 'By Date',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.info,
                    onTap: () => context.push(AppRoutes.adminAttendanceByDate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    label: 'By Class',
                    icon: Icons.class_rounded,
                    color: AppColors.accent,
                    onTap: () => context.push(AppRoutes.adminAttendanceByClass),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Today's List ───
            Text(
              "Today's Attendance",
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            todayAttendance.when(
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
                            title: 'No Attendance Yet',
                            message: 'No attendance recorded for today',
                            icon: Icons.event_busy_rounded,
                          )
                          : Column(
                            children:
                                list.map((record) {
                                  return GestureDetector(
                                    onTap:
                                        () => context.push(
                                          AppRoutes.adminAttendanceEdit,
                                          extra: record,
                                        ),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? AppColors.darkCard
                                                : AppColors.lightCard,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isDark
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
                                                  style: AppTypography
                                                      .labelLarge
                                                      .copyWith(
                                                        color:
                                                            isDark
                                                                ? AppColors
                                                                    .darkText
                                                                : AppColors
                                                                    .lightText,
                                                      ),
                                                ),
                                                if (record.entryTime != null)
                                                  Text(
                                                    'Entry: ${DateFormat('HH:mm').format(record.entryTime!)}',
                                                    style:
                                                        AppTypography.caption,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          AttendanceBadge(
                                            status: record.status,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.statNumber.copyWith(
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: Colors.white60),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
