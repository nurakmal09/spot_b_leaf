import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class QRMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrates all plants without qr_code_id to have one
  /// This should be run once when the app starts
  Future<void> migrateExistingPlants(String userId) async {
    try {
      // Get all plants for this user
      final snapshot = await _firestore
          .collection('plant')
          .where('userId', isEqualTo: userId)
          .get();

      int migrated = 0;
      int skipped = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final qrCodeId = data['qr_code_id'] as String?;

        // Only update if qr_code_id is missing or empty
        if (qrCodeId == null || qrCodeId.isEmpty) {
          // Generate unique QR code ID
          final fieldName = data['field_name'] as String? ?? 'Unknown';
          final plantId = data['plant_id'] as String? ?? 'Unknown';
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newQrCodeId = '${userId}_${fieldName}_${plantId}_$timestamp';

          // Update the document
          await doc.reference.update({
            'qr_code_id': newQrCodeId,
          });

          migrated++;
        } else {
          skipped++;
        }
      }

  // Use debugPrint to avoid lint warnings about print in production
  debugPrint('QR Migration completed: $migrated plants updated, $skipped plants already had QR codes');
    } catch (e) {
      debugPrint('Error during QR migration: $e');
    }
  }

  /// Check if migration has been run before
  /// Stores a flag in Firestore to avoid running multiple times
  Future<bool> hasMigrationRun(String userId) async {
    try {
      final doc = await _firestore
          .collection('_migration_flags')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        return data?['qr_code_migration_completed'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Mark migration as completed
  Future<void> markMigrationComplete(String userId) async {
    try {
      await _firestore.collection('_migration_flags').doc(userId).set({
        'qr_code_migration_completed': true,
        'completed_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking migration complete: $e');
    }
  }

  /// Main migration function - run this once per user
  Future<void> runMigration(String userId) async {
    // Check if already run
    final hasRun = await hasMigrationRun(userId);
    
    if (hasRun) {
      debugPrint('QR Migration already completed for this user');
      return;
    }

    // Run the migration
    await migrateExistingPlants(userId);

    // Mark as complete
    await markMigrationComplete(userId);
  }
}
