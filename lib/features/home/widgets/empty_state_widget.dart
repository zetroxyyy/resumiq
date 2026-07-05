import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_button.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final secondaryTextColor = theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: secondaryTextColor,
            ),
            const SizedBox(height: 24),
            Text(
              'No CVs yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first professional CV optimized with Gemini AI.\n\nNepal users seeking foreign employment are reminded to upload their passport copy or citizenship details during editing if needed.',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
              ),
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
