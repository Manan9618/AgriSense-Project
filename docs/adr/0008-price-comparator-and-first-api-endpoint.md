# ADR 0008: MandiPriceComparator, the project's first API endpoint, and a sample-data fallback

## Status
Accepted — Week 7

## Context
Unlike Week 6 ("weather alerts functional and localized"), the plan's Week 7 deliverable is
explicit about UI: "Build price-comparison UI across nearby markets," "Live price comparison
screen functional." That's a real difference in scope, not just phrasing — it means this week
needed the first actual network path between the Flutter app and the Django backend, which
didn't exist before now (Weeks 4-5 are fully on-device/offline by design).

Also unlike weather, "nearby markets" for mandi prices isn't a lat/lon-radius query — Agmarknet
(data.gov.in) data is organized by state/district/market, with no market coordinates. Ranking by
district is the standard, honest interpretation (same district = geographically closest markets,
matching how real Agmarknet-based apps work, not an invented distance metric).

## Decision
1. Same provider-abstraction pattern as Week 6: `MandiPriceProvider` interface
   (`backend/core/price_provider.py`), `AgmarknetProvider` the real implementation (needs
   `DATA_GOV_IN_API_KEY`, not available here), tests use a fake.
2. **New this week**: `SampleMandiPriceProvider` — fixed, realistic sample data, used
   automatically when no API key is configured. The API response always includes
   `is_sample_data`, and the mobile UI renders a visible "sample data" banner whenever it's true.
   This exists specifically so the endpoint and app have something genuine to render end-to-end
   in this environment, rather than only ever exercising an error path — but it must never be
   mistaken for a live quote, hence the explicit flag threaded all the way to the UI.
3. **First DRF endpoint**: `GET /api/prices/compare/` (`core/views.py`, `core/urls.py`). Deliberately
   minimal — no auth, no persistence beyond the optional `maybe_create_price_advisory` (which,
   like Week 5's `AdvisoryMapper`, is a tested standalone function not yet wired into this view,
   since there's no authenticated farmer identity on the request yet).
4. **Mobile**: `PriceProvider` interface mirroring `PhotoCaptureSource` (ADR 0006) —
   `HttpPriceProvider` is real, tests use a fake. `PriceComparisonScreen` replaces the "Coming in
   Week 7" bottom-nav placeholder.
5. **Genuinely verified end-to-end**, not just each half in isolation:
   `mobile/test/price_provider_live_backend_test.dart` makes a real HTTP call from
   `HttpPriceProvider` to an actually-running `manage.py runserver` and asserts on the real
   response — confirmed working in this session. It self-skips (exit 0) when no server is
   reachable, so it doesn't break `flutter test` in CI or on another machine without a backend
   running; it's a deliberate manual verification step, documented in its own header comment.

## Consequences
- This is the first backend<->mobile network integration in the project. `HttpPriceProvider`'s
  `baseUrl` has no safe production default — set to the Android-emulator localhost alias
  (`10.0.2.2`) for local dev only, since there's no deployed backend yet (Week 18). Whatever
  wires up a real device build needs to supply a real URL.
- `maybe_create_price_advisory` (the "distress sale leverage" logic — Advisory created only when
  the price gap between markets exceeds 10%) is tested but not called from the view, same
  deferred-wiring pattern as Week 5's AdvisoryMapper. Both are waiting on the same missing piece:
  a real authenticated farmer identity on the request, not yet built.
- 16 new backend tests (42 total), 4 new mobile tests (12 total, one of which is the
  self-skipping live-backend check).
