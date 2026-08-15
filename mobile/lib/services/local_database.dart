import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/diagnosis_prediction.dart';
import '../models/scan_record.dart';

/// SQLite-backed local cache (Week 9, OfflineSyncManager component —
/// docs/classes.md). Uses the standard `sqflite` API directly; tests
/// redirect it to the FFI backend by setting the global `databaseFactory`
/// before opening a database (see test/local_database_test.dart) — no
/// environment-specific branching needed in this file itself.
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;

  static Future<LocalDatabase> open(String path) async {
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scans (
            id TEXT PRIMARY KEY,
            image_path TEXT NOT NULL,
            class_id TEXT NOT NULL,
            confidence REAL NOT NULL,
            model_version TEXT NOT NULL,
            captured_at TEXT NOT NULL,
            language TEXT NOT NULL,
            synced_at TEXT
          )
        ''');
        await db.execute(
          'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
    return LocalDatabase._(db);
  }

  Future<void> insertScan(ScanRecord scan) async {
    await _db.insert('scans', {
      'id': scan.id,
      'image_path': scan.imagePath,
      'class_id': scan.prediction.classId,
      'confidence': scan.prediction.confidence,
      'model_version': scan.prediction.modelVersion,
      'captured_at': scan.capturedAt.toIso8601String(),
      'language': scan.language,
      'synced_at': scan.syncedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ScanRecord>> getAllScans() async {
    final rows = await _db.query('scans', orderBy: 'captured_at DESC');
    return rows.map(_scanFromRow).toList();
  }

  Future<List<ScanRecord>> getPendingScans() async {
    final rows = await _db.query(
      'scans',
      where: 'synced_at IS NULL',
      orderBy: 'captured_at ASC',
    );
    return rows.map(_scanFromRow).toList();
  }

  Future<void> markSynced(String id, DateTime syncedAt) async {
    await _db.update(
      'scans',
      {'synced_at': syncedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// A stable per-install identifier, generated once and persisted — used
  /// to associate synced scans with a device before real farmer accounts
  /// exist (see docs/adr/0010-offline-sync-architecture.md).
  Future<String> getOrCreateDeviceId() async {
    final rows = await _db.query(
      'meta',
      where: 'key = ?',
      whereArgs: ['device_id'],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['value'] as String;

    final id = const Uuid().v4();
    await _db.insert('meta', {
      'key': 'device_id',
      'value': id,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  Future<void> close() => _db.close();

  ScanRecord _scanFromRow(Map<String, Object?> row) {
    return ScanRecord(
      id: row['id'] as String,
      imagePath: row['image_path'] as String,
      prediction: DiagnosisPrediction(
        classId: row['class_id'] as String,
        confidence: row['confidence'] as double,
        modelVersion: row['model_version'] as String,
      ),
      capturedAt: DateTime.parse(row['captured_at'] as String),
      language: row['language'] as String,
      syncedAt: row['synced_at'] == null
          ? null
          : DateTime.parse(row['synced_at'] as String),
    );
  }
}
