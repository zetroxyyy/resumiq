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
    const FeatureRow('2 Free CV Generations / month', true, true),
    const FeatureRow('Detailed AI Scores & Suggestions', true, true),
    const FeatureRow('Granular CV Editor & References', true, true),
    const FeatureRow('Full-resolution Photo (with BG removal)', false, true),
    const FeatureRow('Page Attachment Uploads (Passport, Citizenship, etc.)', false, true),
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
                Text(
                  'Unlock Resumiq Pro',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Build unlimited professional CVs',
                  style: TextStyle(color: theme.colorScheme.secondary, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Feature comparison table card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outline, width: 1.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold))),
                            SizedBox(width: 48, child: Text('Free', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary))),
                            SizedBox(width: 48, child: Text('Pro', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary))),
                          ],
                        ),
                        const Divider(),
                        ..._features.map((feature) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(child: Text(feature.name, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.8)))),
                                  SizedBox(
                                    width: 48,
                                    child: feature.free
                                        ? Icon(Icons.check_circle_outline, color: theme.brightness == Brightness.dark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B), size: 18)
                                        : Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 18),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: feature.pro
                                        ? Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 18)
                                        : Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 18),
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

                // Continue Pay with eSewa Button
                CustomButton(
                  text: 'Pay with eSewa',
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 2.0,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          color: theme.colorScheme.surface,
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
                        color: theme.brightness == Brightness.dark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        savingText,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    Formatters.formatCurrency(price),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: theme.colorScheme.primary),
                  ),
                  Text('per $period', style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary)),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary.withOpacity(0.7))),
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
                    borderRadius: BorderRadius.circular(4),
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
