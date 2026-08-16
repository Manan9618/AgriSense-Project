# Village Selection & Pilot Logistics Checklist

Questions that need real, on-the-ground answers before Week 15 (Pilot Launch) can happen. This is
a checklist, not a plan — every item below is unanswered as of Week 13; filling them in requires
actual site visits, conversations, and decisions this repo cannot make on its own.

## Village selection criteria

- [ ] Does the region's dominant crop mix match the app's current 10 classes (Potato, Pepper,
      Tomato — see `docs/classes.md`)? If not, is it close enough that the pilot is still useful,
      or does it justify revisiting the class list first (`docs/adr/0002-class-list-scope.md`
      already flags this as a live possibility)?
- [ ] What's the realistic mobile network coverage — not just "does 4G exist," but how often
      farmers in the target villages actually have a signal, since the app's offline-first design
      assumes long stretches without one.
- [ ] Smartphone penetration among target farmers, and a rough split of who would use the app
      directly versus who needs the SMS/voice fallback (`backend/core/sms_fallback_handler.py`).
- [ ] Is there a existing agricultural extension worker, FPO (farmer producer organization), or
      similar local contact who could act as or help recruit a coordinator?
- [ ] Language: does the village's primary spoken language match one the app supports (English,
      Hindi, Gujarati, Marathi)? If not, that's either a blocker or a new translation task before
      launch.

## Coordinator recruitment

- [ ] How many coordinators does the target village count need, and at what farmer-to-coordinator
      ratio is hands-on help actually feasible during the pilot window?
- [ ] What's the selection criteria — literacy, smartphone comfort, existing trust in the
      community, availability during the pilot period?
- [ ] Who delivers the training in `coordinator-training-guide.md`, and how (in-person session,
      remote call, self-guided)?
- [ ] Is there a point of contact for coordinators to escalate to when they hit something outside
      `coordinator-training-guide.md`'s §6 ("what to escalate")?

## Operational logistics

- [ ] Pilot start date and duration — needed before Week 15 can be scheduled at all.
- [ ] Device provisioning: do farmers use their own phones, or are pilot devices being provided?
      If provided, who owns/replaces them after the pilot?
- [ ] Data costs: if farmers are on limited data plans, does syncing scans/feedback/weather/prices
      meaningfully affect their usage, and does that need to be communicated or subsidized?
- [ ] Backend hosting: the Django backend currently runs locally in development (see the
      "Backend quickstart" section of the top-level `README.md`, and
      `docs/adr/0010-offline-sync-architecture.md`) — Week 18 (Dockerization & CI/CD) is what
      makes a real deployed backend possible; a pilot cannot go live against `manage.py runserver`
      on a laptop.
- [ ] Consent and data handling: farmers' scan photos, locations (if captured), and feedback are
      real personal/agricultural data once a pilot starts — what consent process and data
      retention policy applies, and who owns that decision?

## What happens once these are answered

The answers to this checklist don't belong in this repo's version control (see
`docs/pilot/README.md` for why) — they belong wherever the pilot is actually being coordinated
(a shared spreadsheet, a project management tool, or eventually the Week 21 FPO dashboard's
backing data). This checklist exists so nothing gets missed before Week 15, not to be filled in
here.
