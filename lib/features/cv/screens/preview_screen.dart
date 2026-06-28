import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cv_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/pdf_service.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final String cvId;

  const PreviewScreen({
    super.key,
    required this.cvId,
  });

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  final PdfService _pdfService = const PdfService();
  final CloudinaryService _cloudinary = CloudinaryService();
  bool _isDownloading = false;
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

  Future<void> _handleDownloadAndUpload(dynamic cv, String userId) async {
    setState(() => _isDownloading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdfBytes = await _pdfService.generatePdf(cv, cv.template);
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
            child: Column(
              children: [
                Expanded(
                  child: PdfPreview(
                    build: (format) => _pdfService.generatePdf(cv, cv.template),
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

                // Action panel
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black45,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Download
                      _buildBottomAction(
                        icon: Icons.download,
                        label: 'Download',
                        isLoading: _isDownloading,
                        onTap: () => _handleDownloadAndUpload(cv, user.uid),
                      ),
                      // Edit
                      _buildBottomAction(
                        icon: Icons.edit_note,
                        label: 'Edit',
                        onTap: () => _showEditBottomSheet(cv, user.uid),
                      ),
                      // Pro sharing placeholder
                      if (user.isPro)
                        _buildBottomAction(
                          icon: Icons.share,
                          label: 'Share',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sharing enabled for PRO members!')),
                            );
                          },
                        ),
                    ],
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
