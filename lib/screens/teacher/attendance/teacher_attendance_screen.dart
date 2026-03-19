import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class TeacherAttendanceScreen extends ConsumerWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Action Cards ───
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    isDark: isDark,
                    title: "Today's",
                    subtitle: 'Attendance',
                    icon: Icons.today_rounded,
                    color: AppColors.success,
                    onTap: () => context
                        .push(AppRoutes.teacherAttendanceToday),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    isDark: isDark,
                    title: 'By Date',
                    subtitle: 'Pick a date',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.info,
                    onTap: () => context
                        .push(AppRoutes.teacherAttendanceByDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    isDark: isDark,
                    title: 'Statistics',
                    subtitle: 'Monthly report',
                    icon: Icons.bar_chart_rounded,
                    color: AppColors.accent,
                    onTap: () => context
                        .push(AppRoutes.teacherAttendanceStats),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    isDark: isDark,
                    title: 'Edit',
                    subtitle: 'Manual entry',
                    icon: Icons.edit_rounded,
                    color: AppColors.warning,
                    onTap: () => context
                        .push(AppRoutes.teacherAttendanceByDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Today Summary ───
            Text(
              "Today's Summary",
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    isDark: isDark,
                    label: 'Present',
                    value: ref.watch(todayPresentCountProvider).toString(),
                    color: AppColors.present,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    isDark: isDark,
                    label: 'Absent',
                    value: ref.watch(todayAbsentCountProvider).toString(),
                    color: AppColors.absent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    isDark: isDark,
                    label: 'Late',
                    value: ref.watch(todayLateCountProvider).toString(),
                    color: AppColors.late,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color:
                        isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Text(subtitle, style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.isDark,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.headingLarge.copyWith(color: color),
          ),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}