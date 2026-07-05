import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/update_service.dart';
import '../../../core/widgets/gradient_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  double _opacity = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start animation on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    // Wait 2.5 seconds, then trigger GoRouter redirect validation
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/login');
      }
      // After navigation settles, silently check for updates (3 s total)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          UpdateService.checkForUpdate(context);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeIn,
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: 24),
              AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeIn,
                child: Column(
                  children: [
                    Text(
                      'Resumiq',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your career, powered by AI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
