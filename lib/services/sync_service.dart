import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';
import 'firebase_storage_service.dart';

/// Service to synchronize local cached data with Firebase
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseStorageService _storage = FirebaseStorageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;

  // Stream controller for sync status updates
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Initialize sync service
  Future<void> initialize() async {
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.connectivityStream.listen((isConnected) {
      if (isConnected) {
        // Trigger sync when connection is restored
        syncPendingData();
      }
    });

    // Setup periodic sync (every 5 minutes when online)
    _periodicSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) async {
        if (_connectivity.isConnected) {
          await syncPendingData();
        }
      },
    );

    // Initial sync if online
    if (_connectivity.isConnected) {
      await syncPendingData();
    }
  }

  /// Sync all pending data to Firebase
  Future<SyncResult> syncPendingData() async {
    if (_isSyncing) {
      debugPrint('Sync already in progress, skipping...');
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    if (!_connectivity.isConnected) {
      debugPrint('No internet connection, sync skipped');
      return SyncResult(success: false, message: 'No internet connection');
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    try {
      // Get all unsynced scans
      final unsyncedScans = await _localDb.getUnsyncedScans();
      
      if (unsyncedScans.isEmpty) {
        debugPrint('No pending data to sync');
        _isSyncing = false;
        _syncStatusController.add(SyncStatus.idle);
        return SyncResult(
          success: true,
          message: 'No pending data',
          syncedCount: 0,
        );
      }

      debugPrint('📤 Starting sync: ${unsyncedScans.length} scans to upload');

      int successCount = 0;
      int failedCount = 0;
      final errors = <String>[];

      for (final scan in unsyncedScans) {
        try {
          await _syncSingleScan(scan);
          successCount++;
          debugPrint('✅ Synced scan: ${scan['local_id']}');
        } catch (e) {
          failedCount++;
          final errorMsg = 'Failed to sync ${scan['local_id']}: $e';
          errors.add(errorMsg);
          debugPrint('❌ $errorMsg');
        }
      }

      final message = 'Synced $successCount/${unsyncedScans.length} scans'
          '${failedCount > 0 ? ' ($failedCount failed)' : ''}';

      _isSyncing = false;
      _syncStatusController.add(SyncStatus.idle);

      return SyncResult(
        success: failedCount == 0,
        message: message,
        syncedCount: successCount,
        failedCount: failedCount,
        errors: errors,
      );
    } catch (e) {
      _isSyncing = false;
      _syncStatusController.add(SyncStatus.error);
      debugPrint('Sync error: $e');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
        errors: [e.toString()],
      );
    }
  }

  /// Sync a single scan to Firebase
  Future<void> _syncSingleScan(Map<String, dynamic> scan) async {
    final localId = scan['local_id'] as String;
    final userId = scan['user_id'] as String;
    final plantId = scan['plant_id'] as String?;
    final storedImagePath = scan['image_path'] as String?;

    String? uploadedImageUrl;
    String? imagePathToUpload;

    // Try to use the stored permanent image path first
    if (storedImagePath != null && File(storedImagePath).existsSync()) {
      imagePathToUpload = storedImagePath;
      debugPrint('Using stored image path: $storedImagePath');
    } else {
      // Fall back to cached base64 image
      final imageBase64 = await _localDb.getCachedImage(localId);
      
      if (imageBase64 != null) {
        try {
          // Decode base64 and save as temporary file
          final bytes = base64Decode(imageBase64);
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/temp_$localId.jpg');
          await tempFile.writeAsBytes(bytes);
          imagePathToUpload = tempFile.path;
          debugPrint('Using cached base64 image');
        } catch (e) {
          debugPrint('Warning: Failed to decode cached image: $e');
        }
      }
    }

    // Upload image to Firebase Storage if we have an image
    if (imagePathToUpload != null && plantId != null) {
      try {
        uploadedImageUrl = await _storage.uploadDiseaseImage(
          imagePath: imagePathToUpload,
          plantId: plantId,
          diseaseType: scan['disease_name'] as String?,
          confidenceScore: scan['confidence_score'] as double?,
        );

        // Clean up temp file if it was created from base64
        if (imagePathToUpload.contains('temp_')) {
          await File(imagePathToUpload).delete().catchError((_) {});
        }
        
        debugPrint('✅ Image uploaded: $uploadedImageUrl');
      } catch (e) {
        debugPrint('Warning: Failed to upload image for $localId: $e');
        // Continue with sync even if image upload fails
      }
    }

    // Save scan data to Firestore (user's collection)
    final scanData = {
      'userId': userId,
      'plantId': plantId,
      'plantName': scan['plant_name'],
      'diseaseName': scan['disease_name'],
      'confidenceScore': scan['confidence_score'],
      'severity': scan['severity'],
      'imageUrl': uploadedImageUrl ?? scan['image_path'],
      'timestamp': FieldValue.serverTimestamp(),
      'scanTimestamp': DateTime.fromMillisecondsSinceEpoch(
        scan['scan_timestamp'] as int,
      ),
      'syncedFrom': 'local_cache',
      'localId': localId,
    };

    // Add to user's disease_scans collection
    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('disease_scans')
        .add(scanData);

    // Also save to main disease_detections collection (if plant exists)
    if (plantId != null) {
      try {
        final detectionData = {
          'plantId': plantId,
          'imageUrl': uploadedImageUrl ?? '',
          'diseaseType': scan['disease_name'],
          'confidence': scan['confidence_score'],
          'severity': scan['severity'],
          'detectedAt': DateTime.fromMillisecondsSinceEpoch(
            scan['scan_timestamp'] as int,
          ),
          'createdAt': FieldValue.serverTimestamp(),
          'syncedFrom': 'local_cache',
          'userId': userId,
        };

        await _firestore.collection('disease_detections').add(detectionData);

        // Determine plant health status
        String healthStatus = 'healthy';
        final severity = scan['severity'] as String?;
        
        if (severity != null) {
          if (severity == 'Healthy') {
            healthStatus = 'healthy';
          } else if (severity == 'Low Risk' || severity == 'Medium Risk') {
            healthStatus = 'warning';
          } else if (severity == 'High Risk') {
            healthStatus = 'diseased';
          }
        }

        // Update the plant document with latest disease info
        final plantUpdateData = {
          'lastDiseaseCheck': FieldValue.serverTimestamp(),
          'lastDiseaseType': scan['disease_name'],
          'lastDiseaseConfidence': scan['confidence_score'],
          'lastDiseaseImageUrl': uploadedImageUrl ?? '',
          'status': [healthStatus],
        };

        await _firestore.collection('plant').doc(plantId).update(plantUpdateData);
        
        debugPrint('✅ Plant $plantId updated with disease info');
      } catch (e) {
        debugPrint('Warning: Failed to update plant data: $e');
        // Continue even if plant update fails
      }
    }

    // Mark as synced in local database
    await _localDb.markAsSynced(localId, docRef.id);
    
    debugPrint('✅ Scan $localId synced to Firebase: ${docRef.id}');
  }

  /// Get count of pending syncs
  Future<int> getPendingSyncCount() async {
    return await _localDb.getUnsyncedCount();
  }

  /// Force immediate sync
  Future<SyncResult> forceSyncNow() async {
    return await syncPendingData();
  }

  /// Clean up old synced data
  Future<int> cleanupOldData({int daysToKeep = 30}) async {
    return await _localDb.deleteOldSyncedScans(daysToKeep: daysToKeep);
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final dbStats = await _localDb.getDatabaseStats();
    return {
      ...dbStats,
      'is_syncing': _isSyncing,
      'is_online': _connectivity.isConnected,
      'connection_type': await _connectivity.getConnectivityType(),
    };
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
    _syncStatusController.close();
  }
}

/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  error,
}

/// Sync result data class
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errors = const [],
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, message: $message, '
        'synced: $syncedCount, failed: $failedCount)';
  }
}
