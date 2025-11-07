import 'package:flutter/material.dart';
import 'plant_qr_code_dialog.dart';

class PlantAddedSuccessDialog extends StatelessWidget {
  final String plantId;
  final String section;
  final String row;
  final String age;
  final String status;
  final String fieldName;

  const PlantAddedSuccessDialog({
    super.key,
    required this.plantId,
    required this.section,
    required this.row,
    required this.age,
    required this.status,
    required this.fieldName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 50,
              ),
            ),
            const SizedBox(height: 24),

            // Success Message
            const Text(
              'Plant Added Successfully!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$plantId has been added to $fieldName',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Plant Details Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Plant ID', plantId),
                  const SizedBox(height: 12),
                  _buildDetailRow('Section', section.isEmpty ? 'n' : section),
                  const SizedBox(height: 12),
                  _buildDetailRow('Row', row.isEmpty ? 'n' : row),
                  const SizedBox(height: 12),
                  _buildDetailRow('Age', age.isEmpty ? 'n' : age),
                  const SizedBox(height: 12),
                  _buildDetailRow('Status', status, statusColor: _getStatusColor(status)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Generate QR Code Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Close current dialog
                  Navigator.pop(context);
                  
                  // Show QR code dialog
                  showDialog(
                    context: context,
                    builder: (context) => PlantQRCodeDialog(
                      plantId: plantId,
                      section: section,
                      row: row,
                      age: age,
                      status: status,
                      fieldName: fieldName,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Generate QR Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Done Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: statusColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'diseased':
        return Colors.red;
      default:
        return Colors.black87;
    }
  }
}
