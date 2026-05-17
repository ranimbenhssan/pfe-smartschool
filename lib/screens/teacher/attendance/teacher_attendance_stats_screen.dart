import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme.dart';
import '../../../widgets/widgets.dart';
import '../../../providers/providers.dart';
import '../../../models/models.dart';

class TeacherAttendanceStatsScreen extends ConsumerWidget {
  const TeacherAttendanceStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Attendance Statistics'),
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

          // Get the teacher's Firestore document ID
          final teacherAsync = ref.watch(teacherByUserIdProvider(user.id));

          return teacherAsync.when(
            loading: () => const LoadingWidget(),
            error:
                (e, _) => EmptyState(
                  title: 'Error',
                  message: e.toString(),
                  icon: Icons.error_outline_rounded,
                ),
            data: (teacher) {
              if (teacher == null) {
                return const EmptyState(
                  title: 'No Data',
                  message: 'Teacher profile not found.',
                  icon: Icons.person_off_rounded,
                );
              }

              // Watch today's attendance records for this teacher
              final attendanceAsync = ref.watch(
                teacherTodayAttendanceProvider(teacher.id),
              );

              return attendanceAsync.when(
                loading: () => const LoadingWidget(),
                error:
                    (e, _) => EmptyState(
                      title: 'Error',
                      message: e.toString(),
                      icon: Icons.error_outline_rounded,
                    ),
                data: (list) {
                  final present =
                      list
                          .where((a) => a.status == AttendanceStatus.present)
                          .length;
                  final absent =
                      list
                          .where((a) => a.status == AttendanceStatus.absent)
                          .length;
                  final late =
                      list
                          .where((a) => a.status == AttendanceStatus.late)
                          .length;
                  final total = present + absent + late;
                  final rate =
                      total > 0 ? ((present / total) * 100).toInt() : 0;
                  final today = DateFormat(
                    'EEEE, d MMMM yyyy',
                  ).format(DateTime.now());

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Hero rate card ──────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$rate%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Attendance Rate Today',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                today,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Stat grid ───────────────────────────────────
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.3,
                          children: [
                            _StatCard(
                              label: 'Present',
                              value: present,
                              icon: Icons.check_circle_rounded,
                              color: AppColors.success,
                            ),
                            _StatCard(
                              label: 'Absent',
                              value: absent,
                              icon: Icons.cancel_rounded,
                              color: AppColors.error,
                            ),
                            _StatCard(
                              label: 'Late',
                              value: late,
                              icon: Icons.watch_later_rounded,
                              color: AppColors.warning,
                            ),
                            _StatCard(
                              label: 'Total',
                              value: total,
                              icon: Icons.people_rounded,
                              color: AppColors.info,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Progress bars ────────────────────────────────
                        Text(
                          'Breakdown',
                          style: AppTypography.headingMedium.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ProgressRow(
                          label: 'Present',
                          count: present,
                          total: total,
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _ProgressRow(
                          label: 'Absent',
                          count: absent,
                          total: total,
                          color: AppColors.error,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _ProgressRow(
                          label: 'Late',
                          count: late,
                          total: total,
                          color: AppColors.warning,
                          isDark: isDark,
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

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 8),
          Text(
            '$value',
            style: AppTypography.displaySmall.copyWith(
              color: isDark ? AppColors.darkText : AppColors.lightText,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  final bool isDark;
  const _ProgressRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
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
              '$count (${(pct * 100).toInt()}%)',
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
