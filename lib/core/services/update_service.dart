import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

/// Checks GitHub releases for a newer version and shows an update dialog.
/// Uses dart:io HttpClient — no extra packages required.
class UpdateService {
  static const String _owner = 'zetroxyyy';
  static const String _repo = 'resumind';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Silently fetches the latest GitHub release and compares it with the
  /// current [AppConstants.appVersion]. Shows an update dialog if a newer
  /// version is available. Safe to call from initState / app launch.
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.add('Accept', 'application/vnd.github+json');
      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        client.close();
        return;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final rawTag = data['tag_name'] as String? ?? '';
      final htmlUrl = data['html_url'] as String? ?? '';
      final assets = data['assets'] as List? ?? [];
      
      String downloadUrl = htmlUrl;
      if (assets.isNotEmpty) {
        final firstAsset = assets[0] as Map<String, dynamic>;
        downloadUrl = firstAsset['browser_download_url'] as String? ?? htmlUrl;
      }

      // Extract ONLY the numeric part (e.g. "v1.2.1-bugfixes" -> "1.2.1")
      final remoteVersion = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(rawTag)?.group(1) ?? '';
      final currentVersion = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(AppConstants.appVersion)?.group(1) ?? '';

      if (remoteVersion.isEmpty) return;

      if (_isNewerVersion(remoteVersion, currentVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, remoteVersion, downloadUrl);
        }
      }
    } catch (_) {
      // Silently swallow — network errors should never crash the app launch
    }
  }

  /// Returns true if [remote] is strictly greater than [current].
  /// Both must be in "major.minor.patch" semver format.
  static bool _isNewerVersion(String remote, String current) {
    final remoteParts = remote.split('.').map((x) => int.tryParse(x) ?? 0).toList();
    final currentParts = current.split('.').map((x) => int.tryParse(x) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final r = (i < remoteParts.length ? remoteParts[i] : 0);
      final c = (i < currentParts.length ? currentParts[i] : 0);
      if (r > c) return true;
      if (r < c) return false;
    }
    return false; // equal
  }

  static void _showUpdateDialog(
      BuildContext context, String newVersion, String downloadUrl) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          // Prevent back-button dismiss
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.system_update_rounded,
                    color: Colors.deepPurpleAccent),
                SizedBox(width: 10),
                Text('Update Available'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version $newVersion is now available. Please update Resumind to continue using all features.',
                  style: const TextStyle(height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Current: v${AppConstants.appVersion}  →  Latest: v$newVersion',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Users can skip — they'll be reminded next launch
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'Later',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Update Now'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
