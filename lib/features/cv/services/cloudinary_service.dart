import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final CloudinaryPublic _cloudinary;

  CloudinaryService({
    required String cloudName,
    required String uploadPreset,
  }) : _cloudinary = CloudinaryPublic(cloudName, uploadPreset);

  Future<String> uploadFile({
    required String filePath,
    required String folder,
  }) async {
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        filePath,
        folder: folder,
      ),
    );
    return response.secureUrl;
  }
}
