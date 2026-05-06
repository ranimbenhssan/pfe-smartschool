import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

class CloudinaryService {
  static const String _cloudName = 'dysb3nw2i';
  static const String _uploadPreset = 'smartschool';

  // ── Always use /auto/upload ───────────────────────────────────────────────
  // Cloudinary detects the resource type automatically (image / raw / video).
  // Using /image/upload for non-images or /raw/upload for images both fail
  // because the preset's allowed resource type is "auto".
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  Future<AttachmentModel?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required AttachmentType type,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      // ── Required fields ──────────────────────────────────────────────────
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smartschool/messages';

      // ── Extension preservation ───────────────────────────────────────────
      // use_filename=true  → Cloudinary keeps the original filename including
      //                      extension in the public_id.
      // unique_filename=true → appends a short hash to avoid collision.
      // This replaces setting a custom public_id, which strips extensions.
      request.fields['use_filename'] = 'true';
      request.fields['unique_filename'] = 'true';

      // ── File bytes ───────────────────────────────────────────────────────
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName, // tells Cloudinary the real filename + ext
        ),
      );

      // ── Send ─────────────────────────────────────────────────────────────
      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        debugPrint(
          'Cloudinary upload failed '
          '(HTTP ${streamed.statusCode}): $responseBody',
        );
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      var secureUrl = json['secure_url']?.toString() ?? '';

      if (secureUrl.isEmpty) {
        debugPrint('Cloudinary: upload OK but secure_url missing in response');
        return null;
      }

      // ── Ensure extension is in URL ────────────────────────────────────────
      // For non-image resource types Cloudinary sometimes omits the extension
      // from secure_url. Append it from the original filename if missing.
      secureUrl = _ensureExtension(secureUrl, fileName);

      debugPrint('Cloudinary upload OK: $secureUrl');

      return AttachmentModel(
        url: secureUrl,
        name: fileName,
        type: type,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('Cloudinary upload exception: $e');
      return null;
    }
  }

  /// Appends the original file extension to [url] if it is not already there.
  String _ensureExtension(String url, String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return url;
    final ext = fileName.substring(dot).toLowerCase(); // e.g. ".pdf"
    final base = url.split('?').first; // strip query string
    if (base.toLowerCase().endsWith(ext)) return url; // already present
    return '$base$ext';
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
