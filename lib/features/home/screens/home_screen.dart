import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/cv_card.dart';
import '../widgets/empty_state_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Set<String> _dismissedGlobalAlertIds = {};

  @override
  void initState() {
    super.initState();
    _loadDismissedGlobalAlerts();
  }

  Future<void> _loadDismissedGlobalAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('dismissed_global_alerts') ?? [];
    setState(() {
      _dismissedGlobalAlertIds = list.toSet();
    });
  }

  Future<void> _dismissGlobalAlert(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final newSet = {..._dismissedGlobalAlertIds, id};
    await prefs.setStringList('dismissed_global_alerts', newSet.toList());
    setState(() {
      _dismissedGlobalAlertIds = newSet;
    });
  }

  Widget _buildAlertsSection(String userId, ThemeData theme) {
    return Column(
      children: [
        // 1. Personal Alerts Stream
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('alerts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['read'] != true;
            }).toList();

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final message = data['message'] as String? ?? '';
                final type = data['type'] as String? ?? 'info';
                
                return _buildAlertBanner(
                  message: message,
                  type: type,
                  theme: theme,
                  onDismiss: () async {
                    await doc.reference.update({'read': true});
                  },
                );
              }).toList(),
            );
          },
        ),

        // 2. Global Announcements Stream
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final docs = snapshot.data!.docs.where((doc) {
              return !_dismissedGlobalAlertIds.contains(doc.id);
            }).toList();

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final message = data['message'] as String? ?? '';
                final type = data['type'] as String? ?? 'info';

                return _buildAlertBanner(
                  message: message,
                  type: type,
                  theme: theme,
                  onDismiss: () => _dismissGlobalAlert(doc.id),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAlertBanner({
    required String message,
    required String type,
    required ThemeData theme,
    required VoidCallback onDismiss,
  }) {
    Color bgColor = Colors.blue.withOpacity(0.15);
    Color borderColor = Colors.blue;
    IconData icon = Icons.info_outline;

    if (type == 'success') {
      bgColor = Colors.green.withOpacity(0.15);
      borderColor = Colors.green;
      icon = Icons.check_circle_outline;
    } else if (type == 'warning') {
      bgColor = Colors.orange.withOpacity(0.15);
      borderColor = Colors.orange;
      icon = Icons.warning_amber_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: Icon(icon, color: borderColor),
        title: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18, color: Colors.white70),
          onPressed: onDismiss,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = user.email == AppConstants.adminEmail;
    final firstName = user.name.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumiq'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userCvsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAlertsSection(user.uid, theme),
                // Top Greeting Row
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            const TextSpan(text: 'Hello, '),
                            TextSpan(
                              text: firstName,
                              style: TextStyle(color: theme.colorScheme.primary),
                            ),
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (user.isPro) const ProBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ready to impress?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

                // Free Tier Counter Card
                if (!user.isPro) ...[
                  const SizedBox(height: 20),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${user.generationsThisMonth} of 2 free CVs used this month',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (user.generationsThisMonth >= 2)
                                TextButton(
                                  onPressed: () => context.push('/upgrade'),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Upgrade',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (user.generationsThisMonth / 2.0).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Create New CV Card
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/cv/input'),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_circle_outline,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Create New CV',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start Building →',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // CV List Section
                const SizedBox(height: 32),
                Text(
                  'Your CVs',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                ref.watch(userCvsProvider).when(
                      data: (cvs) {
                        if (cvs.isEmpty) {
                          return const EmptyStateWidget();
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cvs.length,
                          itemBuilder: (context, index) {
                            return CvCard(cv: cvs[index]);
                          },
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Text(
                          'Error loading CVs: $err',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) return;
          if (index == 1) {
            context.push('/cv/input');
          } else if (index == 2) {
            context.go('/profile');
          } else if (index == 3) {
            context.go('/admin');
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Create'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
