import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import 'package:pfe_smartschool/navigation/app_routes.dart';

class NotificationDetailscreen extends ConsumerWidget {
  final NotificationModel message;
  const NotificationDetailscreen({super.key, required this.message});

  Color _typeColor(MessageType t) {
    switch (t) {
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

  IconData _typeIcon(MessageType t) {
    switch (t) {
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

  String _typeLabel(MessageType t) {
    switch (t) {
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

  String _fmt(DateTime dt) {
    const m = [
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
    return '${dt.day} ${m[dt.month - 1]} ${dt.year} '
        'at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _isMeaningfulLabel(String label) {
    return label.isNotEmpty &&
        label.toLowerCase() != 'sent' &&
        label != '—' &&
        label != '-';
  }

  String _getRecipientLabel() {
    // Use stored recipientLabel if meaningful
    final original = message.originalRecipient;
    if (_isMeaningfulLabel(original)) return original;
    final label = message.recipientLabel;
    if (_isMeaningfulLabel(label)) return label;
    // Fallback by role
    switch (message.senderRole) {
      case 'admin':
        return 'Whole School';
      case 'teacher':
        return 'Class students';
      case 'student':
        return 'Selected recipients';
      default:
        return 'You';
    }
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Type badge ──────────────────────────────────────────────────
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

            // ── Title ───────────────────────────────────────────────────────
            Text(
              message.title,
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),

            // ── Meta ────────────────────────────────────────────────────────
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
                Text(_fmt(message.createdAt), style: AppTypography.caption),
              ],
            ),
            if (_getRecipientLabel().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  _RecipientNameOrLabel(
                    label: _getRecipientLabel(),
                    recipientId: message.originalRecipientId,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // ── Body ────────────────────────────────────────────────────────
            Text(
              message.message,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.darkText : AppColors.lightText,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            // ── Attachments ─────────────────────────────────────────────────
            if (message.attachments.isNotEmpty) ...[
              Text(
                'Attachments (${message.attachments.length})',
                style: AppTypography.labelLarge.copyWith(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 10),
              ...message.attachments.map(
                (att) => _AttachmentTile(attachment: att, isDark: isDark),
              ),
              const SizedBox(height: 16),
            ],

            // ── Reply indicator ─────────────────────────────────────────────
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

class _RecipientNameOrLabel extends ConsumerWidget {
  final String label;
  final String recipientId;

  const _RecipientNameOrLabel({required this.label, required this.recipientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (label.isNotEmpty && label != 'Selected recipients') {
      return Text('To: $label', style: AppTypography.caption);
    }

    if (recipientId.isEmpty) {
      return Text('To: $label', style: AppTypography.caption);
    }

    final nameAsync = ref.watch(_recipientNameProvider(recipientId));
    return nameAsync.when(
      loading: () => Text('To: $label', style: AppTypography.caption),
      error: (_, __) => Text('To: $label', style: AppTypography.caption),
      data:
          (name) => Text(
            'To: ${name.isNotEmpty ? name : label}',
            style: AppTypography.caption,
          ),
    );
  }
}

// Looks up name from users first, then students, then teachers
final _recipientNameProvider = FutureProvider.family<String, String>((
  ref,
  userId,
) async {
  if (userId.isEmpty) return '';

  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final userName = userDoc.data()?['name']?.toString() ?? '';
  if (userName.isNotEmpty) return userName;

  final studentDoc =
      await FirebaseFirestore.instance.collection('students').doc(userId).get();
  final studentName = studentDoc.data()?['name']?.toString() ?? '';
  if (studentName.isNotEmpty) return studentName;

  final teacherDoc =
      await FirebaseFirestore.instance.collection('teachers').doc(userId).get();
  return teacherDoc.data()?['name']?.toString() ?? '';
});

// ─────────────────────────────────────────────────────────────────────────────
//  ATTACHMENT TILE
//
//  Images   → inline Image.network (200 px) — tap opens full URL in browser
//  PDF/Docs → "Open" button:
//               1. Download bytes with http.get (no extra package beyond http)
//               2. Write to temp dir WITH the original extension preserved
//               3. OpenFile.open() hands the local path to the native OS
//                  (Android PDF viewer, iOS QuickLook, etc.)
//               Loading spinner + progress text while fetching.
// ─────────────────────────────────────────────────────────────────────────────
class _AttachmentTile extends StatefulWidget {
  final AttachmentModel attachment;
  final bool isDark;
  const _AttachmentTile({required this.attachment, required this.isDark});

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _loading = false;
  String _status = ''; // e.g. "Downloading…" / "Opening…"

  AttachmentModel get att => widget.attachment;
  bool get isDark => widget.isDark;

  // ── Derive extension from the stored file name ────────────────────────────
  String get _ext {
    final dot = att.name.lastIndexOf('.');
    if (dot != -1) return att.name.substring(dot).toLowerCase(); // ".pdf"
    // Fallback: extract from URL path before any query string
    final path = Uri.parse(att.url).path;
    final urlDot = path.lastIndexOf('.');
    if (urlDot != -1) {
      final ext = path.substring(urlDot).toLowerCase();
      if (ext.length <= 5) return ext;
    }
    return '';
  }

  // ── Use the raw Cloudinary URL directly ──────────────────────────────────
  // fl_attachment transformation requires a paid Cloudinary plan and returns
  // HTTP 401 on free tier. The raw URL is publicly accessible and http.get
  // downloads the bytes directly without needing the transformation flag.
  String get _downloadUrl => att.url;

  Future<void> _open() async {
    if (att.url.isEmpty) {
      _show('File URL not available');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Connecting…';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      // Safe filename — keep original name with extension
      final safeName = att.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final savePath = '${tempDir.path}/$safeName';

      // ── Check if already cached ──────────────────────────────────────────
      final cached = File(savePath);
      if (!await cached.exists()) {
        setState(() => _status = 'Downloading…');

        final response = await http.get(
          Uri.parse(_downloadUrl),
          headers: {'Accept': '*/*'}, // ensure CDN serves raw bytes
        );
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        await cached.writeAsBytes(response.bodyBytes);
      }

      setState(() => _status = 'Opening…');
      if (!mounted) return;

      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        // OpenFile could not handle it — fall back to browser
        _show('Cannot open locally, trying browser…');
        final uri = Uri.parse(_downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) _show('Error: $e');
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _status = '';
        });
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // ── IMAGE ─────────────────────────────────────────────────────────────
    if (att.type == AttachmentType.image && att.url.isNotEmpty) {
      return GestureDetector(
        onTap: _open, // download to temp file → OpenFile (native viewer)
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
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, prog) {
                    if (prog == null) return child;
                    return Container(
                      height: 200,
                      alignment: Alignment.center,
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      child: CircularProgressIndicator(
                        value:
                            prog.expectedTotalBytes != null
                                ? prog.cumulativeBytesLoaded /
                                    prog.expectedTotalBytes!
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
                // Loading overlay while downloading
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 8),
                          Text(
                            _status,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
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

    // ── PDF / DOCUMENT ────────────────────────────────────────────────────
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
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),

          // ── Info column ────────────────────────────────────────────────────
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
                // Extension badge
                if (_ext.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _ext.toUpperCase().replaceAll('.', ''),
                      style: AppTypography.caption.copyWith(
                        color: color,
                        fontSize: 9,
                      ),
                    ),
                  ),
                // Loading status text
                if (_loading && _status.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _status,
                      style: AppTypography.caption.copyWith(color: color),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Open button / spinner ──────────────────────────────────────────
          _loading
              ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
              : TextButton.icon(
                onPressed: att.url.isNotEmpty ? _open : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('Open'),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
