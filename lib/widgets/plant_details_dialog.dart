import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
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
  late TextEditingController _todayNotesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.plantData['notes'] as String? ?? '',
    );
    
    // Load today's notes
    final todayNotesData = widget.plantData['dailyNotes'] as Map<String, dynamic>?;
    final todayKey = _getTodayKey();
    _todayNotesController = TextEditingController(
      text: todayNotesData?[todayKey] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _todayNotesController.dispose();
    super.dispose();
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return 'Today at $hour:$minute';
      }
    } catch (e) {
      return 'Recently';
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
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.purple[700]!,
                              Colors.purple[500]!,
                            ],
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            _showQRCodeDialog(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'View QR Code',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Disease Information (if diseased)
                    if (status == 'Diseased' || status == 'Warning') ...[
                      _buildDiseaseInfoSection(),
                      const SizedBox(height: 24),
                    ],

                    // Today's Notes (Editable)
                    _buildSectionTitle(Icons.today, 'Today\'s Notes'),
                    const SizedBox(height: 8),
                    Text(
                      _getTodayKey(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _todayNotesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add notes for today...',
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
                          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.blue[50],
                      ),
                      onChanged: (value) {
                        final todayKey = _getTodayKey();
                        final currentDailyNotes = widget.plantData['dailyNotes'] as Map<String, dynamic>? ?? {};
                        currentDailyNotes[todayKey] = value;
                        
                        // Save to Firestore
                        FirebaseFirestore.instance
                            .collection('plant')
                            .doc(widget.documentId)
                            .update({'dailyNotes': currentDailyNotes});
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Saved automatically',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Recommendations (only for healthy plants)
                    if (status == 'Healthy') ...[
                      _buildSectionTitle(Icons.lightbulb_outline, 'Care Recommendations'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRecommendationItem('Continue regular monitoring weekly'),
                            const SizedBox(height: 8),
                            _buildRecommendationItem('Maintain proper watering schedule'),
                            const SizedBox(height: 8),
                            _buildRecommendationItem('Apply balanced fertilizer monthly'),
                            const SizedBox(height: 8),
                            _buildRecommendationItem('Ensure adequate spacing for air circulation'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

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
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.fromARGB(255, 17, 95, 17),
                              Color.fromARGB(255, 80, 139, 80),
                            ],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
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
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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

  void _showQRCodeDialog(BuildContext context) {
    final plantId = widget.plantData['plant_id'] as String? ?? 'Unknown';
    final qrCodeId = widget.plantData['qr_code_id'] as String? ?? widget.documentId;
    final section = widget.plantData['section']?.toString() ?? 'N/A';
    final row = widget.plantData['row']?.toString() ?? 'N/A';
    final GlobalKey qrKey = GlobalKey();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plant QR Code',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Plant ID: $plantId',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // QR Code with RepaintBoundary for capturing
                  RepaintBoundary(
                    key: qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple[100]!, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrCodeId,
                        version: QrVersions.auto,
                        size: MediaQuery.of(context).size.width * 0.5,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        embeddedImage: null,
                        embeddedImageStyle: null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Plant Info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQRInfoRow('Plant ID', plantId),
                        const SizedBox(height: 8),
                        _buildQRInfoRow('Section', section),
                        const SizedBox(height: 8),
                        _buildQRInfoRow('Row', row),
                        const SizedBox(height: 8),
                        _buildQRInfoRow('Status', _getStatusText()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadQRCode(context, qrKey, plantId),
                      icon: const Icon(Icons.download),
                      label: const Text(
                        'Download QR Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Scan this QR code to quickly access plant information',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
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
    );
  }

  Future<void> _downloadQRCode(BuildContext context, GlobalKey qrKey, String plantId) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving QR Code...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Capture the QR code as an image
      RenderRepaintBoundary boundary =
          qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to gallery using gal package
      await Gal.putImageBytes(pngBytes, album: 'Plant QR Codes');

      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();
        
        // Show success notification
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'QR Code saved to gallery!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog if it's still open
        Navigator.of(context, rootNavigator: true).pop();
        
        String errorMessage = 'Error saving QR code';
        if (e is GalException) {
          if (e.type == GalExceptionType.accessDenied) {
            errorMessage = 'Storage permission denied. Please enable it in Settings.';
          }
        }
        
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        });
      }
    }
  }

  Widget _buildQRInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
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

  Widget _buildDiseaseInfoSection() {
    final lastDiseaseType = widget.plantData['lastDiseaseType'] as String?;
    final lastDiseaseConfidence = widget.plantData['lastDiseaseConfidence'] as double?;
    final lastDiseaseCheck = widget.plantData['lastDiseaseCheck'] as Timestamp?;
    
    if (lastDiseaseType == null) {
      return const SizedBox.shrink();
    }

    // Format confidence percentage
    final confidencePercent = lastDiseaseConfidence != null 
        ? (lastDiseaseConfidence * 100).toStringAsFixed(1) 
        : 'N/A';

    // Format last check date
    String lastCheckDate = 'N/A';
    if (lastDiseaseCheck != null) {
      final date = lastDiseaseCheck.toDate();
      lastCheckDate = '${date.day}/${date.month}/${date.year}';
    }

    // Determine severity color
    Color severityColor = Colors.orange;
    String severityText = 'Medium Risk';
    final disease = lastDiseaseType.toLowerCase();
    
    if (disease.contains('healthy')) {
      severityColor = Colors.green;
      severityText = 'Healthy';
    } else if (disease.contains('panama') || disease.contains('bract mosaic virus')) {
      severityColor = Colors.red;
      severityText = 'High Risk';
    } else if (disease.contains('sigatoka') || disease.contains('cordana')) {
      severityColor = Colors.orange;
      severityText = 'Medium Risk';
    } else if (disease.contains('pestalotiopsis')) {
      severityColor = Colors.yellow[700]!;
      severityText = 'Low Risk';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(Icons.medical_services, 'Disease Information'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: severityColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: severityColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.coronavirus, color: severityColor, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lastDiseaseType,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: severityColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDiseaseInfoRow('Severity', severityText, severityColor),
              const Divider(height: 16),
              _buildDiseaseInfoRow('Confidence', '$confidencePercent%', severityColor),
              const Divider(height: 16),
              _buildDiseaseInfoRow('Last Checked', lastCheckDate, severityColor),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle(Icons.healing, 'Treatment'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _getTreatmentRecommendations(lastDiseaseType),
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  List<Widget> _getTreatmentRecommendations(String diseaseName) {
    final disease = diseaseName.toLowerCase();
    List<String> treatments = [];

    if (disease.contains('healthy')) {
      treatments = [
        'Maintain current care routine',
        'Continue regular monitoring',
        'Apply balanced fertilizer monthly',
        'Ensure adequate water drainage',
      ];
    } else if (disease.contains('black sigatoka')) {
      treatments = [
        'Remove and destroy infected leaves immediately',
        'Apply systemic fungicide (Propiconazole or Azoxystrobin)',
        'Improve air circulation by pruning adjacent plants',
        'Apply treatment every 2-3 weeks during wet season',
        'Ensure proper spacing between plants',
      ];
    } else if (disease.contains('panama')) {
      treatments = [
        'CRITICAL: Remove infected plant to prevent spread',
        'Disinfect all tools used near infected plant',
        'Do not replant in the same location for 2-3 years',
        'Apply soil fumigation before replanting',
        'Monitor nearby plants weekly for symptoms',
      ];
    } else if (disease.contains('bract mosaic virus')) {
      treatments = [
        'Remove and destroy infected plant immediately',
        'Control aphid populations (virus vectors)',
        'Use virus-free planting material only',
        'Disinfect tools between plants',
        'Maintain 2-meter buffer zone around removal site',
      ];
    } else if (disease.contains('cordana')) {
      treatments = [
        'Remove affected leaves and dispose properly',
        'Apply copper-based fungicide every 10-14 days',
        'Reduce leaf wetness duration',
        'Improve drainage around plant base',
        'Avoid overhead irrigation',
      ];
    } else if (disease.contains('pestalotiopsis')) {
      treatments = [
        'Prune and remove affected plant parts',
        'Apply broad-spectrum fungicide',
        'Reduce plant stress through proper watering',
        'Apply balanced fertilizer to boost immunity',
        'Monitor weekly and retreat if symptoms persist',
      ];
    } else {
      // Generic recommendations
      treatments = [
        'Consult with agricultural extension officer',
        'Remove affected plant parts',
        'Apply appropriate fungicide or treatment',
        'Monitor plant closely for changes',
        'Ensure proper cultural practices',
      ];
    }

    return treatments.map((treatment) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _buildRecommendationItem(treatment),
    )).toList();
  }
}
