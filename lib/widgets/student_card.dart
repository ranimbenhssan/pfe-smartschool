import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import 'attendance_badge.dart';

class StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback? onTap;
  final AttendanceStatus? todayStatus;
  final Widget? trailing;

  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
    this.todayStatus,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              backgroundImage:
                  student.photoUrl != null
                      ? NetworkImage(student.photoUrl!)
                      : null,
              child:
                  student.photoUrl == null
                      ? Text(
                        student.name.isNotEmpty
                            ? student.name[0].toUpperCase()
                            : '?',
                        style: AppTypography.headingSmall.copyWith(
                          color: AppColors.accent,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    student.className,
                    style: AppTypography.bodySmall.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Trailing
            if (trailing != null)
              trailing!
            else if (todayStatus != null)
              AttendanceBadge(status: todayStatus!, showLabel: false)
            else
              Icon(
                Icons.chevron_right_rounded,
                color:
                    isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
              ),
          ],
        ),
      ),
    );
  }
}
