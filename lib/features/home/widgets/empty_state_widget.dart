import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_button.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium Layered Geometric Illustration
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: 0.785, // 45 degrees
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.1),
                            theme.colorScheme.secondary.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: 0.392, // 22.5 degrees
                    child: Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.secondary.withOpacity(0.15),
                            theme.colorScheme.primary.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No CVs yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your first professional CV optimized with Gemini AI.\n\nNepal users seeking foreign employment are reminded to upload their passport copy or citizenship details during editing if needed.',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Create your first CV',
              onPressed: () => context.push('/cv/input'),
            ),
          ],
        ),
      ),
    );
  }
}
