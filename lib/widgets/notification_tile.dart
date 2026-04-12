import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  Color _typeColor(MessageType type) {
    switch (type) {
      case MessageType.announcement: return Colors.blue;
      case MessageType.form:         return Colors.orange;
      case MessageType.note:         return Colors.green;
      case MessageType.course:       return Colors.purple;
      case MessageType.report:       return Colors.teal;
      case MessageType.general:      return Colors.grey;
    }
  }

  IconData _typeIcon(MessageType type) {
    switch (type) {
      case MessageType.announcement: return Icons.campaign_rounded;
      case MessageType.form:         return Icons.assignment_rounded;
      case MessageType.note:         return Icons.note_rounded;
      case MessageType.course:       return Icons.menu_book_rounded;
      case MessageType.report:       return Icons.bar_chart_rounded;
      case MessageType.general:      return Icons.notifications_rounded;
    }
  }

  String _typeLabel(MessageType type) {
    switch (type) {
      case MessageType.announcement: return 'Announcement';
      case MessageType.form:         return 'Form';
      case MessageType.note:         return 'Note';
      case MessageType.course:       return 'Course';
      case MessageType.report:       return 'Report';
      case MessageType.general:      return 'Notification';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _typeColor(notification.messageType);
    final icon = _typeIcon(notification.messageType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: notification.isRead
              ? (isDark ? AppColors.darkCard : AppColors.lightCard)
              : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                : color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                const SizedBox(width: 10),
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
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _typeLabel(notification.messageType),
                              style: AppTypography.caption.copyWith(
                                color: color,
                              ),
                            ),
                          ),
                          if (notification.senderName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              'from ${notification.senderName}',
                              style: AppTypography.caption,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification.message,
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ─── Attachments preview ───
            if (notification.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: notification.attachments.map((att) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground
                          : AppColors.lightBackground,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          att.type == AttachmentType.image
                              ? Icons.image_rounded
                              : att.type == AttachmentType.pdf
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.insert_drive_file_rounded,
                          size: 12,
                          color: att.type == AttachmentType.image
                              ? AppColors.info
                              : att.type == AttachmentType.pdf
                                  ? AppColors.error
                                  : AppColors.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          att.name,
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // ─── Timestamp ───
            const SizedBox(height: 6),
            Text(
              _formatTime(notification.createdAt),
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextHint
                    : AppColors.lightTextHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}