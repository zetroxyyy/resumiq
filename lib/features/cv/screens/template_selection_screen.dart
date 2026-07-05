import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../auth/providers/auth_provider.dart';

class TemplateSelectionScreen extends ConsumerStatefulWidget {
  final String cvId;

  const TemplateSelectionScreen({
    super.key,
    required this.cvId,
  });

  @override
  ConsumerState<TemplateSelectionScreen> createState() => _TemplateSelectionScreenState();
}

class _TemplateSelectionScreenState extends ConsumerState<TemplateSelectionScreen> {
  String? _selectedTemplate;
  bool _isSaving = false;

  final List<TemplateItemData> _templates = [
    const TemplateItemData(
      name: 'Normal',
      description: 'Clean minimalist layout — classic and professional',
      isPremium: false,
      previewColor: Color(0xFFE2E8F0),
    ),
    const TemplateItemData(
      name: 'Modern',
      description: 'Vibrant modern layout with side panels and colored headers',
      isPremium: true,
      previewColor: Color(0xFF3B82F6),
    ),
    const TemplateItemData(
      name: 'Nepal-Saudi',
      description: 'Format tailored for Saudi Arabia job market standards',
      isPremium: true,
      previewColor: Color(0xFF009900),
    ),
    const TemplateItemData(
      name: 'Nepal-Qatar',
      description: 'Format tailored for Qatar job market standards',
      isPremium: true,
      previewColor: Color(0xFF8B0000),
    ),
    const TemplateItemData(
      name: 'Nepal-Malaysia',
      description: 'Format tailored for Malaysia job market standards',
      isPremium: true,
      previewColor: Color(0xFFCC0001),
    ),
    const TemplateItemData(
      name: 'Nepal-Japan',
      description: 'Format tailored for Japan job market standards',
      isPremium: true,
      previewColor: Color(0xFFBC002D),
    ),
    const TemplateItemData(
      name: 'Nepal-South Korea',
      description: 'Format tailored for South Korea job market standards',
      isPremium: true,
      previewColor: Color(0xFF003478),
    ),
  ];

  void _handleSelect(TemplateItemData template, bool isPro) {
    if (template.isPremium && !isPro) {
      _showUpgradeBottomSheet();
      return;
    }

    setState(() {
      _selectedTemplate = template.name;
    });
  }

  void _showUpgradeBottomSheet() {
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
                  'Unlock Premium Templates',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Upgrade to Resumiq Pro to unlock Europass, Professional, Modern, and specialized country layouts that double your hiring chances.",
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

  Future<void> _confirmTemplate() async {
    if (_selectedTemplate == null) return;

    setState(() {
      _isSaving = true;
    });

    final user = ref.read(authProvider);
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cvs')
            .doc(widget.cvId)
            .update({'template': _selectedTemplate});

        if (mounted) {
          context.go('/cv/preview/${widget.cvId}?template=$_selectedTemplate');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save template selection: $e')),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final isPro = user?.isPro ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Template'),
        automaticallyImplyLeading: false, // User must choose a template to proceed
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Select a style that represents you',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      final isSelected = _selectedTemplate == template.name;
                      final isLocked = template.isPremium && !isPro;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _handleSelect(template, isPro),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Styled Container acting as preview thumbnail
                                Expanded(
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: TemplateThumbnail(templateName: template.name),
                                      ),
                                      if (isLocked)
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.lock,
                                              size: 14,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ),
                                      if (isLocked)
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'PRO',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  template.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Use This Template',
                  isLoading: _isSaving,
                  onPressed: _selectedTemplate != null ? _confirmTemplate : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TemplateItemData {
  final String name;
  final String description;
  final bool isPremium;
  final Color previewColor;

  const TemplateItemData({
    required this.name,
    required this.description,
    required this.isPremium,
    required this.previewColor,
  });
}

class TemplateThumbnail extends StatelessWidget {
  final String templateName;

  const TemplateThumbnail({
    super.key,
    required this.templateName,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = templateName.toLowerCase();
    if (normalized.startsWith('nepal')) {
      // Nepal flag-themed thumbnail (covers Nepal-Saudi, Nepal-Qatar, etc.)
      return Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 2, color: const Color(0xFFDC143C)),
            Container(height: 1, color: const Color(0xFF003893)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 35, height: 5, color: Colors.black)),
                        const SizedBox(height: 8),
                        _buildTableRow(),
                        const SizedBox(height: 4),
                        _buildTableRow(),
                        const SizedBox(height: 8),
                        _buildLines(crossAlign: CrossAxisAlignment.start, color: Colors.black38),
                      ],
                    ),
                    Positioned(
                      top: 10,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 22,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black38, style: BorderStyle.solid),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Photo', style: TextStyle(fontSize: 4, color: Colors.black38)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (normalized == 'modern') {
      return Container(
        color: Colors.white,
        child: Row(
          children: [
            Container(
              width: 16,
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Column(
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6C63FF))),
                  const SizedBox(height: 8),
                  Container(width: 8, height: 2, color: Colors.black38),
                  const SizedBox(height: 3),
                  Container(width: 8, height: 2, color: Colors.black38),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 30, height: 5, color: const Color(0xFF6C63FF)),
                    const SizedBox(height: 8),
                    _buildLines(crossAlign: CrossAxisAlignment.start, color: Colors.black38),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Normal / default clean thumbnail
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 6, color: const Color(0xFF1A1A2E)),
            const SizedBox(height: 3),
            Container(width: 60, height: 2, color: Colors.black26),
            const SizedBox(height: 6),
            Container(height: 1, color: Colors.black12),
            const SizedBox(height: 8),
            _buildLines(crossAlign: CrossAxisAlignment.start, color: Colors.black38),
          ],
        ),
      );
    }
  }

  Widget _buildLines({required CrossAxisAlignment crossAlign, required Color color}) {
    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Container(width: 50, height: 2, color: color),
        const SizedBox(height: 3),
        Container(width: 70, height: 2, color: color),
        const SizedBox(height: 3),
        Container(width: 40, height: 2, color: color),
      ],
    );
  }

  Widget _buildTableRow() {
    return Row(
      children: [
        Container(width: 15, height: 2, color: Colors.black38),
        const SizedBox(width: 8),
        Container(width: 35, height: 2, color: Colors.black12),
      ],
    );
  }
}
