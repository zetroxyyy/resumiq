import 'package:flutter/material.dart';
import '../../../core/widgets/gradient_background.dart';

class AdminUserDetailScreen extends StatelessWidget {
  final String userId;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management Detail'),
      ),
      body: GradientBackground(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                        child: Icon(
                          Icons.person,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'User ID: $userId',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDetailRow('Full Name', 'Alice Smith'),
                      _buildDetailRow('Email Address', 'alice@example.com'),
                      _buildDetailRow('Status', 'Pro Subscription'),
                      _buildDetailRow('Registration Date', '2026-06-12'),
                      _buildDetailRow('Resume Generations', '4'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
