import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/gradient_background.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _roleController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _roleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Resume Details'),
      ),
      body: GradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter Job Information',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gemini AI will use this information to optimize your resume.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _roleController,
                labelText: 'Target Job Role',
                hintText: 'e.g. Senior Flutter Developer',
                prefixIcon: Icons.work_outline,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _descriptionController,
                labelText: 'Job Description (Optional)',
                hintText: 'Paste the job requirements or details here...',
                prefixIcon: Icons.description_outlined,
                maxLines: 5,
              ),
              const SizedBox(height: 40),
              CustomButton(
                text: 'Generate Resume',
                onPressed: () {
                  context.go('/cv/generating');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
