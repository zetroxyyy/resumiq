import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../models/user_model.dart';
import '../../cv/models/cv_model.dart';
import '../../../models/payment_model.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  Future<void> _updateUserTier({
    required String tier,
    required String? grantedBy,
    required DateTime? expiresAt,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'tier': tier,
        'tierGrantedBy': grantedBy,
        'tierExpiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update access control: $e')),
        );
      }
    }
  }

  void _showConfirmDialog({
    required String actionName,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Action'),
        content: Text('Are you sure you want to perform this operation: "$actionName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (pickedDate != null) {
      _showConfirmDialog(
        actionName: 'Grant Pro until ${DateFormat('yyyy-MM-dd').format(pickedDate)}',
        onConfirm: () => _updateUserTier(
          tier: 'pro',
          grantedBy: 'admin',
          expiresAt: pickedDate,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Streams for real-time reactive displays
    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .map((snap) => snap.exists && snap.data() != null
            ? UserModel.fromJson({...snap.data()!, 'uid': snap.id})
            : null);

    final cvsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cvs')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CvModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());

    final paymentsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PaymentModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());

    return StreamBuilder<UserModel?>(
      stream: userStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final targetUser = userSnapshot.data;
        if (targetUser == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('User Detail')),
            body: const Center(child: Text('User profile not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(targetUser.name),
          ),
          body: GradientBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top user card summary
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: targetUser.photoUrl.isNotEmpty
                                  ? NetworkImage(targetUser.photoUrl)
                                  : null,
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                              child: targetUser.photoUrl.isEmpty
                                  ? Text(
                                      targetUser.name.isNotEmpty ? targetUser.name[0].toUpperCase() : 'U',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              targetUser.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(targetUser.email, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                            const SizedBox(height: 16),
                            const Divider(),
                            _buildDetailRow('User Tier', targetUser.isPro ? 'Pro Subscription' : 'Free Tier'),
                            _buildDetailRow('Runs This Month', '${targetUser.generationsThisMonth} Generations'),
                            _buildDetailRow(
                              'Created At',
                              DateFormat('yyyy-MM-dd').format(targetUser.createdAt),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Access Control
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Access Control',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.stars, color: Colors.amber, size: 16),
                                  label: const Text('Grant Pro (Permanent)'),
                                  onPressed: () => _showConfirmDialog(
                                    actionName: 'Grant Pro (Permanent)',
                                    onConfirm: () => _updateUserTier(
                                      tier: 'pro',
                                      grantedBy: 'admin',
                                      expiresAt: null,
                                    ),
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.calendar_today, color: Colors.blueAccent, size: 16),
                                  label: const Text('Grant Pro (1 Month)'),
                                  onPressed: () => _showConfirmDialog(
                                    actionName: 'Grant Pro (1 Month)',
                                    onConfirm: () => _updateUserTier(
                                      tier: 'pro',
                                      grantedBy: 'admin',
                                      expiresAt: DateTime.now().add(const Duration(days: 30)),
                                    ),
                                  ),
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.date_range, color: Colors.green, size: 16),
                                  label: const Text('Grant Pro (Custom)'),
                                  onPressed: _selectCustomDate,
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.cancel, color: Colors.redAccent, size: 16),
                                  label: const Text('Revoke Pro'),
                                  onPressed: () => _showConfirmDialog(
                                    actionName: 'Revoke Pro',
                                    onConfirm: () => _updateUserTier(
                                      tier: 'free',
                                      grantedBy: null,
                                      expiresAt: null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CV History
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CV History',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<List<CvModel>>(
                              stream: cvsStream,
                              builder: (context, cvsSnapshot) {
                                if (cvsSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final cvs = cvsSnapshot.data ?? [];
                                if (cvs.isEmpty) {
                                  return const Text(
                                    'No CVs generated yet.',
                                    style: TextStyle(color: Colors.white38, fontSize: 13),
                                  );
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: cvs.length,
                                  itemBuilder: (context, index) {
                                    final cv = cvs[index];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.description, color: Colors.blueAccent),
                                      title: Text(cv.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text(
                                        'Template: ${cv.template} | ${DateFormat('yyyy-MM-dd HH:mm').format(cv.updatedAt)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.white60),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Payment History
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment History',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<List<PaymentModel>>(
                              stream: paymentsStream,
                              builder: (context, paymentsSnapshot) {
                                if (paymentsSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final payments = paymentsSnapshot.data ?? [];
                                if (payments.isEmpty) {
                                  return const Text(
                                    'No payments made yet.',
                                    style: TextStyle(color: Colors.white38, fontSize: 13),
                                  );
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: payments.length,
                                  itemBuilder: (context, index) {
                                    final payment = payments[index];
                                    final double nprAmount = payment.amount / 100.0;
                                    
                                    Color statusColor;
                                    switch (payment.status) {
                                      case 'verified':
                                        statusColor = Colors.green;
                                        break;
                                      case 'rejected':
                                        statusColor = Colors.redAccent;
                                        break;
                                      default:
                                        statusColor = Colors.orange;
                                    }

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: Colors.white.withOpacity(0.02),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        leading: Icon(Icons.receipt_long, color: statusColor),
                                        title: Text(
                                          'Plan: ${payment.plan.toUpperCase()} | NPR $nprAmount',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text('Txn ID: ${payment.esewaTransactionId ?? "N/A"}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Status: ${payment.status.toUpperCase()} | Created: ${DateFormat('yyyy-MM-dd HH:mm').format(payment.createdAt)}',
                                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                                            ),
                                            if (payment.verifiedAt != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Verified: ${DateFormat('yyyy-MM-dd HH:mm').format(payment.verifiedAt!)}',
                                                style: const TextStyle(fontSize: 11, color: Colors.green),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
