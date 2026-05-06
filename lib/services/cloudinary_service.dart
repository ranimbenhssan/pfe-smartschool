import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../models/models.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

class CloudinaryService {
  static const String _cloudName = 'dysb3nw2i';
  static const String _uploadPreset = 'smartschool';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  // ── MIME type map ─────────────────────────────────────────────────────────
  // http.MultipartFile.fromBytes defaults to application/octet-stream when no
  // contentType is given. Cloudinary's /auto/upload endpoint rejects that for
  // non-image files on some presets. Providing the explicit MIME type fixes it.
  static MediaType _mimeFor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      // Images
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      // Documents
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
      case 'ppt':
        return MediaType('application', 'vnd.ms-powerpoint');
      case 'pptx':
        return MediaType(
          'application',
          'vnd.openxmlformats-officedocument.presentationml.presentation',
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
      request.fields['use_filename'] = 'true';
      request.fields['unique_filename'] = 'true';

      // ── Explicit MIME type on the file part ──────────────────────────────
      // Without this, file_picker bytes arrive as application/octet-stream
      // which Cloudinary may reject. image_picker bytes carry image/jpeg etc.
      // automatically which is why images always worked.
      final mimeType = _mimeFor(fileName);

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: mimeType, // ← the key fix
        ),
      );

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
        debugPrint('Cloudinary: secure_url missing in response');
        return null;
      }

      // Ensure the URL retains the original file extension
      secureUrl = _ensureExtension(secureUrl, fileName);
      debugPrint('Cloudinary upload OK → $secureUrl');

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
