import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<AttachmentModel?> uploadFile({
    required File file,
    required String fileName,
    required AttachmentType type,
  }) async {
    try {
      final ref = _storage
          .ref()
          .child('messages')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      final sizeBytes = await file.length();

      return AttachmentModel(
        url: url,
        name: fileName,
        type: type,
        sizeBytes: sizeBytes,
      );
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}