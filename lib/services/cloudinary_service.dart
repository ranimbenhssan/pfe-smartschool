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

  // ── ALWAYS use /image/upload ──────────────────────────────────────────────
  // The upload preset delivers raw resources as "authenticated" (private),
  // causing HTTP 401 when receivers try to download. Image resources are
  // always delivered publicly. Uploading PDFs/docs via /image/upload stores
  // them with public access — Cloudinary serves the raw bytes unchanged.
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  // ── Explicit MIME types ───────────────────────────────────────────────────
  // file_picker returns bytes with no MIME info — without an explicit
  // contentType Cloudinary may reject the upload. image_picker always
  // sets image/jpeg or image/png automatically, which is why images worked.
  static MediaType _mime(String fileName) {
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
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smartschool/messages';

      // ── public_id with extension embedded ────────────────────────────────
      // use_filename / unique_filename are blocked by unsigned presets.
      // Instead, set public_id = timestamp_originalname INCLUDING the
      // extension so Cloudinary keeps it in the secure_url.
      final safeName = fileName
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^\w.\-]'), '');
      request.fields['public_id'] =
          '${DateTime.now().millisecondsSinceEpoch}_$safeName';

      // Attach the file with the correct MIME type
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: _mime(fileName),
        ),
      );

      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        debugPrint(
          '[Cloudinary] upload failed '
          '(${streamed.statusCode}): $responseBody',
        );
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      var secureUrl = json['secure_url']?.toString() ?? '';

      if (secureUrl.isEmpty) {
        debugPrint('[Cloudinary] secure_url missing in response');
        return null;
      }

      // Ensure the original extension is present in the URL
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
