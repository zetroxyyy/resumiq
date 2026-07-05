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

  final TextEditingController _announcementController = TextEditingController();
  String _announcementType = 'info';

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
    _announcementController.dispose();
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
      length: 5,
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
              Tab(icon: Icon(Icons.feedback_outlined), text: 'Feedback'),
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

              // Tab 5: Feedback
              _buildFeedbackTab(theme: theme),
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
             const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
             const BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Create'),
             const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
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

  Widget _buildFeedbackTab({required ThemeData theme}) {
    debugPrint('AdminScreen/Feedback: _buildFeedbackTab called');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint(
            'AdminScreen/Feedback: StreamBuilder state=${snapshot.connectionState} '
            'hasData=${snapshot.hasData} '
            'docsCount=${snapshot.data?.docs.length ?? 0} '
            'error=${snapshot.error}');

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading feedback: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('No feedback submitted yet.',
                style: TextStyle(color: theme.colorScheme.secondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final message = data['message'] as String? ?? data['text'] as String? ?? '';
            final email = data['email'] as String? ?? data['userEmail'] as String? ?? 'Anonymous';
            final resolved = data['resolved'] == true;
            final timestamp = data['createdAt'] as Timestamp?;
            final dateStr = timestamp != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
                : 'Pending...';

            debugPrint(
                'AdminScreen/Feedback: rendering doc[${doc.id}] '
                'email=$email resolved=$resolved date=$dateStr');

            return Card(
              elevation: 0,
              color: resolved
                  ? theme.colorScheme.surface.withOpacity(0.5)
                  : theme.colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: resolved
                      ? theme.colorScheme.outline.withOpacity(0.4)
                      : theme.colorScheme.outline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: resolved
                                  ? theme.colorScheme.onSurface.withOpacity(0.5)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Resolved',
                              style: TextStyle(
                                fontSize: 12,
                                color: resolved
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.secondary,
                              ),
                            ),
                            Checkbox(
                              value: resolved,
                              onChanged: (val) async {
                                final newVal = val ?? false;
                                debugPrint(
                                    'AdminScreen/Feedback: toggling resolved '
                                    'doc=${doc.id} newResolved=$newVal');
                                try {
                                  await doc.reference.update({'resolved': newVal});
                                  debugPrint(
                                      'AdminScreen/Feedback: update OK doc=${doc.id}');
                                } catch (e) {
                                  debugPrint(
                                      'AdminScreen/Feedback: update FAILED doc=${doc.id} err=$e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Update failed: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: resolved
                            ? theme.colorScheme.onSurface.withOpacity(0.5)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
            icon: Icons.people_outline,
            color: theme.colorScheme.primary,
          ),
          _buildStatCard(
            label: 'Pro Users',
            valueAsync: proUsersAsync,
            icon: Icons.star_outline,
            color: theme.colorScheme.primary,
          ),
          _buildStatCard(
            label: 'Total Generations',
            valueAsync: totalCvsAsync,
            icon: Icons.description_outlined,
            color: theme.brightness == Brightness.dark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B),
          ),
          _buildStatCard(
            label: 'Your Runs This Month',
            valueAsync: AsyncValue.data(adminGenerations),
            icon: Icons.run_circle_outlined,
            color: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
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
              error: (e, s) => Text('--', style: TextStyle(color: theme.colorScheme.secondary)),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.secondary, fontSize: 11),
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
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.38)),
              prefixIcon: Icon(Icons.search_outlined, color: theme.colorScheme.onSurface.withOpacity(0.7)),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
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
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.colorScheme.outline),
                      ),
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
                        subtitle: Text(targetUser.email, style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: targetUser.isPro ? theme.colorScheme.primary.withOpacity(0.12) : theme.colorScheme.outline,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            targetUser.isPro ? 'PRO' : 'FREE',
                            style: TextStyle(
                              color: targetUser.isPro ? theme.colorScheme.primary : theme.colorScheme.secondary,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Global Announcement',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _announcementController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Type announcement message here... (no emojis)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _announcementType,
                        dropdownColor: theme.colorScheme.surface,
                        items: ['info', 'success', 'warning'].map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _announcementType = val;
                            });
                          }
                        },
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.publish),
                        label: const Text('Publish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                        ),
                        onPressed: () async {
                          final msg = _announcementController.text.trim();
                          if (msg.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a message.')),
                            );
                            return;
                          }

                          try {
                            await FirebaseFirestore.instance.collection('alerts').add({
                              'message': msg,
                              'type': _announcementType,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            _announcementController.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Announcement published successfully.')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to publish: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Announcement History',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('alerts')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: Text('No announcements sent yet.', style: TextStyle(color: theme.colorScheme.secondary))),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final message = data['message'] as String? ?? '';
                  final type = data['type'] as String? ?? 'info';
                  final timestamp = data['createdAt'] as Timestamp?;
                  final dateStr = timestamp != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate())
                      : 'Pending...';

                  Color typeColor = theme.colorScheme.primary;
                  if (type == 'success') typeColor = theme.brightness == Brightness.dark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B);
                  if (type == 'warning') typeColor = theme.brightness == Brightness.dark ? const Color(0xFFD19A4E) : const Color(0xFFC48A3D);

                  return Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outline),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(message),
                      subtitle: Text('$dateStr • ${type.toUpperCase()}', style: TextStyle(color: typeColor, fontSize: 12)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        onPressed: () async {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Delete Announcement?'),
                              content: const Text('Are you sure you want to delete this global announcement?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogCtx);
                                    try {
                                      await FirebaseFirestore.instance.collection('alerts').doc(doc.id).delete();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Announcement deleted.')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to delete: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
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
    final theme = Theme.of(context);
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
                      style: TextStyle(color: theme.colorScheme.secondary, fontSize: 11),
                    ),
                    if (payment.status == 'pending') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _rejectPayment(payment),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error),
                            ),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => _verifyPayment(payment),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B),
                              foregroundColor: theme.colorScheme.onPrimary,
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
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case 'verified':
        color = theme.brightness == Brightness.dark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B);
        break;
      case 'rejected':
        color = theme.colorScheme.error;
        break;
      default:
        color = theme.brightness == Brightness.dark ? const Color(0xFFD19A4E) : const Color(0xFFC48A3D);
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
    final theme = Theme.of(context);
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

      // 4. Create personal alerts: payment verified + Pro activated
      await FirebaseFirestore.instance
          .collection('users')
          .doc(payment.userId)
          .collection('alerts')
          .add({
        'message': 'Your payment has been verified.',
        'type': 'success',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(payment.userId)
          .collection('alerts')
          .add({
        'message': 'Your Pro subscription has been activated.',
        'type': 'success',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pro granted to ${payment.userGmail}'),
            backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF5FAD7E) : const Color(0xFF4C9A6B),
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
    final theme = Theme.of(context);
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

      // 3. Create personal alert: payment rejected
      await FirebaseFirestore.instance
          .collection('users')
          .doc(payment.userId)
          .collection('alerts')
          .add({
        'message': 'Your payment has been rejected.',
        'type': 'warning',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment rejected'),
            backgroundColor: theme.colorScheme.error,
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
