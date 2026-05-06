import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/models.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

class CloudinaryService {
  static const String _cloudName = 'dysb3nw2i';
  static const String _uploadPreset = 'smartschool';

  // ─────────────────────────────────────────────────────────────────────────
  //  UPLOAD FILE
  //
  //  Two separate endpoints:
  //
  //  Images → /image/upload
  //    Cloudinary stores as image resource → public delivery by default.
  //    secure_url: .../image/upload/v.../name.jpg → HTTP 200, no auth needed.
  //
  //  PDFs / Documents → /raw/upload
  //    Requires the preset to have:
  //      • Resource type: Auto (not Image-only)
  //      • Delivery type: Upload (not Authenticated)
  //    Without those dashboard settings, raw files get HTTP 401 on download.
  //    See README: Cloudinary Dashboard → Settings → Upload → smartschool preset.
  // ─────────────────────────────────────────────────────────────────────────

  static const String _imageUploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';
  static const String _rawUploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/raw/upload';

  static bool _isImage(AttachmentType type) => type == AttachmentType.image;

  static MediaType _mimeFor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case 'txt':
        return MediaType('text', 'plain');
      case 'csv':
        return MediaType('text', 'csv');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  Future<AttachmentModel?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required AttachmentType type,
  }) async {
    final isImage = _isImage(type);
    final endpoint = isImage ? _imageUploadUrl : _rawUploadUrl;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));

      // ── Allowed unsigned upload fields ────────────────────────────────────
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smartschool/messages';

      // Embed original filename (with extension) in public_id so the
      // secure_url preserves the extension for correct MIME detection on download.
      final safeName = fileName
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w.\-]'), '');
      request.fields['public_id'] =
          '${DateTime.now().millisecondsSinceEpoch}_$safeName';

      // ── File with explicit MIME type ──────────────────────────────────────
      // file_picker returns bytes with Content-Type: application/octet-stream
      // by default. Providing the explicit MIME lets Cloudinary validate and
      // process the file correctly.
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: _mimeFor(fileName),
        ),
      );

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        debugPrint(
          '[Cloudinary] $endpoint upload failed '
          '(HTTP ${streamed.statusCode}): $responseBody',
        );
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      var secureUrl = json['secure_url']?.toString() ?? '';

      if (secureUrl.isEmpty) {
        debugPrint('[Cloudinary] secure_url missing: $responseBody');
        return null;
      }

      // Ensure the extension is preserved in the URL
      secureUrl = _ensureExtension(secureUrl, fileName);
      debugPrint('[Cloudinary] uploaded → $secureUrl');

      return AttachmentModel(
        url: secureUrl,
        name: fileName,
        type: type,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('[Cloudinary] exception: $e');
      return null;
    }
  }

  String _ensureExtension(String url, String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return url;
    final ext = fileName.substring(dot).toLowerCase();
    final base = url.split('?').first;
    if (base.toLowerCase().endsWith(ext)) return url;
    return '$base$ext';
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
