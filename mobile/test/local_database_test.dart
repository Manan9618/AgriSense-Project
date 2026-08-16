import 'dart:io';

import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/models/feedback_record.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/services/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Real SQLite (via sqflite_common_ffi's in-memory backend), not a fake —
/// `databaseFactory` is sqflite's own extension point for exactly this: production
/// code (LocalDatabase) is unchanged, only the test setup below picks a
/// different backend, the same way tflite_flutter's tests use the real
/// interpreter against a mocked native-library location.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDatabase db;

  setUp(() async {
    db = await LocalDatabase.open(inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  ScanRecord makeScan({
    String id = 'scan-1',
    String classId = 'tomato_healthy',
    DateTime? at,
  }) {
    return ScanRecord(
      id: id,
      imagePath: '/tmp/$id.jpg',
      prediction: DiagnosisPrediction(classId: classId, confidence: 0.95),
      capturedAt: at ?? DateTime(2026, 6, 1, 9, 30),
    );
  }

  test('a newly inserted scan round-trips correctly', () async {
    await db.insertScan(makeScan());

    final all = await db.getAllScans();

    expect(all, hasLength(1));
    expect(all.first.id, 'scan-1');
    expect(all.first.prediction.classId, 'tomato_healthy');
    expect(all.first.prediction.confidence, 0.95);
    expect(all.first.syncedAt, isNull);
  });

  test('getAllScans orders newest capture first', () async {
    await db.insertScan(makeScan(id: 'old', at: DateTime(2026, 1, 1)));
    await db.insertScan(makeScan(id: 'new', at: DateTime(2026, 6, 1)));

    final all = await db.getAllScans();

    expect(all.map((s) => s.id).toList(), ['new', 'old']);
  });

  test('getPendingScans only returns unsynced records', () async {
    await db.insertScan(makeScan(id: 'pending'));
    await db.insertScan(makeScan(id: 'synced'));
    await db.markSynced('synced', DateTime(2026, 6, 2));

    final pending = await db.getPendingScans();

    expect(pending.map((s) => s.id).toList(), ['pending']);
  });

  test('markSynced records the sync timestamp', () async {
    await db.insertScan(makeScan());

    await db.markSynced('scan-1', DateTime(2026, 6, 2, 10, 0));

    final all = await db.getAllScans();
    expect(all.first.isSynced, isTrue);
    expect(all.first.syncedAt, DateTime(2026, 6, 2, 10, 0));
  });

  test('device id is generated once and persisted across calls', () async {
    final first = await db.getOrCreateDeviceId();
    final second = await db.getOrCreateDeviceId();

    expect(first, second);
    expect(first, isNotEmpty);
  });

  test('device id survives reopening the same database file', () async {
    // in-memory DBs don't persist across close/reopen by design — this
    // proves the persistence contract using a real temp file instead.
    final path =
        '${Directory.systemTemp.path}/agrisense_test_${DateTime.now().microsecondsSinceEpoch}.db';
    final dbA = await LocalDatabase.open(path);
    final id = await dbA.getOrCreateDeviceId();
    await dbA.close();

    final dbB = await LocalDatabase.open(path);
    final reopenedId = await dbB.getOrCreateDeviceId();
    await dbB.close();
    await File(path).delete();

    expect(reopenedId, id);
  });

  FeedbackRecord makeFeedback({
    String id = 'feedback-1',
    String scanId = 'scan-1',
    String diagnosisAccuracy = DiagnosisAccuracy.correct,
  }) {
    return FeedbackRecord(
      id: id,
      scanId: scanId,
      diagnosisAccuracy: diagnosisAccuracy,
      treatmentOutcome: TreatmentOutcome.helped,
      notes: 'Cleared up within a week.',
      createdAt: DateTime(2026, 6, 5, 8, 0),
    );
  }

  test('a newly inserted feedback entry round-trips correctly', () async {
    await db.insertFeedback(makeFeedback());

    final pending = await db.getPendingFeedback();

    expect(pending, hasLength(1));
    expect(pending.first.scanId, 'scan-1');
    expect(pending.first.diagnosisAccuracy, DiagnosisAccuracy.correct);
    expect(pending.first.treatmentOutcome, TreatmentOutcome.helped);
    expect(pending.first.notes, 'Cleared up within a week.');
    expect(pending.first.isSynced, isFalse);
  });

  test('getPendingFeedback only returns unsynced entries', () async {
    await db.insertFeedback(makeFeedback(id: 'pending'));
    await db.insertFeedback(makeFeedback(id: 'synced'));
    await db.markFeedbackSynced('synced', DateTime(2026, 6, 6));

    final pending = await db.getPendingFeedback();

    expect(pending.map((f) => f.id).toList(), ['pending']);
  });

  test('hasFeedbackForScan reflects whether feedback was recorded', () async {
    expect(await db.hasFeedbackForScan('scan-1'), isFalse);

    await db.insertFeedback(makeFeedback(scanId: 'scan-1'));

    expect(await db.hasFeedbackForScan('scan-1'), isTrue);
    expect(await db.hasFeedbackForScan('scan-2'), isFalse);
  });
}
