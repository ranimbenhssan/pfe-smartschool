import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';

class TeacherAttendanceStatsScreen extends ConsumerWidget {
  const TeacherAttendanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final present = ref.watch(todayPresentCountProvider);
    final absent = ref.watch(todayAbsentCountProvider);
    final late = ref.watch(todayLateCountProvider);
    final total = present + absent + late;
    final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

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
          children: [
            // ─── Rate Card ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.teacherColor.withValues(alpha: 0.8),
                    AppColors.teacherColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '$rate%',
                    style: AppTypography.displayLarge.copyWith(
                      color: Colors.white,
                      fontSize: 56,
                    ),
                  ),
                  Text(
                    'Attendance Rate Today',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white70,
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
                  title: 'Present',
                  value: present.toString(),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.present,
                ),
                StatCard(
                  title: 'Absent',
                  value: absent.toString(),
                  icon: Icons.cancel_rounded,
                  color: AppColors.absent,
                ),
                StatCard(
                  title: 'Late',
                  value: late.toString(),
                  icon: Icons.watch_later_rounded,
                  color: AppColors.late,
                ),
                StatCard(
                  title: 'Total',
                  value: total.toString(),
                  icon: Icons.people_rounded,
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Progress Bars ───
            _ProgressBar(
              isDark: isDark,
              label: 'Present',
              value: total > 0 ? present / total : 0,
              color: AppColors.present,
              count: present,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              isDark: isDark,
              label: 'Absent',
              value: total > 0 ? absent / total : 0,
              color: AppColors.absent,
              count: absent,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              isDark: isDark,
              label: 'Late',
              value: total > 0 ? late / total : 0,
              color: AppColors.late,
              count: late,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final bool isDark;
  final String label;
  final double value;
  final Color color;
  final int count;

  const _ProgressBar({
    required this.isDark,
    required this.label,
    required this.value,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
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
