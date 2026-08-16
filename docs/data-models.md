# Core Data Models

Defined in `backend/core/models.py`. Three models for Week 1, matching the plan's Component &
Tool Specifications (Section 5): `Scan` feeds `CropScanClassifier`, `Diagnosis` is its output,
`Advisory` is what `AdvisoryMapper` / `WeatherAdvisoryTool` / `MandiPriceComparator` all produce.

## Scan

One crop-photo capture event. Primary key is a client-generated UUID, not an auto-increment int
— the Flutter app creates these while offline (`OfflineSyncManager`, Week 9), so the ID has to be
assignable before the record ever reaches the backend, and stay collision-free across farmers'
devices once it syncs.

`captured_at` (device-local, when the photo was taken) is tracked separately from `created_at`
(when the backend first saw the row) and `synced_at` (when sync completed) — necessary to reason
about sync lag once `OfflineSyncManager` ships.

## Diagnosis

A classification result for a `Scan`. `ForeignKey` to `Scan`, not `OneToOne`, on purpose: after a
model retrain (Week 12/16 feedback loop) the same scan image can be re-run, and we want that
history — not an overwrite — so the Week 22 field-vs-lab evaluation can compare how one image
scored across model versions. `predicted_class` is constrained to `core.constants.DISEASE_CLASSES`
(mirrors `docs/classes.md`) so the backend can never store a class the model/app don't know about.
`source` distinguishes on-device inference from the Week 10 SMS-fallback text-menu path, which
produces a diagnosis without a photo at all.

## Advisory

Deliberately one generic model rather than three (`TreatmentAdvisory`/`WeatherAdvisory`/
`PriceAdvisory`), because all three get delivered through the same channels — app push, TTS
readback, SMS, or IVR voice call — built incrementally across Weeks 5-10. `kind` distinguishes
them; `diagnosis` is nullable because weather and price advisories aren't triggered by a
diagnosis at all.

See `docs/adr/0001-monorepo-structure.md` for the repo-layout reasoning and
`docs/adr/0002-class-list-scope.md` for why `Diagnosis.predicted_class` is scoped to 10 classes.

## Feedback

A farmer-confirmed outcome for a `Diagnosis` (Week 12, `FeedbackCollector` — see
`docs/adr/0013-model-feedback-loop.md`). `ForeignKey` to `Diagnosis`, not `Scan`, since feedback is
about a specific prediction. Its own model rather than fields on `Diagnosis`: feedback typically
arrives well after the diagnosis (a farmer only knows whether a treatment helped once it's had
days to act), and a diagnosis could in principle receive more than one round of feedback.
`diagnosis_accuracy` is always present; `treatment_outcome` is blank when the diagnosis was
"healthy" (nothing to treat).

## Deferred to later weeks (not in scope yet)

- **Farmer profile** — Scan/Advisory/Feedback currently reference Django's built-in `User`. A
  richer Farmer model (phone number as primary identity for SMS/IVR, village, preferred language)
  is needed once Week 13 (pilot onboarding) lands, since feature-phone farmers won't have an
  app-based account.
