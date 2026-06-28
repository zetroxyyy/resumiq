import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_background.dart';

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  String _selectedPlan = 'yearly';

  final List<FeatureRow> _features = [
    const FeatureRow('Unlimited AI Generations', false, true),
    const FeatureRow('Unlock all 8 Templates', false, true),
    const FeatureRow('Premium PDF Layout Styles', false, true),
    const FeatureRow('Detailed AI Scores & Suggestions', false, true),
    const FeatureRow('Draggable Live CV Editors', false, true),
    const FeatureRow('Shareable Resumes (Phase 3)', false, true),
    const FeatureRow('Priority Support', false, true),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Plan'),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Title with Gradient look (using ShaderMask)
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.purpleAccent, Colors.blueAccent],
                  ).createShader(bounds),
                  child: Text(
                    'Unlock Resumind Pro ⚡',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Build unlimited professional CVs',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Feature comparison table card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Expanded(child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 48, child: Text('Free', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white60))),
                            SizedBox(width: 48, child: Text('Pro', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                          ],
                        ),
                        const Divider(),
                        ..._features.map((feature) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                  children: [
                                    Expanded(child: Text(feature.name, style: const TextStyle(fontSize: 13, color: Colors.white70))),
                                  SizedBox(
                                    width: 48,
                                    child: feature.free
                                        ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                                        : const Icon(Icons.cancel, color: Colors.red, size: 18),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: feature.pro
                                        ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 18)
                                        : const Icon(Icons.cancel, color: Colors.red, size: 18),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Selected plans side by side
                Row(
                  children: [
                    // Monthly Card
                    Expanded(
                      child: _buildSelectablePlanCard(
                        title: 'Monthly',
                        price: AppConstants.proMonthlyPriceNpr,
                        period: 'month',
                        planId: 'monthly',
                        subtitle: 'Flexible access',
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Yearly Card
                    Expanded(
                      child: _buildSelectablePlanCard(
                        title: 'Yearly',
                        price: AppConstants.proYearlyPriceNpr,
                        period: 'year',
                        planId: 'yearly',
                        badgeText: 'MOST POPULAR',
                        savingText: 'Save 33%',
                        subtitle: 'Best value deal',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Continue Khalti Button
                CustomButton(
                  text: 'Continue with Khalti',
                  onPressed: () {
                    context.push('/payment/$_selectedPlan');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectablePlanCard({
    required String title,
    required num price,
    required String period,
    required String planId,
    required String subtitle,
    String? badgeText,
    String? savingText,
  }) {
    final isSelected = _selectedPlan == planId;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlan = planId;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            width: 2.5,
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          ),
          color: Colors.white.withOpacity(isSelected ? 0.08 : 0.03),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (savingText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        savingText,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.formatCurrency(price),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.blueAccent),
                  ),
                  Text('per $period', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white38)),
                ],
              ),
            ),
            if (badgeText != null)
              Positioned(
                top: -12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FeatureRow {
  final String name;
  final bool free;
  final bool pro;

  const FeatureRow(this.name, this.free, this.pro);
}
