import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/gradient_background.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Application Metrics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(context, label: 'Total Users', value: '1,280'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(context, label: 'Pro Members', value: '432'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Recent Users',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildUserTile(context, name: 'Alice Smith', email: 'alice@example.com', userId: 'user-01'),
                    _buildUserTile(context, name: 'Bob Johnson', email: 'bob@example.com', userId: 'user-02'),
                    _buildUserTile(context, name: 'Charlie Brown', email: 'charlie@example.com', userId: 'user-03'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, {required String label, required String value}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(
    BuildContext context, {
    required String name,
    required String email,
    required String userId,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(email),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.push('/admin/user/$userId');
        },
      ),
    );
  }
}
