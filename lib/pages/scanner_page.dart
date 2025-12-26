import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;
import '../widgets/bottom_nav_bar.dart';
import '../widgets/plant_details_dialog.dart';
import '../widgets/plant_selection_dialog.dart';
import '../services/disease_detection_service.dart';
import '../services/firebase_storage_service.dart';
import 'settings_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  bool isDiseaseMode = false; // false = QR Code, true = Disease
  bool isScanning = true;
  bool showResult = false;
  
  // Camera for disease detection
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  
  // QR Scanner
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;
  String? _qrCodeResult;
  Map<String, dynamic>? _scannedPlantData;
  String? _scannedPlantDocId;
  bool _isLoadingPlantData = false;
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  
  // Disease detection
  final DiseaseDetectionService _diseaseDetectionService = DiseaseDetectionService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  DiseaseDetectionResult? _diseaseResult;
  bool _isDetecting = false;
  String? _uploadedImageUrl;
  String? _capturedImagePath;
  bool _isSaving = false;
  
  // Selected plant for disease detection
  String? _selectedPlantId;
  Map<String, dynamic>? _selectedPlantData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize disease detection service
    _diseaseDetectionService.initialize().catchError((e) {
      debugPrint('Failed to initialize disease detection: $e');
    });
    // Only initialize camera if in disease mode
    if (isDiseaseMode) {
      _initializeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;
    
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _qrController?.dispose();
    _cameraController?.dispose();
    _diseaseDetectionService.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (mounted && scanData.code != null && !_isLoadingPlantData) {
        final qrCode = scanData.code!;
        setState(() {
          _qrCodeResult = qrCode;
          _isLoadingPlantData = true;
        });
        
        // Pause scanning after successful scan
        controller.pauseCamera();
        
        // Fetch plant data from Firestore
        await _fetchPlantData(qrCode);
        
        if (mounted) {
          setState(() {
            showResult = true;
            isScanning = false;
            _isLoadingPlantData = false;
          });
        }
      }
    });
  }

  Future<void> _fetchPlantData(String qrCodeId) async {
    try {
      final userId = 'tYAAISvcmtX2cULWKg3N9USbpUN2'; // TODO: Get from auth
      debugPrint('Searching for QR code: $qrCodeId');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('plant')
          .where('userId', isEqualTo: userId)
          .where('qr_code_id', isEqualTo: qrCodeId)
          .limit(1)
          .get();

      debugPrint('Found ${querySnapshot.docs.length} plants');

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        debugPrint('Plant found: ${doc.data()}');
        setState(() {
          _scannedPlantData = doc.data();
          _scannedPlantDocId = doc.id;
        });
      } else {
        debugPrint('No plant found with qr_code_id: $qrCodeId');
        setState(() {
          _scannedPlantData = null;
          _scannedPlantDocId = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching plant data: $e');
      setState(() {
        _scannedPlantData = null;
        _scannedPlantDocId = null;
      });
    }
  }

  void _toggleMode(bool diseaseMode) async {
    setState(() {
      isDiseaseMode = diseaseMode;
      showResult = false;
      isScanning = true;
      _qrCodeResult = null;
      _selectedPlantId = null;
      _selectedPlantData = null;
    });
    
    // Dispose and reinitialize based on mode
    if (diseaseMode) {
      // Switch to disease mode - pause QR and init camera
      _qrController?.pauseCamera();
      if (!_isCameraInitialized) {
        await _initializeCamera();
      }
    } else {
      // Switch to QR mode - dispose camera and resume QR
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
        setState(() {
          _isCameraInitialized = false;
        });
      }
      _qrController?.resumeCamera();
    }
  }

  Future<bool> _showPlantSelection() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PlantSelectionDialog(),
    );

    if (result != null) {
      setState(() {
        _selectedPlantId = result['plantId'];
        _selectedPlantData = result['plantData'];
      });
      return true;
    }
    return false;
  }

  Future<void> _captureImage() async {
    if (isDiseaseMode && _cameraController != null && _cameraController!.value.isInitialized) {
      // Check if plant is selected
      if (_selectedPlantId == null) {
        final selected = await _showPlantSelection();
        if (!selected) return; // User cancelled selection
      }

      try {
        setState(() {
          _isDetecting = true;
        });

        final image = await _cameraController!.takePicture();
        debugPrint('Image captured: ${image.path}');
        
        // Run disease detection
        final result = await _diseaseDetectionService.detectDisease(image.path);
        debugPrint('Detection result: $result');
        
        setState(() {
          _diseaseResult = result;
          _capturedImagePath = image.path;
          showResult = true;
          isScanning = false;
          _isDetecting = false;
        });
      } catch (e) {
        debugPrint('Error capturing/detecting image: $e');
        setState(() {
          _isDetecting = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error detecting disease: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    try {
      // Check if plant is selected for disease mode
      if (isDiseaseMode && _selectedPlantId == null) {
        final selected = await _showPlantSelection();
        if (!selected) return; // User cancelled selection
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        debugPrint('Image selected: ${image.path}');
        
        if (isDiseaseMode) {
          // Disease mode - run detection
          setState(() {
            _isDetecting = true;
          });

          try {
            final result = await _diseaseDetectionService.detectDisease(image.path);
            debugPrint('Detection result: $result');
            
            // Upload image to Firebase Storage and save detection
            String? imageUrl;
            String? detectionId;
            try {
              final uploadResult = await _storageService.uploadAndSaveDiseaseDetection(
                imagePath: image.path,
                plantId: _selectedPlantId!,
                diseaseType: result.diseaseName,
                confidence: result.confidence,
                additionalData: {
                  'severity': result.severity,
                  'allPredictions': result.probabilities,
                },
              );
              imageUrl = uploadResult['imageUrl'];
              detectionId = uploadResult['detectionId'];
              debugPrint('Image uploaded to Firebase: $imageUrl');
              debugPrint('Detection saved with ID: $detectionId');
            } catch (uploadError) {
              debugPrint('Error uploading to Firebase: $uploadError');
              // Continue showing result even if upload fails
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Warning: Image upload failed - ${uploadError.toString()}'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
            
            setState(() {
              _diseaseResult = result;
              _uploadedImageUrl = imageUrl;
              showResult = true;
              isScanning = false;
              _isDetecting = false;
            });
            
            // Show success message if upload succeeded
            if (mounted && imageUrl != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('\u2713 Image saved to Firebase successfully'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error detecting disease: $e');
            setState(() {
              _isDetecting = false;
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error detecting disease: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // QR mode - decode QR code from image
          setState(() {
            _isLoadingPlantData = true;
          });
          
          final inputImage = mlkit.InputImage.fromFilePath(image.path);
          final barcodeScanner = mlkit.BarcodeScanner();
          
          try {
            final List<mlkit.Barcode> barcodes = await barcodeScanner.processImage(inputImage);
            
            if (barcodes.isNotEmpty && barcodes.first.displayValue != null) {
              final qrCode = barcodes.first.displayValue!;
              debugPrint('QR Code decoded: $qrCode');
              
              setState(() {
                _qrCodeResult = qrCode;
              });
              
              // Fetch plant data
              await _fetchPlantData(qrCode);
              
              setState(() {
                showResult = true;
                isScanning = false;
                _isLoadingPlantData = false;
              });
            } else {
              debugPrint('No QR code found in image');
              setState(() {
                _qrCodeResult = 'Unknown';
                _scannedPlantData = null;
                _scannedPlantDocId = null;
                showResult = true;
                isScanning = false;
                _isLoadingPlantData = false;
              });
            }
          } catch (e) {
            debugPrint('Error decoding QR code: $e');
            setState(() {
              _qrCodeResult = 'Unknown';
              _scannedPlantData = null;
              _scannedPlantDocId = null;
              showResult = true;
              isScanning = false;
              _isLoadingPlantData = false;
            });
          } finally {
            barcodeScanner.close();
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      setState(() {
        _isLoadingPlantData = false;
      });
    }
  }

  void _resetScanner() {
    setState(() {
      showResult = false;
      isScanning = true;
      _qrCodeResult = null;
      _scannedPlantData = null;
      _scannedPlantDocId = null;
      _isLoadingPlantData = false;
      _diseaseResult = null;
      _isDetecting = false;
      _uploadedImageUrl = null;
      _capturedImagePath = null;
      _isSaving = false;
      
      // Resume camera/scanner
      if (!isDiseaseMode && _qrController != null) {
        _qrController!.resumeCamera();
      }
    });
  }

  Future<void> _saveToFirebase() async {
    if (_capturedImagePath == null || _diseaseResult == null || _selectedPlantId == null) {
      return;
    }

    // Show notes dialog first
    final notes = await _showNotesDialog();
    if (notes == null) {
      // User cancelled the dialog
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Get today's date key
      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // Prepare daily notes update
      final dailyNotesUpdate = notes.isNotEmpty ? {
        'dailyNotes.$todayKey': notes,
      } : null;
      
      final uploadResult = await _storageService.uploadAndSaveDiseaseDetection(
        imagePath: _capturedImagePath!,
        plantId: _selectedPlantId!,
        diseaseType: _diseaseResult!.diseaseName,
        confidence: _diseaseResult!.confidence,
        additionalData: {
          'severity': _diseaseResult!.severity,
          'allPredictions': _diseaseResult!.probabilities,
          if (dailyNotesUpdate != null) ...dailyNotesUpdate,
        },
      );
      
      final imageUrl = uploadResult['imageUrl'];
      final detectionId = uploadResult['detectionId'];
      debugPrint('Image uploaded to Firebase: $imageUrl');
      debugPrint('Detection saved with ID: $detectionId');

      setState(() {
        _uploadedImageUrl = imageUrl;
        _isSaving = false;
      });

      if (mounted) {
        // Show success popup dialog
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
                      'Image saved to Firebase successfully!',
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
        
        // Auto close popup and reset after 3.5 seconds
        await Future.delayed(const Duration(milliseconds: 3500));
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await Future.delayed(const Duration(milliseconds: 500));
          _resetScanner();
        }
      }
    } catch (e) {
      debugPrint('Error uploading to Firebase: $e');
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String?> _showNotesDialog() async {
    final TextEditingController notesController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.note_add, color: Colors.green[700], size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Notes (Optional)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Add any observations or notes about this scan:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'E.g., Noticed yellowing on edges...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
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
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, ''),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, notesController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDiseaseMode ? 'Disease Scanner' : 'QR Code Scanner',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isDiseaseMode
                                  ? (_selectedPlantId != null 
                                      ? '${_selectedPlantData?['field_name'] ?? 'Field'} - ${_selectedPlantData?['plant_id'] ?? 'Plant'}'
                                      : 'Select plant first')
                                  : 'Align QR code within frame',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
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
                      ),
                    ],
                  ),
                ),

                // Mode Toggle Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          icon: Icons.eco,
                          label: 'Disease',
                          isSelected: isDiseaseMode,
                          onTap: () => _toggleMode(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModeButton(
                          icon: Icons.qr_code_2,
                          label: 'QR Code',
                          isSelected: !isDiseaseMode,
                          onTap: () => _toggleMode(false),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Select/Change Plant Button (Disease Mode Only)
                if (isDiseaseMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _showPlantSelection();
                      },
                      icon: Icon(
                        _selectedPlantId != null ? Icons.change_circle : Icons.eco,
                        size: 18,
                      ),
                      label: Text(
                        _selectedPlantId != null 
                            ? '${_selectedPlantData?['field_name'] ?? 'Field'} - ${_selectedPlantData?['plant_id'] ?? 'Plant'}'
                            : 'Select Plant'
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.9),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                if (isDiseaseMode) const SizedBox(height: 12),

                // Upload from Gallery Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton.icon(
                    onPressed: _uploadFromGallery,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Upload from Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Camera/Scanner Area
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camera preview or QR scanner
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        width: double.infinity,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: isDiseaseMode
                              ? (_cameraController != null && _isCameraInitialized
                                  ? CameraPreview(_cameraController!)
                                  : const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    ))
                              : QRView(
                                  key: qrKey,
                                  onQRViewCreated: _onQRViewCreated,
                                  overlay: QrScannerOverlayShape(
                                    borderColor: Colors.blue,
                                    borderRadius: 20,
                                    borderLength: 30,
                                    borderWidth: 10,
                                    cutOutSize: 250,
                                  ),
                                ),
                        ),
                      ),

                      // Scanning Frame overlay
                      if (isScanning)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDiseaseMode ? Colors.green : Colors.blue,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            children: [
                              // Corner indicators
                              _buildCornerIndicator(Alignment.topLeft, isDiseaseMode),
                              _buildCornerIndicator(Alignment.topRight, isDiseaseMode),
                              _buildCornerIndicator(Alignment.bottomLeft, isDiseaseMode),
                              _buildCornerIndicator(Alignment.bottomRight, isDiseaseMode),
                            ],
                          ),
                        ),

                      // Capture/Scan button
                      if (isScanning && !showResult && !_isDetecting)
                        Positioned(
                          bottom: 20,
                          child: FloatingActionButton.extended(
                            onPressed: isDiseaseMode ? _captureImage : () {
                              // QR scanning is automatic
                            },
                            backgroundColor: isDiseaseMode ? Colors.green : Colors.blue,
                            icon: Icon(isDiseaseMode ? Icons.camera_alt : Icons.qr_code_scanner),
                            label: Text(isDiseaseMode ? 'Capture' : 'Scanning...'),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),

            // Result Card
            if (showResult || _isLoadingPlantData || _isDetecting)
              Positioned(
                bottom: 80,
                left: 20,
                right: 20,
                child: _isLoadingPlantData || _isDetecting
                    ? _buildLoadingCard(_isDetecting ? 'Analyzing image...' : 'Loading plant data...')
                    : (isDiseaseMode
                        ? _buildDiseaseResultCard()
                        : _buildQRResultCard()),
              ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1A1F2E) : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1A1F2E) : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerIndicator(Alignment alignment, bool isDiseaseMode) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? BorderSide(
                    color: isDiseaseMode ? Colors.green : Colors.blue,
                    width: 4,
                  )
                : BorderSide.none,
            bottom: alignment.y > 0
                ? BorderSide(
                    color: isDiseaseMode ? Colors.green : Colors.blue,
                    width: 4,
                  )
                : BorderSide.none,
            left: alignment.x < 0
                ? BorderSide(
                    color: isDiseaseMode ? Colors.green : Colors.blue,
                    width: 4,
                  )
                : BorderSide.none,
            right: alignment.x > 0
                ? BorderSide(
                    color: isDiseaseMode ? Colors.green : Colors.blue,
                    width: 4,
                  )
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRResultCard() {
    final plantData = _scannedPlantData;
    final plantFound = plantData != null;
    
    // Extract plant information
    final plantId = plantFound ? (plantData['plant_id']?.toString() ?? 'Unknown') : 'Unknown';
    final fieldName = plantFound ? (plantData['field_name']?.toString() ?? 'N/A') : 'N/A';
    final section = plantFound ? (plantData['section']?.toString() ?? 'N/A') : 'N/A';
    final row = plantFound ? (plantData['row']?.toString() ?? 'N/A') : 'N/A';
    final statusList = plantFound ? (plantData['status'] as List<dynamic>?) : null;
    
    String statusText = 'Unknown';
    Color statusColor = Colors.grey;
    
    if (statusList != null && statusList.isNotEmpty) {
      final status = statusList[0].toString().toLowerCase();
      if (status == 'diseased') {
        statusText = 'Disease Detected';
        statusColor = Colors.red;
      } else if (status == 'warning') {
        statusText = 'Warning';
        statusColor = Colors.orange;
      } else if (status == 'healthy') {
        statusText = 'Healthy';
        statusColor = Colors.green;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 2,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: plantFound ? Colors.blue[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  plantFound ? Icons.check_circle : Icons.warning,
                  color: plantFound ? Colors.blue[600] : Colors.orange[600],
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plantFound ? 'QR Code Scanned' : 'Plant Not Found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plantId,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (plantFound) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Field:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          fieldName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Location:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Section $section, Row $row',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Status
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Status:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This QR code is not registered in your garden.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetScanner,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Scan Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (plantFound) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => PlantDetailsDialog(
                          plantData: _scannedPlantData!,
                          documentId: _scannedPlantDocId!,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseResultCard() {
    final result = _diseaseResult;
    
    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('No detection result available'),
      );
    }

    // Determine color based on severity
    Color severityColor = Colors.green;
    Color severityBgColor = Colors.green[50]!;
    IconData severityIcon = Icons.check_circle;
    
    if (result.severity == 'High Risk') {
      severityColor = Colors.red[600]!;
      severityBgColor = Colors.red[50]!;
      severityIcon = Icons.error;
    } else if (result.severity == 'Medium Risk') {
      severityColor = Colors.orange[600]!;
      severityBgColor = Colors.orange[50]!;
      severityIcon = Icons.warning;
    } else if (result.severity == 'Low Risk') {
      severityColor = Colors.yellow[700]!;
      severityBgColor = Colors.yellow[50]!;
      severityIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 2,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(severityIcon, color: severityColor, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.diseaseName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.severity,
                      style: TextStyle(
                        fontSize: 14,
                        color: severityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Confidence Score
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: result.isReliable ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      result.isReliable ? Icons.check_circle : Icons.warning,
                      color: result.isReliable ? Colors.green[600] : Colors.orange[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Confidence Score',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  result.confidencePercentage,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: result.isReliable ? Colors.green[600] : Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: result.confidence,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                result.isReliable ? Colors.green[600]! : Colors.orange[600]!,
              ),
            ),
          ),
          
          // Recommendation
          if (!result.isReliable) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Low confidence. Consider retaking the photo in better lighting.',
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
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetScanner,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: severityColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Scan Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _uploadedImageUrl != null || _isSaving ? null : _saveToFirebase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _uploadedImageUrl != null ? Colors.grey : severityColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _uploadedImageUrl != null ? 'Saved' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
