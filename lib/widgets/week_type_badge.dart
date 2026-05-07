import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../theme/theme.dart';

/// Inline badge — "Week A", "Week B", or "No Classes" if a closure/holiday.
class WeekTypeBadge extends ConsumerWidget {
  final bool large;
  const WeekTypeBadge({super.key, this.large = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closure = ref.watch(todaySchoolClosureProvider);
    final holiday = ref.watch(todayFixedHolidayProvider);
    final weekType = ref.watch(currentWeekTypeProvider);

    // ── No classes today ─────────────────────────────────────────────────────
    if (closure != null || holiday != null) {
      final label = closure?.name ?? holiday?.name ?? 'Holiday';
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 8,
          vertical: large ? 6 : 3,
        ),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(large ? 12 : 8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_clock_rounded,
              size: large ? 16 : 12,
              color: AppColors.error,
            ),
            const SizedBox(width: 4),
            Text(
              'No Classes · $label',
              style: (large ? AppTypography.labelMedium : AppTypography.caption)
                  .copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );
    }

    if (weekType.isEmpty) return const SizedBox.shrink();

    final isA = weekType == 'A';
    final color = isA ? AppColors.teacherColor : AppColors.studentColor;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 8,
        vertical: large ? 6 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(large ? 12 : 8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isA ? Icons.looks_one_rounded : Icons.looks_two_rounded,
            size: large ? 16 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            'Week $weekType',
            style: (large ? AppTypography.labelMedium : AppTypography.caption)
                .copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Shows "Switches to Week B on Mon 12 May" the week before a transition.
class WeekSwitchHint extends ConsumerWidget {
  const WeekSwitchHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semAsync = ref.watch(activeSemesterProvider);
    final weekType = ref.watch(currentWeekTypeProvider);
    if (weekType.isEmpty) return const SizedBox.shrink();

    return semAsync.when(
      data: (sem) {
        if (sem == null) return const SizedBox.shrink();
        final now = DateTime.now();
        final daysToMonday = (DateTime.monday - now.weekday + 7) % 7;
        final nextMonday =
            daysToMonday == 0
                ? now.add(const Duration(days: 7))
                : now.add(Duration(days: daysToMonday));
        final nextType = sem.weekTypeFor(nextMonday);
        if (nextType == weekType) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Switches to Week $nextType on ${_fmt(nextMonday)}',
            style: AppTypography.caption.copyWith(
              color: AppColors.warning,
              fontSize: 10,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _fmt(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]}';
  }
}

/// Full-width NO CLASSES banner — shown on dashboards when a closure is active.
class NoClassesBanner extends ConsumerWidget {
  const NoClassesBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final closure = ref.watch(todaySchoolClosureProvider);
    final holiday = ref.watch(todayFixedHolidayProvider);
    if (closure == null && holiday == null) return const SizedBox.shrink();

    final name = closure?.name ?? holiday?.name ?? 'Holiday';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_rounded,
            color: AppColors.error,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NO CLASSES TODAY',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(name, style: AppTypography.caption),
                if (closure != null && closure.durationDays > 1)
                  Text(
                    'Until ${DateFormat('d MMM').format(closure.endDate)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
