import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DiseaseDetectionService {
  static const String modelPath = 'assets/models/customcnn_94.07.tflite';
  static const String labelsPath = 'assets/models/labels.txt';
  
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;

  // Model input/output configuration
  static const int inputSize = 224; // Custom CNN input size
  static const int numChannels = 3;
  static const int numClasses = 6; // 6 disease classes: Black Sigatoka, Bract Mosaic Virus, Cordana, Healthy Leaf, Panama, Pestalotiopsis

  /// Initialize the TFLite model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the model
      final interpreterOptions = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: interpreterOptions,
      );

      // Load labels
      final labelsData = await rootBundle.loadString(labelsPath);
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();

      _isInitialized = true;
      print('Disease detection model initialized successfully');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      print('Labels loaded: ${_labels!.length}');
    } catch (e) {
      print('Error initializing disease detection model: $e');
      rethrow;
    }
  }

  /// Detect disease from an image file
  Future<DiseaseDetectionResult> detectDisease(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Read and preprocess image
      final imageData = await _preprocessImage(imagePath);

      // Run inference
      final output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);
      _interpreter!.run(imageData, output);

      // Process results
      final probabilities = output[0] as List<double>;
      final result = _processOutput(probabilities);

      return result;
    } catch (e) {
      print('Error detecting disease: $e');
      rethrow;
    }
  }

  /// Preprocess image for model input
  Future<List<List<List<List<double>>>>> _preprocessImage(String imagePath) async {
    // Read image file
    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize image to model input size
    img.Image resizedImage = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
    );

    // Convert to normalized float array [1, 224, 224, 3]
    var input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0, // Normalize to [0, 1]
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// Process model output to get disease prediction
  DiseaseDetectionResult _processOutput(List<double> probabilities) {
    // Find the class with highest probability
    double maxProb = probabilities[0];
    int maxIndex = 0;

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    // Get disease name from labels
    String diseaseName = _labels != null && maxIndex < _labels!.length
        ? _labels![maxIndex]
        : 'Unknown';

    // Determine severity based on disease type and confidence
    String severity = _determineSeverity(diseaseName, maxProb);

    return DiseaseDetectionResult(
      diseaseName: diseaseName,
      confidence: maxProb,
      severity: severity,
      probabilities: Map.fromIterables(
        _labels ?? List.generate(probabilities.length, (i) => 'Class $i'),
        probabilities,
      ),
    );
  }

  /// Determine disease severity
  String _determineSeverity(String diseaseName, double confidence) {
    final disease = diseaseName.toLowerCase();
    
    // Healthy plants
    if (disease.contains('healthy')) {
      return 'Healthy';
    }
    
    // High risk diseases
    if (disease.contains('panama') || 
        disease.contains('bract mosaic virus')) {
      return 'High Risk';
    }
    
    // Medium risk diseases
    if (disease.contains('sigatoka') || 
        disease.contains('cordana')) {
      return 'Medium Risk';
    }
    
    // Low risk diseases
    if (disease.contains('pestalotiopsis')) {
      return 'Low Risk';
    }
    
    // Default based on confidence
    if (confidence > 0.8) {
      return 'High Risk';
    } else if (confidence > 0.6) {
      return 'Medium Risk';
    } else {
      return 'Low Risk';
    }
  }

  /// Get recommendation based on detected disease
  String getRecommendation(DiseaseDetectionResult result) {
    if (result.diseaseName.toLowerCase().contains('healthy')) {
      return 'Plant appears healthy. Continue regular monitoring.';
    } else if (result.severity == 'Low Risk') {
      return 'Early stage detected. Monitor closely and apply preventive measures.';
    } else if (result.severity == 'Medium Risk') {
      return 'Disease progression detected. Consult treatment guide for management.';
    } else {
      return 'Severe infection detected. Immediate treatment required. Check treatment guide.';
    }
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}

/// Model for disease detection result
class DiseaseDetectionResult {
  final String diseaseName;
  final double confidence;
  final String severity;
  final Map<String, double> probabilities;

  DiseaseDetectionResult({
    required this.diseaseName,
    required this.confidence,
    required this.severity,
    required this.probabilities,
  });

  /// Get confidence as percentage string
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Check if detection is reliable (confidence > 70%)
  bool get isReliable => confidence > 0.7;

  @override
  String toString() {
    return 'DiseaseDetectionResult(disease: $diseaseName, confidence: $confidencePercentage, severity: $severity)';
  }
}
