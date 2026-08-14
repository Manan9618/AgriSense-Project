# ADR 0001: Monorepo with backend/ml/mobile split

## Status
Accepted — Week 1

## Context
The project spans a Django backend, a TFLite training pipeline, and a Flutter mobile app, all
built solo. They need to evolve together (e.g. a new disease class touches the model, the
backend's advisory mapping, and the app's class labels in the same change).

## Decision
Single repo, three top-level directories (`backend/`, `ml/`, `mobile/`) plus `docs/`, each with
its own dependency manifest and lint config. No shared package manager across them — Python
tooling for `backend/`+`ml/`, Dart tooling for `mobile/`.

## Consequences
- One CI pipeline can gate all three, path-scoped so a backend-only change doesn't run Flutter
  jobs (and vice versa) once `mobile/` exists from Week 4.
- Cross-cutting changes (new class, new advisory field) land in one PR instead of being
  coordinated across repos — important for a solo developer.
- Large binary data (trained models, datasets) must stay out of git regardless of this decision;
  handled via `.gitignore` + fetch/export scripts (see ADR 0003).
