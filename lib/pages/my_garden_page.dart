import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../auth.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/add_plant_dialog.dart';
import '../widgets/edit_field_dialog.dart';
import '../widgets/plant_details_dialog.dart';
import 'settings_page.dart';

class MyGardenPage extends StatefulWidget {
  const MyGardenPage({super.key});

  @override
  State<MyGardenPage> createState() => _MyGardenPageState();
}

class _MyGardenPageState extends State<MyGardenPage> {
  final Auth _auth = Auth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _fieldsSubscription;
  StreamSubscription<QuerySnapshot>? _plantsSubscription;
  
  DateTime selectedDate = DateTime.now();
  String selectedField = 'Field A';
  
  // Store plant documents with their data
  final Map<String, List<Map<String, dynamic>>> plantDocuments = {};
  
  // Plant status data
  final Map<String, Map<String, dynamic>> fields = {
    'Field A': {
      'totalPlants': 47,
      'healthy': 34,
      'diseased': 13,
      'plants': [
        PlantStatus.healthy, PlantStatus.healthy, PlantStatus.diseased, PlantStatus.warning, PlantStatus.healthy,
        PlantStatus.healthy, PlantStatus.healthy, PlantStatus.diseased, PlantStatus.warning, PlantStatus.healthy,
        PlantStatus.healthy, PlantStatus.healthy, PlantStatus.diseased, PlantStatus.warning, PlantStatus.healthy,
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _loadFieldsFromFirestore();
    _loadPlantsFromFirestore();
  }

  @override
  void dispose() {
    _fieldsSubscription?.cancel();
    _plantsSubscription?.cancel();
    super.dispose();
  }

  // Load fields from Firestore
  void _loadFieldsFromFirestore() {
    final user = _auth.currentUser;
    if (user == null) return;

    _fieldsSubscription = _firestore
        .collection('field')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      setState(() {
        // Clear default field if we have Firestore data
        if (snapshot.docs.isNotEmpty) {
          fields.clear();
        }

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final fieldName = data['field_name'] as String? ?? 'Unnamed Field';
          
          // Initialize field structure, plants will be loaded separately
          fields[fieldName] = {
            'totalPlants': 0,
            'healthy': 0,
            'diseased': 0,
            'warning': 0,
            'plants': <PlantStatus>[],
          };
        }

        // Update selected field if needed
        if (!fields.containsKey(selectedField) && fields.isNotEmpty) {
          selectedField = fields.keys.first;
        }
      });
    });
  }

  // Load plants from Firestore and update field statistics
  void _loadPlantsFromFirestore() {
    final user = _auth.currentUser;
    if (user == null) return;

    _plantsSubscription = _firestore
        .collection('plant')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        // Reset all field plant counts and documents
        for (var fieldName in fields.keys) {
          fields[fieldName]!['totalPlants'] = 0;
          fields[fieldName]!['healthy'] = 0;
          fields[fieldName]!['diseased'] = 0;
          fields[fieldName]!['warning'] = 0;
          fields[fieldName]!['plants'] = <PlantStatus>[];
        }
        plantDocuments.clear();

        // Count plants per field
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final fieldName = data['field_name'] as String?;
          final statusList = data['status'] as List<dynamic>?;
          
          if (fieldName != null && fields.containsKey(fieldName)) {
            // Store plant document with its ID
            if (!plantDocuments.containsKey(fieldName)) {
              plantDocuments[fieldName] = [];
            }
            plantDocuments[fieldName]!.add({
              'documentId': doc.id,
              ...data,
            });
            
            // Determine plant status
            PlantStatus plantStatus = PlantStatus.healthy;
            String statusStr = 'healthy';
            
            if (statusList != null && statusList.isNotEmpty) {
              statusStr = statusList[0].toString().toLowerCase();
              if (statusStr == 'diseased') {
                plantStatus = PlantStatus.diseased;
                fields[fieldName]!['diseased'] = (fields[fieldName]!['diseased'] as int) + 1;
              } else if (statusStr == 'warning') {
                plantStatus = PlantStatus.warning;
                fields[fieldName]!['warning'] = (fields[fieldName]!['warning'] as int) + 1;
              } else {
                fields[fieldName]!['healthy'] = (fields[fieldName]!['healthy'] as int) + 1;
              }
            } else {
              fields[fieldName]!['healthy'] = (fields[fieldName]!['healthy'] as int) + 1;
            }
            
            // Add plant to field's plant list
            (fields[fieldName]!['plants'] as List<PlantStatus>).add(plantStatus);
            fields[fieldName]!['totalPlants'] = (fields[fieldName]!['totalPlants'] as int) + 1;
          }
        }
      });
    });
  }

  // Save field to Firestore
  Future<void> _saveFieldToFirestore(String fieldName, Map<String, dynamic> fieldData) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to save fields'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Create a document ID based on userId and fieldName
      final docId = '${user.uid}_${fieldName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      
      // Only store field name and userId
      // Plant counts will be calculated from actual plants in the plant collection
      await _firestore.collection('field').doc(docId).set({
        'userId': user.uid,
        'field_name': fieldName,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving field: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete field from Firestore
  Future<void> _deleteFieldFromFirestore(String fieldName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final docId = '${user.uid}_${fieldName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _firestore.collection('field').doc(docId).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting field: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Rename field in Firestore
  Future<void> _renameFieldInFirestore(String oldName, String newName, Map<String, dynamic> fieldData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Delete old document
      final oldDocId = '${user.uid}_${oldName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _firestore.collection('field').doc(oldDocId).delete();

      // Create new document
      final newDocId = '${user.uid}_${newName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _firestore.collection('field').doc(newDocId).set({
        'userId': user.uid,
        'field_name': newName,
        'diseased': fieldData['diseased'] ?? 0,
        'plants': fieldData['totalPlants'] ?? 0,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming field: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldData = fields[selectedField]!;
    
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
                  colors: [Colors.green[600]!, Colors.green[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                            'My Garden',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap plants for details',
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
                    // Date Selector
                    _buildDateSelector(),
                    const SizedBox(height: 16),

                    // Field Selector
                    // Field Selector (shows multiple fields, selectable and editable)
                    _buildFieldSelector(fieldData),
                    const SizedBox(height: 20),

                    // Statistics Cards
                    _buildStatisticsCards(fieldData),
                    const SizedBox(height: 24),

                    // Field Layout Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$selectedField Layout',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            _showAddPlantDialog();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Plant'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Plant Grid Layout
                    _buildPlantGrid(fieldData['plants']),
                    const SizedBox(height: 24),

                    // Status Legend
                    _buildStatusLegend(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 1));
              });
            },
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '${_getMonthName(selectedDate.month)} ${selectedDate.day}, ${selectedDate.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFieldSelector(Map<String, dynamic> fieldData) {
    // Build a horizontal field selector where each field can be selected or edited.
    final fieldNames = fields.keys.toList();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: fieldNames.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == fieldNames.length) {
              // Add new field card
              return GestureDetector(
                onTap: () => _showEditFieldDialog(isNew: true),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 4),
                    ],
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, color: Colors.green, size: 28),
                      SizedBox(height: 8),
                      Text('Add Field', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }

            final name = fieldNames[index];
            final data = fields[name]!;
            final isSelected = name == selectedField;

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedField = name;
                });
              },
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green[50] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.06), blurRadius: 4)],
                  border: Border.all(
                    color: isSelected ? Colors.green[400]! : Colors.grey.withValues(alpha: 0.18),
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name.substring(name.length - 1) : '?',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${data['totalPlants']} plants • ${data['diseased']} diseased', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: Colors.grey[700],
                      onPressed: () => _showEditFieldDialog(isNew: false, name: name),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditFieldDialog({required bool isNew, String? name}) {
    showDialog(
      context: context,
      builder: (context) => EditFieldDialog(
        initialName: name,
        isNew: isNew,
        onSave: (newName) {
          // Prevent duplicate names
          if (!isNew && name != null && newName == name) {
            // nothing changed
            return;
          }

          if (fields.containsKey(newName) && (isNew || newName != name)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('A field with that name already exists')),
            );
            return;
          }

          setState(() {
            if (isNew) {
              // create new field with default data
              final newFieldData = {
                'totalPlants': 0,
                'healthy': 0,
                'diseased': 0,
                'plants': <PlantStatus>[],
              };
              fields[newName] = newFieldData;
              selectedField = newName;
              
              // Save to Firestore
              _saveFieldToFirestore(newName, newFieldData);
            } else if (name != null) {
              // rename field key
              final old = fields.remove(name);
              if (old != null) {
                fields[newName] = old;
                selectedField = newName;
                
                // Update in Firestore
                _renameFieldInFirestore(name, newName, old);
              }
            }
          });
        },
        onDelete: isNew
            ? null
            : () {
                // delete the field
                if (fields.length <= 1) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('At least one field must remain')),
                  );
                  return;
                }

                setState(() {
                  fields.remove(name);
                  // choose another field to show
                  selectedField = fields.keys.first;
                  
                  // Delete from Firestore
                  if (name != null) {
                    _deleteFieldFromFirestore(name);
                  }
                });
              },
      ),
    );
  }

  Widget _buildStatisticsCards(Map<String, dynamic> fieldData) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: fieldData['totalPlants'].toString(),
            label: 'Total Plants',
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: fieldData['healthy'].toString(),
            label: 'Healthy',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            value: fieldData['diseased'].toString(),
            label: 'Diseased',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantGrid(List<PlantStatus> plants) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green[100]!,
          width: 2,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: plants.length,
        itemBuilder: (context, index) {
          return _buildPlantItem(index, plants[index]);
        },
      ),
    );
  }

  Widget _buildPlantItem(int index, PlantStatus status) {
    Color color;
    switch (status) {
      case PlantStatus.healthy:
        color = Colors.green;
        break;
      case PlantStatus.warning:
        color = Colors.orange;
        break;
      case PlantStatus.diseased:
        color = Colors.red;
        break;
    }

    return GestureDetector(
      onTap: () {
        // Get plant document data for this field
        final fieldPlants = plantDocuments[selectedField];
        if (fieldPlants != null && index < fieldPlants.length) {
          final plantData = fieldPlants[index];
          showDialog(
            context: context,
            builder: (context) => PlantDetailsDialog(
              plantData: plantData,
              documentId: plantData['documentId'] as String,
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 50,
                maxHeight: 50,
              ),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.eco,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (index + 1).toString(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Legend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.green, 'Healthy'),
              _buildLegendItem(Colors.orange, 'Warning'),
              _buildLegendItem(Colors.red, 'Diseased'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  void _showAddPlantDialog() {
    showDialog(
      context: context,
      builder: (context) => AddPlantDialog(
        fieldName: selectedField,
      ),
    );
  }
}

enum PlantStatus {
  healthy,
  warning,
  diseased,
}
