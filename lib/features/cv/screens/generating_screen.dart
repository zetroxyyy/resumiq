import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/gradient_background.dart';
import '../providers/cv_provider.dart';

class GeneratingScreen extends ConsumerStatefulWidget {
  const GeneratingScreen({super.key});

  @override
  ConsumerState<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends ConsumerState<GeneratingScreen> {
  int _messageIndex = 0;
  double _opacity = 1.0;
  Timer? _rotationTimer;

  final List<String> _statusMessages = [
    'Reading your information...',
    'Understanding your experience...',
    'Structuring your career story...',
    'Applying professional formatting...',
    'Scoring your CV...',
    'Almost done...',
  ];

  @override
  void initState() {
    super.initState();

    // 1. Trigger Gemini CV Generation async
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cvGenerationProvider.notifier).generate(context);
    });

    // 2. Setup status message rotation timer
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _opacity = 0.0;
        });

        // Fade back in with the next message
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _messageIndex = (_messageIndex + 1) % _statusMessages.length;
              _opacity = 1.0;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Building Your AI Resume',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40, // Height anchor to prevent layout shifts
                  child: AnimatedOpacity(
                    opacity: _opacity,
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _statusMessages[_messageIndex],
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
