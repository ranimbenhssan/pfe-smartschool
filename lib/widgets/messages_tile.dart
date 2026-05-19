import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import 'package:go_router/go_router.dart';
import '../navigation/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessagesTile extends StatelessWidget {
  final NotificationModel message;
  final VoidCallback? onTap;
  final bool showRecipient;

  const MessagesTile({
    super.key,
    required this.message,
    this.onTap,
    this.showRecipient = false,
  });

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
        return 'Course';
      case MessageType.report:
        return 'Report';
      case MessageType.general:
        return 'message';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _typeColor(message.messageType);
    final icon = _typeIcon(message.messageType);

    return GestureDetector(
      onTap: () {
        // Call original onTap if provided
        onTap?.call();
        // Navigate to detail screen
        context.push(AppRoutes.messageDetail, extra: message);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          // ─── Unread = colored background, Read = neutral ───
          color:
              message.isRead
                  ? (isDark ? AppColors.darkCard : AppColors.lightCard)
                  : color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                message.isRead
                    ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    : color.withValues(alpha: 0.35),
            width: message.isRead ? 1 : 1.5,
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
                              message.title,
                              style: AppTypography.labelLarge.copyWith(
                                color:
                                    isDark
                                        ? AppColors.darkText
                                        : AppColors.lightText,
                                fontWeight:
                                    message.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!message.isRead)
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
                              _typeLabel(message.messageType),
                              style: AppTypography.caption.copyWith(
                                color: color,
                              ),
                            ),
                          ),
                          if (message.senderName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              message.senderName.isNotEmpty
                                  ? 'From ${message.senderName}'
                                  : message.senderRole == 'admin'
                                  ? 'From Administration'
                                  : message.senderRole == 'teacher'
                                  ? 'From Teacher'
                                  : 'Faccna',
                              style: AppTypography.caption,
                            ),
                          ],
                          if (showRecipient) ...[
                            const SizedBox(width: 6),
                            Text('·', style: AppTypography.caption),
                            const SizedBox(width: 6),
                            _RecipientLabel(
                              userId: message.userId,
                              recipientLabel: message.recipientLabel,
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
              message.message,
              style: AppTypography.bodySmall.copyWith(
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // ─── Attachments preview ───
            if (message.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    message.attachments.map((att) {
                      final color =
                          att.type == AttachmentType.image
                              ? AppColors.info
                              : att.type == AttachmentType.pdf
                              ? AppColors.error
                              : AppColors.accent;
                      final icon =
                          att.type == AttachmentType.image
                              ? Icons.image_rounded
                              : att.type == AttachmentType.pdf
                              ? Icons.picture_as_pdf_rounded
                              : Icons.insert_drive_file_rounded;

                      // Shorten UUID-style names from image_picker
                      // e.g. "scaled_b0c9d6df-4443-4a2e-90fa..." → "image.jpg"
                      final ext =
                          att.name.contains('.')
                              ? '.${att.name.split('.').last}'
                              : '';
                      final hasUuid = RegExp(
                        r'[0-9a-f]{4,}-[0-9a-f]{4,}',
                        caseSensitive: false,
                      ).hasMatch(att.name);
                      final displayName =
                          hasUuid
                              ? (att.type == AttachmentType.image
                                  ? 'image$ext'
                                  : 'file$ext')
                              : att.name;

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppColors.darkBackground
                                    : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 12, color: color),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: AppTypography.caption,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],

            // ─── Timestamp ───
            const SizedBox(height: 6),
            Text(
              _formatTime(message.createdAt),
              style: AppTypography.caption.copyWith(
                color:
                    isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
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

class _RecipientLabel extends ConsumerWidget {
  final String userId;
  final String recipientLabel;
  const _RecipientLabel({required this.userId, required this.recipientLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If a label is already stored (e.g. "Class 3IOT1TP1", "Whole School")
    // use it directly
    if (recipientLabel.isNotEmpty && recipientLabel != 'sent') {
      // Use stored label if it's meaningful
      if (recipientLabel.isNotEmpty &&
          recipientLabel.toLowerCase() != 'sent' &&
          recipientLabel != '—' &&
          recipientLabel != '-') {
        return Text(
          'To: $recipientLabel',
          style: AppTypography.caption.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        );
      }

      // No useful label — look up recipient name by userId
      if (userId.isEmpty) return const SizedBox.shrink();

      final nameAsync = ref.watch(_recipientNameProvider(userId));
      return nameAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data:
            (name) => name.isEmpty
                ? const SizedBox.shrink()
                : Text(
                  'To: $name',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
      );
// Lightweight provider — only fetches name field
final _userNameProvider = FutureProvider.family<String, String>((
  ref,
  // Looks up name from users first, then students, then teachers
  final _recipientNameProvider = FutureProvider.family<String, String>(
    (ref, userId) async {
      if (userId.isEmpty) return '';

      // Try users collection first (covers all roles)
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userName = userDoc.data()?['name']?.toString() ?? '';
      if (userName.isNotEmpty) return userName;

      // Fallback: students collection
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(userId)
          .get();
      final studentName = studentDoc.data()?['name']?.toString() ?? '';
      if (studentName.isNotEmpty) return studentName;

      // Fallback: teachers collection
      final teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(userId)
          .get();
      return teacherDoc.data()?['name']?.toString() ?? '';
    },
  );
