import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Local database service for offline data caching
/// Stores disease detection scans locally and syncs with Firebase when online
class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  Database? _database;

  /// Get database instance, initialize if needed
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the local database
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'spotbleaf_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    // Table for cached disease detection scans
    await db.execute('''
      CREATE TABLE disease_scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT UNIQUE NOT NULL,
        user_id TEXT NOT NULL,
        plant_id TEXT,
        plant_name TEXT,
        disease_name TEXT NOT NULL,
        confidence_score REAL NOT NULL,
        severity TEXT NOT NULL,
        image_path TEXT NOT NULL,
        scan_timestamp INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        firebase_doc_id TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Table for cached images (base64 encoded for portability)
    await db.execute('''
      CREATE TABLE cached_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_scan_id TEXT NOT NULL,
        image_base64 TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (local_scan_id) REFERENCES disease_scans (local_id)
      )
    ''');

    // Index for faster queries
    await db.execute('CREATE INDEX idx_synced ON disease_scans (is_synced)');
    await db.execute('CREATE INDEX idx_user ON disease_scans (user_id)');
  }

  /// Save a disease scan locally
  Future<int> saveScanLocally({
    required String localId,
    required String userId,
    String? plantId,
    String? plantName,
    required String diseaseName,
    required double confidenceScore,
    required String severity,
    required String imagePath,
    required DateTime scanTimestamp,
    String? imageBase64,
  }) async {
    final db = await database;
    
    // Save scan metadata with permanent image path
    final scanId = await db.insert(
      'disease_scans',
      {
        'local_id': localId,
        'user_id': userId,
        'plant_id': plantId,
        'plant_name': plantName,
        'disease_name': diseaseName,
        'confidence_score': confidenceScore,
        'severity': severity,
        'image_path': imagePath,  // Store permanent path
        'scan_timestamp': scanTimestamp.millisecondsSinceEpoch,
        'is_synced': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save image data if provided
    if (imageBase64 != null) {
      await db.insert('cached_images', {
        'local_scan_id': localId,
        'image_base64': imageBase64,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    return scanId;
  }

  /// Get all unsynced scans (pending Firebase upload)
  Future<List<Map<String, dynamic>>> getUnsyncedScans() async {
    final db = await database;
    return await db.query(
      'disease_scans',
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'scan_timestamp ASC',
    );
  }

  /// Get cached image for a scan
  Future<String?> getCachedImage(String localScanId) async {
    final db = await database;
    final result = await db.query(
      'cached_images',
      where: 'local_scan_id = ?',
      whereArgs: [localScanId],
    );

    if (result.isNotEmpty) {
      return result.first['image_base64'] as String?;
    }
    return null;
  }

  /// Mark a scan as synced to Firebase
  Future<void> markAsSynced(String localId, String firebaseDocId) async {
    final db = await database;
    await db.update(
      'disease_scans',
      {
        'is_synced': 1,
        'firebase_doc_id': firebaseDocId,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Get all scans for a user (both synced and unsynced)
  Future<List<Map<String, dynamic>>> getUserScans(String userId) async {
    final db = await database;
    return await db.query(
      'disease_scans',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'scan_timestamp DESC',
    );
  }

  /// Get scans for a specific plant
  Future<List<Map<String, dynamic>>> getPlantScans(String plantId) async {
    final db = await database;
    return await db.query(
      'disease_scans',
      where: 'plant_id = ?',
      whereArgs: [plantId],
      orderBy: 'scan_timestamp DESC',
    );
  }

  /// Delete old synced scans (cleanup to save space)
  /// Deletes synced scans older than [daysToKeep] days
  Future<int> deleteOldSyncedScans({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    // First, delete associated images
    await db.execute('''
      DELETE FROM cached_images 
      WHERE local_scan_id IN (
        SELECT local_id FROM disease_scans 
        WHERE is_synced = 1 AND scan_timestamp < ?
      )
    ''', [cutoffDate.millisecondsSinceEpoch]);

    // Then delete the scans
    return await db.delete(
      'disease_scans',
      where: 'is_synced = 1 AND scan_timestamp < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  /// Get count of unsynced scans
  Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM disease_scans WHERE is_synced = 0'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all local data (useful for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('cached_images');
    await db.delete('disease_scans');
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    
    final totalScans = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM disease_scans')
    ) ?? 0;
    
    final syncedScans = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM disease_scans WHERE is_synced = 1')
    ) ?? 0;
    
    final unsyncedScans = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM disease_scans WHERE is_synced = 0')
    ) ?? 0;
    
    final cachedImages = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM cached_images')
    ) ?? 0;

    return {
      'total_scans': totalScans,
      'synced_scans': syncedScans,
      'unsynced_scans': unsyncedScans,
      'cached_images': cachedImages,
    };
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
