import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback? onTap;
  final VoidCallback? onDelete; // ← new

  const StudentCard({
    super.key,
    required this.student,
    this.onTap,
    this.onDelete,
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
            // ─── Avatar ───
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ─── Name + chips ───
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Chip(
                        label: student.classDisplay,
                        color: AppColors.studentColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── 3-dot popup menu ───
            if (onDelete != null)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color:
                      isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                // Prevent the tap from bubbling up to GestureDetector
                onSelected: (value) {
                  if (value == 'delete') onDelete!();
                },
                itemBuilder:
                    (_) => [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Chip helper ───
class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}
