import 'package:flutter/material.dart';
import 'plant_added_success_dialog.dart';

class AddPlantDialog extends StatefulWidget {
  final String fieldName;

  const AddPlantDialog({
    super.key,
    required this.fieldName,
  });

  @override
  State<AddPlantDialog> createState() => _AddPlantDialogState();
}

class _AddPlantDialogState extends State<AddPlantDialog> {
  final plantIdController = TextEditingController();
  final sectionController = TextEditingController();
  final rowController = TextEditingController();
  final plantAgeController = TextEditingController();
  final notesController = TextEditingController();
  String selectedStatus = 'Healthy';

  @override
  void dispose() {
    plantIdController.dispose();
    sectionController.dispose();
    rowController.dispose();
    plantAgeController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Plant',
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field Info Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Adding to: ${widget.fieldName}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

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
                                hintText: 'e.g., A, B',
                                icon: Icons.grid_view,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Plant Age Field
                    _buildLabel('Plant Age *'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: plantAgeController,
                      hintText: 'e.g., 6 months, 1 year',
                      icon: Icons.calendar_today,
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
                            Colors.green,
                            () => setState(() => selectedStatus = 'Healthy'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusButton(
                            'Warning',
                            selectedStatus == 'Warning',
                            Colors.orange,
                            () => setState(() => selectedStatus = 'Warning'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatusButton(
                            'Diseased',
                            selectedStatus == 'Diseased',
                            Colors.red,
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
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Add any observations or notes about this plant...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: Icon(Icons.note, color: Colors.grey[600]),
                        ),
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
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Close the add plant dialog
                        Navigator.pop(context);
                        
                        // Show success dialog
                        showDialog(
                          context: context,
                          builder: (context) => PlantAddedSuccessDialog(
                            plantId: plantIdController.text.isEmpty 
                                ? 'n' 
                                : plantIdController.text,
                            section: sectionController.text,
                            row: rowController.text,
                            age: plantAgeController.text,
                            status: selectedStatus,
                            fieldName: widget.fieldName,
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
                        'Add Plant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Cancel',
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
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[600]),
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
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
