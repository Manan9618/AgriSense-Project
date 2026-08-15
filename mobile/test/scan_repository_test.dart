import 'dart:io';

import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/services/local_database.dart';
import 'package:agrisense_ai/services/scan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real filesystem (a real temp directory, not a fake) + real SQLite —
/// proves the actual "copy the photo out of a volatile location, assign an
/// id, persist it" behavior, not just that the code compiles.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late LocalDatabase database;
  late ScanRepository repository;
  late File sourcePhoto;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'agrisense_scan_repo_test_',
    );
    database = await LocalDatabase.open(inMemoryDatabasePath);
    repository = ScanRepository(database: database, storageDirectory: tempDir);

    // Simulates a photo sitting in a volatile location (e.g. the camera
    // plugin's cache dir) before it's durably saved.
    sourcePhoto = File('${tempDir.path}/volatile_capture.jpg')
      ..writeAsBytesSync([1, 2, 3, 4]);
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('copies the image into persistent storage under a stable id', () async {
    final scan = await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      language: 'en',
    );

    expect(scan.imagePath, isNot(sourcePhoto.path));
    expect(File(scan.imagePath).existsSync(), isTrue);
    expect(File(scan.imagePath).readAsBytesSync(), [1, 2, 3, 4]);
    expect(scan.imagePath, contains(scan.id));
  });

  test('the saved scan is queryable from the database afterward', () async {
    final scan = await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'potato_late_blight',
        confidence: 0.8,
      ),
      language: 'en',
    );

    final all = await database.getAllScans();

    expect(all, hasLength(1));
    expect(all.first.id, scan.id);
    expect(all.first.prediction.classId, 'potato_late_blight');
  });

  test('a new scan starts unsynced', () async {
    final scan = await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      language: 'en',
    );

    expect(scan.isSynced, isFalse);
    final pending = await database.getPendingScans();
    expect(pending.map((s) => s.id), contains(scan.id));
  });

  test('two scans from the same session get different ids and files', () async {
    final scan1 = await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      language: 'en',
    );
    final scan2 = await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      language: 'en',
    );

    expect(scan1.id, isNot(scan2.id));
    expect(scan1.imagePath, isNot(scan2.imagePath));
    expect(File(scan1.imagePath).existsSync(), isTrue);
    expect(File(scan2.imagePath).existsSync(), isTrue);
  });
}
