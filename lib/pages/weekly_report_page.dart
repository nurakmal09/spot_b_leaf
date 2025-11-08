import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth.dart';

class WeeklyReportPage extends StatelessWidget {
  final Map<String, dynamic> plantData;
  final String documentId;

  const WeeklyReportPage({
    super.key,
    required this.plantData,
    required this.documentId,
  });

  String _getWeekRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return 'Week of ${months[startOfWeek.month - 1]} ${startOfWeek.day}-${endOfWeek.day}, ${endOfWeek.year}';
  }

  Future<void> _saveReport(BuildContext context) async {
    final auth = Auth();
    final user = auth.currentUser;
    
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to save reports'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final plantId = plantData['plant_id'] as String? ?? 'Unknown';
      final section = plantData['section']?.toString() ?? 'N/A';
      final row = plantData['row']?.toString() ?? 'N/A';
      final fieldName = plantData['field_name'] as String? ?? 'Unknown Field';

      // Get the user's notes from plant data
      final plantNotes = plantData['notes'] as String? ?? '';

      // Create report data
      final reportData = {
        'userId': user.uid,
        'plantId': plantId,
        'documentId': documentId,
        'fieldName': fieldName,
        'section': section,
        'row': row,
        'weekRange': _getWeekRange(),
        'healthyDays': 5,
        'diseaseDays': 2,
        'activities': [
          {
            'date': 'Monday, Dec 15',
            'description': 'Routine inspection completed. No issues detected.',
            'status': 'Healthy',
          },
          {
            'date': 'Wednesday, Dec 17',
            'description': 'Black Sigatoka detected. Fungicide treatment applied immediately.',
            'status': 'Disease',
          },
          {
            'date': 'Friday, Dec 19',
            'description': 'Follow-up scan. Disease progression slowed. Continue treatment.',
            'status': 'Monitoring',
          },
        ],
        'recommendations': [
          'Continue fungicide treatment for 3 more days',
          'Monitor daily for disease progression',
          'Ensure proper drainage around plant base',
          'Schedule follow-up scan in 7 days',
        ],
        'notes': plantNotes, // User's notes from plant details
        'additionalNotes': '', // Can be edited after report is saved
        'createdAt': Timestamp.now(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('weekly_reports')
          .add(reportData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate back after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantId = plantData['plant_id'] as String? ?? 'Unknown';
    final section = plantData['section']?.toString() ?? 'N/A';
    final row = plantData['row']?.toString() ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Weekly Report',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Green Header Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[600]!, Colors.green[500]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getWeekRange(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            plantId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Field $section, Row $row',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Health Summary
                    const Text(
                      'Health Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green[600],
                                  size: 28,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '5',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Healthy Days',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[600],
                                  size: 28,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '2',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Disease Days',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Weekly Activity Log
                    const Text(
                      'Weekly Activity Log',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActivityItem(
                      'Monday, Dec 15',
                      'Routine inspection completed. No issues detected.',
                      'Healthy',
                      Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildActivityItem(
                      'Wednesday, Dec 17',
                      'Black Sigatoka detected. Fungicide treatment applied immediately.',
                      'Disease',
                      Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildActivityItem(
                      'Friday, Dec 19',
                      'Follow-up scan. Disease progression slowed. Continue treatment.',
                      'Monitoring',
                      Colors.orange,
                    ),
                    const SizedBox(height: 24),

                    // Recommendations
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 20, color: Colors.grey[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Recommendations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRecommendationItem('Continue fungicide treatment for 3 more days'),
                          const SizedBox(height: 8),
                          _buildRecommendationItem('Monitor daily for disease progression'),
                          const SizedBox(height: 8),
                          _buildRecommendationItem('Ensure proper drainage around plant base'),
                          const SizedBox(height: 8),
                          _buildRecommendationItem('Schedule follow-up scan in 7 days'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Report Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _saveReport(context),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String date, String description, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.blue[700],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.blue[900],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
