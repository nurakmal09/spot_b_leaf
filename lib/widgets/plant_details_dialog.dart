import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/weekly_report_page.dart';

class PlantDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> plantData;
  final String documentId;

  const PlantDetailsDialog({
    super.key,
    required this.plantData,
    required this.documentId,
  });

  @override
  State<PlantDetailsDialog> createState() => _PlantDetailsDialogState();
}

class _PlantDetailsDialogState extends State<PlantDetailsDialog> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.plantData['notes'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _getStatusText() {
    final statusList = widget.plantData['status'] as List<dynamic>?;
    if (statusList != null && statusList.isNotEmpty) {
      final status = statusList[0].toString();
      return status.substring(0, 1).toUpperCase() + status.substring(1);
    }
    return 'Healthy';
  }

  Color _getStatusColor() {
    final statusList = widget.plantData['status'] as List<dynamic>?;
    if (statusList != null && statusList.isNotEmpty) {
      final status = statusList[0].toString().toLowerCase();
      if (status == 'diseased') return Colors.red;
      if (status == 'warning') return Colors.orange;
    }
    return Colors.green;
  }

  String _formatDayPlanted(dynamic timestamp) {
    if (timestamp == null) return 'Not specified';
    
    try {
      DateTime plantDate;
      if (timestamp is Timestamp) {
        plantDate = timestamp.toDate();
      } else if (timestamp is DateTime) {
        plantDate = timestamp;
      } else {
        return 'Not specified';
      }
      
      // Format: DD/MM/YYYY at HH:MM
      final day = plantDate.day.toString().padLeft(2, '0');
      final month = plantDate.month.toString().padLeft(2, '0');
      final year = plantDate.year.toString();
      final hour = plantDate.hour.toString().padLeft(2, '0');
      final minute = plantDate.minute.toString().padLeft(2, '0');
      
      return '$day/$month/$year at $hour:$minute';
    } catch (e) {
      return 'Not specified';
    }
  }

  @override
  Widget build(BuildContext context) {
    final plantId = widget.plantData['plant_id'] as String? ?? 'Unknown';
    final section = widget.plantData['section']?.toString() ?? 'N/A';
    final row = widget.plantData['row']?.toString() ?? 'N/A';
    final dayPlanted = _formatDayPlanted(widget.plantData['day_first_plant']);
    final status = _getStatusText();
    final statusColor = _getStatusColor();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Plant Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                    // Plant Icon and ID
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.eco,
                              size: 40,
                              color: Colors.green[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            plantId,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status == 'Diseased' ? 'Disease Detected' : status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Basic Info
                    _buildInfoRow('Section', section),
                    const SizedBox(height: 12),
                    _buildInfoRow('Row', row),
                    const SizedBox(height: 12),
                    _buildInfoRow('Day Planted', dayPlanted),
                    const SizedBox(height: 24),

                    // Plant QR Code Section
                    _buildSectionTitle(Icons.qr_code, 'Plant QR Code'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.qr_code, color: Colors.purple[600], size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quick Access Tag',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Scan to instantly view this plant',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Implement QR code generation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('QR Code generation coming soon')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Generate & View QR Code',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recommendations
                    _buildSectionTitle(Icons.lightbulb_outline, 'Recommendations'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRecommendationItem('Increase monitoring frequency to twice weekly'),
                          const SizedBox(height: 8),
                          _buildRecommendationItem('Apply preventive fungicide treatment before rainy season'),
                          const SizedBox(height: 8),
                          _buildRecommendationItem('Ensure proper drainage around plant base'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Your Notes
                    _buildSectionTitle(Icons.note, 'Your Notes'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Add your observations or notes...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.green[600]!),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        // Auto-save notes to Firestore
                        FirebaseFirestore.instance
                            .collection('plant')
                            .doc(widget.documentId)
                            .update({'notes': value});
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Notes are saved automatically',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Generate Weekly Report Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WeeklyReportPage(
                                plantData: widget.plantData,
                                documentId: widget.documentId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.description),
                        label: const Text('Generate Weekly Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
