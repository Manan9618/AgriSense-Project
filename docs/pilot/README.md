# Pilot materials (Week 13)

The project plan's Week 13, "Pilot Logistics & Coordinator Training," is the first week whose
deliverables are primarily real-world activity — recruiting villages, selecting and training
field coordinators — rather than software. That activity requires physical presence in a target
region and cannot be performed or simulated in this environment.

## What's here

What *can* be prepared in advance of that activity — and is genuinely useful once it happens — is
the material a coordinator or farmer would be handed:

- **[coordinator-training-guide.md](coordinator-training-guide.md)** — what a field coordinator
  needs to know to demo the app, help a farmer through first use, and troubleshoot the common
  failure modes, written against what the app actually does (Weeks 1-12) rather than the plan's
  aspirational description of it.
- **[farmer-onboarding-leaflet.md](farmer-onboarding-leaflet.md)** — a short, plain-language
  leaflet a coordinator can read aloud or hand to a farmer, in all four languages the app
  currently supports (English, Hindi, Gujarati, Marathi — see `docs/adr/0012-regional-language-expansion.md`).
- **[village-selection-checklist.md](village-selection-checklist.md)** — the selection criteria
  and logistics questions that need real answers before a village is chosen, laid out as a
  checklist rather than filled in, since none of those answers exist yet.

## What's explicitly not here

No village names, coordinator names, farmer counts, or pilot dates appear anywhere in this repo.
Populating those requires an actual decision by whoever runs the pilot; inventing plausible-looking
placeholders for them would misrepresent how far the project has actually progressed. When that
information exists, it belongs in a tracking system outside this repo (e.g. a spreadsheet or the
Week 21 FPO dashboard's backing data), not hardcoded into documentation that gets committed to
version control.

Week 15 (Pilot Launch) and Week 16 (Mid-Pilot Iteration) carry the same constraint — see their
sections in the top-level `README.md`'s Status log for what's software-ready versus what still
needs a real pilot to happen.
