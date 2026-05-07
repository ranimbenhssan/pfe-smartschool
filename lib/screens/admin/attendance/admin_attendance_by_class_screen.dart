import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';
import '../../../models/models.dart';

class AdminAttendanceByClassScreen extends ConsumerWidget {
  const AdminAttendanceByClassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = ref.watch(classesProvider);
    final selectedClassId = ref.watch(selectedClassIdProvider);
    final today = ref.watch(todayStringProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance by Class'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: Column(
        children: [
          // ─── Class selector ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: classes.when(
              loading: () => const LoadingWidget(),
              error: (e, _) => Text('Error: $e'),
              data:
                  (list) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkCard
                              : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: Text(
                          'Select a class',
                          style: AppTypography.bodyMedium.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkTextHint
                                    : AppColors.lightTextHint,
                          ),
                        ),
                        value: selectedClassId,
                        dropdownColor:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        items:
                            list
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    // FIX: getFullName → "3 IOT 1"
                                    child: Text(
                                      c.getFullName,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color:
                                            isDark
                                                ? AppColors.darkText
                                                : AppColors.lightText,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (val) =>
                                ref
                                    .read(selectedClassIdProvider.notifier)
                                    .state = val,
                      ),
                    ),
                  ),
            ),
          ),

          if (selectedClassId == null)
            const Expanded(
              child: EmptyState(
                title: 'Select a Class',
                message: 'Choose a class to view attendance',
                icon: Icons.class_outlined,
              ),
            )
          else
            Expanded(
              child: _ClassAttendanceBody(
                classId: selectedClassId,
                today: today,
                isDark: isDark,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CLASS ATTENDANCE BODY
// ─────────────────────────────────────────
class _ClassAttendanceBody extends ConsumerWidget {
  final String classId;
  final String today;
  final bool isDark;

  const _ClassAttendanceBody({
    required this.classId,
    required this.today,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Absent/late from attendance collection
    final attendance = ref.watch(
      attendanceByDateAndClassProvider((date: today, classId: classId)),
    );

    // Present count from attendance_counts (the fix)
    final presentAsync = ref.watch(
      presentCountByDateAndClassProvider((date: today, classId: classId)),
    );

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.today_rounded,
                color: AppColors.accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),

        // Stats row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: attendance.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              final absent =
                  list.where((a) => a.status == AttendanceStatus.absent).length;
              final late =
                  list.where((a) => a.status == AttendanceStatus.late).length;
              final present = presentAsync.when(
                data: (c) => c,
                loading: () => 0,
                error: (_, __) => 0,
              );
              final total = present + absent + late;
              final rate = total > 0 ? ((present / total) * 100).toInt() : 0;

              return Column(
                children: [
                  Row(
                    children: [
                      _MiniStat('Present', present, AppColors.present),
                      const SizedBox(width: 8),
                      _MiniStat('Absent', absent, AppColors.absent),
                      const SizedBox(width: 8),
                      _MiniStat('Late', late, AppColors.late),
                      const SizedBox(width: 8),
                      _MiniStat('Rate', rate, AppColors.info, suffix: '%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? present / total : 0,
                      backgroundColor: AppColors.present.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.present,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: attendance.when(
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
                          title: 'No Absence Records',
                          message:
                              'No absent or late records for this class today',
                          icon: Icons.event_available_rounded,
                        )
                        : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final record = list[index];
                            return _RecordCard(
                              record: record,
                              isDark: isDark,
                              onTap:
                                  () => context.push(
                                    AppRoutes.adminAttendanceEdit,
                                    extra: record,
                                  ),
                            );
                          },
                        ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final String suffix;
  const _MiniStat(this.label, this.value, this.color, {this.suffix = ''});

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
              style: AppTypography.headingMedium.copyWith(color: color),
            ),
            Text(label, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;
  final VoidCallback onTap;
  const _RecordCard({
    required this.record,
    required this.isDark,
    required this.onTap,
  });

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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                record.status == AttendanceStatus.late
                    ? Icons.watch_later_rounded
                    : Icons.cancel_rounded,
                color: sc,
                size: 18,
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
                  if (record.subject.isNotEmpty)
                    Text(
                      record.subject +
                          (record.scheduledTimeRange.isNotEmpty
                              ? '  ·  ${record.scheduledTimeRange}'
                              : ''),
                      style: AppTypography.caption,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AttendanceBadge(status: record.status),
                if (record.recordedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(record.recordedAt!),
                    style: AppTypography.caption,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
