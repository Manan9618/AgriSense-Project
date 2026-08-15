import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/diagnosis_prediction.dart';
import '../models/scan_record.dart';
import 'local_database.dart';

/// Turns a freshly-captured photo + prediction into a durable ScanRecord:
/// assigns a stable id, copies the image out of wherever the camera plugin
/// put it (often a volatile cache/temp location) into persistent app
/// storage, and writes it to LocalDatabase. Centralizing this in one place
/// means "what does it take to durably save a scan" has exactly one
/// implementation, tested with a real temp directory + real SQLite (Week 9)
/// rather than scattered across UI code.
class ScanRepository {
  ScanRepository({required this.database, required this.storageDirectory});

  final LocalDatabase database;
  final Directory storageDirectory;

  Future<ScanRecord> saveScan({
    required String capturedImagePath,
    required DiagnosisPrediction prediction,
    required String language,
    DateTime? capturedAt,
  }) async {
    final id = const Uuid().v4();
    final scansDir = Directory(p.join(storageDirectory.path, 'scans'));
    await scansDir.create(recursive: true);

    final extension = p.extension(capturedImagePath);
    final stablePath = p.join(scansDir.path, '$id$extension');
    await File(capturedImagePath).copy(stablePath);

    final scan = ScanRecord(
      id: id,
      imagePath: stablePath,
      prediction: prediction,
      capturedAt: capturedAt ?? DateTime.now(),
      language: language,
    );
    await database.insertScan(scan);
    return scan;
  }
}
