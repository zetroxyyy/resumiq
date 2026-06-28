import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../models/user_model.dart';
import '../../../models/payment_model.dart';
import '../providers/admin_provider.dart';


class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final isAdmin = user?.email == AppConstants.adminEmail;

    final totalUsersAsync = ref.watch(totalUsersProvider);
    final proUsersAsync = ref.watch(proUsersCountProvider);
    final totalCvsAsync = ref.watch(totalGenerationsProvider);
    final allUsersAsync = ref.watch(allUsersProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Console'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Users'),
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Alerts'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Payments'),
            ],
          ),
        ),
        body: GradientBackground(
          child: TabBarView(
            children: [
              // Tab 1: Dashboard
              _buildDashboardTab(
                theme: theme,
                totalUsersAsync: totalUsersAsync,
                proUsersAsync: proUsersAsync,
                totalCvsAsync: totalCvsAsync,
                adminGenerations: user?.generationsThisMonth ?? 0,
              ),

              // Tab 2: Users List
              _buildUsersTab(
                theme: theme,
                allUsersAsync: allUsersAsync,
              ),

              // Tab 3: Announcements Placeholder
              _buildAnnouncementsTab(theme: theme),

              // Tab 4: Payments
              _buildPaymentsTab(theme: theme),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 3,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            if (index == 3) return;
            if (index == 0) {
              context.go('/home');
            } else if (index == 1) {
              context.push('/cv/input');
            } else if (index == 2) {
              context.go('/profile');
            }
          },
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Create'),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            if (isAdmin)
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings),
                label: 'Admin',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab({
    required ThemeData theme,
    required AsyncValue<int> totalUsersAsync,
    required AsyncValue<int> proUsersAsync,
    required AsyncValue<int> totalCvsAsync,
    required int adminGenerations,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildStatCard(
            label: 'Total Users',
            valueAsync: totalUsersAsync,
            icon: Icons.people_alt,
            color: Colors.blueAccent,
          ),
          _buildStatCard(
            label: 'Pro Users',
            valueAsync: proUsersAsync,
            icon: Icons.star,
            color: Colors.amber,
          ),
          _buildStatCard(
            label: 'Total Generations',
            valueAsync: totalCvsAsync,
            icon: Icons.description,
            color: Colors.green,
          ),
          _buildStatCard(
            label: 'Your Runs This Month',
            valueAsync: AsyncValue.data(adminGenerations),
            icon: Icons.run_circle_outlined,
            color: Colors.purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required AsyncValue<int> valueAsync,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            valueAsync.when(
              data: (val) => Text(
                '$val',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
              ),
              loading: () => const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, s) => const Text('--', style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab({
    required ThemeData theme,
    required AsyncValue<List<UserModel>> allUsersAsync,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: allUsersAsync.when(
              data: (users) {
                final filteredUsers = users.where((user) {
                  return user.name.toLowerCase().contains(_searchQuery) ||
                      user.email.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return const Center(child: Text('No users match search criteria.'));
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final targetUser = filteredUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: targetUser.photoUrl.isNotEmpty
                              ? NetworkImage(targetUser.photoUrl)
                              : null,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                          child: targetUser.photoUrl.isEmpty
                              ? Text(targetUser.name.isNotEmpty ? targetUser.name[0].toUpperCase() : 'U')
                              : null,
                        ),
                        title: Text(targetUser.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(targetUser.email, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: targetUser.isPro ? Colors.amber.withOpacity(0.15) : Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            targetUser.isPro ? 'PRO' : 'FREE',
                            style: TextStyle(
                              color: targetUser.isPro ? Colors.amber : Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        onTap: () {
                          context.push('/admin/user/${targetUser.uid}');
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading users: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsTab({required ThemeData theme}) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 72, color: Colors.white30),
          SizedBox(height: 16),
          Text(
            'Announcements Tab',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text('Coming Soon placeholder', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab({required ThemeData theme}) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'All'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPaymentsList(isPendingOnly: true),
                _buildPaymentsList(isPendingOnly: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList({required bool isPendingOnly}) {
    final paymentsAsync = ref.watch(isPendingOnly ? pendingPaymentsProvider : allPaymentsProvider);
    final fmt = DateFormat('MMM dd, yyyy \'at\' h:mm a');

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return const Center(child: Text('No payments found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            final amountNpr = payment.amount / 100.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            payment.userGmail ?? 'Unknown Gmail',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        _buildStatusBadge(payment.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Plan: ${payment.plan.toUpperCase()} | Amount: NPR $amountNpr'),
                    const SizedBox(height: 4),
                    Text('Transaction ID: ${payment.esewaTransactionId ?? "N/A"}'),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted: ${fmt.format(payment.createdAt)}',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    if (payment.status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _rejectPayment(payment),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => _verifyPayment(payment),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Verify & Grant Pro'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading payments: $e')),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'verified':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Future<void> _verifyPayment(PaymentModel payment) async {
    try {
      final now = DateTime.now();
      final durationDays = payment.plan == 'yearly' ? 365 : 30;
      final expiryDate = now.add(Duration(days: durationDays));

      // 1. Update user document tier -> pro
      await FirebaseFirestore.instance
          .collection('users')
          .doc(payment.userId)
          .update({
        'tier': 'pro',
        'tierGrantedBy': 'admin',
        'tierExpiresAt': Timestamp.fromDate(expiryDate),
      });

      // 2. Update payment status in user's subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(payment.userId)
          .collection('payments')
          .doc(payment.id)
          .update({
        'status': 'verified',
        'verifiedBy': 'admin',
        'verifiedAt': Timestamp.fromDate(now),
      });

      // 3. Update payment status in top-level collection
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(payment.id)
          .update({
        'status': 'verified',
        'verifiedBy': 'admin',
        'verifiedAt': Timestamp.fromDate(now),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pro granted to ${payment.userGmail}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    }
  }

  Future<void> _rejectPayment(PaymentModel payment) async {
    try {
      final now = DateTime.now();

      // 1. Update payment status in user's subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(payment.userId)
          .collection('payments')
          .doc(payment.id)
          .update({
        'status': 'rejected',
        'verifiedBy': 'admin',
        'verifiedAt': Timestamp.fromDate(now),
      });

      // 2. Update payment status in top-level collection
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(payment.id)
          .update({
        'status': 'rejected',
        'verifiedBy': 'admin',
        'verifiedAt': Timestamp.fromDate(now),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment rejected'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: $e')),
        );
      }
    }
  }
}
