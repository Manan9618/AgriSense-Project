import 'package:flutter/foundation.dart';

import '../models/scan_record.dart';
import '../services/local_database.dart';

/// Reactive in-memory view over LocalDatabase's `scans` table (Week 9).
/// Not the write path itself — ScanRepository owns persisting a new scan
/// (id assignment, file copy, SQLite insert); this class only mirrors that
/// state for the UI and refreshes after sync runs update which scans are
/// marked synced.
class ScanHistoryProvider extends ChangeNotifier {
  List<ScanRecord> _scans = [];

  List<ScanRecord> get scans => List.unmodifiable(_scans);
  int get pendingSyncCount => _scans.where((s) => !s.isSynced).length;

  Future<void> loadFromDatabase(LocalDatabase database) async {
    _scans = await database.getAllScans();
    notifyListeners();
  }

  /// Adds a scan already persisted elsewhere (ScanRepository.saveScan) to
  /// the in-memory view — does not touch the database itself.
  void add(ScanRecord scan) {
    _scans = [scan, ..._scans];
    notifyListeners();
  }
}
