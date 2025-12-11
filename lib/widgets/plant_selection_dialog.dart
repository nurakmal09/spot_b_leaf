import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

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
  bool _showQRScanner = false;
  
  List<String> _fields = [];
  List<Map<String, dynamic>> _plants = [];
  
  final GlobalKey qrKey = GlobalKey(debugLabel: 'PlantQR');
  QRViewController? _qrController;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  @override
  void dispose() {
    _qrController?.dispose();
    super.dispose();
  }

  Future<void> _loadFields() async {
    setState(() {
      _isLoadingFields = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('field')
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
      
      final snapshot = await FirebaseFirestore.instance
          .collection('plant')
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
        final aId = a['plant_id'] as String;
        final bId = b['plant_id'] as String;
        return aId.compareTo(bId);
      });

      debugPrint('Successfully processed ${plants.length} plants, updating UI...');

      if (mounted) {
        setState(() {
          _plants = plants;
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

  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null) {
        controller.pauseCamera();
        await _loadPlantByQRCode(scanData.code!);
      }
    });
  }

  Future<void> _loadPlantByQRCode(String qrCode) async {
    try {
      debugPrint('Searching for plant with QR code: $qrCode');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('plant')
          .where('qr_code_id', isEqualTo: qrCode)
          .limit(1)
          .get();

      debugPrint('QR code search results: ${snapshot.docs.length} plant(s) found');

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        
        debugPrint('Plant found: ${data['plant_id']} in field ${data['field']}');
        
        setState(() {
          _selectedPlantData = data;
          _selectedPlant = doc.id;
          _showQRScanner = false;
        });

        // Return the selected plant
        if (mounted) {
          Navigator.pop(context, {
            'plantId': doc.id,
            'plantData': data,
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plant not found. Please try again.'),
              backgroundColor: Colors.orange,
            ),
          );
          _qrController?.resumeCamera();
        }
      }
    } catch (e) {
      debugPrint('Error loading plant by QR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        _qrController?.resumeCamera();
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
            Flexible(
              child: _showQRScanner ? _buildQRScanner() : _buildManualSelection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green[300]!, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              const Text(
                'Scan Plant QR Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Position the QR code within the frame',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showQRScanner = false;
                  });
                  _qrController?.dispose();
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Manual Selection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // QR Scan Option
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showQRScanner = true;
                });
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Plant QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[400])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[400])),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Manual Selection
            Text(
              'Select Manually',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Field Dropdown
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
                                'No fields found in database. Please add plants first.',
                                style: TextStyle(color: Colors.orange[900]),
                              ),
                            ),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedField,
                        decoration: InputDecoration(
                          labelText: 'Select Field',
                          prefixIcon: const Icon(Icons.landscape),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _fields.map((field) {
                          return DropdownMenuItem(
                            value: field,
                            child: Text(field),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedField = value;
                            _selectedPlant = null;
                          });
                          if (value != null) {
                            _loadPlantsInField(value);
                          }
                        },
                      ),
            
            const SizedBox(height: 16),
            
            // Plant Dropdown
            if (_selectedField != null) ...[
              _isLoadingPlants
                  ? const Center(child: CircularProgressIndicator())
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
                                  'No plants found in field "$_selectedField".',
                                  style: TextStyle(color: Colors.orange[900]),
                                ),
                              ),
                            ],
                          ),
                        )
                      : DropdownButtonFormField<String>(
                      value: _selectedPlant,
                      decoration: InputDecoration(
                        labelText: 'Select Plant',
                        prefixIcon: const Icon(Icons.eco),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _plants.map((plant) {
                        return DropdownMenuItem<String>(
                          value: plant['id'] as String,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 12,
                                color: _getStatusColor(plant['status']),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${plant['plant_id']} (Section ${plant['section']}, Row ${plant['row']})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPlant = value;
                          _selectedPlantData = _plants
                              .firstWhere((p) => p['id'] == value)['data'];
                        });
                      },
                    ),
              
              const SizedBox(height: 20),
              
              // Confirm Button
              ElevatedButton(
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'sick':
        return Colors.red;
      case 'monitoring':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
