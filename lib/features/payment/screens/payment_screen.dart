import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:khalti_flutter/khalti_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/payment_model.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String plan;

  const PaymentScreen({
    super.key,
    required this.plan,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PreviewKhaltiPaymentLogo extends StatelessWidget {
  const _PreviewKhaltiPaymentLogo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF5C2D91),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          'K',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isProcessing = false;

  Future<void> _handlePaymentSuccess(String token, String transactionId, int amountInPaisa) async {
    setState(() => _isProcessing = true);
    final user = ref.read(authProvider);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User session not found.')),
      );
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final now = DateTime.now();
      final durationDays = widget.plan == 'yearly' ? 365 : 30;
      final expiryDate = now.add(Duration(days: durationDays));

      final paymentCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payments');
      final paymentDocRef = paymentCollection.doc();

      final payment = PaymentModel(
        id: paymentDocRef.id,
        userId: user.uid,
        amount: amountInPaisa,
        plan: widget.plan,
        status: 'completed',
        khaltiToken: token,
        khaltiTransactionId: transactionId,
        createdAt: now,
      );

      // 1. Create PaymentModel in Firestore
      await paymentDocRef.set(payment.toJson());

      // 2. Update User Document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'tier': 'pro',
        'tierGrantedBy': 'payment',
        'tierExpiresAt': Timestamp.fromDate(expiryDate),
      });

      // Update local state if needed (or auth synchronizer handles it)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Pro! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete payment transaction: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _payWithKhalti(int price) {
    final amountInPaisa = price * 100;
    final isMonthly = widget.plan == 'monthly';

    try {
      final config = PaymentConfig(
        amount: amountInPaisa,
        productIdentity: 'resumind-pro-${widget.plan}',
        productName: 'Resumind Pro - ${isMonthly ? "Monthly" : "Yearly"}',
      );

      KhaltiScope.of(context).pay(
        config: config,
        onSuccess: (PaymentSuccessModel success) async {
          await _handlePaymentSuccess(
            success.idx,
            success.token,
            success.amount,
          );
        },
        onFailure: (PaymentFailureModel failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment Failed: ${failure.message}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
        onCancel: () {
          if (mounted) {
            context.pop(); // Pop back to upgrade screen
          }
        },
      );
    } catch (e) {
      // In case we are running in an environment where KhaltiScope throws an error (e.g. desktop/unsupported browser)
      // display a dialog giving them options to complete the payment for development & simulation
      _showDevSandboxPaymentDialog(amountInPaisa);
    }
  }

  void _showDevSandboxPaymentDialog(int amountInPaisa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khalti Dev Sandbox'),
        content: const Text(
          'We detected an environment without standard mobile Khalti support (e.g. Simulator/Desktop). Would you like to simulate a successful payment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handlePaymentSuccess('mock_token', 'mock_txn_id', amountInPaisa);
            },
            child: const Text('Simulate Success'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMonthly = widget.plan == 'monthly';
    final price = isMonthly
        ? AppConstants.proMonthlyPriceNpr
        : AppConstants.proYearlyPriceNpr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Order Summary',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Resumind Pro - ${isMonthly ? "Monthly" : "Yearly"}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(Formatters.formatCurrency(price)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(price),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _isProcessing ? null : () => _payWithKhalti(price),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C2D91),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PreviewKhaltiPaymentLogo(),
                          SizedBox(width: 12),
                          Text(
                            'Pay with Khalti',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
