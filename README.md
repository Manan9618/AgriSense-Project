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

## Status: Week 1 — Foundations & Environment Setup

- [x] Repo scaffold, linting, CI skeleton
- [x] Target disease/pest class list defined (`docs/classes.md`)
- [x] Core data models designed: `Scan`, `Diagnosis`, `Advisory`
- [x] Labeled dataset sourced (PlantVillage subset, see `ml/data/README.md`)

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
```
