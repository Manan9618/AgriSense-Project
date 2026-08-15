# ADR 0012: Regional Language Expansion — Marathi over an ARB/gen-l10n migration

## Status
Accepted — Week 11

## Context
The project plan's Week 11 ("Regional Language Expansion") assumes the app starts from a
single-language baseline and grows to 2-3 languages during this week. In this project, Hindi and
Gujarati were already added back in Week 4 (ADR 0006) alongside English, because the localized
`TreatmentRecommendation` content (Week 5) and the hand-rolled `AppStrings` class in
`mobile/lib/state/app_language.dart` made it roughly the same amount of work to support 3
languages as 1. `app_language.dart`'s doc comment at the time explicitly flagged this as a
placeholder: "Week 4 only needs a working language *selector*, not a translation pipeline; Week 11
... is where this scales up properly" — i.e. a promise to eventually migrate to Flutter's
ARB/`gen-l10n` pipeline.

Arriving at Week 11 with that promise on the table, the actual choice is between two different
things the plan's title could mean:
1. Migrate the *mechanism* — swap hand-rolled `AppStrings` for ARB files + `gen-l10n` codegen.
2. Expand the *coverage* — add another regional language, continuing what Week 4 started.

## Decision
Do (2), not (1): add **Marathi** (`mr`) as a fourth language, and leave `AppStrings` as hand-rolled
Dart maps.

**Why not the ARB migration**: at 4 languages and ~38 UI-chrome keys, `gen-l10n` buys type-safe
codegen and plural/gender rules at the cost of a build-step dependency, `.arb` JSON-in-JSON files,
and losing the current single-file diffability (all four languages' `hearAdviceIn` string sit on
adjacent lines, so a reviewer can eyeball translation drift directly). None of the app's strings
need ICU plural/gender rules — every count-bearing string here already uses a manual
singular/plural-agnostic phrasing (e.g. `'{count} scan(s) waiting to sync'`), matching Marathi/
Hindi/Gujarati number agreement well enough without an ICU-format resolver. The original Week 4
comment's promise was about scale, and 38 keys × 4 languages doesn't cross the threshold where
codegen pays for itself; the actual pain (translation-consistency checking) is solved more directly
below than a codegen switch would solve it. This is a "not yet" rather than a "never" — a genuine
5th-plus language or a jump into ICU plural forms would change the calculus.

**Language-set is now discovered, not hardcoded**, closing a real gap the audit surfaced: prior to
this week, the set of supported languages was hardcoded independently in the seed command
(`("en", "hi", "gu")`), and in `test_advisory_mapper.py`. Adding a language meant updating N call
sites with no compiler or test failure if one was missed. Both are now driven by the content file
itself:
- `backend/core/management/commands/seed_treatment_recommendations.py` derives its per-class
  language set from `content/treatment_recommendations.json`'s own keys, and raises `CommandError`
  if any class's language coverage is inconsistent with the others — turning a silent gap (a class
  missing a translation) into a seed-time failure instead of a runtime English-fallback that could
  go unnoticed.
- `backend/core/tests/test_advisory_mapper.py`'s `_expected_languages()` and
  `mobile/test/advisory_service_test.dart`'s `_loadSupportedLanguages()` both read the same content
  file to build their expected-language set, so the "every class in every language" test extends
  itself automatically the next time a language is added.

**Content updated for full 4-language coverage**: all three shared content files
(`content/treatment_recommendations.json`, `weather_advisory_templates.json`,
`price_advisory_templates.json`) now carry `mr` alongside `en`/`hi`/`gu` for every entry, verified
programmatically to have identical key sets across all four languages before this ADR was written.
`mobile/lib/state/app_language.dart` adds the `marathi` `AppLanguage` enum value (`ttsLocale:
'mr-IN'`, `sttLocale: 'mr_IN'`, ready for Week 8's TTS/STT services with no further code changes
since both consume `AppLanguage` generically) and a `_mr` strings map. `LanguageSelector` iterates
`AppLanguage.values`, so the new language appears in the picker automatically.

`weather_advisory_templates.json` and `price_advisory_templates.json` are backend-only — they feed
`Advisory` records the backend generates and the mobile app displays as opaque text it already
received, not templates the app renders locally — so unlike `treatment_recommendations.json`, they
are not bundled into `mobile/assets/` and need no mobile-side copy step.

## Consequences
- Adding a 5th language is now a content-and-two-maps change (JSON files + `AppLanguage` enum
  value + `_xx` strings map), with the seed command and both "every class, every language" tests
  catching any incomplete coverage automatically — no more silent English-fallback gaps.
- The ARB/gen-l10n migration this comment once promised is explicitly deferred, not done; if a
  future language needs real ICU plural/gender handling, or the key count grows enough that
  reviewing hand-rolled maps stops being tractable, that migration is the right move at that point.
- `docs/classes.md`-style content review remains manual for translation *quality* (a native speaker
  checking the Marathi phrasing) — the automation added here only catches missing coverage, not
  incorrect translation.
