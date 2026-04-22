import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

class CloudinaryService {
  // ─── Replace with your actual Cloudinary credentials ───
  static const String _cloudName = 'dysb3nw2i';
  static const String _uploadPreset = 'smartschool';

  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';

  // ─── Upload bytes to Cloudinary ───
  Future<AttachmentModel?> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required AttachmentType type,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smartschool/messages';
      request.fields['public_id'] =
          '${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(' ', '_')}';

      // ─── Resource type based on file type ───
      final resourceType = type == AttachmentType.image ? 'image' : 'raw';

      final cloudUrl =
          'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload';

      final uploadRequest = http.MultipartRequest('POST', Uri.parse(cloudUrl));
      uploadRequest.fields['upload_preset'] = _uploadPreset;
      uploadRequest.fields['folder'] = 'smartschool/messages';

      uploadRequest.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      final response = await uploadRequest.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        debugPrint('Cloudinary error: $responseBody');
        return null;
      }

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final url = json['secure_url']?.toString() ?? '';

      if (url.isEmpty) return null;

      return AttachmentModel(
        url: url,
        name: fileName,
        type: type,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
