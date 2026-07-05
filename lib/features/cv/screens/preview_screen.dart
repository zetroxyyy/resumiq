import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/widgets/pulsing_mic_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cv_model.dart';
import '../models/version_model.dart';
import '../providers/cv_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/pdf_service.dart';
import '../services/ai_service.dart';
import '../../../core/providers/busy_provider.dart';
import '../../../core/utils/snackbar_helper.dart';


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
  final CloudinaryService _cloudinary = CloudinaryService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isDownloading = false;
  bool _isAiSuggestionsExpanded = false;

  bool _includePassport = false;
  bool _includeCitizenshipFront = false;
  bool _includeCitizenshipBack = false;
  bool _includeBodyPhoto = false;

  Key _pdfKey = UniqueKey();
  Timer? _pdfRebuildTimer;
  bool _togglesInitialized = false;

  void _initDocumentToggles(CvModel cv) {
    _includePassport = cv.passportUrl != null && cv.passportUrl!.isNotEmpty;
    _includeCitizenshipFront = cv.citizenshipFrontUrl != null && cv.citizenshipFrontUrl!.isNotEmpty;
    _includeCitizenshipBack = cv.citizenshipBackUrl != null && cv.citizenshipBackUrl!.isNotEmpty;
    _includeBodyPhoto = cv.bodyPhotoUrl != null && cv.bodyPhotoUrl!.isNotEmpty;
  }

  void _schedulePdfRebuild() {
    _pdfRebuildTimer?.cancel();
    _pdfRebuildTimer = Timer(
      const Duration(milliseconds: 300),
      () {
        if (mounted) setState(() => _triggerPdfRebuild());
      }
    );
  }

  void _triggerPdfRebuild() {
    _pdfKey = ValueKey(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _pdfRebuildTimer?.cancel();
    super.dispose();
  }

  Future<Uint8List> _generatePdfBytes(CvModel cv, bool isPro) {
    return _pdfService.generatePdf(
      cv,
      'Normal',
      options: DocumentOptions(
        includePassport: _includePassport,
        passportUrl: cv.passportUrl,
        includeCitizenshipFront: _includeCitizenshipFront,
        citizenshipFrontUrl: cv.citizenshipFrontUrl,
        includeCitizenshipBack: _includeCitizenshipBack,
        citizenshipBackUrl: cv.citizenshipBackUrl,
        includeBodyPhoto: _includeBodyPhoto,
        bodyPhotoUrl: cv.bodyPhotoUrl,
      ),
    );
  }

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
      debugPrint('Generating PDF with photoUrl: ${cv.photoUrl}');
      final pdfBytes = await _pdfService.generatePdf(
        cv,
        'Normal',
        options: DocumentOptions(
          includePassport: _includePassport,
          passportUrl: cv.passportUrl,
          includeCitizenshipFront: _includeCitizenshipFront,
          citizenshipFrontUrl: cv.citizenshipFrontUrl,
          includeCitizenshipBack: _includeCitizenshipBack,
          citizenshipBackUrl: cv.citizenshipBackUrl,
          includeBodyPhoto: _includeBodyPhoto,
          bodyPhotoUrl: cv.bodyPhotoUrl,
        ),
      );
      final fullName = cv.generatedContent['personalInfo']?['fullName'] as String? ?? 'User';
      final path = await _pdfService.savePdfToDevice(pdfBytes, fullName);

      if (mounted) {
        showAppSnackBar(context, 'Saved to Downloads: ${path.split('/').last}', type: SnackType.success);
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

  Future<String?> _pickAndUploadDocument(String userId, String fieldName) async {
    if (ref.read(busyProvider)) return null;
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return null;
      
      ref.read(busyProvider.notifier).state = true;
      ref.read(busyReasonProvider.notifier).state = 'Uploading document...';
      
      setState(() {
        _isDownloading = true;
      });

      final imageFile = File(picked.path);
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

      final bytes = await imageFile.readAsBytes();
      final url = await _cloudinary.uploadBytes(
        bytes: bytes,
        folder: 'resumiq/users/$userId/documents',
        extension: 'jpg',
      );
      
      return url;
    } catch (e) {
      debugPrint('Doc upload error: $e');
      if (mounted) {
        showAppSnackBar(context, 'Document upload failed: $e', type: SnackType.error);
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
      ref.read(busyProvider.notifier).state = false;
      ref.read(busyReasonProvider.notifier).state = null;
    }
  }


  Future<void> _handlePassportToggle(bool val, CvModel cv, String userId) async {
    if (!val) {
      _includePassport = false;
      _schedulePdfRebuild();
      return;
    }
    if (cv.passportUrl != null && cv.passportUrl!.isNotEmpty) {
      _includePassport = true;
      _schedulePdfRebuild();
      return;
    }
    final uploadedUrl = await _pickAndUploadDocument(userId, 'passportUrl');
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({'passportUrl': uploadedUrl});
      _includePassport = true;
      ref.invalidate(cvDetailProvider(cv.id));
      _schedulePdfRebuild();
    }
  }

  Future<void> _handleCitFrontToggle(bool val, CvModel cv, String userId) async {
    if (!val) {
      _includeCitizenshipFront = false;
      _schedulePdfRebuild();
      return;
    }
    if (cv.citizenshipFrontUrl != null && cv.citizenshipFrontUrl!.isNotEmpty) {
      _includeCitizenshipFront = true;
      _schedulePdfRebuild();
      return;
    }
    final uploadedUrl = await _pickAndUploadDocument(userId, 'citizenshipFrontUrl');
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({'citizenshipFrontUrl': uploadedUrl});
      _includeCitizenshipFront = true;
      ref.invalidate(cvDetailProvider(cv.id));
      _schedulePdfRebuild();
    }
  }

  Future<void> _handleCitBackToggle(bool val, CvModel cv, String userId) async {
    if (!val) {
      _includeCitizenshipBack = false;
      _schedulePdfRebuild();
      return;
    }
    if (cv.citizenshipBackUrl != null && cv.citizenshipBackUrl!.isNotEmpty) {
      _includeCitizenshipBack = true;
      _schedulePdfRebuild();
      return;
    }
    final uploadedUrl = await _pickAndUploadDocument(userId, 'citizenshipBackUrl');
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({'citizenshipBackUrl': uploadedUrl});
      _includeCitizenshipBack = true;
      ref.invalidate(cvDetailProvider(cv.id));
      _schedulePdfRebuild();
    }
  }

  Future<void> _handleBodyPhotoToggle(bool val, CvModel cv, String userId) async {
    if (!val) {
      _includeBodyPhoto = false;
      _schedulePdfRebuild();
      return;
    }
    if (cv.bodyPhotoUrl != null && cv.bodyPhotoUrl!.isNotEmpty) {
      _includeBodyPhoto = true;
      _schedulePdfRebuild();
      return;
    }
    final uploadedUrl = await _pickAndUploadDocument(userId, 'bodyPhotoUrl');
    if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cv.id)
          .update({'bodyPhotoUrl': uploadedUrl});
      _includeBodyPhoto = true;
      ref.invalidate(cvDetailProvider(cv.id));
      _schedulePdfRebuild();
    }
  }

  Widget _buildDocumentPagesSection(CvModel cv, String userId) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Document Pages', 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          const Divider(height: 1),
          // Four SwitchListTiles here
          _documentTile(
            'Passport Copy', 
            isOn: _includePassport,
            onToggle: (val) => _handlePassportToggle(val, cv, userId),
            url: cv.passportUrl,
          ),
          _documentTile(
            'Citizenship Front',
            isOn: _includeCitizenshipFront,
            onToggle: (val) => _handleCitFrontToggle(val, cv, userId),
            url: cv.citizenshipFrontUrl,
          ),
          _documentTile(
            'Citizenship Back',
            isOn: _includeCitizenshipBack,
            onToggle: (val) => _handleCitBackToggle(val, cv, userId),
            url: cv.citizenshipBackUrl,
          ),
          _documentTile(
            'Full Body Photo',
            isOn: _includeBodyPhoto,
            onToggle: (val) => _handleBodyPhotoToggle(val, cv, userId),
            url: cv.bodyPhotoUrl,
          ),
        ],
      ),
    );
  }

  Widget _documentTile(String label, {required bool isOn, required ValueChanged<bool> onToggle, String? url}) {
    final theme = Theme.of(context);
    final isBusy = ref.watch(busyProvider);
    return SwitchListTile(
      title: Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
      subtitle: url != null && url.isNotEmpty
          ? Text('Uploaded', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12))
          : Text('Not uploaded yet (tap to upload)', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.38))),
      value: isOn,
      onChanged: isBusy ? null : onToggle,
      activeColor: theme.colorScheme.primary,
    );
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
                  "$feature is a Pro feature. Upgrade to Pro for access to premium styling and unlimited generations.",
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
    final isBusy = ref.watch(busyProvider);
    final busyReason = ref.watch(busyReasonProvider);

    ref.listen<AsyncValue<CvModel?>>(cvDetailProvider(widget.cvId), (prev, next) {
      next.whenData((cv) {
        if (cv != null && mounted) {
          _initDocumentToggles(cv);
        }
      });
    });

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return cvAsync.when(
      data: (cv) {
        if (cv == null) {
          return const Scaffold(body: Center(child: Text('CV not found.')));
        }
        if (!_togglesInitialized) {
          _initDocumentToggles(cv);
          _togglesInitialized = true;
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
                margin: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: Text(
                    'Score: $score/100',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  backgroundColor: scoreColor,
                  padding: EdgeInsets.zero,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Version History',
                onPressed: () => _showHistoryBottomSheet(cv, user.uid),
              ),
            ],
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
                  flex: 3,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: PdfPreview(
                      key: _pdfKey,
                      build: (format) => _generatePdfBytes(cv, user.isPro),
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      allowPrinting: false,
                      allowSharing: false,
                      maxPageWidth: 700,
                      initialPageFormat: PdfPageFormat.a4,
                      scrollViewDecoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      pdfPreviewPageDecoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      useActions: false,
                      loadingWidget: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (cv.scoreFeedback.isNotEmpty)
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
                                'AI Suggestions',
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
                        _buildDocumentPagesSection(cv, user.uid),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomAction(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  isLoading: _isDownloading,
                  isPrimary: true,
                  onTap: () => _handleDownloadAndUpload(cv, user.uid, isPro: user.isPro),
                ),
                _buildBottomAction(
                  icon: Icons.mic_none_outlined,
                  label: 'Voice Edit',
                  onTap: () => _showVoiceEditBottomSheet(cv, user.uid),
                ),
                _buildBottomAction(
                  icon: Icons.edit_note_outlined,
                  label: 'Edit',
                  onTap: () async {
                    final result = await context.push('/cv/editor/${cv.id}', extra: cv);
                    if (result == true) {
                      ref.invalidate(cvDetailProvider(cv.id));
                    }
                  },
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
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final activeColor = isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                  )
                : Icon(icon, size: 28, color: activeColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: activeColor, fontSize: 11),
            ),
          ],
        ),
      ),
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

  void _showHistoryBottomSheet(CvModel cv, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _HistoryBottomSheet(
          cvId: cv.id,
          userId: userId,
          currentTemplate: cv.template,
        );
      },
    );
  }
}

class _EditCvBottomSheet extends ConsumerStatefulWidget {
  final dynamic cv;
  final String userId;

  const _EditCvBottomSheet({
    required this.cv,
    required this.userId,
  });

  @override
  ConsumerState<_EditCvBottomSheet> createState() => _EditCvBottomSheetState();
}

class _EditCvBottomSheetState extends ConsumerState<_EditCvBottomSheet> {
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
    if (ref.read(busyProvider)) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        showAppSnackBar(context, 'Session expired. Please sign in and sign in again.', type: SnackType.error);
      }
      return;
    }

    final String userId = currentUser.uid;
    final String cvId = widget.cv.id;

    if (userId.isEmpty || cvId.isEmpty) {
      if (mounted) {
        showAppSnackBar(context, 'Error: User ID or CV ID is missing.', type: SnackType.error);
      }
      return;
    }

    ref.read(busyProvider.notifier).state = true;
    ref.read(busyReasonProvider.notifier).state = 'Saving changes...';
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
      // Snapshot current state before overwriting (version history)
      await saveVersion(
        uid: userId,
        cvId: cvId,
        generatedContent:
            Map<String, dynamic>.from(widget.cv.generatedContent),
        template: widget.cv.template,
        changedBy: 'manual_edit',
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Auth UID: ${currentUser?.uid}');
      debugPrint('Auth email: ${currentUser?.email}');
      debugPrint('CV userId being used: $userId');
      debugPrint('CV id being used: $cvId');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cvs')
          .doc(cvId)
          .update({
        'generatedContent': _editedContent,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      });

      if (mounted) {
        showAppSnackBar(context, 'Changes saved successfully!', type: SnackType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to save changes: $e', type: SnackType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      ref.read(busyProvider.notifier).state = false;
      ref.read(busyReasonProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBusy = ref.watch(busyProvider);

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
                onPressed: isBusy ? null : _saveChanges,
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

class _VoiceEditBottomSheet extends ConsumerStatefulWidget {
  final CvModel cv;
  final String userId;

  const _VoiceEditBottomSheet({
    required this.cv,
    required this.userId,
  });

  @override
  ConsumerState<_VoiceEditBottomSheet> createState() => _VoiceEditBottomSheetState();
}

class _VoiceEditBottomSheetState extends ConsumerState<_VoiceEditBottomSheet> {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
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
            'Resumiq needs access to your microphone to enable voice editing. Please enable it in the app settings.',
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
        debugLogging: true,
      );

      if (!init) return;

      if (mounted) {
        setState(() {
          _isListening = true;
          _transcribedText = '';
        });
      }

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
              _transcribedText = result.recognizedWords;
            });
            if (result.finalResult) {
              setState(() => _isListening = false);
            }
          }
        },
      );
    }
  }

  Future<void> _applyChange() async {
    if (_transcribedText.trim().isEmpty) return;
    if (ref.read(busyProvider)) return;

    ref.read(busyProvider.notifier).state = true;
    ref.read(busyReasonProvider.notifier).state = 'Applying voice edits...';
    setState(() => _isApplying = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() => _isApplying = false);
        ref.read(busyProvider.notifier).state = false;
        ref.read(busyReasonProvider.notifier).state = null;
        showAppSnackBar(context, 'Session expired. Please sign in again.', type: SnackType.error);
      }
      return;
    }

    final cvId = widget.cv.id;

    try {
      final updatedContent = await ref.read(aiServiceProvider)
        .editCv(
          currentCvData: widget.cv.generatedContent,
          editInstruction: _transcribedText.trim(),
        );

      await saveVersion(
        uid: userId,
        cvId: cvId,
        generatedContent: Map<String, dynamic>.from(widget.cv.generatedContent),
        template: widget.cv.template,
        changedBy: 'voice_edit',
      );

      await FirebaseFirestore.instance
          .collection('users').doc(userId)
          .collection('cvs').doc(cvId)
          .update({
            'generatedContent': updatedContent,
            'updatedAt': FieldValue.serverTimestamp(),
            'version': FieldValue.increment(1),
          });

      ref.invalidate(cvDetailProvider(cvId));

      if (mounted) {
        Navigator.pop(context); // Close bottom sheet
        showAppSnackBar(context, 'CV updated successfully', type: SnackType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Edit failed: $e', type: SnackType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
      ref.read(busyProvider.notifier).state = false;
      ref.read(busyReasonProvider.notifier).state = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTranscribed = _transcribedText.trim().isNotEmpty;
    final isBusy = ref.watch(busyProvider);

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
                      'Tell me what to change in your CV',
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
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  if (_isListening) ...[
                    const ListeningLabel(),
                    const SizedBox(height: 8),
                  ],
                  PulsingMicButton(
                    isListening: _isListening,
                    onTap: isBusy ? null : _handleMicTap,
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
              onPressed: isTranscribed && !isBusy ? _applyChange : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History Bottom Sheet ─────────────────────────────────────────────────────

class _HistoryBottomSheet extends ConsumerStatefulWidget {
  final String cvId;
  final String userId;
  final String currentTemplate;

  const _HistoryBottomSheet({
    required this.cvId,
    required this.userId,
    required this.currentTemplate,
  });

  @override
  ConsumerState<_HistoryBottomSheet> createState() =>
      _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends ConsumerState<_HistoryBottomSheet> {
  String? _restoringId;

  String _changedByLabel(String changedBy) {
    switch (changedBy) {
      case 'manual_edit':
        return 'Manual Edit';
      case 'voice_edit':
        return 'Voice Edit';
      case 'regenerated':
        return 'Regenerated';
      case 'initial':
        return 'Initial Version';
      case 'before_restore':
        return 'Before Restore';
      default:
        return changedBy;
    }
  }

  IconData _changedByIcon(String changedBy) {
    switch (changedBy) {
      case 'manual_edit':
        return Icons.edit_note_rounded;
      case 'voice_edit':
        return Icons.mic_rounded;
      case 'regenerated':
        return Icons.auto_awesome_rounded;
      case 'before_restore':
        return Icons.restore_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  Future<void> _restoreVersion(VersionModel version) async {
    setState(() => _restoringId = version.id);
    try {
      await restoreVersion(
        uid: widget.userId,
        cvId: widget.cvId,
        version: version,
      );
      if (mounted) {
        Navigator.pop(context);
        showAppSnackBar(context, 'Restored to version #${version.versionNumber}', type: SnackType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Restore failed: $e', type: SnackType.error);
      }
    } finally {
      if (mounted) setState(() => _restoringId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versionsAsync = ref.watch(
      cvVersionsProvider((uid: widget.userId, cvId: widget.cvId)),
    );


    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Handle bar
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
                children: [
                  const Icon(Icons.history_rounded,
                      color: Colors.deepPurpleAccent),
                  const SizedBox(width: 10),
                  Text(
                    'Version History',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Up to 10 snapshots are kept. Tap Restore to roll back.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
              const Divider(height: 24),
              Expanded(
                child: versionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Error loading history: $e')),
                  data: (versions) {
                    if (versions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded,
                                size: 56, color: Colors.white24),
                            const SizedBox(height: 16),
                            const Text(
                              'No version history yet.\nEdit your CV to create snapshots.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: versions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final v = versions[index];
                        final isCurrentVersion = index == 0; // newest = current
                        final isRestoring = _restoringId == v.id;
                        final name =
                            v.generatedContent['personalInfo']?['fullName']
                                as String? ??
                                'Unknown';
                        final fmt2 = DateFormat('MMM dd, yyyy \'at\' h:mm a');

                        return Container(
                          decoration: isCurrentVersion
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: Colors.deepPurpleAccent,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : null,
                          margin: isCurrentVersion
                              ? const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2)
                              : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCurrentVersion
                                  ? Colors.deepPurpleAccent.withOpacity(0.3)
                                  : Colors.deepPurpleAccent.withOpacity(0.15),
                              child: Icon(
                                _changedByIcon(v.changedBy),
                                color: Colors.deepPurpleAccent,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'Version #${v.versionNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCurrentVersion
                                        ? Colors.deepPurpleAccent
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCurrentVersion
                                        ? Colors.deepPurpleAccent
                                            .withOpacity(0.2)
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _changedByLabel(v.changedBy),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isCurrentVersion
                                          ? Colors.deepPurpleAccent
                                          : Colors.white60,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                                Text(fmt2.format(v.changedAt),
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: isCurrentVersion
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurpleAccent
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.deepPurpleAccent
                                              .withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      'Current',
                                      style: TextStyle(
                                        color: Colors.deepPurpleAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : isRestoring
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : TextButton(
                                        onPressed: () =>
                                            _showRestoreConfirm(v),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Colors.deepPurpleAccent,
                                        ),
                                        child: const Text('Restore'),
                                      ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRestoreConfirm(VersionModel version) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Version?'),
        content: Text(
          'This will restore version #${version.versionNumber} (${_changedByLabel(version.changedBy)}). '
          'Your current state will be saved as a new version first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _restoreVersion(version);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
