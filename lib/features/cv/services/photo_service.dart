import 'dart:io';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'cloudinary_service.dart';

class PhotoService {
  final CloudinaryService _cloudinary = CloudinaryService();

  // ─── Remote Config Key ──────────────────────────────────────────────────────

  Future<String> fetchRemoveBgKey() async {
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

  /// Calls remove.bg API and returns white-background PNG bytes.
  /// Throws if the API call completely fails (not quota issue).
  Future<Uint8List> removeBackground(File imageFile) async {
    final apiKey = await fetchRemoveBgKey();
    if (apiKey.isEmpty) {
      throw Exception('remove.bg API key not configured');
    }

    final uri = Uri.parse('https://api.remove.bg/v1.0/removebg');
    final request = http.MultipartRequest('POST', uri)
      ..headers['X-Api-Key'] = apiKey
      ..fields['size'] = 'auto'
      ..files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      // response.bodyBytes is the transparent PNG
      return addWhiteBackground(response.bodyBytes);
    } else {
      debugPrint('remove.bg error ${response.statusCode}: ${response.body}');
      throw Exception('remove.bg API error ${response.statusCode}: ${response.body}');
    }
  }

  // ─── White Background Compositing ───────────────────────────────────────────

  /// Takes a transparent PNG (Uint8List) and composites it onto a white canvas.
  /// Returns JPEG/PNG bytes suitable for use as a profile photo.
  Future<Uint8List> addWhiteBackground(Uint8List transparentPng) async {
    return await compute(_addWhiteBackgroundIsolate, transparentPng);
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
      final processedBytes = await removeBackground(imageFile);
      final url = await uploadPhoto(processedBytes, userId);
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

// ─── Isolate Helper (runs in separate isolate via compute) ────────────────────

Uint8List _addWhiteBackgroundIsolate(Uint8List transparentPng) {
  // Decode the transparent image
  final transparentImage = img.decodeImage(transparentPng);
  if (transparentImage == null) {
    throw Exception('Failed to decode transparent image');
  }

  // Create a white canvas of the same size
  final whiteImage = img.Image(
    width: transparentImage.width,
    height: transparentImage.height,
  );

  // Fill with white
  img.fill(whiteImage, color: img.ColorRgba8(255, 255, 255, 255));

  // Composite the transparent image on top
  img.compositeImage(whiteImage, transparentImage);

  // Encode to JPEG (smaller, no transparency needed)
  return Uint8List.fromList(img.encodeJpg(whiteImage, quality: 90));
}

// ─── Result Model ────────────────────────────────────────────────────────────

class PhotoUploadResult {
  final String url;
  final bool usedBgRemoval;

  const PhotoUploadResult({required this.url, required this.usedBgRemoval});
}
