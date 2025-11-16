import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth.dart';
import '../widgets/plant_added_success_dialog.dart';

class AddPlantPage extends StatefulWidget {
  final String fieldName;

  const AddPlantPage({
    super.key,
    required this.fieldName,
  });

  @override
  State<AddPlantPage> createState() => _AddPlantPageState();
}

class _AddPlantPageState extends State<AddPlantPage> {
  final Auth _auth = Auth();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final plantIdController = TextEditingController();
  final sectionController = TextEditingController();
  final rowController = TextEditingController();
  final notesController = TextEditingController();
  DateTime? selectedPlantingDate;
  String selectedStatus = 'Healthy';
  bool _isSaving = false;

  @override
  void dispose() {
    plantIdController.dispose();
    sectionController.dispose();
    rowController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _selectPlantingDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedPlantingDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.green[600]!,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedPlantingDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.green[600]!,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          selectedPlantingDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _savePlantToFirestore() async {
    // Validate required fields
    if (plantIdController.text.trim().isEmpty ||
        sectionController.text.trim().isEmpty ||
        rowController.text.trim().isEmpty) {
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
                    'Please fill in all required fields (Plant ID, Section, Row)',
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
      return;
    }

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
                      'Please sign in to add plants',
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

    setState(() => _isSaving = true);

    try {
      // Parse section and row to integers if possible
      final section = int.tryParse(sectionController.text.trim()) ?? 1;
      final row = int.tryParse(rowController.text.trim()) ?? 1;
      
      // Convert status to array format matching Firestore schema
      List<String> statusArray = [];
      if (selectedStatus == 'Healthy') {
        statusArray = ['healthy'];
      } else if (selectedStatus == 'Warning') {
        statusArray = ['warning'];
      } else if (selectedStatus == 'Diseased') {
        statusArray = ['diseased'];
      }

      // Generate unique QR code ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final qrCodeId = '${user.uid}_${widget.fieldName}_${plantIdController.text.trim()}_$timestamp';

      // Create plant document
      await _firestore.collection('plant').add({
        'userId': user.uid,
        'field_name': widget.fieldName,
        'plant_id': plantIdController.text.trim(),
        'section': section,
        'row': row,
        'day_first_plant': selectedPlantingDate != null 
            ? Timestamp.fromDate(selectedPlantingDate!) 
            : FieldValue.serverTimestamp(),
        'notes': notesController.text.trim(),
        'status': statusArray,
        'qr_code_id': qrCodeId,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isSaving = false);
        
        // Go back to previous page
        Navigator.pop(context);
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => PlantAddedSuccessDialog(
            plantId: plantIdController.text.trim(),
            section: sectionController.text.trim(),
            row: rowController.text.trim(),
            age: selectedPlantingDate != null 
                ? '${selectedPlantingDate!.day}/${selectedPlantingDate!.month}/${selectedPlantingDate!.year}'
                : 'Not specified',
            status: selectedStatus,
            fieldName: widget.fieldName,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
                      'Error adding plant: $e',
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
            // Header Section
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
                                'Add New Plant',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Create plant record',
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
                  // Field Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.agriculture,
                            color: Colors.green[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Adding to Field',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.fieldName,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Plant ID Field
                  _buildLabel('Plant ID *'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: plantIdController,
                    hintText: 'e.g., BN-001, Plant A-1',
                    icon: Icons.tag,
                    helperText: 'Enter a unique identifier for this plant',
                  ),
                  const SizedBox(height: 20),

                  // Section and Row Fields (side by side)
                  Row(
                    children: [
                      // Section Field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Section *'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: sectionController,
                              hintText: 'e.g., 1, 2, 3',
                              icon: Icons.grid_view,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Row Field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Row *'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: rowController,
                              hintText: 'e.g., 1, 2, 3',
                              icon: Icons.view_headline,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Day Planted Field
                  _buildLabel('Day Planted *'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectPlantingDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.green[600], size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedPlantingDate != null
                                  ? '${selectedPlantingDate!.day}/${selectedPlantingDate!.month}/${selectedPlantingDate!.year} at ${selectedPlantingDate!.hour.toString().padLeft(2, '0')}:${selectedPlantingDate!.minute.toString().padLeft(2, '0')}'
                                  : 'Select date and time',
                              style: TextStyle(
                                color: selectedPlantingDate != null 
                                    ? Colors.black87 
                                    : Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Initial Status
                  _buildLabel('Initial Status *'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusButton(
                          'Healthy',
                          selectedStatus == 'Healthy',
                          const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.fromARGB(255, 17, 95, 17),
                              Color.fromARGB(255, 80, 139, 80),
                            ],
                          ),
                          () => setState(() => selectedStatus = 'Healthy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatusButton(
                          'Warning',
                          selectedStatus == 'Warning',
                          const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.fromARGB(255, 230, 140, 0),
                              Color.fromARGB(255, 255, 180, 80),
                            ],
                          ),
                          () => setState(() => selectedStatus = 'Warning'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatusButton(
                          'Diseased',
                          selectedStatus == 'Diseased',
                          const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.fromARGB(255, 200, 50, 50),
                              Color.fromARGB(255, 255, 100, 100),
                            ],
                          ),
                          () => setState(() => selectedStatus = 'Diseased'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Initial Notes
                  _buildLabel('Initial Notes'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Add any observations or notes about this plant...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: Icon(Icons.note, color: Colors.green[600]),
                      ),
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
                    ),
                  ),
                  const SizedBox(height: 100), // Extra space for button
                ],
              ),
            ),
          ),
          ],
        ),
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
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _savePlantToFirestore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Add Plant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: Colors.green[600]),
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
        helperText: helperText,
        helperStyle: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    String label,
    bool isSelected,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected ? gradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
