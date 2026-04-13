import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../models/models.dart';
import '../../services/services.dart';

class MessageDetailScreen extends ConsumerWidget {
  final NotificationModel message;

  const MessageDetailScreen({super.key, required this.message});

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
      case MessageType.general:      return Icons.message_rounded;
    }
  }

  String _typeLabel(MessageType type) {
    switch (type) {
      case MessageType.announcement: return 'Announcement';
      case MessageType.form:         return 'Form';
      case MessageType.note:         return 'Note';
      case MessageType.course:       return 'Course Content';
      case MessageType.report:       return 'Report';
      case MessageType.general:      return 'Message';
    }
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} at $hour:$min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _typeColor(message.messageType);

    // Mark as read
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!message.isRead) {
        ref.read(firestoreServiceProvider).markNotificationRead(message.id);
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Message'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Type badge + title ───
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_typeIcon(message.messageType),
                      color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _typeLabel(message.messageType),
                          style: AppTypography.labelSmall
                              .copyWith(color: color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.title,
                        style: AppTypography.headingMedium.copyWith(
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Info card ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  // Sender
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.person_rounded,
                    label: 'From',
                    value: message.senderName.isNotEmpty
                        ? '${message.senderName} (${_capitalize(message.senderRole)})'
                        : 'System',
                    color: color,
                  ),
                  const Divider(height: 20),

                  // Date & time
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.access_time_rounded,
                    label: 'Sent',
                    value: _formatDateTime(message.createdAt),
                    color: color,
                  ),
                  const Divider(height: 20),

                  // Recipients
                  _InfoRow(
                    isDark: isDark,
                    icon: Icons.group_rounded,
                    label: 'To',
                    value: _getRecipientLabel(),
                    color: color,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Message body ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message',
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message.message,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Attachments ───
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Attachments (${message.attachments.length})',
                style: AppTypography.headingSmall.copyWith(
                  color:
                      isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 10),
              ...message.attachments.map(
                (att) => _AttachmentTile(
                  attachment: att,
                  isDark: isDark,
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getRecipientLabel() {
    switch (message.senderRole) {
      case 'admin':
        return 'All school members';
      case 'teacher':
        return 'Class students';
      case 'student':
        return 'Selected recipients';
      default:
        return 'You';
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

// ─── Info Row ────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                value,
                style: AppTypography.labelMedium.copyWith(
                  color:
                      isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Attachment Tile ──────────────────────────────────────────────────────────
class _AttachmentTile extends StatelessWidget {
  final AttachmentModel attachment;
  final bool isDark;

  const _AttachmentTile(
      {required this.attachment, required this.isDark});

  IconData get _icon {
    switch (attachment.type) {
      case AttachmentType.image:    return Icons.image_rounded;
      case AttachmentType.pdf:      return Icons.picture_as_pdf_rounded;
      case AttachmentType.document: return Icons.insert_drive_file_rounded;
    }
  }

  Color get _color {
    switch (attachment.type) {
      case AttachmentType.image:    return AppColors.info;
      case AttachmentType.pdf:      return AppColors.error;
      case AttachmentType.document: return AppColors.accent;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (attachment.url.isNotEmpty) {
          final uri = Uri.parse(attachment.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri,
                mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
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
                  Text(
                    attachment.name,
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatSize(attachment.sizeBytes),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              color: _color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}