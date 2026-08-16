# ADR 0015: Pilot launch monitoring — a command, not a dashboard or a public endpoint

## Status
Accepted — Week 15

## Context
The project plan's Week 15, "Pilot Launch," is a real-world event — farmers in real villages
using the app for the first time — that requires the Week 13 recruitment/training to have already
happened and the Week 15 launch itself to occur. Neither can happen from this environment (see
`docs/pilot/README.md`), and no pilot has launched, so there is no real usage data to report on.

What *is* in scope: the tooling a real launch would need on day one to know whether it's working —
"structured usage/diagnosis-accuracy data-collection infrastructure" per the plan's own phrasing.
Two questions shaped the design:

1. **Is new data collection needed, or does it already exist?** Scans, diagnoses, feedback, and
   community questions (Weeks 1, 9, 12, 14) are already real, tested, persisted data — the gap
   isn't collection, it's *aggregation*: nothing currently turns those rows into "is the pilot
   going well."
2. **Command, API endpoint, or dashboard?** A dashboard (Week 21, FPO dashboard) is explicitly a
   later week's deliverable. An API endpoint would need to be reachable and gated — but no
   authentication/staff-permission system exists yet (every write path in this app still uses the
   device-identity placeholder from ADR 0010), so an aggregate-usage endpoint today would either be
   public (exposing real farmer activity counts and diagnosis accuracy to anyone who finds the URL)
   or would need auth infrastructure this project hasn't built. Neither is acceptable to ship now.

## Decision
**`python manage.py pilot_usage_report`** (`backend/core/management/commands/pilot_usage_report.py`)
is the entire Week 15 deliverable: a management command a project operator runs directly against
the backend (same trust boundary as `export_retraining_candidates`, ADR 0013), summarizing
`Scan`/`Diagnosis`/`Feedback`/`Question`/`Answer` activity over a trailing window (`--days`,
default 7): scan counts by language, diagnosis class distribution and average confidence, the
diagnosis-accuracy and treatment-helped rates computed from `Feedback`, and community question/
answer counts. `--output <path>` writes JSON for scripting; without it, a human-readable summary
prints to stdout.

**Rates are `None`, never `0%`, when there's no data to compute them from** (`_rate()`'s explicit
empty-queryset check) — a pilot with zero feedback so far should read as "no data yet," not as "0%
accuracy," which would be actively misleading about a model that's actually performing fine but
just hasn't received feedback.

**No public API endpoint** — deliberately, for the auth reason above. If Week 21's FPO dashboard
needs this data over HTTP, that's the point to either add real auth or restrict such an endpoint to
Django's admin/staff permission system, not before.

## Consequences
- Running this command today (or in any test) produces an honestly empty/zero report — that's
  correct behavior, not a stub. `core/tests/test_pilot_usage_report.py` verifies the aggregation
  logic against fixture data, not real pilot claims.
- The moment a real pilot launches and Scan/Diagnosis/Feedback rows start arriving, this command
  becomes immediately useful with no code changes — the data model already supported this;
  Week 15 only added the aggregation.
- `docs/pilot/pilot-launch-readiness.md` tracks what's still blocking an actual launch (deployed
  backend, confirmed coordinator training, an owner for running this report) — this ADR is about
  the tool, that doc is about the operational gap the tool doesn't close.
