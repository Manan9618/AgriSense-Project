import 'package:flutter/foundation.dart';

import '../models/scan_record.dart';

/// In-memory scan history for this app session. Week 9 replaces the backing
/// store with SQLite (offline-first cache) without changing this class's
/// public shape, so screens built against it now don't need rework later.
class ScanHistoryProvider extends ChangeNotifier {
  final List<ScanRecord> _scans = [];

  List<ScanRecord> get scans => List.unmodifiable(_scans);

  void add(ScanRecord scan) {
    _scans.insert(0, scan);
    notifyListeners();
  }
}
