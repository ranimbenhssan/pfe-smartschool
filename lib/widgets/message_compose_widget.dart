import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/cloudinary_service.dart';
import '../theme/theme.dart';

class MessageComposeWidget extends ConsumerStatefulWidget {
  final List<String> allowedTypes;
  final Function(
    String title,
    String message,
    MessageType messageType,
    List<AttachmentModel> attachments,
  )
  onSend;
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

class _MessageComposeWidgetState extends ConsumerState<MessageComposeWidget> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  MessageType _selectedType = MessageType.general;
  final List<AttachmentModel> _attachments = [];
  bool _isUploading = false;
  String? _uploadError;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // ── Upload to Cloudinary ─────────────────────────────────────────────────
  Future<void> _uploadBytes(
    Uint8List bytes,
    String fileName,
    AttachmentType type,
  ) async {
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    final attachment = await ref
        .read(cloudinaryServiceProvider)
        .uploadFile(bytes: bytes, fileName: fileName, type: type);

    if (attachment != null) {
      setState(() => _attachments.add(attachment));
    } else {
      setState(
        () =>
            _uploadError =
                'Upload failed. Please check your connection and try again.',
      );
    }

    setState(() => _isUploading = false);
  }

  // ── Pick image from gallery ──────────────────────────────────────────────
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final fileName =
          image.name.isNotEmpty
              ? image.name
              : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _uploadBytes(bytes, fileName, AttachmentType.image);
    } catch (e) {
      setState(() => _uploadError = 'Could not pick image: $e');
    }
  }

  // ── Pick file (PDF, DOCX, etc.) ──────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'csv'],
        withData: true, // requests in-memory bytes
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      Uint8List? bytes = picked.bytes;

      // ── Fallback: read from path if withData returned null ────────────────
      // On Android 10+ (scoped storage) or when picking from Google Drive,
      // file_picker may return null bytes even with withData:true.
      // Reading from the path directly always works.
      if (bytes == null) {
        final path = picked.path;
        if (path == null) {
          setState(
            () => _uploadError = 'Could not read file. Try a different file.',
          );
          return;
        }
        bytes = await File(path).readAsBytes();
      }

      if (bytes.isEmpty) {
        setState(() => _uploadError = 'File is empty.');
        return;
      }

      final ext = picked.extension?.toLowerCase() ?? '';
      final type = ext == 'pdf' ? AttachmentType.pdf : AttachmentType.document;

      await _uploadBytes(bytes, picked.name, type);
    } catch (e) {
      setState(() => _uploadError = 'Could not pick file: $e');
    }
  }

  void _removeAttachment(int index) =>
      setState(() => _attachments.removeAt(index));

  String _typeLabel(MessageType t) {
    switch (t) {
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
        return 'General';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allowed =
        MessageType.values
            .where((t) => widget.allowedTypes.contains(t.name))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Message type selector ──────────────────────────────────────────
        if (allowed.length > 1) ...[
          Text(
            'Message Type',
            style: AppTypography.labelMedium.copyWith(
              color:
                  isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  allowed.map((msgType) {
                    final isSelected = _selectedType == msgType;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = msgType),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.accent.withValues(alpha: 0.15)
                                  : isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.accent
                                    : isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                          ),
                        ),
                        child: Text(
                          _typeLabel(msgType),
                          style: AppTypography.labelSmall.copyWith(
                            color: isSelected ? AppColors.accent : null,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Title ──────────────────────────────────────────────────────────
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'Message title',
            prefixIcon: const Icon(Icons.title_rounded, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        // ── Message body ────────────────────────────────────────────────────
        TextField(
          controller: _messageController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Message',
            hintText: 'Write your message here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        // ── Attachments list ────────────────────────────────────────────────
        if (_attachments.isNotEmpty) ...[
          Text(
            'Attachments (${_attachments.length})',
            style: AppTypography.labelMedium,
          ),
          const SizedBox(height: 8),
          ..._attachments.asMap().entries.map((entry) {
            final att = entry.value;
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

            return Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
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
                              .read(cloudinaryServiceProvider)
                              .formatFileSize(att.sizeBytes),
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.cloud_done_rounded,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
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

        // ── Upload error ────────────────────────────────────────────────────
        if (_uploadError != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _uploadError!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _uploadError = null),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),

        // ── Attach buttons ──────────────────────────────────────────────────
        Row(
          children: [
            _AttachBtn(
              icon: Icons.image_rounded,
              label: 'Image',
              color: AppColors.info,
              enabled: !_isUploading,
              onTap: _pickImage,
            ),
            const SizedBox(width: 8),
            _AttachBtn(
              icon: Icons.attach_file_rounded,
              label: 'File',
              color: AppColors.accent,
              enabled: !_isUploading,
              onTap: _pickFile,
            ),
            if (_isUploading) ...[
              const SizedBox(width: 14),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Uploading...', style: AppTypography.caption),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // ── Send button ─────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                widget.isLoading || _isUploading
                    ? null
                    : () {
                      if (_titleController.text.trim().isEmpty ||
                          _messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in title and message'),
                          ),
                        );
                        return;
                      }
                      // Disable immediately to prevent double-tap
                      setState(() => _isUploading = true);
                      widget.onSend(
                        _titleController.text.trim(),
                        _messageController.text.trim(),
                        _selectedType,
                        List.from(_attachments),
                      );
                    },
            icon:
                widget.isLoading
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
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  ATTACH BUTTON
// ─────────────────────────────────────────
class _AttachBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _AttachBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
