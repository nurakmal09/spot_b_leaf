import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../auth.dart';
import '../widgets/bottom_nav_bar.dart';
import 'add_plant_page.dart';
import '../widgets/edit_field_dialog.dart';
import '../widgets/plant_details_dialog.dart';
import '../services/qr_migration_service.dart';
import 'settings_page.dart';

class MyGardenPage extends StatefulWidget {
  const MyGardenPage({super.key});

  @override
  State<MyGardenPage> createState() => _MyGardenPageState();
}

class _MyGardenPageState extends State<MyGardenPage> {
  final Auth _auth = Auth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final QRMigrationService _qrMigrationService = QRMigrationService();
  StreamSubscription<QuerySnapshot>? _fieldsSubscription;
  StreamSubscription<QuerySnapshot>? _plantsSubscription;
  
  // Scroll controllers for synchronized scrolling
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();
  
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
    // Load data in parallel for faster initialization
    _loadFieldsFromFirestore();
    _loadPlantsFromFirestore();
    // Run migration asynchronously without blocking UI
    _runQRMigrationAsync();
    
    // Sync scroll controllers
    _horizontalScrollController.addListener(() {
      if (_headerScrollController.hasClients) {
        _headerScrollController.jumpTo(_horizontalScrollController.offset);
      }
    });
    
    _verticalScrollController.addListener(() {
      if (_sidebarScrollController.hasClients) {
        _sidebarScrollController.jumpTo(_verticalScrollController.offset);
      }
    });
  }

  // Run QR code migration for existing plants (async, non-blocking)
  void _runQRMigrationAsync() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Run migration in background without blocking UI
    _qrMigrationService.runMigration(user.uid).catchError((_) {
      // Silently fail - migration is not critical for app functionality
    });
  }

  @override
  void dispose() {
    _fieldsSubscription?.cancel();
    _plantsSubscription?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _headerScrollController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  // Load fields from Firestore with caching
  void _loadFieldsFromFirestore() {
    final user = _auth.currentUser;
    if (user == null) return;

    _fieldsSubscription = _firestore
        .collection('field')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      // Only update if there are actual changes
      bool hasChanges = false;
      final newFields = <String, Map<String, dynamic>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final fieldName = data['field_name'] as String? ?? 'Unnamed Field';
        
        // Check if this is a new field
        if (!fields.containsKey(fieldName)) {
          hasChanges = true;
        }
        
        // Initialize field structure, plants will be loaded separately
        newFields[fieldName] = {
          'totalPlants': 0,
          'healthy': 0,
          'diseased': 0,
          'warning': 0,
          'plants': <PlantStatus>[],
        };
      }

      // Only update state if there are changes
      if (hasChanges || fields.isEmpty) {
        setState(() {
          fields.clear();
          fields.addAll(newFields);

          // Update selected field if needed
          if (!fields.containsKey(selectedField) && fields.isNotEmpty) {
            selectedField = fields.keys.first;
          }
        });
      }
    });
  }

  // Load plants from Firestore and update field statistics (optimized)
  void _loadPlantsFromFirestore() {
    final user = _auth.currentUser;
    if (user == null) return;

    _plantsSubscription = _firestore
        .collection('plant')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      // Batch process all changes before calling setState once
      final newPlantDocuments = <String, List<Map<String, dynamic>>>{};
      final fieldStats = <String, Map<String, dynamic>>{};

      // Initialize stats for all fields
      for (var fieldName in fields.keys) {
        fieldStats[fieldName] = {
          'totalPlants': 0,
          'healthy': 0,
          'diseased': 0,
          'warning': 0,
          'plants': <PlantStatus>[],
        };
      }

      // Process all plants in a single pass
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final fieldName = data['field_name'] as String?;
        final statusList = data['status'] as List<dynamic>?;
        
        if (fieldName != null && fields.containsKey(fieldName)) {
          // Store plant document with its ID
          if (!newPlantDocuments.containsKey(fieldName)) {
            newPlantDocuments[fieldName] = [];
          }
          newPlantDocuments[fieldName]!.add({
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
              fieldStats[fieldName]!['diseased'] = (fieldStats[fieldName]!['diseased'] as int) + 1;
            } else if (statusStr == 'warning') {
              plantStatus = PlantStatus.warning;
              fieldStats[fieldName]!['warning'] = (fieldStats[fieldName]!['warning'] as int) + 1;
            } else {
              fieldStats[fieldName]!['healthy'] = (fieldStats[fieldName]!['healthy'] as int) + 1;
            }
          } else {
            fieldStats[fieldName]!['healthy'] = (fieldStats[fieldName]!['healthy'] as int) + 1;
          }
          
          // Add plant to field's plant list
          (fieldStats[fieldName]!['plants'] as List<PlantStatus>).add(plantStatus);
          fieldStats[fieldName]!['totalPlants'] = (fieldStats[fieldName]!['totalPlants'] as int) + 1;
        }
      }

      // Single setState call with all updates
      setState(() {
        plantDocuments.clear();
        plantDocuments.addAll(newPlantDocuments);
        
        // Update field stats
        for (var fieldName in fieldStats.keys) {
          fields[fieldName]!.addAll(fieldStats[fieldName]!);
        }
      });
    });
  }

  // Save field to Firestore
  Future<void> _saveFieldToFirestore(String fieldName, Map<String, dynamic> fieldData) async {
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
                      'Please sign in to save fields',
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
      // First, delete all plants associated with this field
      final plantsQuery = await _firestore
          .collection('plant')
          .where('userId', isEqualTo: user.uid)
          .where('field_name', isEqualTo: fieldName)
          .get();

      // Delete all plants in batch
      final batch = _firestore.batch();
      for (var doc in plantsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Then delete the field document
      final docId = '${user.uid}_${fieldName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _firestore.collection('field').doc(docId).delete();

      // Show success notification
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
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Field and ${plantsQuery.docs.length} plant(s) deleted successfully',
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
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        });
      }
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
                      'Error deleting field: $e',
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

  // Rename field in Firestore
  Future<void> _renameFieldInFirestore(String oldName, String newName, Map<String, dynamic> fieldData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Update all plants with the new field name
      final plantsQuery = await _firestore
          .collection('plant')
          .where('userId', isEqualTo: user.uid)
          .where('field_name', isEqualTo: oldName)
          .get();

      // Update plants in batch
      final batch = _firestore.batch();
      for (var doc in plantsQuery.docs) {
        batch.update(doc.reference, {'field_name': newName});
      }
      await batch.commit();

      // Delete old field document
      final oldDocId = '${user.uid}_${oldName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _firestore.collection('field').doc(oldDocId).delete();

      // Create new field document
      final newDocId = '${user.uid}_${newName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';
      await _firestore.collection('field').doc(newDocId).set({
        'userId': user.uid,
        'field_name': newName,
      });

      // Show success notification
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
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Field renamed and ${plantsQuery.docs.length} plant(s) updated',
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
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        });
      }
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
                      'Error renaming field: $e',
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
                    const SizedBox(height: 20),

                    // "My Fields" Title
                    const Text(
                      'My Fields',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

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
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.fromARGB(255, 99, 144, 83),
                                Color.fromARGB(255, 23, 147, 33),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showAddPlantDialog();
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Plant'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
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
        height: 100, // Increased height to prevent overflow
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name.substring(name.length - 1) : '?',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${data['totalPlants']} plants • ${data['diseased']} diseased',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
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
    // Get plant documents for the selected field
    final fieldPlants = plantDocuments[selectedField] ?? [];
    
    if (fieldPlants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.green[100]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grass,
                size: 64,
                color: Colors.green[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No plants in this field yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click "Add Plant" to start planting',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Grid dimensions: 50 sections × 50 rows
    const int maxSections = 50;
    const int maxRows = 50;

    // Create a map for quick plant lookup by position
    final Map<String, Map<String, dynamic>> plantPositions = {};
    for (var plant in fieldPlants) {
      final section = plant['section'] as int? ?? 1;
      final row = plant['row'] as int? ?? 1;
      final key = '${section}_$row';
      plantPositions[key] = plant;
    }

    return Container(
      height: 480, // Fixed height for the grid container
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green[100]!,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.grid_on, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Field Map (Pan to navigate)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '50×50 grid',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable grid with sticky headers
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Top row: corner + column headers
                  Row(
                    children: [
                      // Corner box
                      Container(
                        width: 50,
                        height: 30,
                        color: Colors.green[100],
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.grid_on,
                          size: 16,
                          color: Colors.green[800],
                        ),
                      ),
                      // Column headers (R1, R2, R3...)
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _headerScrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            children: List.generate(maxRows, (index) {
                              return Container(
                                width: 60,
                                height: 30,
                                color: Colors.green[50],
                                alignment: Alignment.center,
                                child: Text(
                                  'R${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Main grid area
                  Expanded(
                    child: Row(
                      children: [
                        // Row headers (S1, S2, S3...)
                        SingleChildScrollView(
                          controller: _sidebarScrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: List.generate(maxSections, (sectionIndex) {
                              final sectionNum = sectionIndex + 1;
                              return Container(
                                width: 50,
                                height: 64, // Match cell height
                                color: Colors.green[50],
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  'S$sectionNum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        // Scrollable grid content
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: Column(
                                children: List.generate(maxSections, (sectionIndex) {
                                  final sectionNum = sectionIndex + 1;
                                  return Row(
                                    children: List.generate(maxRows, (rowIndex) {
                                      final rowNum = rowIndex + 1;
                                      final key = '${sectionNum}_$rowNum';
                                      final plantData = plantPositions[key];
                                      
                                      return SizedBox(
                                        width: 60,
                                        height: 64,
                                        child: _buildPlantCell(sectionNum, rowNum, plantData),
                                      );
                                    }),
                                  );
                                }),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildPlantCell(int section, int row, Map<String, dynamic>? plantData) {
    if (plantData == null) {
      // Empty cell - show subtle grid lines
      return Container(
        height: 60,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.1),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    // Determine plant status and color
    final statusList = plantData['status'] as List<dynamic>?;
    String statusStr = 'healthy';
    LinearGradient gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromARGB(255, 17, 95, 17),
        Color.fromARGB(255, 114, 188, 114),
      ],
    );
    Color shadowColor = const Color.fromARGB(255, 17, 95, 17);
    
    if (statusList != null && statusList.isNotEmpty) {
      statusStr = statusList[0].toString().toLowerCase();
      if (statusStr == 'diseased') {
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 200, 50, 50),
            Color.fromARGB(255, 251, 133, 133),
          ],
        );
        shadowColor = const Color.fromARGB(255, 200, 50, 50);
      } else if (statusStr == 'warning') {
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 230, 140, 0),
            Color.fromARGB(255, 247, 190, 117),
          ],
        );
        shadowColor = const Color.fromARGB(255, 230, 140, 0);
      }
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => PlantDetailsDialog(
            plantData: plantData,
            documentId: plantData['documentId'] as String,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.3),
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
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              plantData['plant_id'] as String? ?? '',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPlantPage(
          fieldName: selectedField,
        ),
      ),
    );
  }
}

enum PlantStatus {
  healthy,
  warning,
  diseased,
}
