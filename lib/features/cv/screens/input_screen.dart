import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/pulsing_mic_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cv_provider.dart';

class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  final _infoController = TextEditingController();
  final _jobController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isJobExpanded = false;
  String _selectedFormat = 'Standard';
  String? _inlineError;
  bool _atsOptimized = false;

  final List<String> _formats = [
    'Standard',
    'Europass',
    'Modern',
    'Nepal-Saudi',
    'Nepal-Qatar',
    'Nepal-Malaysia',
    'Nepal-Japan',
    'Nepal-South Korea',
  ];

  final SpeechToText _speech = SpeechToText();
  bool _isListeningInfo = false;
  bool _isListeningJob = false;
  bool _hasMicPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
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
            'Resumind needs access to your microphone to enable voice typing. Please enable it in the app settings.',
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
    _jobController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _validateAndSubmit() {
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

    // 3. Save input values to Riverpod provider & route to Generating screen
    ref.read(cvInputProvider.notifier).state = CvInputState(
      rawInput: rawInput,
      format: _selectedFormat,
      jobDescription: _isJobExpanded && _jobController.text.trim().isNotEmpty
          ? _jobController.text.trim()
          : null,
      atsOptimized: _atsOptimized,
    );

    context.go('/cv/generating');
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
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your CV'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Part 4: Permission Card
                if (!_hasMicPermission) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Text('🎤', style: TextStyle(fontSize: 24)),
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

                // Part 1: Language selection and Voice Button
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

                Stack(
                  children: [
                    TextFormField(
                      controller: _infoController,
                      minLines: 6,
                      maxLines: 12,
                      keyboardType: TextInputType.multiline,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type your experiences here...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _inlineError != null ? Colors.redAccent : Colors.white10,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
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
                          color: _infoController.text.length < 50 ? Colors.white38 : Colors.greenAccent,
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

                // Section: Tailor for a Job (Optional)
                const SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    title: const Text('Tailor for a Job? (Optional)'),
                    subtitle: const Text(
                      'AI will customize your CV for this specific role',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _isJobExpanded = expanded;
                      });
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _jobController,
                                labelText: 'Job Description or URL',
                                hintText: 'Paste target requirements or job detail here...',
                                prefixIcon: Icons.description_outlined,
                                maxLines: 5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                if (_isListeningJob)
                                  const ListeningLabel(),
                                const SizedBox(height: 8),
                                PulsingMicButton(
                                  isListening: _isListeningJob,
                                  onTap: () {
                                    _handleMicAction(() {
                                      if (_isListeningJob) {
                                        _stopListening(onStop: () => setState(() => _isListeningJob = false));
                                      } else {
                                        setState(() => _isListeningJob = true);
                                        _startListening(
                                          controller: _jobController,
                                          onStop: () => setState(() => _isListeningJob = false),
                                        );
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Section: CV Format
                const SizedBox(height: 24),
                Text(
                  'CV Format',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _formats.length,
                    itemBuilder: (context, index) {
                      final format = _formats[index];
                      final isSelected = _selectedFormat == format;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(format),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFormat = format;
                              });
                            }
                          },
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Section: ATS Optimization
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Optimize for ATS',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 20, color: Colors.white60),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('What is ATS?'),
                            content: const Text(
                              'Most companies use software to filter CVs before a human reads them.\n\n'
                              'Enabling this creates a plain-text version of your CV that passes '
                              'these filters — no columns, tables, or graphics.'
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const Spacer(),
                    Switch(
                      value: (user?.isPro ?? false) ? _atsOptimized : false,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (value) {
                        final isPro = user?.isPro ?? false;
                        if (!isPro) {
                          _showUpgradePrompt('Optimize for ATS');
                        } else {
                          setState(() {
                            _atsOptimized = value;
                          });
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                CustomButton(
                  text: 'Generate CV',
                  onPressed: _validateAndSubmit,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
