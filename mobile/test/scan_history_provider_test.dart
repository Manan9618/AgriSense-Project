import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/services/local_database.dart';
import 'package:agrisense_ai/state/scan_history_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDatabase database;

  setUp(() async {
    database = await LocalDatabase.open(inMemoryDatabasePath);
  });

  tearDown(() => database.close());

  ScanRecord makeScan(String id, {bool synced = false}) {
    return ScanRecord(
      id: id,
      imagePath: '/tmp/$id.jpg',
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.9,
      ),
      capturedAt: DateTime(2026, 6, 1),
      syncedAt: synced ? DateTime(2026, 6, 2) : null,
    );
  }

  test('loadFromDatabase populates scans from persisted records', () async {
    await database.insertScan(makeScan('a'));
    await database.insertScan(makeScan('b'));
    final provider = ScanHistoryProvider();

    await provider.loadFromDatabase(database);

    expect(provider.scans, hasLength(2));
  });

  test('add prepends without touching the database', () async {
    final provider = ScanHistoryProvider();
    final scan = makeScan('new-scan');

    provider.add(scan);

    expect(provider.scans, [scan]);
    expect(await database.getAllScans(), isEmpty);
  });

  test('pendingSyncCount reflects unsynced records only', () async {
    await database.insertScan(makeScan('pending-1'));
    await database.insertScan(makeScan('pending-2'));
    await database.insertScan(makeScan('already-synced', synced: true));
    final provider = ScanHistoryProvider();

    await provider.loadFromDatabase(database);

    expect(provider.pendingSyncCount, 2);
  });

  test('notifies listeners when loaded', () async {
    await database.insertScan(makeScan('a'));
    final provider = ScanHistoryProvider();
    var notified = false;
    provider.addListener(() => notified = true);

    await provider.loadFromDatabase(database);

    expect(notified, isTrue);
  });
}
