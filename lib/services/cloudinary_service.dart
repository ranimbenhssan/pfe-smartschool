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

  // ─────────────────────────────────────────────────────────────────────────
  //  UPLOAD FILE
  //
  //  The live code created TWO MultipartRequests but only sent the second
  //  one — which was missing upload_preset and had no file attached for
  //  the image path. For raw files the second request also lacked
  //  use_filename, so Cloudinary rejected it (non-200) → "check internet".
  //
  //  Fix: one clean request per call.
  //
  //  Resource type rules:
  //  • image → /image/upload  (Cloudinary resizes/optimises)
  //  • pdf / document → /raw/upload  (stored as-is, extension preserved)
  //
  //  For raw uploads:
  //  • use_filename=true   → keeps original filename incl. extension in
  //                          public_id so the secure_url ends with .pdf etc.
  //  • unique_filename=true → appends a short random suffix to avoid
  //                          collision without mangling the extension.
  //  • Do NOT set a custom public_id for raw — Cloudinary strips the ext.
  //
  //  NOTE: your Cloudinary upload preset ("smartschool") must have
  //  "Signing Mode" set to "Unsigned" AND "Resource type" set to "Auto"
  //  (not locked to "Image"). If you cannot change the preset, create a
  //  second unsigned preset named "smartschool_raw" with resource type Auto
  //  and set _rawUploadPreset below accordingly.
  // ─────────────────────────────────────────────────────────────────────────

  // If your preset is locked to images only, create a second preset for raw.
  // Set it to the same name if your preset already allows "auto" resource type.
  static const String _rawUploadPreset = 'smartschool'; // change if needed

  Future<AttachmentModel?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required AttachmentType type,
  }) async {
    final isImage = type == AttachmentType.image;
    final resourceType = isImage ? 'image' : 'raw';
    final uploadUrl =
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload';
    final preset = isImage ? _uploadPreset : _rawUploadPreset;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // ── Fields ────────────────────────────────────────────────────────────
      request.fields['upload_preset'] = preset;
      request.fields['folder'] = 'smartschool/messages';

      if (isImage) {
        // For images: set a timestamped public_id — Cloudinary keeps the ext
        request.fields['public_id'] =
            '${DateTime.now().millisecondsSinceEpoch}_'
            '${fileName.replaceAll(' ', '_')}';
      } else {
        // For raw: let Cloudinary preserve the original filename + extension
        request.fields['use_filename'] = 'true';
        request.fields['unique_filename'] = 'true';
        // Do NOT set public_id here — it would strip the extension
      }

      // ── File bytes ────────────────────────────────────────────────────────
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      // ── Send ──────────────────────────────────────────────────────────────
      final streamed = await request.send();
      final responseBody = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        // Print the full Cloudinary error so you can diagnose preset issues
        debugPrint(
          'Cloudinary [$resourceType] upload failed '
          '(${streamed.statusCode}): $responseBody',
        );
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      var secureUrl = json['secure_url']?.toString() ?? '';

      if (secureUrl.isEmpty) {
        debugPrint('Cloudinary: response OK but secure_url missing');
        return null;
      }

      // For raw uploads, ensure the URL ends with the original extension.
      // use_filename=true usually handles this, but guard just in case.
      if (!isImage) {
        secureUrl = _ensureExtension(secureUrl, fileName);
      }

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

  /// Appends the original file extension to the URL if it's missing.
  String _ensureExtension(String url, String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return url;
    final ext = fileName.substring(dot).toLowerCase(); // ".pdf"
    final base = url.split('?').first; // strip query params
    if (base.toLowerCase().endsWith(ext)) return url; // already correct
    return '$base$ext';
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
