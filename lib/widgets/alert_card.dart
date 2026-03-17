import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class AlertCard extends StatelessWidget {
  final AiFlagModel flag;
  final VoidCallback? onTap;
  final VoidCallback? onResolve;

  const AlertCard({super.key, required this.flag, this.onTap, this.onResolve});

  Color get _color {
    switch (flag.type) {
      case FlagType.frequentAbsent:
        return AppColors.error;
      case FlagType.latePattern:
        return AppColors.warning;
      case FlagType.suspicious:
        return AppColors.info;
    }
  }

  IconData get _icon {
    switch (flag.type) {
      case FlagType.frequentAbsent:
        return Icons.event_busy_rounded;
      case FlagType.latePattern:
        return Icons.watch_later_rounded;
      case FlagType.suspicious:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flag.studentName,
                    style: AppTypography.headingSmall.copyWith(
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    flag.typeLabel,
                    style: AppTypography.labelSmall.copyWith(color: _color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flag.details,
                    style: AppTypography.bodySmall.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('dd/MM').format(flag.detectedAt),
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(flag.riskScore * 100).toInt()}%',
                    style: AppTypography.labelSmall.copyWith(color: _color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
