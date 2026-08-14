# AgriSense AI

Smart farming assistant for smallholder farmers — offline crop disease diagnosis from a photo,
weather advisories, and live mandi price comparison, with SMS/voice fallback for feature phones.

Full 24-week project plan lives in `AgriSense_AI_24Week_Full_Plan.pdf`. This repo tracks the
implementation, phase by phase.

## Repo layout

```
backend/    Django API — farmer accounts, advisory orchestration, price/weather aggregation
ml/         Model training pipeline — dataset prep, CV model training, TFLite conversion
mobile/     Flutter app — camera capture, voice-first UI, offline sync (scaffolded Week 4)
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

## Backend quickstart

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
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
