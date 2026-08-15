# ADR 0011: SMS/Voice fallback needs no Twilio credentials — and a menu design that admits its own imprecision

## Status
Accepted — Week 10

## Context
Unlike every other external-service integration so far (OpenWeatherMap, data.gov.in), Twilio's
SMS/Voice **webhooks** are the opposite direction: Twilio calls *our* server when a message or
call comes in, and expects a TwiML XML document back — generated entirely locally, no outbound
API call, no account SID/auth token required. Credentials are only needed for *proactively*
sending a message or placing a call, which this week's scope (react to an inbound SMS/call) never
does. This is a materially different, better situation than Weeks 6/7's "real implementation,
untested here" pattern — the whole flow can be genuinely exercised end-to-end.

The harder problem is the menu design itself. Section 11.2 of the project plan calls out "SMS/Voice
UX for Non-Readers" as a hard problem and prescribes "menus to 3 options max." With 10 classes
across 3 crops, a text/voice-only conversation fundamentally cannot achieve photo-level diagnostic
precision — there's no way to fit "which of 5 tomato diseases" into a 3-option menu without
either violating the 3-option guidance or asking the farmer to describe visual details that are
exactly what a photo would show more reliably.

## Decision
1. **Two-question triage, not a disease picker**: "Which crop?" (3 options, one per crop) then
   "What do you see?" (3 options: spots/blight, wilting/fast-spreading, healthy) — 9 total
   combinations, each mapped to the single most-likely class in `docs/classes.md`
   (`core/fallback_diagnosis.py`'s `SYMPTOM_TO_CLASS`). The "wilting" option is deliberately the
   more urgent condition per crop (late blight over early blight) — the distinction the treatment
   advice actually depends on, not a false promise of matching a specific pathogen from a text
   description. This is Section 11.2's guidance applied literally rather than worked around.
2. **SMS state lives in `SmsSession`** (keyed by phone number — the only identity a feature-phone
   farmer has, no app account or device id involved), since Twilio's SMS webhook is one stateless
   POST per message. **Voice state lives in the `<Gather>` action URL's query string** instead —
   Twilio's redirect-with-parameters mechanism already *is* a state machine for a flow this
   short, so a parallel session model would be pure duplication.
3. **Shared lookup logic** (`get_treatment_text`, in the same module as the crop/symptom mapping)
   reuses `TreatmentRecommendation` — the exact Week 5 content, with the same English-fallback
   behavior as `AdvisoryMapper` and the weather/price advisory generators. No fourth copy of
   "look up localized advice, fall back to English."
4. **`Diagnosis.Source.SMS_FALLBACK`** already existed in the model (Week 1 anticipated this) but
   isn't written to yet — the fallback handlers reply directly with advice text rather than
   creating `Scan`/`Diagnosis` rows, since there's no photo and no authenticated farmer to attach
   a record to (the same device-identity gap noted in ADR 0010). Wiring fallback interactions
   into the outcome-tracking data model is a natural fit for Week 12's feedback loop, not this
   week's scope.

## Consequences
- Fully tested, not "real but unverifiable here": 26 new tests cover the crop/symptom mapping,
  the SMS state machine (happy paths, invalid input at each state, session isolation per phone
  number, cleanup after completion, language persistence), and both webhook views via Django's
  test client posting form-encoded payloads shaped exactly like Twilio's real ones.
- The 9-combination mapping is a real accuracy ceiling, and an honest one: a farmer describing
  "spots" on a tomato gets early-blight advice even if it's actually bacterial spot. Both are
  fungal/bacterial leaf-spot conditions with overlapping treatment (copper-based fungicide,
  remove affected leaves), so the practical harm of the mapping being "not the exact right
  disease" is low — but it's a real limitation to track once field data exists (Week 22), not
  something to paper over.
- Outbound Twilio use (proactively texting a weather/price alert, rather than replying to an
  inbound message) is out of scope here and would need real credentials — a different problem
  from this week's, deferred rather than half-built.
