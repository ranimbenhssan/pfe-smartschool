import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';

class AdminAttendanceStatsScreen extends ConsumerWidget {
  const AdminAttendanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presentCount = ref.watch(todayPresentCountProvider);
    final absentCount = ref.watch(todayAbsentCountProvider);
    final lateCount = ref.watch(todayLateCountProvider);
    final total = presentCount + absentCount + lateCount;
    final attendanceRate =
        total > 0 ? ((presentCount / total) * 100).toInt() : 0;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance Statistics'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Overall Rate ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '$attendanceRate%',
                    style: AppTypography.displayLarge.copyWith(
                      color: AppColors.accent,
                      fontSize: 56,
                    ),
                  ),
                  Text(
                    'Overall Attendance Rate',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Stats Grid ───
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                StatCard(
                  title: 'Present Today',
                  value: presentCount.toString(),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.present,
                ),
                StatCard(
                  title: 'Absent Today',
                  value: absentCount.toString(),
                  icon: Icons.cancel_rounded,
                  color: AppColors.absent,
                ),
                StatCard(
                  title: 'Late Today',
                  value: lateCount.toString(),
                  icon: Icons.watch_later_rounded,
                  color: AppColors.late,
                ),
                StatCard(
                  title: 'Total Records',
                  value: total.toString(),
                  icon: Icons.people_rounded,
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Progress Bars ───
            Text(
              'Breakdown',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 16),
            _ProgressBar(
              label: 'Present',
              value: total > 0 ? presentCount / total : 0,
              color: AppColors.present,
              count: presentCount,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: 'Absent',
              value: total > 0 ? absentCount / total : 0,
              color: AppColors.absent,
              count: absentCount,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: 'Late',
              value: total > 0 ? lateCount / total : 0,
              color: AppColors.late,
              count: lateCount,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final int count;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Text(
              '$count (${(value * 100).toInt()}%)',
              style: AppTypography.labelMedium.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
