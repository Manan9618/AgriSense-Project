# Pilot Launch Readiness (Week 15)

The project plan's Week 15, "Pilot Launch," means going live with real farmers in real villages.
That event — and everything it depends on (village selection, coordinator deployment, actual
farmers using actual phones) — cannot happen from this environment; see
[README.md](README.md) and [village-selection-checklist.md](village-selection-checklist.md) for
why. What this week adds instead is the monitoring tooling a real launch would need on day one,
and an honest checklist of what's still blocking that launch.

## What's ready

- **Usage/accuracy monitoring**: `python manage.py pilot_usage_report` (backend, see
  `docs/adr/0015-pilot-launch-monitoring.md`) summarizes real Scan/Diagnosis/Feedback/Question
  activity over a trailing window — total scans, diagnosis class distribution, average confidence,
  the diagnosis-accuracy and treatment-helped rates computed from `Feedback` (Week 12), and
  community activity (Week 14). It reports honestly empty/zero right now, because no pilot
  activity exists yet — running it against a freshly-seeded database is exactly what
  `core/tests/test_pilot_usage_report.py` verifies.
- **Every data source it reports on already exists and is tested**: scans (Week 9), diagnoses
  (Week 1), feedback (Week 12), and community questions (Week 14) are all real, working pipelines
  — this command aggregates what's already being collected, it doesn't add new collection.

## What's still blocking an actual launch

Everything in [village-selection-checklist.md](village-selection-checklist.md) remains
unanswered — village, coordinators, dates, devices, consent process. On top of that, launch
specifically needs:

- [ ] **A deployed, reachable backend.** Today the backend only runs via `manage.py runserver` on
      a developer's machine (see the top-level `README.md`'s "Backend quickstart"). Week 18
      (Dockerization & CI/CD) is what makes a real deployment possible — a pilot cannot go live
      against a laptop.
- [ ] **A decision on who runs `pilot_usage_report` and how often**, and where its output goes
      (a shared doc, a Slack post, eventually the Week 21 FPO dashboard) — the command exists, but
      nobody has been assigned to actually run it during a live pilot.
- [ ] **Confirmation that Week 13's training materials were actually delivered** to real
      coordinators — `docs/pilot/coordinator-training-guide.md` existing in this repo doesn't mean
      anyone has been trained yet.
- [ ] **A rollback/support plan**: who a coordinator escalates to (per
      `coordinator-training-guide.md` §6) if something breaks mid-pilot, and what "pause the
      pilot" looks like operationally if needed.

## What happens once launch actually happens

Real usage will start populating `Scan`/`Diagnosis`/`Feedback`/`Question` rows for the first time.
`pilot_usage_report` immediately becomes meaningful at that point — no code changes are needed for
that transition, only real farmers using the real app. This document should be revisited and its
checkboxes updated (or replaced by whatever actually happened) once that's true; it isn't
self-updating.
