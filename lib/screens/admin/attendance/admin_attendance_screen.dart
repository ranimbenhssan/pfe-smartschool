import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() =>
      _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Today-only data ───────────────────────────────────────────────────
    final today = ref.watch(todayStringProvider);
    final todayAttendance = ref.watch(todayAttendanceProvider);
    final presentToday = ref.watch(todayPresentCountProvider);
    final absentToday = ref.watch(todayAbsentCountProvider);
    final lateToday = ref.watch(todayLateCountProvider);

    // ── All-time cumulative counters ──────────────────────────────────────
    final allTimeAbsent = ref.watch(allTimeAbsentCountProvider);
    final allTimeLate = ref.watch(allTimeLateCountProvider);
    final allTimeAsync = ref.watch(allTimeAttendanceProvider);
    final allTimeTotal = allTimeAsync.when(
      data: (l) => l.length,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // ── Filtered list (student name search) ───────────────────────────────
    final filteredAsync = ref.watch(filteredAttendanceProvider);
    final searchQuery = ref.watch(attendanceSearchQueryProvider);

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
            tooltip: 'Statistics',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () => context.push(AppRoutes.adminAttendanceByDate),
            tooltip: 'By Date',
          ),
          IconButton(
            icon: const Icon(Icons.class_rounded),
            onPressed: () => context.push(AppRoutes.adminAttendanceByClass),
            tooltip: 'By Class',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── TODAY BANNER ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "TODAY'S ATTENDANCE",
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.accent,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Live badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                      style: AppTypography.caption.copyWith(
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TodayStat(
                            label: 'Present',
                            value: presentToday,
                            color: AppColors.success,
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        _Divider(),
                        Expanded(
                          child: _TodayStat(
                            label: 'Absent',
                            value: absentToday,
                            color: AppColors.error,
                            icon: Icons.cancel_rounded,
                          ),
                        ),
                        _Divider(),
                        Expanded(
                          child: _TodayStat(
                            label: 'Late',
                            value: lateToday,
                            color: AppColors.warning,
                            icon: Icons.watch_later_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── ALL-TIME CUMULATIVE COUNTERS ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All-Time Records',
                    style: AppTypography.headingMedium.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cumulative totals — never reset.',
                    style: AppTypography.caption.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CumulativeCard(
                          label: 'Total Absences',
                          count: allTimeAbsent,
                          color: AppColors.absent,
                          icon: Icons.cancel_rounded,
                          subtitle: 'Across all dates',
                          onTap: () {
                            ref
                                .read(attendanceSearchQueryProvider.notifier)
                                .state = '';
                            _searchController.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CumulativeCard(
                          label: 'Total Late',
                          count: allTimeLate,
                          color: AppColors.late,
                          icon: Icons.watch_later_rounded,
                          subtitle: 'Across all dates',
                          onTap: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CumulativeCard(
                          label: 'Total Records',
                          count: allTimeTotal,
                          color: AppColors.info,
                          icon: Icons.list_alt_rounded,
                          subtitle: 'Abs + Late combined',
                          onTap: null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── STUDENT NAME SEARCH ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Absence / Late History',
                    style: AppTypography.headingMedium.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    onChanged:
                        (v) =>
                            ref
                                .read(attendanceSearchQueryProvider.notifier)
                                .state = v,
                    decoration: InputDecoration(
                      hintText: 'Search by student name...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon:
                          searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(
                                        attendanceSearchQueryProvider.notifier,
                                      )
                                      .state = '';
                                },
                              )
                              : null,
                      filled: true,
                      fillColor:
                          isDark ? AppColors.darkCard : AppColors.lightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: filteredAsync.when(
                        data:
                            (list) => Text(
                              '${list.length} record${list.length == 1 ? '' : 's'} for "$searchQuery"',
                              style: AppTypography.caption.copyWith(
                                color:
                                    isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                              ),
                            ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── FILTERED ABSENCE LIST ───────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: filteredAsync.when(
              loading:
                  () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: LoadingWidget(),
                    ),
                  ),
              error:
                  (e, _) => SliverToBoxAdapter(
                    child: EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                  ),
              data: (list) {
                if (list.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyState(
                      title: searchQuery.isEmpty ? 'No Records' : 'No Results',
                      message:
                          searchQuery.isEmpty
                              ? 'No absence or late records found'
                              : 'No records match "$searchQuery"',
                      icon:
                          searchQuery.isEmpty
                              ? Icons.event_busy_rounded
                              : Icons.search_off_rounded,
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final record = list[index];
                    return _AttendanceRecordCard(
                      record: record,
                      isDark: isDark,
                      onTap:
                          () => context.push(
                            AppRoutes.adminAttendanceEdit,
                            extra: record,
                          ),
                    );
                  }, childCount: list.length),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TODAY STAT — inside gradient banner
// ─────────────────────────────────────────
class _TodayStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _TodayStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: AppTypography.headingLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 50, color: Colors.white12);
}

// ─────────────────────────────────────────
//  CUMULATIVE CARD — all-time counter
// ─────────────────────────────────────────
class _CumulativeCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final String subtitle;
  final VoidCallback? onTap;

  const _CumulativeCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: AppTypography.headingLarge.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Text(subtitle, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  ATTENDANCE RECORD CARD
// ─────────────────────────────────────────
class _AttendanceRecordCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;
  final VoidCallback onTap;

  const _AttendanceRecordCard({
    required this.record,
    required this.isDark,
    required this.onTap,
  });

  String _fmtDate(String s) {
    try {
      final p = s.split('-');
      return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : s;
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc =
        record.status == AttendanceStatus.late
            ? AppColors.late
            : AppColors.absent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sc.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                record.status == AttendanceStatus.late
                    ? Icons.watch_later_rounded
                    : Icons.cancel_rounded,
                color: sc,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  Text(
                    '${record.className}  ·  ${_fmtDate(record.date)}',
                    style: AppTypography.caption,
                  ),
                  if (record.subject.isNotEmpty)
                    Text(
                      record.subject +
                          (record.scheduledTimeRange.isNotEmpty
                              ? '  ·  ${record.scheduledTimeRange}'
                              : ''),
                      style: AppTypography.caption.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.status.name.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      color: sc,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
