import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../models/models.dart';

class MessageReplyScreen extends ConsumerStatefulWidget {
  final NotificationModel originalMessage;

  const MessageReplyScreen({super.key, required this.originalMessage});

  @override
  ConsumerState<MessageReplyScreen> createState() => _MessageReplyScreenState();
}

class _MessageReplyScreenState extends ConsumerState<MessageReplyScreen> {
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a reply'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // ─── Must have a valid sender to reply to ───
    if (widget.originalMessage.senderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reply — sender information missing'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final replyTitle = 'Re: ${widget.originalMessage.title}';

      // ─── Write reply directly to Firestore ───
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.originalMessage.senderId,
        'senderId': currentUser.id,
        'senderName': currentUser.name,
        'senderRole': currentUser.role.name,
        'title': replyTitle,
        'message': _messageController.text.trim(),
        'messageType': MessageType.general.name,
        'attachments': [],
        'recipientLabel': widget.originalMessage.senderName,
        'replyToId': widget.originalMessage.id,
        'replyToTitle': widget.originalMessage.title,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply sent successfully ✅'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reply: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final original = widget.originalMessage;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Reply'),
        backgroundColor:
            isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Original message quote ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  width: 1,
                ),
                // ─── Left accent bar ───
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.reply_rounded,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Replying to ${original.senderName}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          original.title,
                          style: AppTypography.labelMedium.copyWith(
                            color:
                                isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          original.message,
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── To: info ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'To: ',
                    style: AppTypography.caption.copyWith(
                      color:
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                    ),
                  ),
                  Text(
                    original.senderName,
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      original.senderRole.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Subject (auto-filled, read-only) ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.title_rounded,
                    size: 16,
                    color:
                        isDark
                            ? AppColors.darkTextHint
                            : AppColors.lightTextHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Re: ${original.title}',
                      style: AppTypography.labelMedium.copyWith(
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─── Reply message ───
            TextField(
              controller: _messageController,
              maxLines: 6,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Write your reply here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
              ),
            ),
            const SizedBox(height: 24),

            // ─── Send button ───
            AppButton(
              label: _isLoading ? 'Sending...' : 'Send Reply',
              onPressed: _isLoading ? () {} : _sendReply,
              isLoading: _isLoading,
              width: double.infinity,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
