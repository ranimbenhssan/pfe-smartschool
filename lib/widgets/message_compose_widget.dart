import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/theme.dart';

class MessageComposeWidget extends ConsumerStatefulWidget {
  final List<String> allowedTypes;
  final Function(
    String title,
    String message,
    MessageType messageType,
    List<AttachmentModel> attachments,
  ) onSend;
  final bool isLoading;

  const MessageComposeWidget({
    super.key,
    required this.allowedTypes,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  ConsumerState<MessageComposeWidget> createState() =>
      _MessageComposeWidgetState();
}

class _MessageComposeWidgetState
    extends ConsumerState<MessageComposeWidget> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  MessageType _selectedType = MessageType.general;
  final List<AttachmentModel> _attachments = [];
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;
    await _uploadFile(File(image.path), AttachmentType.image);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx'],
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.path != null) {
        final ext = file.extension?.toLowerCase() ?? '';
        final type = ext == 'pdf'
            ? AttachmentType.pdf
            : AttachmentType.document;
        await _uploadFile(File(file.path!), type, name: file.name);
      }
    }
  }

  Future<void> _uploadFile(
    File file,
    AttachmentType type, {
    String? name,
  }) async {
    setState(() => _isUploading = true);
    final fileName = name ?? file.path.split('/').last;
    final attachment = await ref
        .read(storageServiceProvider)
        .uploadFile(
          file: file,
          fileName: fileName,
          type: type,
        );
    if (attachment != null) {
      setState(() => _attachments.add(attachment));
    }
    setState(() => _isUploading = false);
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Message Type ───
        if (widget.allowedTypes.length > 1) ...[
          Text(
            'Message Type',
            style: AppTypography.labelMedium.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.allowedTypes.map((type) {
                final msgType = MessageType.values.firstWhere(
                  (t) => t.name == type,
                  orElse: () => MessageType.general,
                );
                final isSelected = _selectedType == msgType;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = msgType),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : isDark
                              ? AppColors.darkCard
                              : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent
                            : isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _typeIcon(msgType),
                          size: 14,
                          color: isSelected
                              ? AppColors.accent
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _typeLabel(msgType),
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected
                                ? AppColors.accent
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ─── Title ───
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'Message title',
            prefixIcon: const Icon(Icons.title_rounded, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Message ───
        TextField(
          controller: _messageController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Message',
            hintText: 'Write your message here...',
            prefixIcon: const Icon(Icons.message_rounded, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Attachments ───
        if (_attachments.isNotEmpty) ...[
          Text('Attachments', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          ..._attachments.asMap().entries.map((entry) {
            final att = entry.value;
            return Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkCard
                    : AppColors.lightCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    att.type == AttachmentType.image
                        ? Icons.image_rounded
                        : att.type == AttachmentType.pdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.insert_drive_file_rounded,
                    color: att.type == AttachmentType.image
                        ? AppColors.info
                        : att.type == AttachmentType.pdf
                            ? AppColors.error
                            : AppColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.name,
                          style: AppTypography.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          ref
                              .read(storageServiceProvider)
                              .formatFileSize(att.sizeBytes),
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    onPressed: () => _removeAttachment(entry.key),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],

        // ─── Attach buttons ───
        Row(
          children: [
            _AttachButton(
              icon: Icons.image_rounded,
              label: 'Image',
              color: AppColors.info,
              onTap: _isUploading ? null : _pickImage,
            ),
            const SizedBox(width: 8),
            _AttachButton(
              icon: Icons.attach_file_rounded,
              label: 'File',
              color: AppColors.accent,
              onTap: _isUploading ? null : _pickFile,
            ),
            if (_isUploading) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 6),
              Text('Uploading...', style: AppTypography.caption),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // ─── Send button ───
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.isLoading || _isUploading
                ? null
                : () {
                    if (_titleController.text.trim().isEmpty ||
                        _messageController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please fill in title and message',
                          ),
                        ),
                      );
                      return;
                    }
                    widget.onSend(
                      _titleController.text.trim(),
                      _messageController.text.trim(),
                      _selectedType,
                      List.from(_attachments),
                    );
                  },
            icon: widget.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(widget.isLoading ? 'Sending...' : 'Send Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
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
      case MessageType.course:       return 'Course';
      case MessageType.report:       return 'Report';
      case MessageType.general:      return 'General';
    }
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AttachButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}