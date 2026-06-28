import 'package:cloudinary_public/cloudinary_public.dart';

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
