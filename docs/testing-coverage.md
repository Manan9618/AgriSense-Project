# Test Coverage (Week 17)

The project plan's target is 85%+ coverage. Both sides comfortably exceed it — this doc records
how the numbers were produced, what's deliberately excluded, and what the sweep found and fixed
along the way.

## Backend: 98% (117 tests)

```bash
cd backend && source .venv/bin/activate
pip install -r requirements-dev.txt
coverage run --source='core' --omit='core/migrations/*,core/tests/*' manage.py test
coverage report -m
```

The uncovered 2% (14 of 655 statements) is entirely trivial: `__str__` methods on every model
(8 lines), two abstract-base-class `NotImplementedError` stubs (`WeatherProvider`/
`MandiPriceProvider` — real subclasses are exercised throughout, the base class's placeholder body
never runs), and a handful of defensive `return None` fallback branches whose calling code is
already covered from the branch that *does* find a match. None of these represent real,
un-exercised behavior — consistent with this project's standing practice of not writing tests to
hit a line for its own sake (see e.g. how model `__str__` methods have never had dedicated tests
across 16 prior weeks).

### What the sweep added

Three gaps were real enough to close:
- `seed_treatment_recommendations`'s three `CommandError` guard paths (missing content file,
  missing classes, inconsistent language coverage across classes) had never been exercised —
  only the happy path was. These are real data-integrity guards, not boilerplate; `unittest.mock.patch`
  swaps `CONTENT_PATH` to point at fixture files that trigger each failure deliberately.
- `FeedbackSyncView`'s "no diagnosis exists yet for this scan" 400 branch — a defensive guard for
  a `Scan` created without a `Diagnosis`, which shouldn't happen via the normal sync flow but is
  guarded against directly rather than trusting that invariant.

## Mobile: 92.8% (89 tests, 5 self-skipping)

```bash
cd mobile
flutter test --coverage
```

Coverage is measurably different depending on whether a live Django server is running during the
test run — several classes (`HttpPriceProvider`, `HttpSyncBackend`, `HttpCommunityQAProvider`) are
only exercised by the self-skipping live-backend tests (`test/*_live_backend_test.dart`), per this
project's established pattern (`mobile/README.md`): real HTTP calls against a real server, not a
mocked `http.Client`, because a hand-rolled mock would only prove the code calls `http.Client`
correctly, not that it actually talks to the real API shape. Coverage collected **with** the
backend running (see `mobile/README.md`'s "Verifying against a real backend") is the number above;
without one, the same suite reports ~76% because those network classes read as unexercised, not
because anything is actually untested — they're tested, just not by the *default* offline run:

```bash
cd backend && source .venv/bin/activate
python manage.py migrate && python manage.py seed_treatment_recommendations
python manage.py runserver 127.0.0.1:8000 &
cd mobile && flutter test --coverage
```

### What the sweep found and fixed

- **Two genuinely dead `copyWith()` methods** (`ScanRecord.copyWith`, `FeedbackRecord.copyWith`) —
  never called anywhere in `lib/` or `test/`. Coverage flagged them as 0%; the fix was deleting
  them, not writing a test to justify their existence (per this project's standing practice: don't
  keep unused code around).
- **Marathi voice commands silently never matched anything.** `voice_command_parser.dart`'s
  keyword map was never extended when Marathi was added as a 4th language (Week 11, ADR 0012) —
  a Marathi-speaking farmer's voice commands fell back to English keyword matching and would
  rarely match. Caught while reviewing `home_screen.dart`'s voice-intent coverage, not by a
  targeted Marathi test that didn't exist yet; fixed by adding the missing `AppLanguage.marathi`
  entry to `_keywords`, plus a `Marathi` test group in `voice_command_parser_test.dart`.
- **`MandiPrice`/`CommunityQuestion`/`CommunityAnswer.fromJson`** had no coverage outside the live
  network tests — added plain unit tests against literal JSON (`mandi_price_test.dart`,
  `community_question_test.dart`) so the parsing logic itself is verified independent of whether a
  server happens to be running.
- **`AppBottomNav`'s `onTap` handler had never actually been tapped** in any test — the existing
  "prices" coverage came from the *voice command* path, not the bottom nav itself. Added
  `app_bottom_nav_test.dart` covering all four tabs directly.
- **`RecentScanTile`'s relative-time formatting** only ever exercised the "just now" branch (every
  existing test captures a scan and checks it immediately). Added `recent_scan_tile_test.dart`
  covering the minutes/hours/days branches.
- **`HomeScreen`'s "Sync Now" button, tapping a past scan from Recent Scans, and the voice
  "community"/"weather" commands** had no test coverage at all — closed in
  `home_screen_flow_test.dart`.

### A real test-isolation bug found along the way

`pumpUntilFound(tester, find.text('Community'))` in one new test passed trivially and immediately
— not because navigation had completed, but because "Community" is *also* the bottom nav's own tab
label, already on screen before the voice command even fires. The fix was polling for something
that only exists on the destination screen (`'Ask a Question'`) instead. A similar issue affected
the "Sync Now" test: polling for the SnackBar's transient message text raced against its
auto-dismiss timer when run after other tests in the same file had already consumed real wall-clock
time; the fix was asserting on the persistent sync-status text instead. Both are noted here because
they're easy to reintroduce in future tests that reach for `pumpUntilFound` with an ambiguous or
transient finder.

## What's not chased further

Both numbers exceed the 85% target with margin. The remaining backend gaps are boilerplate
(`__str__`, abstract stubs); the remaining mobile gaps are almost entirely network-exception
branches (a real connection failure, a non-200 response) that would need fault injection against
the live server to exercise for real — consistent with this project's stance of not adding a mock
just to inflate a percentage.
