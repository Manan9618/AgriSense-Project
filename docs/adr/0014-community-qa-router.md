# ADR 0014: Community Q&A — CommunityQARouter reuses the SMS fallback's own triage, not free text

## Status
Accepted — Week 14

## Context
The project plan's Week 14 introduces a `CommunityQARouter` component and the mobile app's
Community tab, previously a "Coming in Week 14" placeholder in `AppBottomNav`
(`mobile/lib/widgets/app_bottom_nav.dart`) since Week 4. Two questions shaped the design:

1. What does a farmer actually post — free text, or something more structured? Free-text
   questions are the obvious default for a Q&A feature, but this app already has a working,
   tested crop+symptom vocabulary from Week 10's SMS/voice fallback
   (`backend/core/fallback_diagnosis.py`'s `CROP_CHOICES`/`SYMPTOM_CHOICES`/`SYMPTOM_TO_CLASS`).
2. What should "Router" mean? The plan's name implies more than a CRUD forum — routing a question
   somewhere useful before a human necessarily sees it.

## Decision

**Questions carry optional `crop`/`symptom` tags using the exact same three-choice vocabulary as
the SMS/voice fallback** (`core.constants.CropChoice`/`SymptomChoice`, values matching
`fallback_diagnosis.py`'s `CROP_CHOICES.values()`/`SYMPTOM_CHOICES.values()` exactly) rather than
free-text crop/symptom fields or NLP-based extraction from the question body. A question can still
be posted with neither tag for anything that doesn't fit that triage — it just doesn't get an
automated answer.

**`CommunityQARouter.route_question()` is the actual router**: when a question's crop+symptom tags
resolve to a known class (via the same `SYMPTOM_TO_CLASS` dict Week 10 already built and tested),
it immediately creates an auto-suggested `Answer` from the existing localized
`TreatmentRecommendation` content (`get_treatment_text`, also reused directly from
`fallback_diagnosis.py`) — before any human replies. This is a deterministic content lookup, not
guessing from prose, so it's exactly as precise (and exactly as imprecise) as the SMS fallback's
own 3-option triage; `docs/adr/0011-twilio-fallback-channels.md`'s reasoning for that tradeoff
applies unchanged here. The alternative — keyword-matching the question body — would have
introduced a second, less reliable way to reach the same content Week 10 already made
queryable, and would be harder to explain to a farmer as to why a match sometimes fails.

**`Feedback`'s reasoning for a separate model** (ADR 0013) extends to `Question`/`Answer`: they
don't attach to `Diagnosis` or `Scan` at all, since a community question is farmer-initiated and
often not tied to any specific scan. `Answer.author` is nullable specifically so the
router's auto-suggestion (`author=None`, `is_auto_suggested=True`) is structurally distinct from a
real farmer/coordinator reply, letting the mobile UI badge it differently
(`_AnswerTile` in `mobile/lib/screens/question_detail_screen.dart`) without a side-channel flag.

**Same device-based identity as every other write path** (`ScanSyncView`/`FeedbackSyncView`):
`QuestionListCreateView`/`AnswerCreateView` auto-provision a `device-<device_id>` `User`, no new
identity scheme introduced for this feature.

**Mobile crop/symptom picker labels are English-only**, matching the tradeoff
`PriceComparisonScreen`'s crop dropdown already made in Week 7 (`mobile/lib/screens/
price_comparison_screen.dart`'s `_crops` list) — these are three fixed option labels for a
picker, not narrative UI chrome, so they're held to the same bar as that earlier precedent rather
than expanded into the 4-language `AppStrings` system. The rest of the screen's chrome (buttons,
hints, empty states) *is* fully localized across all 4 languages, consistent with everything since
Week 11.

## Consequences
- Community questions inherit the SMS fallback's precision ceiling: a farmer asking "why are my
  tomato leaves wilting" gets the same single best-guess class (`tomato_late_blight`) the SMS
  channel would give a caller, not a nuanced multi-condition differential. This is accepted, not
  overlooked — see the ADR 0011 cross-reference above.
- Extending the router to consider a photo (if a farmer wants to attach a scan to their question)
  is a natural next step but out of scope this week; `Question` has no FK to `Scan` yet.
- The community list/detail screens are the first *read* paths in this app that require a network
  connection for their core function (unlike scan diagnosis, which is fully offline) — this is
  consistent with weather and price comparison already being online-only, not a new gap.
