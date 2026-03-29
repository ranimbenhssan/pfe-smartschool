import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/theme.dart';
import '../../../providers/providers.dart';
import '../../../navigation/app_routes.dart';

class TeacherAttendanceScreen extends ConsumerWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final teachers = ref.watch(teachersProvider);

    // ─── Resolve current teacher ───
    final teacher =
        currentUser.whenData((user) {
          if (user == null) return null;
          return teachers.whenData((list) {
            try {
              return list.firstWhere((t) => t.userId == user.id);
            } catch (_) {
              return null;
            }
          }).value;
        }).value;

    final hasClasses = teacher != null && teacher.assignedClassIds.isNotEmpty;

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
                    title: 'Name Call',
                    subtitle: 'Take attendance',
                    icon: Icons.co_present_rounded,
                    color: AppColors.success,
                    onTap:
                        !hasClasses
                            ? null
                            : teacher.assignedClassIds.length == 1
                            // Single class → go directly
                            ? () => context.push(
                              AppRoutes.teacherAttendanceNameCall,
                              extra: {
                                'classId': teacher.assignedClassIds[0],
                                'className': teacher.assignedClassNames[0],
                              },
                            )
                            // Multiple classes → show picker sheet
                            : () => _showClassPicker(
                              context,
                              isDark: isDark,
                              teacher: teacher,
                            ),
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
                    onTap:
                        () => context.push(AppRoutes.teacherAttendanceByDate),
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
                    onTap: () => context.push(AppRoutes.teacherAttendanceStats),
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
                    onTap:
                        () => context.push(AppRoutes.teacherAttendanceByDate),
                  ),
                ),
              ],
            ),

            // ─── Assigned Classes quick-tap chips ───
            if (hasClasses) ...[
              const SizedBox(height: 24),
              Text(
                'Your Classes',
                style: AppTypography.headingMedium.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(
                  teacher.assignedClassIds.length,
                  (i) => GestureDetector(
                    onTap:
                        () => context.push(
                          AppRoutes.teacherAttendanceNameCall,
                          extra: {
                            'classId': teacher.assignedClassIds[i],
                            'className': teacher.assignedClassNames[i],
                          },
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.class_rounded,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            teacher.assignedClassNames[i],
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

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

  // ─── Class Picker Bottom Sheet ───────────────────────────────────────────

  void _showClassPicker(
    BuildContext context, {
    required bool isDark,
    required teacher,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Class for Name Call',
                style: AppTypography.headingMedium.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Which class are you taking attendance for?',
                style: AppTypography.bodySmall.copyWith(
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(
                teacher.assignedClassIds.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push(
                        AppRoutes.teacherAttendanceNameCall,
                        extra: {
                          'classId': teacher.assignedClassIds[i],
                          'className': teacher.assignedClassNames[i],
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.class_rounded,
                              color: AppColors.accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              teacher.assignedClassNames[i],
                              style: AppTypography.labelLarge.copyWith(
                                color:
                                    isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color:
                                isDark
                                    ? AppColors.darkTextHint
                                    : AppColors.lightTextHint,
                          ),
                        ],
                      ),
                    ),
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

// ─── Action Card ─────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

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
    final disabled = onTap == null;
    final effectiveColor = disabled ? color.withValues(alpha: 0.4) : color;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        color:
                            isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    Text(
                      disabled ? 'No class assigned' : subtitle,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

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
          Text(value, style: AppTypography.headingLarge.copyWith(color: color)),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }
}
