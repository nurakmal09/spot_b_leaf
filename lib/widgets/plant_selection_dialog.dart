import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlantSelectionDialog extends StatefulWidget {
  const PlantSelectionDialog({super.key});

  @override
  State<PlantSelectionDialog> createState() => _PlantSelectionDialogState();
}

class _PlantSelectionDialogState extends State<PlantSelectionDialog> {
  String? _selectedField;
  String? _selectedPlant;
  Map<String, dynamic>? _selectedPlantData;
  bool _isLoadingFields = false;
  bool _isLoadingPlants = false;
  
  List<String> _fields = [];
  List<String> _filteredFields = [];
  List<Map<String, dynamic>> _plants = [];
  List<Map<String, dynamic>> _filteredPlants = [];
  
  final TextEditingController _fieldSearchController = TextEditingController();
  final TextEditingController _plantSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  @override
  void dispose() {
    _fieldSearchController.dispose();
    _plantSearchController.dispose();
    super.dispose();
  }

  void _filterFields(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFields = List.from(_fields);
      } else {
        _filteredFields = _fields
            .where((field) => field.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _filterPlants(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPlants = List.from(_plants);
      } else {
        _filteredPlants = _plants.where((plant) {
          final plantId = (plant['plant_id'] as String).toLowerCase();
          final section = plant['section'].toString();
          final row = plant['row'].toString();
          final searchQuery = query.toLowerCase();
          return plantId.contains(searchQuery) ||
              section.contains(searchQuery) ||
              row.contains(searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _loadFields() async {
    setState(() {
      _isLoadingFields = true;
    });

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        setState(() {
          _isLoadingFields = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('field')
          .where('userId', isEqualTo: user.uid)
          .get();

      debugPrint('Total fields in database: ${snapshot.docs.length}');

      final fields = snapshot.docs
          .map((doc) => doc.data()['field_name']?.toString())
          .where((field) => field != null && field.isNotEmpty)
          .toList();

      fields.sort();

      debugPrint('Fields found: ${fields.length} - $fields');

      setState(() {
        _fields = fields.cast<String>();
        _filteredFields = List.from(_fields);
        _isLoadingFields = false;
      });
    } catch (e) {
      debugPrint('Error loading fields: $e');
      setState(() {
        _isLoadingFields = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading fields: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPlantsInField(String field) async {
    setState(() {
      _isLoadingPlants = true;
      _selectedPlant = null;
      _selectedPlantData = null;
      _plants = [];
    });

    try {
      debugPrint('Loading plants for field: $field');
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No user logged in');
        setState(() {
          _isLoadingPlants = false;
        });
        return;
      }
      
      final snapshot = await FirebaseFirestore.instance
          .collection('plant')
          .where('userId', isEqualTo: user.uid)
          .where('field_name', isEqualTo: field)
          .get();

      debugPrint('Plants found in field "$field": ${snapshot.docs.length}');

      final plants = snapshot.docs.map((doc) {
        final data = doc.data();
        final plantId = data['plant_id']?.toString() ?? 'Unknown';
        final section = data['section']?.toString() ?? 'N/A';
        final row = data['row']?.toString() ?? 'N/A';
        final status = data['status']?.toString() ?? 'unknown';
        
        debugPrint('Plant: ${doc.id} - $plantId (Section: $section, Row: $row)');
        
        return {
          'id': doc.id,
          'plant_id': plantId,
          'section': section,
          'row': row,
          'status': status,
          'data': data,
        };
      }).toList();

      plants.sort((a, b) {
        // Sort by section first, then by row
        final aSection = int.tryParse(a['section'].toString()) ?? 0;
        final bSection = int.tryParse(b['section'].toString()) ?? 0;
        
        if (aSection != bSection) {
          return aSection.compareTo(bSection);
        }
        
        // If sections are equal, sort by row
        final aRow = int.tryParse(a['row'].toString()) ?? 0;
        final bRow = int.tryParse(b['row'].toString()) ?? 0;
        return aRow.compareTo(bRow);
      });

      debugPrint('Successfully processed ${plants.length} plants, updating UI...');

      if (mounted) {
        setState(() {
          _plants = plants;
          _filteredPlants = List.from(_plants);
          _plantSearchController.clear();
          _isLoadingPlants = false;
        });
        debugPrint('UI updated successfully');
      }
    } catch (e) {
      debugPrint('Error loading plants: $e');
      debugPrint('Error details: ${e.toString()}');
      
      setState(() {
        _isLoadingPlants = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading plants: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Plant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildManualSelection(),
            ),

            // Fixed Confirm Button at bottom
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _selectedPlant != null
                    ? () {
                        Navigator.pop(context, {
                          'plantId': _selectedPlant,
                          'plantData': _selectedPlantData,
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Confirm Selection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Field Search Box
            if (_fields.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _fieldSearchController,
                  onChanged: _filterFields,
                  decoration: InputDecoration(
                    hintText: 'Search fields...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _fieldSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _fieldSearchController.clear();
                              _filterFields('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            
            // Field Selection List
            _isLoadingFields
                ? const Center(child: CircularProgressIndicator())
                : _fields.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No fields found. Please add fields first.',
                                style: TextStyle(color: Colors.orange[900]),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _filteredFields.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_off, color: Colors.grey[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No fields match your search.',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            // Fields label
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                children: [
                                  Text(
                                    'Fields',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Field items
                            ..._filteredFields.asMap().entries.map((entry) {
                              final index = entry.key;
                              final field = entry.value;
                              final isSelected = _selectedField == field;
                              final isLast = index == _filteredFields.length - 1;
                              
                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedField = field;
                                        _selectedPlant = null;
                                      });
                                      _loadPlantsInField(field);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.green[50] : Colors.transparent,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green[100],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.landscape,
                                              size: 20,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              field,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? Colors.green[700] : Colors.grey[800],
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green[600],
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Divider(
                                      height: 1,
                                      indent: 56,
                                      color: Colors.grey[200],
                                    ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
            
            const SizedBox(height: 20),
            
            // Plant Selection List
            if (_selectedField != null) ...[
              Row(
                children: [
                  Text(
                    'Plants in $_selectedField',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  if (_plants.isNotEmpty)
                    Text(
                      '${_filteredPlants.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Plant Search Box
              if (_plants.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _plantSearchController,
                    onChanged: _filterPlants,
                    decoration: InputDecoration(
                      hintText: 'Search plants...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _plantSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _plantSearchController.clear();
                                _filterPlants('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              _isLoadingPlants
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _plants.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No plants found in "$_selectedField".',
                                  style: TextStyle(color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _filteredPlants.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.search_off, color: Colors.grey[600]),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No plants match your search.',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              // Plants label
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                child: Row(
                                  children: [
                                    Text(
                                      'Available Plants',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Plant items
                              ..._filteredPlants.asMap().entries.map((entry) {
                                final index = entry.key;
                                final plant = entry.value;
                                final plantId = plant['id'] as String;
                                final isSelected = _selectedPlant == plantId;
                                final isLast = index == _filteredPlants.length - 1;
                                // Get status from status list (matching my_garden_page logic)
                                final statusList = plant['data']['status'] as List<dynamic>?;
                                String statusStr = 'healthy';
                                if (statusList != null && statusList.isNotEmpty) {
                                  statusStr = statusList[0].toString().toLowerCase();
                                }
                                final statusColor = _getStatusColor(statusStr);
                                
                                return Column(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedPlant = plantId;
                                          _selectedPlantData = plant['data'];
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.green[50] : Colors.transparent,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.eco,
                                                size: 20,
                                                color: statusColor,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    plant['plant_id'] as String,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                      color: isSelected ? Colors.green[700] : Colors.grey[800],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Section ${plant['section']}, Row ${plant['row']}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green[600],
                                                size: 20,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!isLast)
                                      Divider(
                                        height: 1,
                                        indent: 56,
                                        color: Colors.grey[200],
                                      ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return const Color.fromARGB(255, 17, 95, 17);
      case 'diseased':
        return const Color.fromARGB(255, 200, 50, 50);
      case 'warning':
        return const Color.fromARGB(255, 230, 140, 0);
      default:
        return Colors.grey;
    }
  }
}
