import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/treatment_notes_dialog.dart';
import '../auth.dart';
import 'settings_page.dart';

class TreatmentPage extends StatefulWidget {
  const TreatmentPage({super.key});

  @override
  State<TreatmentPage> createState() => _TreatmentPageState();
}

class _TreatmentPageState extends State<TreatmentPage> {
  final Auth _auth = Auth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _notesSubscription;
  
  // Store notes for each disease
  final Map<String, String> diseaseNotes = {
    'Panama Disease (Fusarium Wilt)': '',
    'Cordana': '',
    'Pestalotiopsis': '',
    'Black Sigatoka': '',
    'Bract Mosaic Virus': '',
  };

  @override
  void initState() {
    super.initState();
    _loadNotesFromFirestore();
  }

  @override
  void dispose() {
    _notesSubscription?.cancel();
    super.dispose();
  }

  // Load notes from Firestore
  void _loadNotesFromFirestore() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen to real-time updates from Firestore
    _notesSubscription = _firestore
        .collection('treatment_notes')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        // Clear existing notes first
        diseaseNotes.updateAll((key, value) => '');
        
        // Load notes from Firestore
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final diseaseTitle = data['diseaseTitle'] as String?;
          final notes = data['notes'] as String?;
          
          if (diseaseTitle != null && diseaseNotes.containsKey(diseaseTitle)) {
            diseaseNotes[diseaseTitle] = notes ?? '';
          }
        }
      });
    });
  }

  // Save notes to Firestore
  Future<void> _saveNoteToFirestore(String diseaseTitle, String notes) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
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
                      'Please sign in to save notes',
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
      // Create a document ID based on userId and diseaseTitle
      final docId = '${user.uid}_${diseaseTitle.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      
      await _firestore.collection('treatment_notes').doc(docId).set({
        'userId': user.uid,
        'diseaseTitle': diseaseTitle,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        diseaseNotes[diseaseTitle] = notes;
      });
    } catch (e) {
      if (mounted) {
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
                      'Error saving notes: $e',
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Green Header
            Container(
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Treatment Guide',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Disease management solutions',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Disease Trend Chart
                    _buildDiseaseTrendChart(),
                    const SizedBox(height: 24),

                    // Treatment Guide Header
                    Row(
                      children: [
                        Icon(Icons.medical_services, color: Colors.green[600], size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Treatment Guide',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Disease Cards
                    _buildDiseaseCard(
              title: 'Panama Disease (Fusarium Wilt)',
              subtitle: 'Soil-borne fungal disease causing wilting',
              riskLevel: 'High Risk',
              riskColor: Colors.red[100]!,
              riskTextColor: Colors.red[700]!,
              treatments: [
                'Use resistant banana varieties',
                'Improve soil drainage and pH management',
                'Practice crop rotation with non-host plants',
                'Disinfect tools and equipment between plants',
              ],
            ),
            const SizedBox(height: 16),

            _buildDiseaseCard(
              title: 'Cordana',
              subtitle: 'Fungal leaf spot disease',
              riskLevel: 'Medium Risk',
              riskColor: Colors.amber[100]!,
              riskTextColor: Colors.amber[800]!,
              treatments: [
                'Apply copper-based fungicides',
                'Remove infected leaves and debris',
                'Ensure proper plant spacing',
                'Avoid overhead irrigation',
              ],
            ),
            const SizedBox(height: 16),

            _buildDiseaseCard(
              title: 'Pestalotiopsis',
              subtitle: 'Fungal disease causing leaf tip dieback',
              riskLevel: 'Low Risk',
              riskColor: Colors.green[100]!,
              riskTextColor: Colors.green[700]!,
              treatments: [
                'Prune affected leaf tips',
                'Apply preventive fungicide sprays',
                'Reduce plant stress through proper nutrition',
                'Maintain optimal soil moisture levels',
              ],
            ),
            const SizedBox(height: 16),

            _buildDiseaseCard(
              title: 'Black Sigatoka',
              subtitle: 'Fungal disease causing dark streaks on leaves',
              riskLevel: 'High Risk',
              riskColor: Colors.red[100]!,
              riskTextColor: Colors.red[700]!,
              treatments: [
                'Apply systemic fungicide (Mancozeb or Chlorothalonil)',
                'Remove severely infected leaves immediately',
                'Improve air circulation between plants',
                'Apply treatment every 14 days for 6 weeks',
              ],
            ),
            const SizedBox(height: 16),

            _buildDiseaseCard(
              title: 'Bract Mosaic Virus',
              subtitle: 'Viral disease causing mosaic patterns on bracts',
              riskLevel: 'Medium Risk',
              riskColor: Colors.amber[100]!,
              riskTextColor: Colors.amber[800]!,
              treatments: [
                'Remove and destroy infected plants',
                'Control aphid vectors with insecticides',
                'Use virus-free planting material',
              ],
            ),
            const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildDiseaseTrendChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Disease Trend (30 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 6,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 5,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        );
                        String text;
                        switch (value.toInt()) {
                          case 1:
                            text = 'Day 1';
                            break;
                          case 5:
                            text = 'Day 5';
                            break;
                          case 10:
                            text = 'Day 10';
                            break;
                          case 15:
                            text = 'Day 15';
                            break;
                          case 20:
                            text = 'Day 20';
                            break;
                          case 30:
                            text = 'Day 30';
                            break;
                          default:
                            text = '';
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(text, style: style),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 6,
                      reservedSize: 28,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        );
                        return Text(
                          value.toInt().toString(),
                          style: style,
                          textAlign: TextAlign.left,
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: false,
                ),
                minX: 1,
                maxX: 30,
                minY: 0,
                maxY: 24,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(1, 8),
                      const FlSpot(5, 10),
                      const FlSpot(10, 14),
                      const FlSpot(15, 16),
                      const FlSpot(20, 19),
                      const FlSpot(25, 21),
                      const FlSpot(30, 13),
                    ],
                    isCurved: true,
                    color: Colors.red[400],
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.red[400]!,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseCard({
    required String title,
    required String subtitle,
    required String riskLevel,
    required Color riskColor,
    required Color riskTextColor,
    required List<String> treatments,
  }) {
    final hasNotes = diseaseNotes[title]?.isNotEmpty ?? false;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: riskColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: riskColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskTextColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  riskLevel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: riskTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          ...treatments.map((treatment) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: riskTextColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        treatment,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          
          // Notes button and preview
          if (hasNotes)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.note, color: Colors.green[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      diseaseNotes[title]!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Add/Edit Notes button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => TreatmentNotesDialog(
                    diseaseTitle: title,
                    initialNotes: diseaseNotes[title] ?? '',
                    onSave: (notes) {
                      _saveNoteToFirestore(title, notes);
                    },
                  ),
                );
              },
              icon: Icon(
                hasNotes ? Icons.edit_note : Icons.note_add,
                size: 18,
              ),
              label: Text(hasNotes ? 'Edit Notes' : 'Add Notes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green[700],
                side: BorderSide(color: Colors.green[700]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
