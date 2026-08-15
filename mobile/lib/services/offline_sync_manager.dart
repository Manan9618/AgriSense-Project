import 'local_database.dart';
import 'sync_backend.dart';

/// OfflineSyncManager (docs/classes.md component spec, Week 9): "Local
/// scan/advisory queue -> Synced records when online."
///
/// Per-item error handling is the point: one scan failing to upload (flaky
/// connection mid-batch) must not abandon the rest of the queue, and must
/// leave that one scan pending rather than losing it — it's retried
/// automatically the next time syncPending() runs (app open, manual "Sync
/// Now" tap; see docs/adr/0010-offline-sync-architecture.md for why this
/// isn't a true background service).
class SyncSummary {
  const SyncSummary({required this.syncedCount, required this.failedCount});

  final int syncedCount;
  final int failedCount;

  bool get hadFailures => failedCount > 0;
  int get total => syncedCount + failedCount;
}

class OfflineSyncManager {
  OfflineSyncManager({required this.database, required this.backend});

  final LocalDatabase database;
  final SyncBackend backend;

  Future<SyncSummary> syncPending() async {
    final deviceId = await database.getOrCreateDeviceId();
    final pending = await database.getPendingScans();

    var syncedCount = 0;
    var failedCount = 0;
    for (final scan in pending) {
      try {
        await backend.pushScan(scan, deviceId: deviceId);
        await database.markSynced(scan.id, DateTime.now());
        syncedCount++;
      } on SyncBackendException {
        failedCount++;
      }
    }

    return SyncSummary(syncedCount: syncedCount, failedCount: failedCount);
  }
}
