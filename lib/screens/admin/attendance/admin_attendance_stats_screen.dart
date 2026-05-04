import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';

class AdminAttendanceStatsScreen extends ConsumerWidget {
  const AdminAttendanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── All plain int — no .maybeWhen() needed ────────────────────────────
    final presentToday = ref.watch(todayPresentCountProvider); // int
    final absentToday = ref.watch(todayAbsentCountProvider); // int
    final lateToday = ref.watch(todayLateCountProvider); // int
    final totalToday = presentToday + absentToday + lateToday;
    final rateToday =
        totalToday > 0 ? ((presentToday / totalToday) * 100).toInt() : 0;

    // ── All-time ──────────────────────────────────────────────────────────
    final allTimeAbsent = ref.watch(allTimeAbsentCountProvider); // int
    final allTimeLate = ref.watch(allTimeLateCountProvider); // int
    final allTimeAsync = ref.watch(allTimeAttendanceProvider);
    final allTimeTotal = allTimeAsync.when(
      data: (l) => l.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

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
            // ── TODAY RATE RING ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: rateToday / 100,
                          strokeWidth: 7,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                        ),
                        Text(
                          '$rateToday%',
                          style: AppTypography.labelLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Rate",
                          style: AppTypography.headingSmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          DateFormat('EEE, d MMM').format(DateTime.now()),
                          style: AppTypography.caption.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Pill('P: $presentToday', AppColors.success),
                            const SizedBox(width: 6),
                            _Pill('A: $absentToday', AppColors.error),
                            const SizedBox(width: 6),
                            _Pill('L: $lateToday', AppColors.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── TODAY BREAKDOWN ───────────────────────────────────────────
            Text(
              "Today's Breakdown",
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              label: 'Present',
              value: totalToday > 0 ? presentToday / totalToday : 0,
              color: AppColors.present,
              count: presentToday,
            ),
            const SizedBox(height: 10),
            _ProgressBar(
              label: 'Absent',
              value: totalToday > 0 ? absentToday / totalToday : 0,
              color: AppColors.absent,
              count: absentToday,
            ),
            const SizedBox(height: 10),
            _ProgressBar(
              label: 'Late',
              value: totalToday > 0 ? lateToday / totalToday : 0,
              color: AppColors.late,
              count: lateToday,
            ),
            const SizedBox(height: 28),

            // ── ALL-TIME TOTALS ───────────────────────────────────────────
            Row(
              children: [
                Text(
                  'All-Time Totals',
                  style: AppTypography.headingMedium.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Never resets',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AllTimeStat(
                    label: 'Total Absences',
                    count: allTimeAbsent,
                    color: AppColors.absent,
                    icon: Icons.cancel_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AllTimeStat(
                    label: 'Total Late',
                    count: allTimeLate,
                    color: AppColors.late,
                    icon: Icons.watch_later_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AllTimeStat(
                    label: 'Total Records',
                    count: allTimeTotal,
                    color: AppColors.info,
                    icon: Icons.list_alt_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (allTimeTotal > 0) ...[
              _ProgressBar(
                label: 'Absent (all-time)',
                value: allTimeAbsent / allTimeTotal,
                color: AppColors.absent,
                count: allTimeAbsent,
              ),
              const SizedBox(height: 10),
              _ProgressBar(
                label: 'Late (all-time)',
                value: allTimeLate / allTimeTotal,
                color: AppColors.late,
                count: allTimeLate,
              ),
            ],
            const SizedBox(height: 32),
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
              '$count (${(value.clamp(0.0, 1.0) * 100).toInt()}%)',
              style: AppTypography.labelMedium.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _AllTimeStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _AllTimeStat({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: AppTypography.headingLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: AppTypography.caption.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
