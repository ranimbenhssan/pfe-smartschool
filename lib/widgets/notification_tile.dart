import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationTile({super.key, required this.notification, this.onTap});

  Color get _color {
    switch (notification.type) {
      case NotificationType.attendance:
        return AppColors.success;
      case NotificationType.aiAlert:
        return AppColors.error;
      case NotificationType.rfid:
        return AppColors.info;
      case NotificationType.general:
        return AppColors.accent;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.attendance:
        return Icons.how_to_reg_rounded;
      case NotificationType.aiAlert:
        return Icons.warning_amber_rounded;
      case NotificationType.rfid:
        return Icons.nfc_rounded;
      case NotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color:
              notification.isRead
                  ? (isDark ? AppColors.darkCard : AppColors.lightCard)
                  : (isDark
                      ? AppColors.darkCard
                      : _color.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                notification.isRead
                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    : _color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppTypography.labelLarge.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: AppTypography.bodySmall.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(notification.createdAt),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
