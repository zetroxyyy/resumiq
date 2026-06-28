import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/pulsing_mic_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cv_model.dart';
import '../providers/cv_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/docx_service.dart';
import '../services/gemini_service.dart';
import '../services/pdf_service.dart';

class CoverLetterScreen extends ConsumerStatefulWidget {
  final String cvId;

  const CoverLetterScreen({
    super.key,
    required this.cvId,
  });

  @override
  ConsumerState<CoverLetterScreen> createState() => _CoverLetterScreenState();
}

class _CoverLetterScreenState extends ConsumerState<CoverLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _jobDescController = TextEditingController();
  late TextEditingController _coverLetterTextController;

  final GeminiService _gemini = const GeminiService();
  final PdfService _pdfService = const PdfService();
  final DocxService _docxService = const DocxService();
  final CloudinaryService _cloudinary = CloudinaryService();

  final SpeechToText _speech = SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  bool _hasMicPermission = true;

  bool _isLoading = false;
  String _loadingMessage = '';
  bool _hasCoverLetter = false;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _coverLetterTextController = TextEditingController();
    _coverLetterTextController.addListener(() {
      setState(() {});
    });
    _checkPermission();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _jobDescController.dispose();
    _coverLetterTextController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    setState(() {
      _hasMicPermission = status.isGranted;
    });
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _hasMicPermission = status.isGranted;
    });
  }

  Future<bool> _initSpeech() async {
    if (_speechInitialized) return true;
    final init = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() {
      _speechInitialized = init;
    });
    return init;
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      final hasPerm = await Permission.microphone.request().isGranted;
      if (!hasPerm) {
        setState(() => _hasMicPermission = false);
        return;
      }
      final init = await _initSpeech();
      if (!init) return;

      setState(() => _isListening = true);
      final baseText = _jobDescController.text.trim();
      await _speech.listen(
        localeId: 'en_US',
        onResult: (result) {
          setState(() {
            final words = result.recognizedWords;
            if (words.isNotEmpty) {
              _jobDescController.text = baseText.isEmpty ? words : '$baseText $words';
              _jobDescController.selection = TextSelection.fromPosition(
                TextPosition(offset: _jobDescController.text.length),
              );
            }
          });
        },
      );
    }
  }

  Future<void> _generateLetter(CvModel cv) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Generating cover letter...';
    });

    try {
      final letter = await _gemini.generateCoverLetter(
        cv: cv,
        jobDescription: _jobDescController.text.trim().isNotEmpty ? _jobDescController.text.trim() : null,
        targetCompany: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
      );

      setState(() {
        _coverLetterTextController.text = letter;
        _hasCoverLetter = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSave(CvModel cv, String userId) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Saving cover letter...';
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({
        'coverLetter': _coverLetterTextController.text,
        'updatedAt': Timestamp.now(),
      });

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover letter saved successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleDownloadPdf(CvModel cv, String userId) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Generating PDF...';
    });

    try {
      final pdfBytes = await _pdfService.generateCoverLetterPdf(
        cv,
        _coverLetterTextController.text,
        targetCompany: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
      );

      final name = cv.generatedContent['personalInfo']?['fullName'] as String? ?? 'User';
      final path = await _pdfService.saveCoverLetterPdfToDevice(pdfBytes, name);

      // Upload to Cloudinary
      final url = await _cloudinary.uploadCoverLetterPdf(filePath: path, userId: userId);

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({
        'coverLetter': _coverLetterTextController.text,
        'coverLetterPdfUrl': url,
        'updatedAt': Timestamp.now(),
      });

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Documents: ${path.split('/').last}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                Share.shareXFiles([XFile(path)], text: 'My Cover Letter');
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generation/upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleExportDocx(CvModel cv, String userId) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Exporting Word DOCX...';
    });

    try {
      final docxBytes = _docxService.generateCoverLetterDocx(
        cv,
        _coverLetterTextController.text,
        targetCompany: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
      );

      final fullName = cv.generatedContent['personalInfo']?['fullName'] as String? ?? 'User';
      final cleanName = fullName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${cleanName}_CoverLetter_$timestamp.docx';

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(docxBytes);

      // Upload to Cloudinary
      final docxUrl = await _cloudinary.uploadCoverLetterDocx(filePath: filePath, userId: userId);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({
        'coverLetter': _coverLetterTextController.text,
        'coverLetterDocxUrl': docxUrl,
        'updatedAt': Timestamp.now(),
      });

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word Document exported!'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                Share.shareXFiles([XFile(filePath)], text: 'My Cover Letter Word Doc');
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DOCX generation/upload failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleShare() {
    final text = _coverLetterTextController.text;
    if (text.isNotEmpty) {
      Share.share(text, subject: 'My Cover Letter');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final cvAsync = ref.watch(cvDetailProvider(widget.cvId));

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Authentication required')));
    }

    return cvAsync.when(
      data: (cv) {
        if (cv == null) {
          return const Scaffold(body: Center(child: Text('CV not found.')));
        }

        // Run initialization logic exactly once when CV data initially arrives
        if (_isInit) {
          _isInit = false;
          if (cv.coverLetter != null && cv.coverLetter!.isNotEmpty) {
            _coverLetterTextController.text = cv.coverLetter!;
            _hasCoverLetter = true;
          }
        }

        return LoadingOverlay(
          isLoading: _isLoading,
          message: _loadingMessage,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Cover Letter'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
            body: GradientBackground(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _hasCoverLetter
                      ? _buildEditMode(theme, cv, user.uid)
                      : _buildGenerationForm(theme, cv),
                ),
              ),
            ),
            bottomNavigationBar: _hasCoverLetter
                ? Container(
                    margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionBarButton(
                          icon: Icons.save,
                          label: 'Save',
                          onTap: () => _handleSave(cv, user.uid),
                        ),
                        _buildActionBarButton(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF',
                          onTap: () => _handleDownloadPdf(cv, user.uid),
                        ),
                        _buildActionBarButton(
                          icon: Icons.description,
                          label: 'Word',
                          onTap: () => _handleExportDocx(cv, user.uid),
                        ),
                        _buildActionBarButton(
                          icon: Icons.share,
                          label: 'Share',
                          onTap: _handleShare,
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildGenerationForm(ThemeData theme, CvModel cv) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('generation_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.primary.withOpacity(0.1),
            margin: const EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text('✍️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Cover Letter Generator tailored specifically to your resume ${cv.title}.',
                      style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!_hasMicPermission) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.red.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.mic_off, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Voice permissions disabled. Please grant microphone access to enable voice dictation.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _requestPermission,
                      child: const Text('Enable', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          Text(
            'Target Company (Optional)',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _companyController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Samsung Nepal',
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Job Description (Optional)',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_isListening) const ListeningLabel(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _jobDescController,
                  maxLines: 8,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Paste the job posting description here to customize...',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PulsingMicButton(
                isListening: _isListening,
                onTap: _toggleListening,
              ),
            ],
          ),
          const SizedBox(height: 32),

          CustomButton(
            text: 'Generate Cover Letter',
            onPressed: () => _generateLetter(cv),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(ThemeData theme, CvModel cv, String userId) {
    final charCount = _coverLetterTextController.text.length;
    return Column(
      key: const ValueKey('edit_mode'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Customize Cover Letter',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Regenerate'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(color: theme.colorScheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  _hasCoverLetter = false;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _coverLetterTextController,
                  maxLines: 18,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
                const Divider(color: Colors.white10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$charCount characters',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80), // bottom bar spacing
      ],
    );
  }

  Widget _buildActionBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
