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
  //  Key fixes:
  //  1. Two separate upload URLs — /image/upload for images, /raw/upload for docs.
  //  2. For raw (non-image) uploads:
  //     - use_filename=true  → Cloudinary keeps the original filename INCLUDING
  //       extension (e.g. report.pdf) in the public_id.
  //     - unique_filename=true → avoids collision without mangling the extension.
  //     - Do NOT set a custom public_id (it strips the extension).
  //  3. The returned secure_url for raw resources now ends with the real
  //     extension (e.g. .pdf, .docx, .txt) so the OS can identify the MIME type.
  // ─────────────────────────────────────────────────────────────────────────
  Future<AttachmentModel?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required AttachmentType type,
  }) async {
    try {
      final isImage = type == AttachmentType.image;
      final resourceType = isImage ? 'image' : 'raw';
      final uploadUrl =
          'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smartschool/messages';

      if (isImage) {
        // For images Cloudinary handles the extension automatically.
        request.fields['public_id'] =
            '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';
      } else {
        // For raw files: let Cloudinary keep the original name+extension.
        // Setting public_id would strip the extension — so we don't set it.
        request.fields['use_filename'] = 'true';
        request.fields['unique_filename'] = 'true';
      }

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint('Cloudinary upload error: $responseBody');
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final secureUrl = json['secure_url']?.toString() ?? '';

      if (secureUrl.isEmpty) return null;

      // For raw uploads: ensure the URL ends with the original extension.
      // If Cloudinary already includes it (use_filename=true), this is a no-op.
      final finalUrl = _ensureExtension(secureUrl, fileName);

      return AttachmentModel(
        url: finalUrl,
        name: fileName,
        type: type,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  // ─── Append original extension if the URL is missing it ──────────────────
  // e.g. secureUrl ends with "/v1234/smartschool/messages/report"
  //      fileName is "report.pdf"
  //      → returns ".../report.pdf"
  String _ensureExtension(String url, String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1) return url; // no extension
    final ext = fileName.substring(dot); // ".pdf"
    if (url.toLowerCase().endsWith(ext.toLowerCase()))
      return url; // already there
    // Strip any Cloudinary format suffix (e.g. ?_a=...) before appending
    final base = url.split('?').first;
    return '$base$ext';
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
