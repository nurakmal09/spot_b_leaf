import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload disease detection image to Firebase Storage
  /// Images are organized by plant ID: plant_images/{plantId}/disease_scans/{timestamp}_{filename}
  /// Returns the download URL of the uploaded image
  Future<String> uploadDiseaseImage({
    required String imagePath,
    required String plantId,
    String? diseaseType,
    double? confidenceScore,
  }) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist at path: $imagePath');
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = imagePath.split('/').last;
      final String storagePath = 'plant_images/$plantId/disease_scans/${timestamp}_$fileName';

      // Create reference to Firebase Storage location
      final Reference storageRef = _storage.ref().child(storagePath);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'plantId': plantId,
          'uploadTimestamp': timestamp.toString(),
          if (diseaseType != null) 'diseaseType': diseaseType,
          if (confidenceScore != null) 'confidenceScore': confidenceScore.toString(),
        },
      );

      // Upload file
      final UploadTask uploadTask = storageRef.putFile(imageFile, metadata);

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('Image uploaded successfully to: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      rethrow;
    }
  }

  /// Save disease detection record to Firestore with image URL
  /// Creates a document in the 'disease_detections' collection
  Future<String> saveDiseaseDetection({
    required String plantId,
    required String imageUrl,
    required String diseaseType,
    required double confidence,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final detectionData = {
        'plantId': plantId,
        'imageUrl': imageUrl,
        'diseaseType': diseaseType,
        'confidence': confidence,
        'detectedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      // Add to disease_detections collection
      final DocumentReference docRef = await _firestore
          .collection('disease_detections')
          .add(detectionData);

      // Determine plant health status based on disease severity
      String healthStatus = 'healthy';
      final severity = additionalData?['severity'] as String?;
      
      if (severity != null) {
        if (severity == 'Healthy') {
          healthStatus = 'healthy';
        } else if (severity == 'Low Risk' || severity == 'Medium Risk') {
          healthStatus = 'warning';
        } else if (severity == 'High Risk') {
          healthStatus = 'diseased';
        }
      } else {
        // Fallback: determine status from disease name
        final disease = diseaseType.toLowerCase();
        if (disease.contains('healthy')) {
          healthStatus = 'healthy';
        } else if (disease.contains('panama') || disease.contains('bract mosaic virus')) {
          healthStatus = 'diseased';
        } else {
          healthStatus = 'warning';
        }
      }

      // Update the plant document with latest disease detection and health status
      await _firestore.collection('plant').doc(plantId).update({
        'lastDiseaseCheck': FieldValue.serverTimestamp(),
        'lastDiseaseType': diseaseType,
        'lastDiseaseConfidence': confidence,
        'lastDiseaseImageUrl': imageUrl,
        'status': [healthStatus], // Update health status for field map icon
      });

      print('Disease detection saved with ID: ${docRef.id}');
      print('Plant health status updated to: $healthStatus');
      return docRef.id;
    } catch (e) {
      print('Error saving disease detection to Firestore: $e');
      rethrow;
    }
  }

  /// Complete workflow: Upload image and save detection record
  Future<Map<String, String>> uploadAndSaveDiseaseDetection({
    required String imagePath,
    required String plantId,
    required String diseaseType,
    required double confidence,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Step 1: Upload image to Firebase Storage
      final String imageUrl = await uploadDiseaseImage(
        imagePath: imagePath,
        plantId: plantId,
        diseaseType: diseaseType,
        confidenceScore: confidence,
      );

      // Step 2: Save detection record to Firestore
      final String detectionId = await saveDiseaseDetection(
        plantId: plantId,
        imageUrl: imageUrl,
        diseaseType: diseaseType,
        confidence: confidence,
        additionalData: additionalData,
      );

      return {
        'imageUrl': imageUrl,
        'detectionId': detectionId,
      };
    } catch (e) {
      print('Error in complete disease detection workflow: $e');
      rethrow;
    }
  }

  /// Get all disease detection images for a specific plant
  Future<List<String>> getPlantDiseaseImages(String plantId) async {
    try {
      final Reference plantRef = _storage.ref().child('plant_images/$plantId/disease_scans');
      final ListResult result = await plantRef.listAll();

      final List<String> imageUrls = [];
      for (var item in result.items) {
        final url = await item.getDownloadURL();
        imageUrls.add(url);
      }

      return imageUrls;
    } catch (e) {
      print('Error getting plant disease images: $e');
      return [];
    }
  }

  /// Get disease detection history from Firestore for a specific plant
  Future<List<Map<String, dynamic>>> getDiseaseDetectionHistory(String plantId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('disease_detections')
          .where('plantId', isEqualTo: plantId)
          .orderBy('detectedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      print('Error getting disease detection history: $e');
      return [];
    }
  }

  /// Delete an image from Firebase Storage
  Future<void> deleteDiseaseImage(String imageUrl) async {
    try {
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('Image deleted successfully');
    } catch (e) {
      print('Error deleting image: $e');
      rethrow;
    }
  }
}
