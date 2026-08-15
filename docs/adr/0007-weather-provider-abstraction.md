# ADR 0007: WeatherProvider abstraction + rule-based (not ML) advisory logic

## Status
Accepted — Week 6

## Context
Week 6 needs live weather data (OpenWeatherMap, per the plan's tech stack) and push-alert logic
for spray/irrigation timing. No `OPENWEATHERMAP_API_KEY` is available in this environment, so the
real API can't be exercised end-to-end here — the same shape of constraint as Week 4's camera
(no hardware) and Week 10's Twilio credentials.

## Decision
1. **`WeatherProvider` interface** (`backend/core/weather_provider.py`): `OpenWeatherMapProvider`
   is the real implementation (reads the API key from `OPENWEATHERMAP_API_KEY`, calls the free
   5-day/3-hour forecast endpoint). Tests use a `FakeWeatherProvider` returning canned
   `ForecastPoint` lists — same pattern as `PhotoCaptureSource` in the Flutter app (ADR 0006).
   The parsing logic itself (`OpenWeatherMapProviderTests`) *is* tested for real, against a
   mocked `requests.get` response shaped like OpenWeatherMap's actual API — only the network
   call and the credential are faked, not the parsing.
2. **Rule-based advisory generation** (`backend/core/weather_advisory_tool.py`), not a model.
   Three rules against the forecast: rain within 6h -> high-urgency "don't spray" alert (and nothing
   else, to avoid contradictory advice in the same batch); a dry+calm window in the next 24h ->
   medium-urgency "good spray window"; no rain in the next 3 days -> medium-urgency "consider
   irrigating". A farmer needs to trust *why* an alert fired, and the input signal (rain
   probability, wind speed) is already clean structured data — a model would add opacity without
   adding accuracy.
3. **Advisory text templates** live in `content/weather_advisory_templates.json`, same
   shared-content pattern as Week 5's treatment recommendations (`docs/advisory-content.md`):
   `{placeholder}`-based strings per language, filled in with `str.format()`.

## Consequences
- Everything except the literal live API call is genuinely tested: 10 tests cover the parsing
  logic, all three rules independently, a rule-interaction case (rain later in the week
  suppresses the dry-spell alert but not the spray-window one), wind exclusion, and language
  fallback. Confidence here is equivalent to Weeks 4/5, not weaker — the untested surface is
  narrowly the network call itself.
- Unlike Weeks 4/5, this week's work stays backend-only — no Django REST endpoint or mobile
  Weather-tab UI yet. The plan's literal Week 6 deliverable is "weather alerts functional and
  localized," which this satisfies (the generation logic works and is verified); exposing it
  over an API and displaying it in the app is a natural fit for whenever the project adds a
  general backend-sync layer (Week 9 is the obvious point, since that's when the app starts
  talking to the backend at all) rather than a one-off endpoint built just for weather.
- `generate_weather_advisories` takes `latitude`/`longitude` directly rather than reading them
  off a `Scan` — weather advisories aren't tied to a diagnosis (`Advisory.diagnosis` stays null
  for these, same as the model design already anticipated in Week 1). Callers will eventually
  source the coordinates from the farmer's profile or last known location, not built yet.
