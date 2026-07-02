import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image_lib;
import 'cloudinary_service.dart';

class PhotoService {
  final CloudinaryService _cloudinary = CloudinaryService();

  // ─── Remote Config Key ──────────────────────────────────────────────────────

  Future<String> _fetchRemoveBgKey() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: Duration.zero,
      ));
      await rc.fetchAndActivate();
      final key = rc.getString('removeBgApiKey');
      return key;
    } catch (e) {
      debugPrint('PhotoService: Remote Config fetch failed: $e');
      return '';
    }
  }

  // ─── Background Removal via remove.bg API ───────────────────────────────────

  Future<Uint8List> removeBackground(File imageFile) async {
    final apiKey = await _fetchRemoveBgKey();
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.remove.bg/v1.0/removebg'),
    );
    
    request.headers['X-Api-Key'] = apiKey;
    request.fields['size'] = 'auto';
    request.files.add(await http.MultipartFile.fromPath(
      'image_file',
      imageFile.path,
    ));
    
    final streamedResponse = await request.send()
      .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    
    debugPrint('remove.bg status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return response.bodyBytes; // transparent PNG
    } else {
      debugPrint('remove.bg error: ${response.body}');
      throw Exception('Background removal failed: ${response.statusCode}');
    }
  }

  // ─── White Background Compositing ───────────────────────────────────────────

  Future<Uint8List> addWhiteBackground(Uint8List transparentPng) async {
    final image_lib.Image? original = 
      image_lib.decodeImage(transparentPng);
    if (original == null) throw Exception('Could not decode image');
    
    // Create white background canvas same size
    final whiteBg = image_lib.Image(
      width: original.width,
      height: original.height,
    );
    
    // Fill with white
    image_lib.fill(whiteBg, color: image_lib.ColorRgb8(255, 255, 255));
    
    // Composite original over white background
    image_lib.compositeImage(whiteBg, original);
    
    return Uint8List.fromList(image_lib.encodePng(whiteBg));
  }

  // ─── Cloudinary Upload ───────────────────────────────────────────────────────

  /// Uploads processed photo bytes to Cloudinary and returns the secure URL.
  Future<String> uploadPhoto(Uint8List photoBytes, String userId) async {
    return await _cloudinary.uploadBytes(
      bytes: photoBytes,
      folder: 'resumind/users/$userId/photos',
      extension: 'jpg',
    );
  }

  /// Uploads passport image bytes to Cloudinary and returns the secure URL.
  Future<String> uploadPassport(Uint8List passportBytes, String userId) async {
    return await _cloudinary.uploadBytes(
      bytes: passportBytes,
      folder: 'resumind/users/$userId/passports',
      extension: 'jpg',
    );
  }

  // ─── Full Pipeline: Pick → Remove BG → Upload ────────────────────────────────

  /// Full photo processing pipeline.
  /// Returns Cloudinary URL on success.
  /// On remove.bg failure, uploads original image and returns URL (graceful fallback).
  Future<PhotoUploadResult> processAndUploadPhoto({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Try remove.bg
      final transparentBytes = await removeBackground(imageFile);
      final whiteBytes = await addWhiteBackground(transparentBytes);
      final url = await uploadPhoto(whiteBytes, userId);
      return PhotoUploadResult(url: url, usedBgRemoval: true);
    } catch (bgError) {
      debugPrint('PhotoService: BG removal failed ($bgError), uploading original');
      // Fallback: upload original image
      try {
        final originalBytes = await imageFile.readAsBytes();
        // Still add white background if the original has transparency
        Uint8List bytesToUpload;
        try {
          bytesToUpload = await addWhiteBackground(originalBytes);
        } catch (_) {
          bytesToUpload = originalBytes;
        }
        final url = await uploadPhoto(bytesToUpload, userId);
        return PhotoUploadResult(url: url, usedBgRemoval: false);
      } catch (uploadError) {
        throw Exception('Photo upload failed: $uploadError');
      }
    }
  }
}

// ─── Result Model ────────────────────────────────────────────────────────────

class PhotoUploadResult {
  final String url;
  final bool usedBgRemoval;

  const PhotoUploadResult({required this.url, required this.usedBgRemoval});
}
