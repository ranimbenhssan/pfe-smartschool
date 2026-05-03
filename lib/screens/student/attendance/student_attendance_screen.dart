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
        error:
            (e, _) => EmptyState(
              title: 'Error',
              message: e.toString(),
              icon: Icons.error_outline_rounded,
            ),
        data: (user) {
          if (user == null) return const SizedBox.shrink();

          // ─── presenceCount lives on the student doc ───
          final studentAsync = ref.watch(studentProvider(user.id));

          // ─── Only absent/late records are stored as documents ───
          final attendanceAsync = ref.watch(
            attendanceByStudentProvider(user.id),
          );

          return studentAsync.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (student) {
              if (student == null) return const SizedBox.shrink();

              return attendanceAsync.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                data: (absenceList) {
                  // ─── Today's record (absent or late only) ───
                  final todayRecord =
                      absenceList.where((a) => a.date == today).firstOrNull;

                  final absent =
                      absenceList
                          .where((a) => a.status == AttendanceStatus.absent)
                          .toList();
                  final late =
                      absenceList
                          .where((a) => a.status == AttendanceStatus.late)
                          .toList();

                  // ─── presenceCount from student doc (counter, no docs) ───
                  final presenceCount = student.presenceCount;

                  final total = presenceCount + absenceList.length;
                  final rate =
                      total > 0 ? ((presenceCount / total) * 100).toInt() : 0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── Today status card ───
                        _TodayStatusCard(
                          record: todayRecord,
                          presenceCount: presenceCount,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20),

                        // ─── Overview heading ───
                        Text(
                          'Attendance Overview',
                          style: AppTypography.headingMedium.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ─── Rate banner ───
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.studentColor.withValues(alpha: 0.7),
                                AppColors.studentColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '$rate%',
                                style: AppTypography.displayLarge.copyWith(
                                  color: Colors.white,
                                  fontSize: 40,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Attendance\nRate',
                                style: AppTypography.bodySmall.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ─── Three stat cards ───
                        Row(
                          children: [
                            // Present: counter only, no documents to navigate
                            Expanded(
                              child: _CountCard(
                                label: 'Present',
                                count: presenceCount,
                                color: AppColors.present,
                                icon: Icons.check_circle_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Absent: full detail records
                            Expanded(
                              child: _DrillDownCard(
                                label: 'Absent',
                                count: absent.length,
                                color: AppColors.absent,
                                icon: Icons.cancel_rounded,
                                onTap:
                                    () => context.push(
                                      AppRoutes.studentAttendanceStats,
                                      extra: {
                                        'filter': 'absent',
                                        'records': absent,
                                      },
                                    ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Late: full detail records
                            Expanded(
                              child: _DrillDownCard(
                                label: 'Late',
                                count: late.length,
                                color: AppColors.late,
                                icon: Icons.watch_later_rounded,
                                onTap:
                                    () => context.push(
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
                        const SizedBox(height: 20),

                        // ─── View absence history ───
                        AppButton(
                          label: 'View Absence History',
                          onPressed:
                              () => context.push(
                                AppRoutes.studentAttendanceStats,
                                extra: {
                                  'filter': 'all',
                                  'records': absenceList,
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
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TODAY STATUS CARD
// ─────────────────────────────────────────
class _TodayStatusCard extends StatelessWidget {
  /// Non-null only when today has an absence/late record.
  /// If null AND presenceCount > 0 it could mean present (or not yet taken).
  final AttendanceModel? record;
  final int presenceCount;
  final bool isDark;

  const _TodayStatusCard({
    this.record,
    required this.presenceCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final status = record?.status;

    // If no absence record for today, status is unknown (not yet taken)
    // We don't store present docs so we can't distinguish
    // "present today" from "not yet taken" without an extra query.
    // Show a neutral "not recorded" state in that case.
    final color =
        status == AttendanceStatus.late
            ? AppColors.warning
            : status == AttendanceStatus.absent
            ? AppColors.error
            : AppColors.info;

    final label =
        status == AttendanceStatus.late
            ? 'Late Today ⚠️'
            : status == AttendanceStatus.absent
            ? 'Absent Today ❌'
            : 'Today Not Recorded Yet';

    final icon =
        status == AttendanceStatus.late
            ? Icons.watch_later_rounded
            : status == AttendanceStatus.absent
            ? Icons.cancel_rounded
            : Icons.help_outline_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                // Show absence detail if available
                if (record != null && record!.subject.isNotEmpty)
                  Text(
                    '${record!.subject}'
                    '${record!.roomName.isNotEmpty ? ' · ${record!.roomName}' : ''}',
                    style: AppTypography.caption,
                  ),
                // Show running presence count as context
                Text(
                  '$presenceCount session(s) present this period',
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  COUNT CARD — non-tappable, counter only
// ─────────────────────────────────────────
class _CountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: AppTypography.headingLarge.copyWith(color: color),
          ),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
          // No arrow — not tappable (no documents)
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  DRILL-DOWN CARD — tappable, has detail records
// ─────────────────────────────────────────
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
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: AppTypography.headingLarge.copyWith(color: color),
            ),
            Text(label, style: AppTypography.caption.copyWith(color: color)),
            const SizedBox(height: 4),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
          ],
        ),
      ),
    );
  }
}
