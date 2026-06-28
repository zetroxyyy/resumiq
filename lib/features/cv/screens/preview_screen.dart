import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/pulsing_mic_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cv_model.dart';
import '../providers/cv_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/pdf_service.dart';
import '../services/docx_service.dart';
import '../services/gemini_service.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String cvId;
  final String? templateName;

  const PreviewScreen({
    super.key,
    required this.cvId,
    this.templateName,
  });

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final PdfService _pdfService = const PdfService();
  final DocxService _docxService = const DocxService();
  final CloudinaryService _cloudinary = CloudinaryService();
  bool _isDownloading = false;
  bool _isDocxLoading = false;
  bool _isAiSuggestionsExpanded = false;

  void _showRenameDialog(String currentTitle, String userId) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (dialogContext) {
        final nav = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('Rename CV'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter new title...',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => nav.pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('cvs')
                      .doc(widget.cvId)
                      .update({'title': newTitle});
                  nav.pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleDownloadAndUpload(dynamic cv, String userId, {required bool isPro}) async {
    setState(() => _isDownloading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfBytes = await _pdfService.generatePdf(cv, widget.templateName ?? cv.template, isPro: isPro);
      final fullName = cv.generatedContent['personalInfo']?['fullName'] as String? ?? 'User';
      final path = await _pdfService.savePdfToDevice(pdfBytes, fullName);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads: ${path.split('/').last}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                Share.shareXFiles([XFile(path)], text: 'Check out my resume!');
              },
            ),
          ),
        );
      }

      // Asynchronously upload same PDF to Cloudinary
      final url = await _cloudinary.uploadPdf(filePath: path, userId: userId);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(widget.cvId)
          .update({'pdfUrl': url});
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Download/Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _handleDocxExport(CvModel cv, String userId) async {
    setState(() => _isDocxLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final docxBytes = _docxService.generateDocx(cv);
      final fullName = cv.generatedContent['personalInfo']?['fullName'] as String? ?? 'User';
      final cleanName = fullName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${cleanName}_CV_$timestamp.docx';
      
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(docxBytes);
      
      final docxUrl = await _cloudinary.uploadDocx(filePath: filePath, userId: userId);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({'docxUrl': docxUrl});
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Word document saved and uploaded!'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                Share.shareXFiles([XFile(filePath)], text: '$fullName Resume (DOCX)');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to export Word document: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDocxLoading = false);
      }
    }
  }

  void _showUpgradePrompt(String feature) {
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
                  'Pro Feature Needed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "$feature is a Pro feature. Upgrade to Pro for access to ATS optimization, DOCX export, and unlimited generations.",
                  style: const TextStyle(color: Colors.white70, height: 1.5),
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
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
    final user = ref.watch(authProvider);
    final cvAsync = ref.watch(cvDetailProvider(widget.cvId));

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return cvAsync.when(
      data: (cv) {
        if (cv == null) {
          return const Scaffold(body: Center(child: Text('CV not found.')));
        }
        final theme = Theme.of(context);

        final score = cv.score ?? 0;
        final scoreColor = score >= 80
            ? Colors.greenAccent
            : score >= 60
                ? Colors.orangeAccent
                : Colors.redAccent;

        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () => _showRenameDialog(cv.title, user.uid),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cv.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 16, color: Colors.white70),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Chip(
                  label: Text(
                    'Score: $score/100',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  backgroundColor: scoreColor,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          body: GradientBackground(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: PdfPreview(
                        build: (format) => _pdfService.generatePdf(cv, widget.templateName ?? cv.template, isPro: user.isPro),
                        useActions: false,
                        canChangePageFormat: false,
                        loadingWidget: const Center(child: CircularProgressIndicator()),
                      ),
                    ),

                    // Collapsible AI suggestions suggestions
                    if (cv.scoreFeedback.isNotEmpty) ...[
                      Card(
                        margin: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ExpansionTile(
                          initiallyExpanded: _isAiSuggestionsExpanded,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _isAiSuggestionsExpanded = expanded;
                            });
                          },
                          leading: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                          title: const Text(
                            '💡 AI Suggestions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: cv.scoreFeedback
                                    .map((feed) => Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.check_circle_outline,
                                                  size: 18, color: Colors.greenAccent),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  feed,
                                                  style: const TextStyle(color: Colors.white70, height: 1.4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ATS Banner above action bar when atsOptimized is true
                    if (cv.atsOptimized || cv.generatedContent['atsOptimized'] == true)
                      Container(
                        color: theme.colorScheme.secondary.withOpacity(0.9),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.bolt, color: Colors.black, size: 18),
                            SizedBox(width: 6),
                            Text(
                              '⚡ ATS Mode — formatted for applicant tracking systems',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Action panel
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      color: Colors.black45,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBottomAction(
                                icon: Icons.picture_as_pdf,
                                label: 'PDF',
                                isLoading: _isDownloading,
                                onTap: () => _handleDownloadAndUpload(cv, user.uid, isPro: user.isPro),
                              ),
                              _buildBottomActionWithProBadge(
                                icon: Icons.description,
                                label: 'Word',
                                isLoading: _isDocxLoading,
                                isProOnly: true,
                                isUserPro: user.isPro,
                                onTap: () {
                                  if (user.isPro) {
                                    _handleDocxExport(cv, user.uid);
                                  } else {
                                    _showUpgradePrompt('Word DOCX Export');
                                  }
                                },
                              ),
                              _buildBottomActionWithProBadge(
                                icon: Icons.mail_outline,
                                label: 'Cover Letter',
                                isProOnly: true,
                                isUserPro: user.isPro,
                                onTap: () {
                                  if (user.isPro) {
                                    context.push('/cv/cover-letter/${cv.id}');
                                  } else {
                                    _showUpgradePrompt('Cover Letter Generator');
                                  }
                                },
                              ),
                            ],
                          ),
                          // Right side action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBottomAction(
                                icon: Icons.mic,
                                label: 'Voice Edit',
                                onTap: () => _showVoiceEditBottomSheet(cv, user.uid),
                              ),
                              _buildBottomAction(
                                icon: Icons.edit_note,
                                label: 'Edit',
                                onTap: () => _showEditBottomSheet(cv, user.uid),
                              ),
                              _buildBottomActionWithProBadge(
                                icon: Icons.share,
                                label: 'Share',
                                isProOnly: true,
                                isUserPro: user.isPro,
                                onTap: () {
                                  if (user.isPro) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Sharing enabled for PRO members!')),
                                    );
                                  } else {
                                    _showUpgradePrompt('Resume Link Sharing');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, size: 28, color: Colors.white),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionWithProBadge({
    required IconData icon,
    required String label,
    bool isLoading = false,
    required bool isProOnly,
    required bool isUserPro,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(icon, size: 28, color: Colors.white),
                if (isProOnly && !isUserPro)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showEditBottomSheet(dynamic cv, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EditCvBottomSheet(
          cv: cv,
          userId: userId,
        );
      },
    );
  }

  void _showVoiceEditBottomSheet(CvModel cv, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _VoiceEditBottomSheet(
          cv: cv,
          userId: userId,
        );
      },
    );
  }
}

class _EditCvBottomSheet extends StatefulWidget {
  final dynamic cv;
  final String userId;

  const _EditCvBottomSheet({
    required this.cv,
    required this.userId,
  });

  @override
  State<_EditCvBottomSheet> createState() => _EditCvBottomSheetState();
}

class _EditCvBottomSheetState extends State<_EditCvBottomSheet> {
  late Map<String, dynamic> _editedContent;
  bool _isSaving = false;

  // Personal Info Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _linkedinController;
  late TextEditingController _portfolioController;

  // Summary
  late TextEditingController _summaryController;

  // References
  late TextEditingController _referencesController;

  @override
  void initState() {
    super.initState();
    _editedContent = Map<String, dynamic>.from(widget.cv.generatedContent);

    final personalInfo = _editedContent['personalInfo'] as Map<String, dynamic>? ?? {};
    _fullNameController = TextEditingController(text: personalInfo['fullName'] as String? ?? '');
    _emailController = TextEditingController(text: personalInfo['email'] as String? ?? '');
    _phoneController = TextEditingController(text: personalInfo['phone'] as String? ?? '');
    _locationController = TextEditingController(text: personalInfo['location'] as String? ?? '');
    _linkedinController = TextEditingController(text: personalInfo['linkedIn'] as String? ?? '');
    _portfolioController = TextEditingController(text: personalInfo['portfolio'] as String? ?? '');

    _summaryController = TextEditingController(text: _editedContent['summary'] as String? ?? '');
    _referencesController = TextEditingController(text: _editedContent['references'] as String? ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _summaryController.dispose();
    _referencesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    // Update locally edited variables
    _editedContent['personalInfo'] = {
      'fullName': _fullNameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'location': _locationController.text,
      'linkedIn': _linkedinController.text,
      'portfolio': _portfolioController.text,
    };
    _editedContent['summary'] = _summaryController.text;
    _editedContent['references'] = _referencesController.text;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cvs')
          .doc(widget.cv.id)
          .update({
        'generatedContent': _editedContent,
        'version': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header indicator bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Resume Data',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Section 1: Personal Info
                    ExpansionTile(
                      title: const Text('Personal Info', style: TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        _buildInputField('Full Name', _fullNameController),
                        _buildInputField('Email', _emailController),
                        _buildInputField('Phone', _phoneController),
                        _buildInputField('Location', _locationController),
                        _buildInputField('LinkedIn', _linkedinController),
                        _buildInputField('Portfolio', _portfolioController),
                      ],
                    ),
                    // Section 2: Summary
                    ExpansionTile(
                      title: const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        _buildInputField('Career Summary', _summaryController, maxLines: 4),
                      ],
                    ),
                    // Section 3: References
                    ExpansionTile(
                      title: const Text('References', style: TextStyle(fontWeight: FontWeight.bold)),
                      children: [
                        _buildInputField('References Description', _referencesController, maxLines: 3),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _saveChanges,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _VoiceEditBottomSheet extends StatefulWidget {
  final CvModel cv;
  final String userId;

  const _VoiceEditBottomSheet({
    required this.cv,
    required this.userId,
  });

  @override
  State<_VoiceEditBottomSheet> createState() => _VoiceEditBottomSheetState();
}

class _VoiceEditBottomSheetState extends State<_VoiceEditBottomSheet> {
  final SpeechToText _speech = SpeechToText();
  bool _speechInitialized = false;
  bool _isListening = false;
  bool _isNepali = false;
  String _transcribedText = '';
  bool _isApplying = false;

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _handleMicTap() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      _toggleListening();
    } else {
      final newStatus = await Permission.microphone.request();
      if (newStatus.isGranted) {
        _toggleListening();
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
            'Resumind needs access to your microphone to enable voice editing. Please enable it in the app settings.',
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

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
    } else {
      if (!_speechInitialized) {
        final init = await _speech.initialize(
          onError: (e) {
            debugPrint('Speech error: $e');
            if (mounted) {
              setState(() => _isListening = false);
            }
          },
          onStatus: (status) {
            debugPrint('Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              if (mounted) {
                setState(() => _isListening = false);
              }
            }
          },
        );
        if (mounted) {
          setState(() {
            _speechInitialized = init;
          });
        }
        if (!init) return;
      }

      String localeId = _isNepali ? 'ne_NP' : 'en_US';
      if (_isNepali) {
        final locales = await _speech.locales();
        final supportsNepali = locales.any((l) =>
            l.localeId.replaceAll('_', '-').toLowerCase() == 'ne-np' ||
            l.localeId.split('_').first == 'ne');
        if (!supportsNepali) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nepali voice not supported on this device, using English')),
            );
          }
          localeId = 'en_US';
        }
      }

      if (mounted) {
        setState(() {
          _isListening = true;
          _transcribedText = '';
        });
      }

      await _speech.listen(
        localeId: localeId,
        onResult: (result) {
          if (mounted) {
            setState(() {
              _transcribedText = result.recognizedWords;
            });
          }
        },
      );
    }
  }

  Future<void> _applyChange() async {
    if (_transcribedText.trim().isEmpty) return;

    setState(() => _isApplying = true);
    final gemini = const GeminiService();

    try {
      final currentCvJson = widget.cv.generatedContent;
      final updatedContent = await gemini.editCv(
        currentCvJson: currentCvJson,
        transcribedText: _transcribedText.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cvs')
          .doc(widget.cv.id)
          .update({
        'generatedContent': updatedContent,
        'version': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV updated ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice edit failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTranscribed = _transcribedText.trim().isNotEmpty;

    return LoadingOverlay(
      isLoading: _isApplying,
      message: 'Applying changes with Gemini...',
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          top: 20.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Edit',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tell me what to change in English or Nepali',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(
                    label: const Text('EN'),
                    selected: !_isNepali,
                    onSelected: (selected) {
                      if (selected) setState(() => _isNepali = false);
                    },
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: !_isNepali ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('नेपाली'),
                    selected: _isNepali,
                    onSelected: (selected) {
                      if (selected) setState(() => _isNepali = true);
                    },
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: _isNepali ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  if (_isListening) ...[
                    const ListeningLabel(),
                    const SizedBox(height: 8),
                  ],
                  PulsingMicButton(
                    isListening: _isListening,
                    onTap: _handleMicTap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                _transcribedText.isEmpty
                    ? 'Press the microphone and start speaking...'
                    : _transcribedText,
                style: TextStyle(
                  color: _transcribedText.isEmpty ? Colors.white30 : Colors.white,
                  fontStyle: _transcribedText.isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Apply Change',
              onPressed: isTranscribed ? _applyChange : null,
            ),
          ],
        ),
      ),
    );
  }
}
