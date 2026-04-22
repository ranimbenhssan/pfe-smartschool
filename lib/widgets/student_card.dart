import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback? onTap;

  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
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
            color:
                isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor:
                  AppColors.accent.withValues(alpha: 0.15),
              child: Text(
                student.name.isNotEmpty
                    ? student.name[0].toUpperCase()
                    : '?',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: AppTypography.labelLarge.copyWith(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // ─── Class + Level display ───
                  Row(
                    children: [
                      _Chip(
                        label: student.classDisplay,
                        color: AppColors.studentColor,
                      ),
                      if (student.level.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _Chip(
                          label: 'Level ${student.level}',
                          color: AppColors.info,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark
                  ? AppColors.darkTextHint
                  : AppColors.lightTextHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}