import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _PaymentScreenState extends ConsumerState<PaymentScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  bool _isSubmitted = false;
  
  // For the checkmark animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String _merchantNumber = "9703511213"; // Dummy merchant eSewa number

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitPaymentReceipt(String transactionId) async {
    if (transactionId.trim().isEmpty) return;
    
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
      final isMonthly = widget.plan == 'monthly';
      final price = isMonthly ? AppConstants.proMonthlyPriceNpr : AppConstants.proYearlyPriceNpr;
      final amountInPaisa = price * 100;

      // 1. Create top-level /payments/{id}
      final paymentsRef = FirebaseFirestore.instance.collection('payments');
      final paymentId = paymentsRef.doc().id;

      final payment = PaymentModel(
        id: paymentId,
        userId: user.uid,
        amount: amountInPaisa,
        plan: widget.plan,
        status: 'pending',
        esewaTransactionId: transactionId.trim(),
        userGmail: user.email,
        createdAt: now,
      );

      // Save to top-level collection for admin
      await paymentsRef.doc(paymentId).set(payment.toJson());

      // Save to user subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payments')
          .doc(paymentId)
          .set(payment.toJson());

      setState(() {
        _isSubmitted = true;
        _isProcessing = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit receipt: $e')),
        );
      }
    }
  }

  void _showTransactionIdSheet() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Confirm Your Payment',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open eSewa → Transactions → copy the ID',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'eSewa Transaction ID',
                    hintText: 'e.g. 8AB123456C',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the Transaction ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open eSewa app → History → tap your payment → copy Transaction ID',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(context);
                      _submitPaymentReceipt(controller.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    final isMonthly = widget.plan == 'monthly';
    final price = isMonthly ? AppConstants.proMonthlyPriceNpr : AppConstants.proYearlyPriceNpr;
    final user = ref.watch(authProvider);

    if (_isSubmitted) {
      return Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green, width: 3),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.green,
                          size: 64,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Payment Submitted! ✅',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "We'll verify your payment within a few hours and activate your Pro subscription. You'll see the Pro badge appear on your home screen once verified.",
                        style: TextStyle(color: Colors.white70, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () => context.go('/home'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: GradientBackground(
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Order Summary Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Summary',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Resumind Pro - ${isMonthly ? "Monthly" : "Yearly"}'),
                                Text(Formatters.formatCurrency(price)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  Formatters.formatCurrency(price),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // How to Pay Title
                    const Text(
                      'How to Pay',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 16),

                    // Step 1 Card
                    _buildStepCard(
                      number: "1",
                      title: "Open eSewa on your phone",
                    ),
                    const SizedBox(height: 12),

                    // Step 2 Card (with QR)
                    _buildStepCard(
                      number: "2",
                      title: "Scan this QR code and send the exact amount",
                      content: Column(
                        children: [
                          const SizedBox(height: 16),
                          Container(
                            width: 250,
                            height: 250,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.asset(
                              'assets/images/esewa_qr.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _merchantNumber,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.deepPurpleAccent),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _merchantNumber));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('eSewa number copied')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Step 3 Card (User Gmail Remarks)
                    _buildStepCard(
                      number: "3",
                      title: "Add your Gmail in the payment remarks",
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user?.email ?? '',
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 20, color: Colors.deepPurpleAccent),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: user?.email ?? ''));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Gmail copied')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This helps us verify your payment faster',
                            style: TextStyle(fontSize: 11, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Step 4 Card
                    _buildStepCard(
                      number: "4",
                      title: "Tap 'I\'ve Paid' below after completing payment",
                    ),
                    const SizedBox(height: 32),

                    // Submit Buttons
                    ElevatedButton(
                      onPressed: _showTransactionIdSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "I've Paid",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStepCard({
    required String number,
    required String title,
    Widget? content,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.deepPurpleAccent,
                  child: Text(
                    number,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            if (content != null) content,
          ],
        ),
      ),
    );
  }
}
