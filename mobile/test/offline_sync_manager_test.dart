import 'dart:io';

import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/services/local_database.dart';
import 'package:agrisense_ai/services/offline_sync_manager.dart';
import 'package:agrisense_ai/services/scan_repository.dart';
import 'package:agrisense_ai/services/sync_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fake backend that fails for specific scan ids and records what it was
/// called with — lets tests verify per-item failure handling without a
/// real network call.
class FakeSyncBackend implements SyncBackend {
  FakeSyncBackend({this.failForIds = const {}});

  final Set<String> failForIds;
  final List<String> pushedScanIds = [];
  final List<String> deviceIdsSeen = [];

  @override
  Future<void> pushScan(ScanRecord scan, {required String deviceId}) async {
    deviceIdsSeen.add(deviceId);
    if (failForIds.contains(scan.id)) {
      throw SyncBackendException('simulated failure for ${scan.id}');
    }
    pushedScanIds.add(scan.id);
  }
}

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
    tempDir = await Directory.systemTemp.createTemp('agrisense_sync_test_');
    database = await LocalDatabase.open(inMemoryDatabasePath);
    repository = ScanRepository(database: database, storageDirectory: tempDir);
    sourcePhoto = File('${tempDir.path}/capture.jpg')
      ..writeAsBytesSync([9, 9, 9]);
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test(
    'syncs all pending scans and marks them synced in the database',
    () async {
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
          classId: 'potato_late_blight',
          confidence: 0.8,
        ),
        language: 'hi',
      );

      final backend = FakeSyncBackend();
      final manager = OfflineSyncManager(database: database, backend: backend);

      final summary = await manager.syncPending();

      expect(summary.syncedCount, 2);
      expect(summary.failedCount, 0);
      expect(backend.pushedScanIds, containsAll([scan1.id, scan2.id]));
      expect(await database.getPendingScans(), isEmpty);
    },
  );

  test(
    'a failed upload stays pending; successful ones are still marked synced',
    () async {
      final good = await repository.saveScan(
        capturedImagePath: sourcePhoto.path,
        prediction: const DiagnosisPrediction(
          classId: 'tomato_healthy',
          confidence: 0.9,
        ),
        language: 'en',
      );
      final bad = await repository.saveScan(
        capturedImagePath: sourcePhoto.path,
        prediction: const DiagnosisPrediction(
          classId: 'tomato_healthy',
          confidence: 0.9,
        ),
        language: 'en',
      );

      final backend = FakeSyncBackend(failForIds: {bad.id});
      final manager = OfflineSyncManager(database: database, backend: backend);

      final summary = await manager.syncPending();

      expect(summary.syncedCount, 1);
      expect(summary.failedCount, 1);
      expect(summary.hadFailures, isTrue);

      final stillPending = await database.getPendingScans();
      expect(stillPending.map((s) => s.id), [bad.id]);

      final all = await database.getAllScans();
      expect(all.firstWhere((s) => s.id == good.id).isSynced, isTrue);
    },
  );

  test('retrying only re-attempts scans that are still pending', () async {
    final scan = await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      language: 'en',
    );

    final failingBackend = FakeSyncBackend(failForIds: {scan.id});
    await OfflineSyncManager(
      database: database,
      backend: failingBackend,
    ).syncPending();
    expect(failingBackend.pushedScanIds, isEmpty);

    final recoveredBackend = FakeSyncBackend();
    final summary = await OfflineSyncManager(
      database: database,
      backend: recoveredBackend,
    ).syncPending();

    expect(summary.syncedCount, 1);
    expect(recoveredBackend.pushedScanIds, [scan.id]);
  });

  test(
    'running sync with nothing pending does nothing and reports zero',
    () async {
      final manager = OfflineSyncManager(
        database: database,
        backend: FakeSyncBackend(),
      );

      final summary = await manager.syncPending();

      expect(summary.total, 0);
    },
  );

  test('the same device id is used for every scan in the batch', () async {
    await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      language: 'en',
    );
    await repository.saveScan(
      capturedImagePath: sourcePhoto.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      language: 'en',
    );

    final backend = FakeSyncBackend();
    await OfflineSyncManager(
      database: database,
      backend: backend,
    ).syncPending();

    expect(backend.deviceIdsSeen.toSet(), hasLength(1));
  });
}
