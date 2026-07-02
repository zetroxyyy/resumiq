import 'dart:io';
import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:path_provider/path_provider.dart';

class CloudinaryService {
  final CloudinaryPublic _cloudinary;

  CloudinaryService()
      : _cloudinary = CloudinaryPublic(
          'dkrnhqhe9',
          'resumind',
          cache: false,
        );

  Future<String> uploadPdf({
    required String filePath,
    required String userId,
  }) async {
    return _uploadWithRetry(
      filePath: filePath,
      folder: 'resumind/users/$userId/cvs',
      resourceType: CloudinaryResourceType.Auto,
    );
  }
  Future<String> uploadCoverLetterPdf({
    required String filePath,
    required String userId,
  }) async {
    return _uploadWithRetry(
      filePath: filePath,
      folder: 'resumind/users/$userId/cover-letters',
      resourceType: CloudinaryResourceType.Auto,
    );
  }
  Future<String> uploadImage({
    required String filePath,
    required String userId,
  }) async {
    return _uploadWithRetry(
      filePath: filePath,
      folder: 'resumind/users/$userId/profile',
      resourceType: CloudinaryResourceType.Image,
    );
  }

  /// Upload raw bytes (e.g., processed photo or passport scan) to Cloudinary.
  /// [folder] is the full folder path, [extension] is the file extension (e.g., 'jpg').
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String folder,
    String extension = 'jpg',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}/upload_$timestamp.$extension');
    await tempFile.writeAsBytes(bytes);
    try {
      return await _uploadWithRetry(
        filePath: tempFile.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Image,
      );
    } finally {
      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<String> _uploadWithRetry({
    required String filePath,
    required String folder,
    required CloudinaryResourceType resourceType,
    bool isRetry = false,
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          folder: folder,
          resourceType: resourceType,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      if (!isRetry) {
        // Retry once on failure
        return await _uploadWithRetry(
          filePath: filePath,
          folder: folder,
          resourceType: resourceType,
          isRetry: true,
        );
      }
      throw Exception('Cloudinary upload failed after retrying: $e');
    }
  }
}
