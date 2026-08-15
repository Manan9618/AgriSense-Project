# Treatment Advisory Content (Week 5)

## Source of truth

`content/treatment_recommendations.json` (repo root) — one entry per class_id from
`docs/classes.md`, each with a shared `urgency` (low/medium/high) and per-language
(`en`/`hi`/`gu`) `title` + `instructions`.

Both the backend and the app consume this **same file** rather than maintaining the content
twice:

- **Backend**: `manage.py seed_treatment_recommendations` loads it into `TreatmentRecommendation`
  rows (`backend/core/models.py`). `core/advisory_mapper.py`'s `map_diagnosis_to_advisory()` is
  the `AdvisoryMapper` component from the plan's Section 5 spec — turns a `Diagnosis` + language
  into a saved `Advisory` (kind=`treatment`).
- **Mobile**: `mobile/assets/content/treatment_recommendations.json` is a bundled copy, read
  directly by `AdvisoryService` (`mobile/lib/services/advisory_service.dart`) — no backend call
  needed. This is a deliberate offline-first choice, not scope-cutting: the project's core value
  proposition ("diagnosis-to-treatment time from days to minutes") depends on this working
  without connectivity, and the content is small and static enough (10 classes) that shipping it
  with the app costs nothing meaningful in size while removing a network dependency entirely.

Editing content: change the JSON once, then re-run the seed command (backend) and re-copy the
file into `mobile/assets/content/` (mobile) — see `mobile/README.md`.

## Coverage

All 10 classes × 3 languages = 30 entries. Verified by:
- `backend/core/tests.py::SeedTreatmentRecommendationsCommandTests` — every class has all 3
  languages after seeding, and re-seeding is idempotent (`update_or_create`).
- `mobile/test/advisory_service_test.dart` — same completeness check from the app side, plus
  urgency-level spot checks (late blight = high, healthy = low).

## Urgency levels

Assigned per condition, not derived from model confidence — a low-confidence late blight
detection is still high-urgency if correct, so urgency reflects the disease's real-world
severity/spread risk, independent of how sure the model was:

| Urgency | Conditions |
|---|---|
| High | Late blight (potato, tomato) — spreads fast, can destroy a field within days |
| Medium | Early blight, bacterial spot, leaf mold — treatable, less time-critical |
| Low | All `*_healthy` classes — no treatment needed |

## Content disclaimer

Instructions are general, widely-accepted horticultural guidance (remove affected material,
copper-based/appropriate fungicide classes, spacing/airflow/irrigation practices) — not
region-specific dosing or brand recommendations, since those vary by local regulation and
product availability. Appropriate as a first-response advisory pending the Week 13-16 pilot's
agronomist involvement (`CommunityQARouter`, Week 14) for anything more specific.
