# ADR 0010: SQLite local cache, Django (not Firebase) as the sync target, device-based identity

## Status
Accepted — Week 9

## Context
Week 9 needs "SQLite local cache for scans, advisories, and price data" and "background Firebase
sync when connectivity returns." Two things in that literal wording don't fit the project as it
actually stands by Week 9:

1. **Firebase**: the plan's tech stack (Section 2.1) lists Firebase for "data sync and push
   notifications." No Firebase project or credentials exist in this environment — same shape of
   constraint as every other external service so far (OpenWeatherMap, data.gov.in, Twilio-to-come).
   But unlike those, there's a second issue: the backend's `Scan`/`Diagnosis` models
   (`backend/core/models.py`) were *explicitly designed in Week 1* around exactly this scenario —
   "the Flutter app creates Scan records while offline... must be able to assign a durable ID
   before it ever talks to the backend." Adding Firebase as a second, parallel sync target
   alongside a Django backend already purpose-built for this would mean two sources of truth for
   the same data, for a solo-developer project, for no offsetting benefit.
2. **"Background" sync**: true background execution (syncing while the app is closed) needs
   platform-specific APIs (WorkManager on Android, BGTaskScheduler on iOS) that are exactly as
   unverifiable here as camera/microphone hardware — no device to confirm a background task
   actually fires.

## Decision
1. **Sync target is the Django backend**, not Firebase — a new endpoint,
   `POST /api/sync/scans/` (`backend/core/views.py`'s `ScanSyncView`), not a second, disconnected
   data store. This is a deliberate deviation from the plan's literal tech choice, made for
   architectural coherence given the constraints above, not a corner cut.
2. **"Background" sync becomes "sync on app open + manual retry,"** not a true OS background
   task: `OfflineSyncManager.syncPending()` runs once automatically at startup (via
   `_AppRootState._load`) and via a "Sync Now" button when scans are pending. Every failure is
   per-item (one scan failing doesn't block the rest of the batch) and leaves that scan pending
   for the next attempt — the retry *mechanism* is real and tested; only the *trigger* (open app,
   not "whenever the OS wakes a background task") is narrowed from the literal spec.
3. **Device-based identity, not real farmer accounts.** No auth system exists yet (flagged since
   ADR 0008). `ScanSyncView` auto-provisions a placeholder Django `User`
   (`device-<device_id>`) from a UUID generated once per install and persisted in SQLite's `meta`
   table (`LocalDatabase.getOrCreateDeviceId`). This is a real, working identity — not a stub —
   just not tied to a farmer's actual account, which doesn't exist yet.
4. **`sqflite_common_ffi` for genuine SQLite testing**, the same "real dependency, redirected
   backend for tests" pattern as `tflite_flutter` (ADR 0006) and `databaseFactory` is sqflite's
   own extension point for it — `LocalDatabase`, `ScanRepository`, and `OfflineSyncManager` are
   all tested against a real (if in-memory or temp-file) SQLite database and a real temp
   filesystem, not hand-rolled fakes standing in for either. Only `SyncBackend` (the network call)
   and `PhotoCaptureSource`/`VoiceCommandSource` (hardware) use the fake-for-tests pattern.
5. **`AppServices` bundle** (`lib/app_services.dart`): `HomeScreen`'s constructor had reached 8
   individually-threaded parameters by this week and was still growing — consolidated into one
   object rather than letting the list keep expanding.

## Consequences
- Confirmed genuinely working end-to-end, not just unit-tested in isolation:
  `sync_backend_live_backend_test.dart` performs a real multipart HTTP upload from
  `HttpSyncBackend` to an actually-running Django server, which creates a real `Scan` +
  `Diagnosis` + device `User` — verified in this session, including idempotent re-sync.
  `local_database_test.dart` proves the device id survives closing and reopening the same
  database *file* (not just in-memory), the actual persistence guarantee that matters.
- What's still a known gap: true background sync while the app is closed (needs a device to
  verify), and connectivity-change-triggered sync (would need `connectivity_plus`, another
  platform-channel dependency with the same untestable-here property as camera/STT — deferred
  rather than added speculatively).
- Migrating from device-based identity to real farmer accounts later means adding auth and
  re-pointing existing `device-*` `User` rows to real accounts — a known, bounded migration, not
  a redesign, since the `Scan.farmer` FK relationship itself doesn't change.
- 21 new mobile tests (50 total, 2 self-skipping), 7 new backend tests (49 total).
