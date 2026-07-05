import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image_lib;
import 'cloudinary_service.dart';

class PhotoService {
  final CloudinaryService _cloudinary = CloudinaryService();

  // ─── Background Removal via remove.bg API ───────────────────────────────────

  Future<Uint8List> removeBackground(File imageFile) async {
    final apiKey = FirebaseRemoteConfig.instance
      .getString('REMOVE_BG_API_KEY').trim();
    
    debugPrint('remove.bg key length: ${apiKey.length}');
    
    if (apiKey.isEmpty) {
      throw Exception('BG_KEY_MISSING');
    }
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.remove.bg/v1.0/removebg'),
    );
    request.headers['X-Api-Key'] = apiKey;
    request.fields['size'] = 'auto';
    request.files.add(await http.MultipartFile.fromPath(
      'image_file', imageFile.path,
    ));
    
    debugPrint('remove.bg: sending request...');
    
    final streamedResponse = await request.send()
      .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    
    debugPrint('remove.bg: status ${response.statusCode}');
    
    if (response.statusCode == 200) {
      debugPrint('remove.bg: success, bytes=${response.bodyBytes.length}');
      return response.bodyBytes;
    }
    
    // Surface the exact reason
    final bodyPreview = response.body.length > 300 
      ? response.body.substring(0, 300) 
      : response.body;
    debugPrint('remove.bg: FAILED - ${response.statusCode} - $bodyPreview');
    
    throw Exception('BG_REMOVAL_FAILED_${response.statusCode}: $bodyPreview');
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
}
