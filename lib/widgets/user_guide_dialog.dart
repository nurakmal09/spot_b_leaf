import 'package:flutter/material.dart';

class UserGuideDialog extends StatelessWidget {
  const UserGuideDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const UserGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.help_outline, color: Color.fromARGB(255, 99, 144, 83)),
          SizedBox(width: 8),
          Text('User Guide'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGuideSection(
              '📊 Dashboard',
              'View your farm statistics, plant health status, and real-time weather information.',
            ),
            const SizedBox(height: 16),
            _buildGuideSection(
              '🌱 My Garden',
              'Manage your field layout, add new plants, and monitor individual plant health status.',
            ),
            const SizedBox(height: 16),
            _buildGuideSection(
              '📸 Camera',
              'Scan QR codes to quickly access plant details or capture images for disease detection.',
            ),
            const SizedBox(height: 16),
            _buildGuideSection(
              '💊 Treatment',
              'Access disease treatment guides with detailed instructions for different risk levels.',
            ),
            const SizedBox(height: 16),
            _buildGuideSection(
              '📋 Report',
              'Generate and view weekly reports with plant health analytics and trends.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Got it',
            style: TextStyle(
              color: Color.fromARGB(255, 99, 144, 83),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

