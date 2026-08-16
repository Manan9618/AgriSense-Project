# AgriSense AI

Smart farming assistant for smallholder farmers — offline crop disease diagnosis from a photo,
weather advisories, and live mandi price comparison, with SMS/voice fallback for feature phones.

Full 24-week project plan lives in `AgriSense_AI_24Week_Full_Plan.pdf`. This repo tracks the
implementation, phase by phase.

## Repo layout

```
backend/    Django API — farmer accounts, advisory orchestration, price/weather aggregation
ml/         Model training pipeline — dataset prep, CV model training, TFLite conversion
mobile/     Flutter app — camera capture, on-device diagnosis, voice-first UI, offline sync
content/    Shared content (treatment recommendations) consumed by both backend and mobile
docs/       Class list, data model notes, ADRs, dataset card
```

## Status

### Week 1 — Foundations & Environment Setup
- [x] Repo scaffold, linting, CI skeleton
- [x] Target disease/pest class list defined (`docs/classes.md`)
- [x] Core data models designed: `Scan`, `Diagnosis`, `Advisory`
- [x] Labeled dataset sourced (PlantVillage subset, see `docs/dataset-card.md`)

### Week 2 — CV Model v1 (Training)
- [x] Baseline classifier trained: MobileNetV2 transfer learning (`docs/adr/0004-mobilenetv2-transfer-learning.md`)
- [x] Precision/recall per class evaluated on held-out test set
- [x] Class imbalance addressed via oversampling + augmentation (`ml/scripts/data.py`)
- [x] Documented accuracy: **96.12% test accuracy** — see `docs/model-card.md`

### Week 3 — TFLite Quantization & On-Device Test
- [x] Converted to TFLite, full int8 quantization (`docs/adr/0005-tflite-int8-quantization.md`)
- [x] Model size: **2.63MB** (target <15MB)
- [x] Accuracy retention validated: **95.20%** quantized vs 96.12% float (0.93pp drop, within 3% tolerance)
- [x] Latency benchmarked: ~3ms mean (CPU proxy — see caveat in `docs/model-card.md`; real Android device benchmarking still needed)

### Week 4 — App Shell
- [x] Flutter app shell: camera capture flow, results screen, language selector (`docs/adr/0006-flutter-app-architecture.md`)
- [x] TFLite model wired for on-device inference — verified with **real** inference in `flutter test` (not mocked), using the actual bundled quantized model against held-out test images
- [x] Camera hardware itself isolated behind a `PhotoCaptureSource` interface and untested here (no device/emulator available) — see `mobile/README.md` for what's verified vs. not

### Week 5 — Diagnosis Advisory Content
- [x] Treatment-recommendation database: `TreatmentRecommendation` model + `AdvisoryMapper` (`backend/core/advisory_mapper.py`)
- [x] Localized into English, Hindi, Gujarati — all 10 classes × 3 languages (`content/treatment_recommendations.json`, see `docs/advisory-content.md`)
- [x] Wired into the app's Diagnosis Result screen — real localized advice shown fully offline, no backend call
- [x] Urgency levels (low/medium/high) drive the result screen's urgency badge and color

### Week 6 — Weather Advisory Integration
- [x] `WeatherProvider` abstraction + `OpenWeatherMapProvider` (`backend/core/weather_provider.py`) — no live API key in this environment, so tests use a fake provider + a mocked-response parsing test (`docs/adr/0007-weather-provider-abstraction.md`)
- [x] `WeatherAdvisoryTool` rule engine (`backend/core/weather_advisory_tool.py`): rain-within-6h, good-spray-window, dry-spell-irrigate — localized into all 3 languages (`content/weather_advisory_templates.json`)
- [x] 10 tests covering the rule engine (including rule-interaction and wind-exclusion edge cases) — backend-only this week, no API endpoint/mobile UI yet (see ADR 0007 for why)

### Week 7 — Mandi Price Feed
- [x] `MandiPriceProvider` abstraction + `AgmarknetProvider` (data.gov.in) + `SampleMandiPriceProvider` fallback when no API key is configured (`backend/core/price_provider.py`, `docs/adr/0008-price-comparator-and-first-api-endpoint.md`)
- [x] `MandiPriceComparator` ranks nearby markets best-price-first (`backend/core/price_comparator.py`); "distress sale" price-gap advisory logic tested (10%+ gap threshold)
- [x] **First backend<->app network integration**: `GET /api/prices/compare/` (DRF) + a mobile Price Comparison screen — verified with a **genuine end-to-end test** (real HTTP call to a live `manage.py runserver`, not mocked), which self-skips safely when no server is running
- [x] 16 new backend tests (42 total), 4 new mobile tests (12 total)

### Week 8 — Voice-First Navigation
- [x] TTS advisory readback: "Hear Advice in {language}" button on the Diagnosis Result screen (`mobile/lib/services/tts_service.dart`) — **tested for real** by mocking flutter_tts's actual platform channel, not faked (`docs/adr/0009-voice-first-navigation.md`)
- [x] Voice-command navigation for scan/prices (`mobile/lib/core/voice_command_parser.dart`): simple, transparent keyword matching across English/Hindi/Gujarati, no NLU/network call — offline-first like the rest of the app
- [x] `VoiceCommandSource` interface for speech-to-text, same interface-plus-fake pattern as the camera (`PhotoCaptureSource`) — real STT plugin usage untested here (no microphone/emulator), everything downstream of it (command parsing, navigation wiring) tested via a fake
- [x] 17 new mobile tests (29 total, 1 self-skipping)

### Week 9 — Offline-First Sync
- [x] SQLite local cache (`mobile/lib/services/local_database.dart`) — **tested for real** against an actual SQLite database via `sqflite_common_ffi`, not fakes (same "redirect the real dependency" pattern as `tflite_flutter`)
- [x] `ScanRepository` persists captured photos into stable app storage + SQLite under a client-generated UUID; `ScanHistoryProvider` is now a reactive view over the database instead of in-memory-only
- [x] `OfflineSyncManager` + `POST /api/sync/scans/` (DRF) sync scans to the **Django backend** (not Firebase — a deliberate, documented deviation, see `docs/adr/0010-offline-sync-architecture.md`) with per-item retry and device-based identity (no farmer auth yet)
- [x] Verified end-to-end: a real multipart upload to a live Django server creates a real `Scan` + `Diagnosis` + device `User`, confirmed idempotent on re-sync
- [x] `HomeScreen`'s constructor, having reached 8 individually-threaded parameters, was consolidated into an `AppServices` bundle
- [x] 21 new mobile tests (50 total, 2 self-skipping), 7 new backend tests (49 total)

### Week 10 — SMS/Voice Fallback
- [x] **Fully tested, not just "real but unverifiable here"**: Twilio webhooks handle *incoming* SMS/calls, which needs zero API credentials (only outbound sends would) — the first external-service integration this project could exercise completely, see `docs/adr/0011-twilio-fallback-channels.md`
- [x] SMS: two-question triage (crop, then symptom — 3 options each, per the plan's own non-literate-UX guidance) reusing Week 5's `TreatmentRecommendation` content; state tracked in `SmsSession` keyed by phone number (`backend/core/sms_fallback_handler.py`)
- [x] Voice IVR: same triage, state carried via `<Gather>` action-URL query params instead of a session model (`POST /api/voice/webhook/`)
- [x] 26 new backend tests (75 total) — the crop/symptom mapping, the full SMS state machine (happy paths, invalid input recovery, per-phone-number isolation), and both webhook views via simulated Twilio payloads

### Week 11 — Regional Language Expansion
- [x] Added **Marathi** as a 4th supported language across the whole stack (content JSON, backend seed data, mobile UI chrome, TTS/STT locales) rather than migrating `AppStrings` to Flutter's ARB/`gen-l10n` pipeline — a deferral explained in `docs/adr/0012-regional-language-expansion.md`, not an oversight
- [x] Supported-language set is now **discovered from `content/treatment_recommendations.json`**, not hardcoded — the seed command (`backend/core/management/commands/seed_treatment_recommendations.py`) derives it and fails loudly (`CommandError`) on inconsistent per-class coverage; both the backend and mobile "every class, every language" tests derive their expected set the same way, so they extend themselves automatically the next time a language is added
- [x] All three shared content files (`treatment_recommendations.json`, `weather_advisory_templates.json`, `price_advisory_templates.json`) now have full `en`/`hi`/`gu`/`mr` coverage for every entry
- [x] 1 new mobile test assertion (Marathi selection in `home_screen_flow_test.dart`), `advisory_service_test.dart` now iterates the discovered language set instead of a hardcoded 3 (48 mobile tests total, 2 self-skipping); backend stays at 75 tests (assertions strengthened, no new test count) with the seed command now producing 40 rows (10 classes × 4 languages)

### Week 12 — Model Feedback Loop
- [x] `Feedback` model (`backend/core/models.py`): farmer-confirmed diagnosis accuracy + treatment outcome, its own model FK'd to `Diagnosis` rather than fields on it — see `docs/adr/0013-model-feedback-loop.md`
- [x] `POST /api/sync/feedback/` (`FeedbackSyncView`) resolves the diagnosis from `scan_id` (the only id the client ever has) and is idempotent by client-generated id, same pattern as Week 9's scan sync
- [x] Mobile: `FeedbackSheet` + `_FeedbackSection` on the Diagnosis Result screen (reachable from a past scan, not just right after capture), offline-first via a new `feedback` SQLite table (`LocalDatabase` bumped to schema v2 with a real `onUpgrade` path) and synced by `OfflineSyncManager` alongside scans
- [x] `export_retraining_candidates` management command: a real, tested CSV export of feedback flagged "incorrect" for human review — the actual retraining pipeline is deliberately just this today, since no real pilot feedback exists yet (Weeks 13/15/16 are still ahead)
- [x] 13 new backend tests (88 total); 10 new mobile tests across `local_database_test.dart`, `offline_sync_manager_test.dart`, a new `diagnosis_result_feedback_test.dart`, and a self-skipping `feedback_sync_backend_live_backend_test.dart` (60 mobile tests total, 4 self-skipping) — the live-backend ones were also run for real against a running `manage.py runserver` and pass genuinely, not just in the self-skip path

### Week 13 — Pilot Logistics & Coordinator Training
- [ ] **Not software** — this week's actual deliverable is real-world activity (recruiting pilot villages, selecting and training field coordinators) that requires physical presence and cannot be performed or simulated here; see `docs/pilot/README.md` for the explicit scope boundary
- [x] What *can* be prepared in advance: `docs/pilot/coordinator-training-guide.md` (grounded in what the app actually does through Week 12, not the plan's aspirational description), `docs/pilot/farmer-onboarding-leaflet.md` (all 4 supported languages), and `docs/pilot/village-selection-checklist.md` (the questions that need real answers, deliberately left unanswered)
- [ ] No village, coordinator, or farmer data — real or placeholder — has been added anywhere in this repo; that data belongs in a pilot-tracking system outside version control once it exists

## Backend quickstart

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_treatment_recommendations
python manage.py test
```

## ML pipeline quickstart

```bash
cd ml
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python scripts/download_dataset.py
python scripts/prepare_dataset.py
python scripts/train.py --run-name v1       # ~66 min on CPU (Apple M3)
python scripts/evaluate.py --run-name v1
```
