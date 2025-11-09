import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as mlkit;
import '../widgets/bottom_nav_bar.dart';
import '../widgets/plant_details_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  Future<void> _captureImage() async {
    if (isDiseaseMode && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final image = await _cameraController!.takePicture();
        // TODO: Send image to disease detection API
        debugPrint('Image captured: ${image.path}');
        
        setState(() {
          showResult = true;
          isScanning = false;
        });
      } catch (e) {
        debugPrint('Error capturing image: $e');
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        debugPrint('Image selected: ${image.path}');
        
        if (isDiseaseMode) {
          // Disease mode - just show placeholder result
          setState(() {
            showResult = true;
            isScanning = false;
          });
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
      
      // Resume camera/scanner
      if (!isDiseaseMode && _qrController != null) {
        _qrController!.resumeCamera();
      }
    });
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
                      Column(
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
                                ? 'Position leaf within frame'
                                : 'Align QR code within frame',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
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
                      if (isScanning && !showResult)
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
            if (showResult || _isLoadingPlantData)
              Positioned(
                bottom: 80,
                left: 20,
                right: 20,
                child: _isLoadingPlantData
                    ? _buildLoadingCard()
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

  Widget _buildLoadingCard() {
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
            'Loading plant data...',
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
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.error, color: Colors.red[600], size: 32),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disease Detected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Black Sigatoka',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 20),
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
                  '98%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: 0.98,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetScanner,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[600],
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
                  onPressed: () {
                    // TODO: Navigate to plant details
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
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
          ),
        ],
      ),
    );
  }
}
