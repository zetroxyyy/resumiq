import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../models/cv_model.dart';
import '../providers/cv_provider.dart';
import '../services/photo_service.dart';

class CvEditorScreen extends ConsumerStatefulWidget {
  final String cvId;

  const CvEditorScreen({super.key, required this.cvId});

  @override
  ConsumerState<CvEditorScreen> createState() => _CvEditorScreenState();
}

class _CvEditorScreenState extends ConsumerState<CvEditorScreen> {
  // ─── Services ────────────────────────────────────────────────────────────────
  final PhotoService _photoService = PhotoService();
  final ImagePicker _imagePicker = ImagePicker();

  // ─── Save state ───────────────────────────────────────────────────────────────
  bool _isSaving = false;
  bool _isPhotoLoading = false;

  // ─── Photo / Passport ────────────────────────────────────────────────────────
  String? _photoUrl;
  String? _passportUrl;

  // ─── Personal Info ────────────────────────────────────────────────────────────
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _linkedinController;
  late TextEditingController _portfolioController;

  // ─── Summary ──────────────────────────────────────────────────────────────────
  late TextEditingController _summaryController;

  // ─── Work Experience ─────────────────────────────────────────────────────────
  // Each entry: Map with keys: company, role, startDate, endDate, current, responsibilities (List<String>)
  List<Map<String, dynamic>> _workExperience = [];
  // Controllers per entry, per field:
  // _workControllers[i] = {company, role, startDate, endDate}
  List<Map<String, TextEditingController>> _workControllers = [];
  // Responsibility controllers per entry
  List<List<TextEditingController>> _respControllers = [];

  // ─── Education ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _education = [];
  List<Map<String, TextEditingController>> _eduControllers = [];

  // ─── Skills ──────────────────────────────────────────────────────────────────
  List<String> _technicalSkills = [];
  List<String> _softSkills = [];
  List<String> _languages = [];
  final _techSkillInput = TextEditingController();
  final _softSkillInput = TextEditingController();
  final _langSkillInput = TextEditingController();

  // ─── Certifications ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _certifications = [];
  List<Map<String, TextEditingController>> _certControllers = [];

  // ─── Projects ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, TextEditingController>> _projControllers = [];
  List<List<String>> _projTechStacks = [];
  List<TextEditingController> _projTechInputs = [];

  // ─── Achievements ────────────────────────────────────────────────────────────
  List<String> _achievements = [];
  List<TextEditingController> _achieveControllers = [];

  // ─── CV Meta ─────────────────────────────────────────────────────────────────
  CvModel? _cvModel;

  @override
  void initState() {
    super.initState();
    // Initialize with empty controllers — data loaded in didChangeDependencies
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _locationController = TextEditingController();
    _linkedinController = TextEditingController();
    _portfolioController = TextEditingController();
    _summaryController = TextEditingController();
  }

  void _loadFromCv(CvModel cv) {
    if (_cvModel?.id == cv.id && _cvModel?.updatedAt == cv.updatedAt) return;
    _cvModel = cv;

    final content = cv.generatedContent;
    final personalInfo = content['personalInfo'] as Map<String, dynamic>? ?? {};

    _fullNameController.text = personalInfo['fullName'] as String? ?? '';
    _emailController.text = personalInfo['email'] as String? ?? '';
    _phoneController.text = personalInfo['phone'] as String? ?? '';
    _locationController.text = personalInfo['location'] as String? ?? '';
    _linkedinController.text = personalInfo['linkedIn'] as String? ?? '';
    _portfolioController.text = personalInfo['portfolio'] as String? ?? '';
    _summaryController.text = content['summary'] as String? ?? '';

    _photoUrl = cv.photoUrl;
    _passportUrl = cv.passportUrl;

    // Work Experience
    _disposeWorkControllers();
    final workList = content['workExperience'] as List? ?? [];
    _workExperience = workList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _initWorkControllers();

    // Education
    _disposeEduControllers();
    final eduList = content['education'] as List? ?? [];
    _education = eduList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _initEduControllers();

    // Skills
    final skillsMap = content['skills'] as Map<String, dynamic>? ?? {};
    _technicalSkills = List<String>.from(skillsMap['technical'] as List? ?? []);
    _softSkills = List<String>.from(skillsMap['soft'] as List? ?? []);
    _languages = List<String>.from(skillsMap['languages'] as List? ?? []);

    // Certifications
    _disposeCertControllers();
    final certList = content['certifications'] as List? ?? [];
    _certifications = certList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _initCertControllers();

    // Projects
    _disposeProjControllers();
    final projList = content['projects'] as List? ?? [];
    _projects = projList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _initProjControllers();

    // Achievements
    _disposeAchieveControllers();
    final achList = content['achievements'] as List? ?? [];
    _achievements = achList.map((e) => e.toString()).toList();
    _initAchieveControllers();
  }

  // ─── Controller Init/Dispose ─────────────────────────────────────────────────

  void _initWorkControllers() {
    _workControllers = _workExperience.map((e) => {
      'company': TextEditingController(text: e['company'] as String? ?? ''),
      'role': TextEditingController(text: e['role'] as String? ?? ''),
      'startDate': TextEditingController(text: e['startDate'] as String? ?? ''),
      'endDate': TextEditingController(text: e['endDate'] as String? ?? ''),
    }).toList();

    _respControllers = _workExperience.map((e) {
      final resps = e['responsibilities'] as List? ?? [];
      return resps.map((r) => TextEditingController(text: r.toString())).toList();
    }).toList();
  }

  void _disposeWorkControllers() {
    for (final map in _workControllers) {
      for (final c in map.values) { c.dispose(); }
    }
    for (final list in _respControllers) {
      for (final c in list) { c.dispose(); }
    }
    _workControllers = [];
    _respControllers = [];
  }

  void _initEduControllers() {
    _eduControllers = _education.map((e) => {
      'institution': TextEditingController(text: e['institution'] as String? ?? ''),
      'degree': TextEditingController(text: e['degree'] as String? ?? ''),
      'field': TextEditingController(text: e['field'] as String? ?? ''),
      'startDate': TextEditingController(text: e['startDate'] as String? ?? ''),
      'endDate': TextEditingController(text: e['endDate'] as String? ?? ''),
      'grade': TextEditingController(text: e['grade'] as String? ?? ''),
    }).toList();
  }

  void _disposeEduControllers() {
    for (final map in _eduControllers) {
      for (final c in map.values) { c.dispose(); }
    }
    _eduControllers = [];
  }

  void _initCertControllers() {
    _certControllers = _certifications.map((e) => {
      'name': TextEditingController(text: e['name'] as String? ?? ''),
      'issuer': TextEditingController(text: e['issuer'] as String? ?? ''),
      'date': TextEditingController(text: e['date'] as String? ?? ''),
    }).toList();
  }

  void _disposeCertControllers() {
    for (final map in _certControllers) {
      for (final c in map.values) { c.dispose(); }
    }
    _certControllers = [];
  }

  void _initProjControllers() {
    _projControllers = _projects.map((e) => {
      'name': TextEditingController(text: e['name'] as String? ?? ''),
      'description': TextEditingController(text: e['description'] as String? ?? ''),
      'url': TextEditingController(text: e['url'] as String? ?? ''),
    }).toList();
    _projTechStacks = _projects.map((e) {
      final stack = e['techStack'] as List? ?? [];
      return stack.map((s) => s.toString()).toList();
    }).toList();
    _projTechInputs = List.generate(_projects.length, (_) => TextEditingController());
  }

  void _disposeProjControllers() {
    for (final map in _projControllers) {
      for (final c in map.values) { c.dispose(); }
    }
    for (final c in _projTechInputs) { c.dispose(); }
    _projControllers = [];
    _projTechStacks = [];
    _projTechInputs = [];
  }

  void _initAchieveControllers() {
    _achieveControllers = _achievements.map((a) => TextEditingController(text: a)).toList();
  }

  void _disposeAchieveControllers() {
    for (final c in _achieveControllers) { c.dispose(); }
    _achieveControllers = [];
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
    _disposeWorkControllers();
    _disposeEduControllers();
    _disposeCertControllers();
    _disposeProjControllers();
    _disposeAchieveControllers();
    _techSkillInput.dispose();
    _softSkillInput.dispose();
    _langSkillInput.dispose();
    super.dispose();
  }

  // ─── Save All ────────────────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnack('Session expired. Please sign in again.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build updated generatedContent
      final updatedContent = Map<String, dynamic>.from(_cvModel?.generatedContent ?? {});

      updatedContent['personalInfo'] = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'linkedIn': _linkedinController.text.trim(),
        'portfolio': _portfolioController.text.trim(),
      };

      updatedContent['summary'] = _summaryController.text.trim();

      updatedContent['workExperience'] = List.generate(_workControllers.length, (i) {
        final resps = _respControllers[i].map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
        return {
          'company': _workControllers[i]['company']!.text.trim(),
          'role': _workControllers[i]['role']!.text.trim(),
          'startDate': _workControllers[i]['startDate']!.text.trim(),
          'endDate': _workControllers[i]['endDate']!.text.trim(),
          'current': _workExperience[i]['current'] as bool? ?? false,
          'responsibilities': resps,
        };
      });

      updatedContent['education'] = List.generate(_eduControllers.length, (i) => {
        'institution': _eduControllers[i]['institution']!.text.trim(),
        'degree': _eduControllers[i]['degree']!.text.trim(),
        'field': _eduControllers[i]['field']!.text.trim(),
        'startDate': _eduControllers[i]['startDate']!.text.trim(),
        'endDate': _eduControllers[i]['endDate']!.text.trim(),
        'grade': _eduControllers[i]['grade']!.text.trim(),
      });

      updatedContent['skills'] = {
        'technical': _technicalSkills,
        'soft': _softSkills,
        'languages': _languages,
      };

      updatedContent['certifications'] = List.generate(_certControllers.length, (i) => {
        'name': _certControllers[i]['name']!.text.trim(),
        'issuer': _certControllers[i]['issuer']!.text.trim(),
        'date': _certControllers[i]['date']!.text.trim(),
      });

      updatedContent['projects'] = List.generate(_projControllers.length, (i) => {
        'name': _projControllers[i]['name']!.text.trim(),
        'description': _projControllers[i]['description']!.text.trim(),
        'url': _projControllers[i]['url']!.text.trim(),
        'techStack': _projTechStacks[i],
      });

      updatedContent['achievements'] = _achieveControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Save version snapshot before overwriting
      await saveVersion(
        uid: currentUser.uid,
        cvId: widget.cvId,
        generatedContent: Map<String, dynamic>.from(_cvModel?.generatedContent ?? {}),
        template: _cvModel?.template ?? 'clean',
        changedBy: 'granular_edit',
      );

      // Build update map
      final updateMap = <String, dynamic>{
        'generatedContent': updatedContent,
        'updatedAt': FieldValue.serverTimestamp(),
        'version': FieldValue.increment(1),
      };

      if (_photoUrl != null) {
        updateMap['photoUrl'] = _photoUrl;
      } else {
        updateMap['photoUrl'] = FieldValue.delete();
      }
      if (_passportUrl != null) {
        updateMap['passportUrl'] = _passportUrl;
      } else {
        updateMap['passportUrl'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('cvs')
          .doc(widget.cvId)
          .update(updateMap);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CV updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error saving CV: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Photo Methods ────────────────────────────────────────────────────────────

  Future<void> _pickPhoto({bool isPassport = false}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

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
                color: Colors.white24, borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isPassport ? 'Upload Passport' : 'Profile Photo',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    if (isPassport) {
      await _processPassport(File(picked.path), currentUser.uid);
    } else {
      await _processProfilePhoto(File(picked.path), currentUser.uid);
    }
  }

  Future<void> _processProfilePhoto(File imageFile, String userId) async {
    setState(() => _isPhotoLoading = true);
    try {
      final result = await _photoService.processAndUploadPhoto(
        imageFile: imageFile,
        userId: userId,
      );
      if (mounted) {
        setState(() {
          _photoUrl = result.url;
          _isPhotoLoading = false;
        });
        if (!result.usedBgRemoval) {
          _showSnack('Photo added without background removal');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPhotoLoading = false);
        _showSnack('Photo upload failed: $e');
      }
    }
  }

  Future<void> _processPassport(File imageFile, String userId) async {
    setState(() => _isPhotoLoading = true);
    try {
      final bytes = await imageFile.readAsBytes();
      final url = await _photoService.uploadPassport(bytes, userId);
      if (mounted) {
        setState(() {
          _passportUrl = url;
          _isPhotoLoading = false;
        });
        _showSnack('Passport uploaded successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPhotoLoading = false);
        _showSnack('Passport upload failed: $e');
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cvAsync = ref.watch(cvDetailProvider(widget.cvId));

    return cvAsync.when(
      data: (cv) {
        if (cv == null) {
          return const Scaffold(body: Center(child: Text('CV not found')));
        }
        // Load data only once or when CV changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFromCv(cv);
        });

        final isNepalTemplate = cv.template.toLowerCase().contains('nepal');

        return LoadingOverlay(
          isLoading: _isSaving,
          message: 'Saving your CV...',
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Edit CV'),
              actions: [
                TextButton.icon(
                  onPressed: _isSaving ? null : _saveAll,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save All'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // ─── Profile Photo Card ───────────────────────────────────────
                _buildPhotoCard(theme),
                const SizedBox(height: 12),

                // ─── Personal Info ─────────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Personal Info',
                  icon: Icons.person_outline,
                  initiallyExpanded: true,
                  children: [
                    CustomTextField(
                      controller: _fullNameController,
                      labelText: 'Full Name *',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _phoneController,
                      labelText: 'Phone',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _locationController,
                      labelText: 'Location',
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _linkedinController,
                      labelText: 'LinkedIn URL',
                      prefixIcon: Icons.link,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _portfolioController,
                      labelText: 'Portfolio URL',
                      prefixIcon: Icons.language,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Summary ───────────────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Summary',
                  icon: Icons.notes,
                  children: [
                    CustomTextField(
                      controller: _summaryController,
                      labelText: 'Professional Summary',
                      maxLines: 6,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Work Experience ───────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Work Experience',
                  icon: Icons.work_outline,
                  children: [
                    ..._buildWorkExperienceItems(theme),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _workExperience.add({
                          'company': '', 'role': '', 'startDate': '', 'endDate': '', 'current': false, 'responsibilities': [],
                        });
                        _workControllers.add({
                          'company': TextEditingController(),
                          'role': TextEditingController(),
                          'startDate': TextEditingController(),
                          'endDate': TextEditingController(),
                        });
                        _respControllers.add([]);
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Work Experience'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Education ─────────────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Education',
                  icon: Icons.school_outlined,
                  children: [
                    ..._buildEducationItems(theme),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _education.add({'institution': '', 'degree': '', 'field': '', 'startDate': '', 'endDate': '', 'grade': ''});
                        _eduControllers.add({
                          'institution': TextEditingController(),
                          'degree': TextEditingController(),
                          'field': TextEditingController(),
                          'startDate': TextEditingController(),
                          'endDate': TextEditingController(),
                          'grade': TextEditingController(),
                        });
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Education'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Skills ────────────────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Skills',
                  icon: Icons.psychology_outlined,
                  children: [
                    _buildSkillsSubSection(theme, 'Technical Skills', _technicalSkills, _techSkillInput, (v) {
                      setState(() { _technicalSkills.add(v); _techSkillInput.clear(); });
                    }, (i) => setState(() => _technicalSkills.removeAt(i))),
                    const Divider(height: 24),
                    _buildSkillsSubSection(theme, 'Soft Skills', _softSkills, _softSkillInput, (v) {
                      setState(() { _softSkills.add(v); _softSkillInput.clear(); });
                    }, (i) => setState(() => _softSkills.removeAt(i))),
                    const Divider(height: 24),
                    _buildSkillsSubSection(theme, 'Languages', _languages, _langSkillInput, (v) {
                      setState(() { _languages.add(v); _langSkillInput.clear(); });
                    }, (i) => setState(() => _languages.removeAt(i))),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Certifications ────────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Certifications',
                  icon: Icons.verified_outlined,
                  children: [
                    ..._buildCertificationItems(theme),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _certifications.add({'name': '', 'issuer': '', 'date': ''});
                        _certControllers.add({
                          'name': TextEditingController(),
                          'issuer': TextEditingController(),
                          'date': TextEditingController(),
                        });
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Certification'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Projects ──────────────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Projects',
                  icon: Icons.code_outlined,
                  children: [
                    ..._buildProjectItems(theme),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _projects.add({'name': '', 'description': '', 'url': '', 'techStack': []});
                        _projControllers.add({
                          'name': TextEditingController(),
                          'description': TextEditingController(),
                          'url': TextEditingController(),
                        });
                        _projTechStacks.add([]);
                        _projTechInputs.add(TextEditingController());
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Project'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Achievements ──────────────────────────────────────────────
                _buildSectionCard(
                  theme: theme,
                  title: 'Achievements',
                  icon: Icons.emoji_events_outlined,
                  children: [
                    ..._buildAchievementItems(theme),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _achievements.add('');
                        _achieveControllers.add(TextEditingController());
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Achievement'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── Passport Card (Nepal templates only) ──────────────────────
                if (isNepalTemplate) ...[
                  _buildPassportCard(theme),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  // ─── Section Card Builder ─────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  // ─── Photo Card ─────────────────────────────────────────────────────────────

  Widget _buildPhotoCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                  child: _photoUrl == null
                      ? Icon(Icons.person, size: 38, color: theme.colorScheme.primary.withOpacity(0.5))
                      : null,
                ),
                if (_isPhotoLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45, shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
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
                    'Profile Photo',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Background removed automatically',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isPhotoLoading ? null : () => _pickPhoto(),
                        icon: const Icon(Icons.camera_alt, size: 16),
                        label: Text(_photoUrl != null ? 'Change' : 'Add Photo'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (_photoUrl != null)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _photoUrl = null),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 13),
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Passport Card ───────────────────────────────────────────────────────────

  Widget _buildPassportCard(ThemeData theme) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.document_scanner_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Passport Copy',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Upload passport document (optional)',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const Text(
              'Will be added as the last page of your CV PDF',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            const SizedBox(height: 12),
            if (_passportUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _passportUrl!,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isPhotoLoading ? null : () => _pickPhoto(isPassport: true),
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(_passportUrl != null ? 'Replace Passport' : 'Upload Passport Photo'),
                ),
                if (_passportUrl != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _passportUrl = null),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Work Experience Items ────────────────────────────────────────────────────

  List<Widget> _buildWorkExperienceItems(ThemeData theme) {
    return List.generate(_workControllers.length, (i) {
      final isCurrent = _workExperience[i]['current'] as bool? ?? false;
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Experience ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    for (final c in _workControllers[i].values) { c.dispose(); }
                    for (final c in _respControllers[i]) { c.dispose(); }
                    _workExperience.removeAt(i);
                    _workControllers.removeAt(i);
                    _respControllers.removeAt(i);
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(controller: _workControllers[i]['company']!, labelText: 'Company'),
            const SizedBox(height: 10),
            CustomTextField(controller: _workControllers[i]['role']!, labelText: 'Job Title / Role'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: CustomTextField(controller: _workControllers[i]['startDate']!, labelText: 'Start Date')),
                const SizedBox(width: 10),
                Expanded(child: CustomTextField(
                  controller: _workControllers[i]['endDate']!,
                  labelText: 'End Date',
                  enabled: !isCurrent,
                )),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: isCurrent,
                  onChanged: (v) => setState(() => _workExperience[i]['current'] = v ?? false),
                ),
                const Text('Currently working here'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Responsibilities', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ..._buildResponsibilityItems(i, theme),
            TextButton.icon(
              onPressed: () => setState(() {
                _respControllers[i].add(TextEditingController());
              }),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Responsibility'),
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildResponsibilityItems(int workIdx, ThemeData theme) {
    return List.generate(_respControllers[workIdx].length, (j) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _respControllers[workIdx][j],
                labelText: 'Responsibility ${j + 1}',
                maxLines: 2,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
              onPressed: () => setState(() {
                _respControllers[workIdx][j].dispose();
                _respControllers[workIdx].removeAt(j);
              }),
            ),
          ],
        ),
      );
    });
  }

  // ─── Education Items ──────────────────────────────────────────────────────────

  List<Widget> _buildEducationItems(ThemeData theme) {
    return List.generate(_eduControllers.length, (i) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Education ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    for (final c in _eduControllers[i].values) { c.dispose(); }
                    _education.removeAt(i);
                    _eduControllers.removeAt(i);
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(controller: _eduControllers[i]['institution']!, labelText: 'Institution'),
            const SizedBox(height: 10),
            CustomTextField(controller: _eduControllers[i]['degree']!, labelText: 'Degree'),
            const SizedBox(height: 10),
            CustomTextField(controller: _eduControllers[i]['field']!, labelText: 'Field of Study'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: CustomTextField(controller: _eduControllers[i]['startDate']!, labelText: 'Start Year')),
                const SizedBox(width: 10),
                Expanded(child: CustomTextField(controller: _eduControllers[i]['endDate']!, labelText: 'End Year')),
              ],
            ),
            const SizedBox(height: 10),
            CustomTextField(controller: _eduControllers[i]['grade']!, labelText: 'Grade / GPA (optional)'),
          ],
        ),
      );
    });
  }

  // ─── Skills Sub-Section ───────────────────────────────────────────────────────

  Widget _buildSkillsSubSection(
    ThemeData theme,
    String label,
    List<String> skills,
    TextEditingController input,
    ValueChanged<String> onAdd,
    ValueChanged<int> onRemove,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ...List.generate(skills.length, (i) => Chip(
              label: Text(skills[i], style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => onRemove(i),
              visualDensity: VisualDensity.compact,
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: input,
                decoration: InputDecoration(
                  hintText: 'Add $label...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.white38),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) onAdd(v.trim());
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle, color: theme.colorScheme.primary),
              onPressed: () {
                if (input.text.trim().isNotEmpty) onAdd(input.text.trim());
              },
            ),
          ],
        ),
      ],
    );
  }

  // ─── Certifications Items ─────────────────────────────────────────────────────

  List<Widget> _buildCertificationItems(ThemeData theme) {
    return List.generate(_certControllers.length, (i) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Certification ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    for (final c in _certControllers[i].values) { c.dispose(); }
                    _certifications.removeAt(i);
                    _certControllers.removeAt(i);
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(controller: _certControllers[i]['name']!, labelText: 'Certification Name'),
            const SizedBox(height: 10),
            CustomTextField(controller: _certControllers[i]['issuer']!, labelText: 'Issuing Organization'),
            const SizedBox(height: 10),
            CustomTextField(controller: _certControllers[i]['date']!, labelText: 'Date'),
          ],
        ),
      );
    });
  }

  // ─── Projects Items ───────────────────────────────────────────────────────────

  List<Widget> _buildProjectItems(ThemeData theme) {
    return List.generate(_projControllers.length, (i) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Project ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => setState(() {
                    for (final c in _projControllers[i].values) { c.dispose(); }
                    _projTechInputs[i].dispose();
                    _projects.removeAt(i);
                    _projControllers.removeAt(i);
                    _projTechStacks.removeAt(i);
                    _projTechInputs.removeAt(i);
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CustomTextField(controller: _projControllers[i]['name']!, labelText: 'Project Name'),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _projControllers[i]['description']!,
              labelText: 'Description',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            const Text('Tech Stack', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...List.generate(_projTechStacks[i].length, (j) => Chip(
                  label: Text(_projTechStacks[i][j], style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _projTechStacks[i].removeAt(j)),
                  visualDensity: VisualDensity.compact,
                )),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _projTechInputs[i],
                    decoration: const InputDecoration(
                      hintText: 'Add technology...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.white38),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        setState(() { _projTechStacks[i].add(v.trim()); _projTechInputs[i].clear(); });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle, color: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    final v = _projTechInputs[i].text.trim();
                    if (v.isNotEmpty) {
                      setState(() { _projTechStacks[i].add(v); _projTechInputs[i].clear(); });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            CustomTextField(controller: _projControllers[i]['url']!, labelText: 'Project URL (optional)'),
          ],
        ),
      );
    });
  }

  // ─── Achievements Items ───────────────────────────────────────────────────────

  List<Widget> _buildAchievementItems(ThemeData theme) {
    return List.generate(_achieveControllers.length, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: CustomTextField(
                controller: _achieveControllers[i],
                labelText: 'Achievement ${i + 1}',
                maxLines: 2,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
              onPressed: () => setState(() {
                _achieveControllers[i].dispose();
                _achievements.removeAt(i);
                _achieveControllers.removeAt(i);
              }),
            ),
          ],
        ),
      );
    });
  }
}
