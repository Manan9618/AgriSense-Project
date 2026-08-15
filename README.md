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
