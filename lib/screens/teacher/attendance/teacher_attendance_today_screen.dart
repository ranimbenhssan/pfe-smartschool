import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';
import '../../../navigation/app_routes.dart';

class TeacherAttendanceTodayScreen extends ConsumerWidget {
  const TeacherAttendanceTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = ref.watch(todayStringProvider);

    // ── Teacher's class IDs (from teachers collection) ───────────────────
    final classIdsAsync = ref.watch(teacherClassIdsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Today's Attendance"),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: classIdsAsync.when(
        loading: () => const LoadingWidget(),
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (classIds) {
          if (classIds.isEmpty) {
            return const EmptyState(
              title: 'No Classes Assigned',
              message:
                  'You have no classes assigned yet.\n'
                  'Contact the admin to get assigned to a class.',
              icon: Icons.class_outlined,
            );
          }

          // ── Counts from providers (plain int) ────────────────────────
          final presentCount = ref.watch(teacherPresentCountIntProvider);
          final absentCount = ref.watch(teacherAbsentCountIntProvider);
          final lateCount = ref.watch(teacherLateCountIntProvider);
          final total = presentCount + absentCount + lateCount;
          final rate = total > 0 ? ((presentCount / total) * 100).toInt() : 0;

          return Column(
            children: [
              // ── Stats banner ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.teacherColor.withValues(alpha: 0.85),
                      AppColors.teacherColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.how_to_reg_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Today — ${DateFormat('d MMM yyyy').format(DateTime.now())}",
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$rate% rate',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _StatPill('Present', presentCount, AppColors.success),
                        const SizedBox(width: 8),
                        _StatPill('Absent', absentCount, AppColors.error),
                        const SizedBox(width: 8),
                        _StatPill('Late', lateCount, AppColors.warning),
                        const Spacer(),
                        Text(
                          '$total total',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total > 0 ? presentCount / total : 0,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Per-class attendance lists ───────────────────────────
              Expanded(
                child: _MultiClassAttendanceList(
                  classIds: classIds,
                  today: today,
                  isDark: isDark,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MULTI-CLASS ATTENDANCE LIST
//  Shows absent/late records grouped by class.
//  Also shows present count per class from attendance_counts.
// ─────────────────────────────────────────
class _MultiClassAttendanceList extends ConsumerWidget {
  final List<String> classIds;
  final String today;
  final bool isDark;

  const _MultiClassAttendanceList({
    required this.classIds,
    required this.today,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (classIds.isEmpty) {
      return const EmptyState(
        title: 'No Classes',
        message: 'No classes assigned',
        icon: Icons.class_outlined,
      );
    }

    // Build one section per class
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: classIds.length,
      itemBuilder: (context, index) {
        final classId = classIds[index];
        return _ClassSection(classId: classId, today: today, isDark: isDark);
      },
    );
  }
}

// ─────────────────────────────────────────
//  CLASS SECTION
//  Shows class name + present count + absent/late records
// ─────────────────────────────────────────
class _ClassSection extends ConsumerWidget {
  final String classId;
  final String today;
  final bool isDark;

  const _ClassSection({
    required this.classId,
    required this.today,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Absent/late records for this class today
    final attendanceAsync = ref.watch(
      attendanceByDateAndClassProvider((date: today, classId: classId)),
    );

    // Present count for this class today (from attendance_counts)
    final presentAsync = ref.watch(
      presentCountByDateAndClassProvider((date: today, classId: classId)),
    );

    // Class info for display name
    final classAsync = ref.watch(classProvider(classId));

    final className = classAsync.when(
      data: (c) => c?.getFullName() ?? classId,
      loading: () => classId,
      error: (_, __) => classId,
    );

    final presentCount = presentAsync.when(
      data: (c) => c,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return attendanceAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingWidget(),
          ),
      error:
          (e, _) => EmptyState(
            title: 'Error',
            message: e.toString(),
            icon: Icons.error_outline_rounded,
          ),
      data: (list) {
        final absent =
            list.where((a) => a.status == AttendanceStatus.absent).length;
        final late =
            list.where((a) => a.status == AttendanceStatus.late).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Class header ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.teacherColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.teacherColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.class_rounded,
                        color: AppColors.teacherColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        // Uses getFullName() → "3 IOT 1"
                        className,
                        style: AppTypography.labelLarge.copyWith(
                          color:
                              isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                    ),
                    // Mini stats chips
                    _MiniChip('$presentCount P', AppColors.present),
                    const SizedBox(width: 4),
                    _MiniChip('$absent A', AppColors.absent),
                    const SizedBox(width: 4),
                    _MiniChip('$late L', AppColors.late),
                  ],
                ),
              ),

              // ── Records list ──────────────────────────────────────────
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'All $presentCount students present',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...list.map(
                  (record) => _AttendanceRecordTile(
                    record: record,
                    isDark: isDark,
                    onTap:
                        () => context.push(
                          AppRoutes.teacherAttendanceEdit,
                          extra: record,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
//  ATTENDANCE RECORD TILE
// ─────────────────────────────────────────
class _AttendanceRecordTile extends StatelessWidget {
  final AttendanceModel record;
  final bool isDark;
  final VoidCallback onTap;

  const _AttendanceRecordTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                record.status == AttendanceStatus.late
                    ? Icons.watch_later_rounded
                    : Icons.cancel_rounded,
                color: sc,
                size: 16,
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
                  const SizedBox(height: 2),
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

// ─────────────────────────────────────────
//  STAT PILL
// ─────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  MINI CHIP (inside class header)
// ─────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
