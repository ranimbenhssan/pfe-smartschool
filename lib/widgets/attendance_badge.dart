import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class AttendanceBadge extends StatelessWidget {
  final AttendanceStatus status;
  final bool showLabel;
  final double size;

  const AttendanceBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.size = 14,
  });

  Color get _color {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.absent:
        return AppColors.absent;
      case AttendanceStatus.late:
        return AppColors.late;
    }
  }

  String get _label {
    switch (status) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
    }
  }

  IconData get _icon {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_rounded;
      case AttendanceStatus.late:
        return Icons.watch_later_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 10 : 6,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: size),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              _label,
              style: AppTypography.labelSmall.copyWith(color: _color),
            ),
          ],
        ],
      ),
    );
  }
}
