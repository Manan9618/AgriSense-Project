import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/diagnosis_prediction.dart';
import '../models/feedback_record.dart';
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
      version: 2,
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
        await _createFeedbackTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Week 12: existing installs at version 1 only have scans/meta.
        if (oldVersion < 2) {
          await _createFeedbackTable(db);
        }
      },
    );
    return LocalDatabase._(db);
  }

  static Future<void> _createFeedbackTable(Database db) async {
    await db.execute('''
      CREATE TABLE feedback (
        id TEXT PRIMARY KEY,
        scan_id TEXT NOT NULL,
        diagnosis_accuracy TEXT NOT NULL,
        treatment_outcome TEXT NOT NULL,
        notes TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
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

  Future<void> insertFeedback(FeedbackRecord feedback) async {
    await _db.insert('feedback', {
      'id': feedback.id,
      'scan_id': feedback.scanId,
      'diagnosis_accuracy': feedback.diagnosisAccuracy,
      'treatment_outcome': feedback.treatmentOutcome,
      'notes': feedback.notes,
      'created_at': feedback.createdAt.toIso8601String(),
      'synced_at': feedback.syncedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FeedbackRecord>> getPendingFeedback() async {
    final rows = await _db.query(
      'feedback',
      where: 'synced_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map(_feedbackFromRow).toList();
  }

  /// Whether this scan already has feedback recorded — used to show "thank
  /// you, already submitted" instead of asking the farmer twice.
  Future<bool> hasFeedbackForScan(String scanId) async {
    final rows = await _db.query(
      'feedback',
      where: 'scan_id = ?',
      whereArgs: [scanId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markFeedbackSynced(String id, DateTime syncedAt) async {
    await _db.update(
      'feedback',
      {'synced_at': syncedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() => _db.close();

  FeedbackRecord _feedbackFromRow(Map<String, Object?> row) {
    return FeedbackRecord(
      id: row['id'] as String,
      scanId: row['scan_id'] as String,
      diagnosisAccuracy: row['diagnosis_accuracy'] as String,
      treatmentOutcome: row['treatment_outcome'] as String,
      notes: row['notes'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      syncedAt: row['synced_at'] == null
          ? null
          : DateTime.parse(row['synced_at'] as String),
    );
  }

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
