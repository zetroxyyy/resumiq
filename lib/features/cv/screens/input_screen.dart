import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/pulsing_mic_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cv_provider.dart';
import '../services/photo_service.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../../core/providers/busy_provider.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  final _infoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _inlineError;

  // Photo upload state
  final PhotoService _photoService = PhotoService();
  final ImagePicker _imagePicker = ImagePicker();
  String? _photoUrl;
  bool _isPhotoLoading = false;

  StreamSubscription? _sharingSubscription;

  final SpeechToText _speech = SpeechToText();
  bool _isListeningInfo = false;
  bool _hasMicPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();

    // Listen to sharing intents when app is in memory
    _sharingSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty && mounted) {
        final sharedText = value.map((f) => f.path).join('\n');
        if (sharedText.isNotEmpty) {
          _infoController.text = sharedText;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Text received from sharing. Review and tap Generate CV.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              duration: const Duration(seconds: 4),
            )
          );
        }
      }
    }, onError: (err) {
      debugPrint('Sharing error: $err');
    });

    // Check sharing intent that opened the app
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty && mounted) {
        final sharedText = value.map((f) => f.path).join('\n');
        if (sharedText.isNotEmpty) {
          setState(() {
            _infoController.text = sharedText;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Text received. Review and tap Generate CV.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          );
        }
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        _hasMicPermission = status.isGranted;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (mounted) {
      setState(() {
        _hasMicPermission = status.isGranted;
      });
    }
  }

  Future<void> _handleMicAction(VoidCallback onGranted) async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      onGranted();
    } else {
      final newStatus = await Permission.microphone.request();
      if (mounted) {
        setState(() {
          _hasMicPermission = newStatus.isGranted;
        });
      }
      if (newStatus.isGranted) {
        onGranted();
      } else {
        _showPermissionExplanationDialog();
      }
    }
  }

  void _showPermissionExplanationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Microphone Permission Required'),
          content: const Text(
            'Resumiq needs access to your microphone to enable voice typing. Please enable it in the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startListening({
    required TextEditingController controller,
    required VoidCallback onStop,
  }) async {
    final init = await _speech.initialize(
      onError: (error) => debugPrint('Speech error: $error'),
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          onStop();
        }
      },
      debugLogging: true,
    );
    if (!init) return;

    final baseText = controller.text.trim();

    await _speech.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      cancelOnError: false,
      sampleRate: 44100,
      onResult: (result) {
        if (mounted) {
          setState(() {
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              controller.text = baseText.isEmpty ? words : '$baseText $words';
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
          });
          if (result.finalResult) {
            onStop();
          }
        }
      },
    );
  }

  Future<void> _stopListening({required VoidCallback onStop}) async {
    await _speech.stop();
    onStop();
  }

  @override
  void dispose() {
    _infoController.dispose();
    _speech.stop();
    _sharingSubscription?.cancel();
    super.dispose();
  }

  // ─── Photo Upload Methods ────────────────────────────────────────────────────

  Future<void> _handlePhotoUpload() async {
    if (ref.read(busyProvider)) return; // block if already busy
    final user = ref.read(authProvider);
    if (user == null) return;

    // Show gallery/camera choice
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            if (_photoUrl != null) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  setState(() => _photoUrl = null);
                  ref.read(cvGenerationProvider.notifier).setPhotoUrl('');
                  Navigator.pop(ctx);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    ref.read(busyProvider.notifier).state = true;
    ref.read(busyReasonProvider.notifier).state = 'Uploading photo...';
    setState(() => _isPhotoLoading = true);
    try {
      final imageFile = File(picked.path);
      // STEP 2 — Defensive validation
      if (!await imageFile.exists()) {
        throw Exception('Image file not found. Please try picking again.');
      }
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        throw Exception('Image file is empty. Please try a different photo.');
      }
      if (fileSize > 10 * 1024 * 1024) {
        throw Exception('Image too large. Please use a smaller photo.');
      }

      String uploadedUrl = '';
      try {
        final transparentBytes = await _photoService.removeBackground(imageFile);
        final whiteBgBytes = await _photoService.addWhiteBackground(transparentBytes);
        uploadedUrl = await _photoService.uploadPhoto(whiteBgBytes, user.uid);
      } catch (e) {
        debugPrint('BG removal error caught: $e');
        String reason = 'Unknown error';
        if (e.toString().contains('BG_KEY_MISSING')) {
          reason = 'Service not configured';
        } else if (e.toString().contains('402')) {
          reason = 'Monthly limit reached';
        } else if (e.toString().contains('403')) {
          reason = 'Invalid API key';
        } else if (e.toString().contains('BG_REMOVAL_FAILED')) {
          reason = 'Processing failed';
        }

        // Still use the original photo so the user isn't blocked
        // upload original imageFile bytes to Cloudinary as fallback
        final originalBytes = await imageFile.readAsBytes();
        Uint8List bytesToUpload;
        try {
          bytesToUpload = await _photoService.addWhiteBackground(originalBytes);
        } catch (_) {
          bytesToUpload = originalBytes;
        }
        uploadedUrl = await _photoService.uploadPhoto(bytesToUpload, user.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Background removal unavailable ($reason). Using original photo.'),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 5),
            )
          );
        }
      }

      if (mounted) {
        ref.read(cvGenerationProvider.notifier).setPhotoUrl(uploadedUrl);
        setState(() {
          _photoUrl = uploadedUrl;
          _isPhotoLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Photo upload error: $e');
      if (mounted) {
        setState(() => _isPhotoLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
    } finally {
      ref.read(busyProvider.notifier).state = false;
      ref.read(busyReasonProvider.notifier).state = null;
    }
  }

  Widget _buildPhotoUploadRow() {
    final isBusy = ref.watch(busyProvider);
    return GestureDetector(
      onTap: isBusy ? null : _handlePhotoUpload,
      child: Opacity(
        opacity: isBusy ? 0.5 : 1.0,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white10,
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null
                      ? const Icon(Icons.person, size: 36, color: Colors.white38)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isPhotoLoading
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _photoUrl != null ? 'Photo added' : 'Add your photo (optional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _photoUrl != null
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Background will be removed automatically',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGenerate() async {
    if (ref.read(busyProvider)) return;
    
    setState(() {
      _inlineError = null;
    });

    final user = ref.read(authProvider);
    if (user == null) return;

    // 1. Free Tier Gate Check
    if (!user.isPro && user.generationsThisMonth >= 2) {
      _showLimitBottomSheet();
      return;
    }

    // 2. Validate input length
    final rawInput = _infoController.text.trim();
    if (rawInput.length < 50) {
      setState(() {
        _inlineError = 'Please enter at least 50 characters to describe yourself.';
      });
      return;
    }

    ref.read(busyProvider.notifier).state = true;
    ref.read(busyReasonProvider.notifier).state = 'Generating CV...';
    try {
      // 3. Save input values to Riverpod provider & route to Generating screen
      ref.read(cvInputProvider.notifier).state = CvInputState(
        rawInput: rawInput,
        photoUrl: _photoUrl,
      );

      context.go('/cv/generating');
    } catch (e) {
      debugPrint('CV generation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    } finally {
      ref.read(busyProvider.notifier).state = false;
      ref.read(busyReasonProvider.notifier).state = null;
    }
  }

  void _showLimitBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Generation Limit Reached',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "You've used your 2 free CVs this month. Upgrade to Pro for unlimited creations, professional formats, and scoring insights.",
                  style: TextStyle(color: Colors.white70, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                CustomButton(
                  text: 'Upgrade to Pro',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/upgrade');
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Maybe Later', style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = ref.watch(busyProvider);
    final busyReason = ref.watch(busyReasonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your CV'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: isBusy
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please wait for $busyReason to finish')))
              : () => Navigator.pop(context),
        ),
      ),
      body: GradientBackground(
        child: Column(
          children: [
            if (isBusy) ...[
              const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: Text(
                  busyReason ?? 'Please wait...',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Microphone permission card
                      if (!_hasMicPermission) ...[
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.mic_none_outlined,
                                  color: theme.colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Enable microphone to use voice typing',
                                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                  ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _requestPermission,
                                  child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Photo upload row
                      _buildPhotoUploadRow(),
                      const SizedBox(height: 24),

                      // Section: Your Information
                      Text(
                        'Your Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Dump everything here — your name, work history, education, skills, achievements... Don't worry about formatting or structure.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Voice typing label + mic button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Voice Typing',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                          ),
                          Row(
                            children: [
                              if (_isListeningInfo)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: ListeningLabel(),
                                ),
                              PulsingMicButton(
                                isListening: _isListeningInfo,
                                onTap: () {
                                  _handleMicAction(() {
                                    if (_isListeningInfo) {
                                      _stopListening(onStop: () => setState(() => _isListeningInfo = false));
                                    } else {
                                      setState(() => _isListeningInfo = true);
                                      _startListening(
                                        controller: _infoController,
                                        onStop: () => setState(() => _isListeningInfo = false),
                                      );
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Large multiline text field
                      Stack(
                        children: [
                          TextFormField(
                            controller: _infoController,
                            minLines: 6,
                            maxLines: 12,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Type your experiences here...',
                              hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.38)),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _inlineError != null ? Colors.redAccent : theme.colorScheme.outline,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _inlineError != null ? Colors.redAccent : theme.colorScheme.primary,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16.0),
                            ),
                            onChanged: (text) {
                              if (_inlineError != null && text.trim().length >= 50) {
                                setState(() => _inlineError = null);
                              }
                              setState(() {}); // Repaint char counter
                            },
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Text(
                              '${_infoController.text.length} chars',
                              style: TextStyle(
                                color: _infoController.text.length < 50 ? theme.colorScheme.secondary : theme.colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_inlineError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _inlineError!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ],

                      // Generate CV button
                      const SizedBox(height: 24),
                      CustomButton(
                        text: isBusy ? (busyReason ?? 'Please wait...') : 'Generate CV',
                        onPressed: isBusy ? null : _handleGenerate,
                        isLoading: isBusy,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListeningLabel extends StatelessWidget {
  const ListeningLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Listening...',
            style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
