import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/payment_model.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Payment History',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        body: const Center(child: Text('Please log in to view history.')),
      );
    }

    final paymentsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payment History',
          style: TextStyle(
            fontFamily: 'Fraunces',
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: GradientBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: paymentsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No payment history yet',
                        style: TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upgrade to Pro to unlock unlimited generations, templates, and cover letters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          context.push('/upgrade');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        child: const Text(
                          'View Pro Plans',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final payment = PaymentModel.fromJson(data);

                final isMonthly = payment.plan.toLowerCase() == 'monthly';
                final planName = isMonthly ? 'Pro Monthly' : 'Pro Yearly';
                final amountNpr = (payment.amount / 100).toStringAsFixed(0);
                final formattedDate =
                    DateFormat('yyyy-MM-dd HH:mm').format(payment.createdAt);

                Color statusColor;
                switch (payment.status.toLowerCase()) {
                  case 'verified':
                    statusColor = const Color(0xFF4C9A6B); // success color
                    break;
                  case 'rejected':
                    statusColor = const Color(0xFFB5544A); // error color
                    break;
                  default:
                    statusColor = const Color(0xFFC48A3D); // pending / warning color
                }

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            planName,
                            style: TextStyle(
                              fontFamily: 'Fraunces',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              payment.status.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'NPR $amountNpr',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      if (payment.esewaTransactionId != null &&
                          payment.esewaTransactionId!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Divider(color: theme.colorScheme.outline, height: 1),
                        const SizedBox(height: 8),
                        Text(
                          'eSewa Txn ID: ${payment.esewaTransactionId}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
