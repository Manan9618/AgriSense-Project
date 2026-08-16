# ADR 0013: Model Feedback Loop — FeedbackCollector, and what "retraining pipeline" means before a pilot exists

## Status
Accepted — Week 12

## Context
The project plan's Week 12 introduces `FeedbackCollector`: "farmer-confirmed outcome -> feeds
retraining pipeline" (docs/classes.md's "Revising this list" section already anticipated this,
and `docs/data-models.md`'s "Deferred to later weeks" section flagged Feedback as its own model
back in Week 1). Two questions had to be answered before writing any code:

1. What does a farmer actually confirm, and when? A diagnosis's correctness and a treatment's
   effectiveness are two different questions answerable at two different times — a farmer can say
   "that doesn't look right" the moment they see the result, but "did the spray work" only after
   days have passed. Both matter for the same underlying goal (surfacing bad predictions for
   retraining) but can't be collected as a single event.
2. What can "feeds retraining pipeline" honestly mean this week? No pilot has launched yet
   (Weeks 13/15/16 haven't happened), so there is no real farmer feedback to feed anything. A
   pipeline "design" that can't be exercised isn't trustworthy — the goal here is a mechanism that
   is fully real and tested today, and does something useful the moment real feedback starts
   arriving, without fabricating that feedback now.

## Decision

**Feedback is its own model**, FK'd to `Diagnosis` (not `Scan`): `diagnosis_accuracy` (correct /
incorrect / unsure) is always asked; `treatment_outcome` (helped / no change / worsened / not
applicable) is asked only when the diagnosis wasn't "healthy" — there's nothing to treat
otherwise. Both land in one `Feedback` row rather than two separate submissions, since in practice
a farmer answers both in one sitting when they do revisit a scan.

**The mobile UI is reachable from a past scan, not just the one just captured**: `DiagnosisResultScreen`
gained a `_FeedbackSection` (a "Give Feedback" button that opens `FeedbackSheet`, a bottom sheet
with the two questions) — and that screen is already reachable from `RecentScanTile` taps
(Week 4), so no new navigation had to be built. This matches how the questions actually get
answered in practice: a farmer taps back into an old scan once they know how the treatment went,
not necessarily right after capture.

**Offline-first, syncing the same way scans do**: `FeedbackRecord` mirrors `ScanRecord`'s shape —
client-generated UUID, a local `feedback` SQLite table (`LocalDatabase` bumped to schema version 2
with an `onUpgrade` path for existing installs), synced via `SyncBackend.pushFeedback` /
`OfflineSyncManager`. The backend's `FeedbackSyncView` (`POST /api/sync/feedback/`) resolves the
`Diagnosis` from `scan_id` — the only identifier the client ever has, since `ScanSyncView` never
hands back a server-assigned `Diagnosis` id — rather than requiring the client to track a second
server-side UUID. This means feedback for a scan that hasn't synced yet 404s; `OfflineSyncManager`
syncs scans before feedback in the same `syncPending()` pass specifically so same-session feedback
gets its best chance of going through immediately, and a failed feedback push is retried
independently of the scan (see `offline_sync_manager_test.dart`'s two new tests).

**The retraining "pipeline" is one real, tested command, not a design doc**: `export_retraining_candidates`
(a Django management command) queries `Feedback` rows where `diagnosis_accuracy=incorrect`,
joins back to the `Diagnosis`/`Scan`, and writes a CSV manifest (`ml/data/retraining_candidates.csv`
by default — already gitignored, same convention as the rest of `ml/data/`) for a human to review
before the next retrain. This is deliberately the *entire* pipeline for now: it moves data that
already exists, produces an empty CSV when no such feedback exists (which is the honest state of
the world today), and is exercised in `test_export_retraining_candidates.py` against fixture data
that is clearly fixture data, not something dressed up as real pilot results. The next stage —
relabeling flagged images and feeding them into `ml/scripts/prepare_dataset.py` — needs actual
field images, which don't exist until Weeks 13-16.

## Explicitly out of scope this week
Weeks 13, 15, and 16 involve real-world activity — recruiting pilot villages, training
coordinators, a live multi-village launch, farmers actually using the app and giving feedback —
that requires physical presence and cannot be performed or simulated from this environment. This
week's work is the software those weeks will need once they happen: the collection mechanism, the
sync path, and the export command. No synthetic pilot feedback has been created anywhere in this
codebase to make the retraining pipeline look further along than it is — `Feedback.objects.count()`
is genuinely zero outside of test fixtures until real farmers use the real app.

## Consequences
- Adding a class-relabeling step later is additive: `export_retraining_candidates --output <path>`
  already produces exactly the join a human reviewer needs; nothing about today's schema needs to
  change to support it.
- `LocalDatabase`'s version bump (1 -> 2) with `onUpgrade` is the first schema migration this app
  has needed — establishes the pattern (`if (oldVersion < N) { ... }`) for future additions instead
  of relying on `onCreate` alone, which only new installs would ever hit.
- `FeedbackSyncView`'s scan-first ordering means a feedback submission made entirely offline for a
  scan that's never synced can wait indefinitely — acceptable today (no real users), but worth
  revisiting if the Week 15 pilot shows farmers going long stretches offline between scan and
  feedback.
