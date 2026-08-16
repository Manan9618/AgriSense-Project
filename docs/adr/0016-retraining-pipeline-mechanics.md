# ADR 0016: Validating retraining-pipeline mechanics without real field data

## Status
Accepted — Week 16

## Context
The project plan's Week 16, "Mid-Pilot Iteration," assumes a pilot has been running (Weeks 13-15)
and is now producing real field feedback and images that reveal model weaknesses worth fixing.
None of that exists yet — see `docs/pilot/README.md` and ADR 0015 — so there is no real
pilot-driven fix to make and no field images to retrain on.

What *can* be validated now: whether the mechanical pipeline Week 12 started (`Feedback` ->
`export_retraining_candidates` -> a CSV of flagged scans) actually connects all the way through to
something `ml/scripts/prepare_dataset.py` can consume, so that the day real field data exists,
incorporating it is a known, tested procedure rather than something invented under pressure
mid-pilot.

## Decision

**`export_retraining_candidates`'s CSV (Week 12) gained a blank `corrected_class` column**, filled
in by a human reviewer after actually looking at the flagged image — the export command itself
still only reports what a diagnosis was *flagged as wrong*, never guesses what it should have
been.

**`ml/scripts/incorporate_feedback.py` (Week 16) is the missing link**: given that reviewed CSV
and a directory of the corresponding image files (copied out of the Django backend's `media/` by
whoever did the review — `ml/` has no direct access to the backend's storage, by design, keeping
the ML pipeline's only dependency on the backend being this one CSV handoff), it copies each
reviewed image into `ml/data/raw/<corrected_class>/`, the exact layout
`ml/scripts/prepare_dataset.py` already expects from `download_dataset.py`'s output. Unreviewed
rows, rows with an unrecognized class, and rows whose image file wasn't found are all skipped and
counted separately, never silently dropped or guessed at.

**The controlled test uses synthetic images, not real field photos**: `ml/scripts/tests/
test_incorporate_feedback.py` generates tiny in-memory images with Pillow and a hand-written CSV
fixture, verifying the merge mechanics (correct destination path, class-folder creation, skip
behavior for each failure mode, idempotent re-runs) — this is the first pytest coverage `ml/`
scripts have had (Weeks 2-3's `train.py`/`evaluate.py` were verified by running them and reading
their accuracy output, not unit-tested, since their point is model quality; `incorporate_feedback.py`
is pure file-mechanics and benefits from the same real-testing standard applied everywhere else in
this project). It proves the script works, not that any real diagnosis was ever wrong.

**Actually re-running `train.py` is explicitly not automated by this script, and not done this
week.** `incorporate_feedback.py` prints a reminder to re-run `prepare_dataset.py` next, but stops
there — retraining on a handful of reviewed images (which is all that could exist without a real
pilot) wouldn't produce a meaningfully better model, and running it now would produce a model
version with no real basis, which this project has consistently avoided (see ADR 0004's, ADR
0005's, and every prior week's insistence on real verification over fabricated results). Deciding
when there's *enough* reviewed field data to justify a retrain is a judgment call for whoever runs
the pilot, not something to hardcode a threshold for today.

## Consequences
- The retraining pipeline is now fully mechanically connected end-to-end (`Feedback` ->
  CSV export -> human review -> `incorporate_feedback.py` -> `prepare_dataset.py` ->
  `train.py`), with every step except the human review itself covered by passing tests.
- The first real use of `incorporate_feedback.py` will be during an actual pilot (Week 15+); until
  then it has nothing to incorporate, same honesty stance as `pilot_usage_report` (ADR 0015).
- `ml/scripts/tests/` and its `conftest.py` (adding `ml/scripts/` to `sys.path` so flat script
  modules can import each other in tests, mirroring how the scripts already import each other when
  run directly) establish the pattern for testing future `ml/` scripts that are pure mechanics
  rather than model training.
