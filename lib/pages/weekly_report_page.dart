import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth.dart';

class WeeklyReportPage extends StatefulWidget {
  final Map<String, dynamic> plantData;
  final String documentId;

  const WeeklyReportPage({
    super.key,
    required this.plantData,
    required this.documentId,
  });

  @override
  State<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<WeeklyReportPage> {
  List<Map<String, dynamic>> _weeklyActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyActivities();
  }

  Future<void> _loadWeeklyActivities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      
      // Reload fresh plant data from Firestore to get latest dailyNotes
      final plantDoc = await FirebaseFirestore.instance
          .collection('plant')
          .doc(widget.documentId)
          .get();
      
      final plantData = plantDoc.data() ?? {};
      
      // Get ALL disease detections for this plant (avoid index requirement)
      final detections = await FirebaseFirestore.instance
          .collection('disease_detections')
          .where('plantId', isEqualTo: widget.documentId)
          .get();
      
      debugPrint('=== WEEKLY REPORT DEBUG ===');
      debugPrint('Plant document ID: ${widget.documentId}');
      debugPrint('Start of week: $startOfWeek');
      debugPrint('Found ${detections.docs.length} total disease detections');
      
      // Filter detections to only this week
      final weekDetections = detections.docs.where((doc) {
        final detectedAt = (doc.data()['detectedAt'] as Timestamp?)?.toDate();
        if (detectedAt == null) return false;
        return detectedAt.isAfter(startOfWeek.subtract(const Duration(days: 1)));
      }).toList();
      
      debugPrint('Found ${weekDetections.length} detections for this week');
      
      // Log each detection
      for (var doc in weekDetections) {
        final data = doc.data();
        final detectedAt = (data['detectedAt'] as Timestamp?)?.toDate();
        debugPrint('  - Detection: ${data['diseaseType']} at $detectedAt');
        debugPrint('    Full detection data: $data');
      }
      
      // Get daily notes from fresh plant data
      final dailyNotes = plantData['dailyNotes'] as Map<String, dynamic>? ?? {};
      debugPrint('Daily notes: $dailyNotes');
      
      // Create activities for each day of the week
      final activities = <Map<String, dynamic>>[];
      final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final dayName = daysOfWeek[date.weekday - 1];
        final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final dateLabel = '$dayName, ${monthNames[date.month - 1]} ${date.day}';
        
        debugPrint('Processing day: $dateLabel (key: $dateKey)');
        
        // Find disease detection for this day
        final dayDetections = weekDetections.where((doc) {
          final detectedAt = (doc.data()['detectedAt'] as Timestamp?)?.toDate();
          if (detectedAt == null) return false;
          return detectedAt.year == date.year &&
                 detectedAt.month == date.month &&
                 detectedAt.day == date.day;
        }).toList();
        
        debugPrint('  Detections found: ${dayDetections.length}');
        
        // Log detection data for this day
        if (dayDetections.isNotEmpty) {
          for (var detection in dayDetections) {
            final data = detection.data();
            debugPrint('    Detection data: imageUrl=${data['imageUrl']}, diseaseType=${data['diseaseType']}, severity=${data['severity']}');
          }
        }
        
        // Get notes for this day
        final notes = dailyNotes[dateKey] as String?;
        debugPrint('  Notes: $notes');
        
        // Always add an entry for this day
        final detection = dayDetections.isNotEmpty ? dayDetections.first.data() : null;
        final diseaseType = detection?['diseaseType'] as String?;
        final severity = detection?['severity'] as String?;
        final imageUrl = detection?['imageUrl'] as String?;
        
        debugPrint('  Disease Type: $diseaseType');
        debugPrint('  Severity: $severity');
        debugPrint('  Image URL: $imageUrl');
        
        String status = 'No Record';
        Color statusColor = Colors.grey;
        String description = 'No record on this day';
        
        if (diseaseType != null) {
          // Add disease scan info with current condition
          if (diseaseType.toLowerCase().contains('healthy')) {
            status = 'Healthy';
            statusColor = Colors.green;
            description = 'Disease Scan: Plant is healthy.';
          } else if (severity == 'High Risk') {
            status = 'Disease';
            statusColor = Colors.red;
            description = 'Disease Scan: $diseaseType detected (High Risk). Immediate attention required.';
          } else if (severity == 'Medium Risk' || severity == 'Low Risk') {
            status = 'Monitoring';
            statusColor = Colors.orange;
            description = 'Disease Scan: $diseaseType detected ($severity). Monitor closely.';
          } else {
            status = 'Disease';
            statusColor = Colors.red;
            description = 'Disease Scan: $diseaseType detected.';
          }
        }
        
        // Add notes if available - shown prominently
        if (notes != null && notes.isNotEmpty) {
          if (diseaseType != null) {
            description += '\n\nToday\'s Notes: $notes';
          } else {
            description = 'Today\'s Notes: $notes';
            status = 'Note';
            statusColor = Colors.blue;
          }
        }
        
        activities.add({
          'date': dateLabel,
          'description': description,
          'status': status,
          'color': statusColor,
          'imageUrl': imageUrl,
        });
      }
      
      setState(() {
        _weeklyActivities = activities;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading weekly activities: $e');
      
      // Even on error, show the 7 days with "No record"
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      
      final fallbackActivities = <Map<String, dynamic>>[];
      for (int i = 0; i < 7; i++) {
        final date = startOfWeek.add(Duration(days: i));
        final dayName = daysOfWeek[date.weekday - 1];
        final dateLabel = '$dayName, ${monthNames[date.month - 1]} ${date.day}';
        
        fallbackActivities.add({
          'date': dateLabel,
          'description': 'No record on this day',
          'status': 'No Record',
          'color': Colors.grey,
        });
      }
      
      setState(() {
        _weeklyActivities = fallbackActivities;
        _isLoading = false;
      });
    }
  }

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
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Please sign in to save reports',
                      textAlign: TextAlign.center,
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
      return;
    }

    try {
      final plantId = widget.plantData['plant_id'] as String? ?? 'Unknown';
      final section = widget.plantData['section']?.toString() ?? 'N/A';
      final row = widget.plantData['row']?.toString() ?? 'N/A';
      final fieldName = widget.plantData['field_name'] as String? ?? 'Unknown Field';

      // Get the user's notes from plant data
      final plantNotes = widget.plantData['notes'] as String? ?? '';
      
      // Calculate healthy and disease days from activities
      int healthyDays = 0;
      int diseaseDays = 0;
      
      for (var activity in _weeklyActivities) {
        final status = activity['status'] as String;
        if (status == 'Healthy') {
          healthyDays++;
        } else if (status == 'Disease' || status == 'Monitoring') {
          diseaseDays++;
        }
      }

      // Create report data
      final reportData = {
        'userId': user.uid,
        'plantId': plantId,
        'documentId': widget.documentId,
        'fieldName': fieldName,
        'section': section,
        'row': row,
        'weekRange': _getWeekRange(),
        'healthyDays': healthyDays,
        'diseaseDays': diseaseDays,
        'activities': _weeklyActivities.map((activity) => {
          'date': activity['date'],
          'description': activity['description'],
          'status': activity['status'],
          'imageUrl': activity['imageUrl'],
        }).toList(),
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
                      'Report saved successfully!',
                      textAlign: TextAlign.center,
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

        // Navigate back after showing notification
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Close notification
            Navigator.pop(context); // Go back
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
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
                      'Error saving report: $e',
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

  @override
  Widget build(BuildContext context) {
    final plantId = widget.plantData['plant_id'] as String? ?? 'Unknown';
    final section = widget.plantData['section']?.toString() ?? 'N/A';
    final row = widget.plantData['row']?.toString() ?? 'N/A';
    final fieldName = widget.plantData['field_name'] as String? ?? 'Unknown Field';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header Section
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 20),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color.fromARGB(255, 99, 144, 83),
                    const Color.fromARGB(255, 23, 147, 33),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Report',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Plant health summary',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plant Info Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color.fromARGB(255, 99, 144, 83),
                          const Color.fromARGB(255, 23, 147, 33),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getWeekRange(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
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
                        Row(
                          children: [
                            Icon(Icons.agriculture, color: Colors.white.withOpacity(0.8), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '$fieldName • Section $section • Row $row',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                              ),
                            ),
                          ],
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
                                  _weeklyActivities.where((activity) => activity['status'] == 'Healthy').length.toString(),
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
                                  _weeklyActivities.where((activity) => activity['status'] == 'Disease' || activity['status'] == 'Monitoring').length.toString(),
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
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      ..._weeklyActivities.asMap().entries.map((entry) {
                        final index = entry.key;
                        final activity = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(bottom: index < _weeklyActivities.length - 1 ? 12 : 0),
                          child: _buildActivityItem(
                            activity['date'] as String,
                            activity['description'] as String,
                            activity['status'] as String,
                            activity['color'] as Color,
                            activity['imageUrl'] as String?,
                          ),
                        );
                      }).toList(),
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
                    const SizedBox(height: 100), // Extra space for bottom button
                  ],
                ),
              ),
            ),
          ],
        ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _saveReport(context),
              icon: const Icon(Icons.save, size: 22),
              label: const Text(
                'Save Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(String date, String description, String status, Color statusColor, String? imageUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[700],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: EdgeInsets.zero,
                    child: Stack(
                      children: [
                        Center(
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          top: 40,
                          right: 20,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 32),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
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
