import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'package:pfe_smartschool/navigation/app_routes.dart';

class NotificationDetailscreen extends ConsumerWidget {
  final NotificationModel message;

  const NotificationDetailscreen({super.key, required this.message});

  Color _typeColor(MessageType type) {
    switch (type) {
      case MessageType.announcement:
        return Colors.blue;
      case MessageType.form:
        return Colors.orange;
      case MessageType.note:
        return Colors.green;
      case MessageType.course:
        return Colors.purple;
      case MessageType.report:
        return Colors.teal;
      case MessageType.general:
        return Colors.grey;
    }
  }

  IconData _typeIcon(MessageType type) {
    switch (type) {
      case MessageType.announcement:
        return Icons.campaign_rounded;
      case MessageType.form:
        return Icons.assignment_rounded;
      case MessageType.note:
        return Icons.note_rounded;
      case MessageType.course:
        return Icons.menu_book_rounded;
      case MessageType.report:
        return Icons.bar_chart_rounded;
      case MessageType.general:
        return Icons.message_rounded;
    }
  }

  String _typeLabel(MessageType type) {
    switch (type) {
      case MessageType.announcement:
        return 'Announcement';
      case MessageType.form:
        return 'Form';
      case MessageType.note:
        return 'Note';
      case MessageType.course:
        return 'Course Content';
      case MessageType.report:
        return 'Report';
      case MessageType.general:
        return 'Message';
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} at $h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _typeColor(message.messageType);

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
        actions: [
          IconButton(
            icon: const Icon(Icons.reply_rounded),
            onPressed:
                () => context.push(AppRoutes.messageReply, extra: message),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Type badge ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_typeIcon(message.messageType), color: color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _typeLabel(message.messageType),
                    style: AppTypography.labelSmall.copyWith(color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Title ────────────────────────────────────────────────────
            Text(
              message.title,
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),

            // ─── Meta ─────────────────────────────────────────────────────
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  message.senderName.isNotEmpty ? message.senderName : 'System',
                  style: AppTypography.caption,
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(message.createdAt),
                  style: AppTypography.caption,
                ),
              ],
            ),
            if (message.recipientLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'To: ${message.recipientLabel}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ─── Body ─────────────────────────────────────────────────────
            Text(
              message.message,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // ─── Attachments ──────────────────────────────────────────────
            if (message.attachments.isNotEmpty) ...[
              Text(
                'Attachments',
                style: AppTypography.labelLarge.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 10),
              ...message.attachments.map(
                (att) => _AttachmentWidget(att: att, isDark: isDark),
              ),
              const SizedBox(height: 16),
            ],

            // ─── Reply ────────────────────────────────────────────────────
            if (message.replyToTitle.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.reply_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Re: ${message.replyToTitle}',
                        style: AppTypography.caption.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
//  ATTACHMENT WIDGET
//  • Images → inline preview (Image.network)
//  • PDFs and documents → download button that launches Cloudinary URL
//  • Falls back gracefully if URL is empty
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentWidget extends StatelessWidget {
  final AttachmentModel att;
  final bool isDark;

  const _AttachmentWidget({required this.att, required this.isDark});

  Future<void> _launch(BuildContext context) async {
    if (att.url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('File URL not available')));
      return;
    }
    final uri = Uri.parse(att.url);
    final canLaunch = await canLaunchUrl(uri);
    if (canLaunch) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Image → show inline preview with tap to open full ──────────────────
    if (att.type == AttachmentType.image && att.url.isNotEmpty) {
      return GestureDetector(
        onTap: () => _launch(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Image.network(
                  att.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                        color: AppColors.info,
                      ),
                    );
                  },
                  errorBuilder:
                      (_, __, ___) => Container(
                        height: 80,
                        alignment: Alignment.center,
                        color:
                            isDark ? AppColors.darkCard : AppColors.lightCard,
                        child: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                        ),
                      ),
                ),
                // Open indicator
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          att.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── PDF / Document → download button ────────────────────────────────────
    final color =
        att.type == AttachmentType.pdf ? AppColors.error : AppColors.accent;
    final icon =
        att.type == AttachmentType.pdf
            ? Icons.picture_as_pdf_rounded
            : Icons.insert_drive_file_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  att.name,
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (att.sizeBytes > 0)
                  Text(
                    att.sizeBytes < 1024 * 1024
                        ? '${(att.sizeBytes / 1024).toStringAsFixed(1)} KB'
                        : '${(att.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                    style: AppTypography.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Download button ───────────────────────────────────────────────
          TextButton.icon(
            onPressed: att.url.isNotEmpty ? () => _launch(context) : null,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Open'),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
