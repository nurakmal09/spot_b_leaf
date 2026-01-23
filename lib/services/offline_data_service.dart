import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_database_service.dart';
import 'connectivity_service.dart';

/// Service to merge offline cached data with online Firebase data
class OfflineDataService {
  static final OfflineDataService _instance = OfflineDataService._internal();
  factory OfflineDataService() => _instance;
  OfflineDataService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  final ConnectivityService _connectivity = ConnectivityService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all scans for a plant (combines online Firebase + offline local)
  Future<List<Map<String, dynamic>>> getPlantScans(String plantId) async {
    final List<Map<String, dynamic>> allScans = [];

    // Get local cached scans (including unsynced)
    try {
      final localScans = await _localDb.getPlantScans(plantId);
      
      for (final scan in localScans) {
        allScans.add({
          'id': scan['local_id'],
          'diseaseType': scan['disease_name'],
          'diseaseName': scan['disease_name'],
          'confidence': scan['confidence_score'],
          'confidenceScore': scan['confidence_score'],
          'severity': scan['severity'],
          'imageUrl': scan['image_path'],
          'imagePath': scan['image_path'],
          'timestamp': DateTime.fromMillisecondsSinceEpoch(
            scan['scan_timestamp'] as int,
          ),
          'detectedAt': DateTime.fromMillisecondsSinceEpoch(
            scan['scan_timestamp'] as int,
          ),
          'isSynced': scan['is_synced'] == 1,
          'isLocal': true,
          'plantId': plantId,
        });
      }
    } catch (e) {
      print('Error loading local scans: $e');
    }

    // Get online Firebase scans if connected
    if (_connectivity.isConnected) {
      try {
        final snapshot = await _firestore
            .collection('disease_detections')
            .where('plantId', isEqualTo: plantId)
            .orderBy('detectedAt', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          
          // Check if this scan is already in local data (by localId)
          final localId = data['localId'] as String?;
          if (localId != null) {
            // Remove the local version, use the synced Firebase version
            allScans.removeWhere((scan) => scan['id'] == localId);
          }

          allScans.add({
            'id': doc.id,
            ...data,
            'isLocal': false,
            'isSynced': true,
          });
        }
      } catch (e) {
        print('Error loading Firebase scans: $e');
        // Continue with local data only
      }
    }

    // Sort by timestamp (newest first)
    allScans.sort((a, b) {
      final aTime = a['timestamp'] as DateTime? ?? a['detectedAt'];
      final bTime = b['timestamp'] as DateTime? ?? b['detectedAt'];
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    return allScans;
  }

  /// Get user's recent scans (combines online + offline)
  Future<List<Map<String, dynamic>>> getUserScans(String userId) async {
    final List<Map<String, dynamic>> allScans = [];

    // Get local cached scans
    try {
      final localScans = await _localDb.getUserScans(userId);
      
      for (final scan in localScans) {
        allScans.add({
          'id': scan['local_id'],
          'plantId': scan['plant_id'],
          'plantName': scan['plant_name'],
          'diseaseType': scan['disease_name'],
          'confidence': scan['confidence_score'],
          'severity': scan['severity'],
          'imageUrl': scan['image_path'],
          'timestamp': DateTime.fromMillisecondsSinceEpoch(
            scan['scan_timestamp'] as int,
          ),
          'isSynced': scan['is_synced'] == 1,
          'isLocal': true,
        });
      }
    } catch (e) {
      print('Error loading local user scans: $e');
    }

    // Get online Firebase scans if connected
    if (_connectivity.isConnected) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('disease_scans')
            .orderBy('scanTimestamp', descending: true)
            .limit(50)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final localId = data['localId'] as String?;
          
          if (localId != null) {
            allScans.removeWhere((scan) => scan['id'] == localId);
          }

          allScans.add({
            'id': doc.id,
            ...data,
            'isLocal': false,
            'isSynced': true,
          });
        }
      } catch (e) {
        print('Error loading Firebase user scans: $e');
      }
    }

    // Sort by timestamp
    allScans.sort((a, b) {
      final aTime = a['timestamp'] as DateTime? ?? DateTime.now();
      final bTime = b['timestamp'] as DateTime? ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return allScans;
  }

  /// Check if there are unsynced local scans
  Future<bool> hasUnsyncedScans() async {
    final count = await _localDb.getUnsyncedCount();
    return count > 0;
  }

  /// Get count of unsynced scans
  Future<int> getUnsyncedCount() async {
    return await _localDb.getUnsyncedCount();
  }
}
