"""WeatherAdvisoryTool (docs/classes.md component spec, Week 6).

Turns a forecast into zero or more saved, localized Advisory records for
spray/irrigation timing. Rule-based rather than ML — weather advisories
need to be explainable ("why does it say don't spray") and the underlying
signal (rain probability, wind) is already a clean numeric forecast, so a
model would add complexity without adding accuracy here.
"""

import json
from datetime import timedelta

from django.conf import settings

from core.models import Advisory
from core.weather_provider import ForecastPoint, WeatherProvider

TEMPLATES_PATH = settings.BASE_DIR.parent / "content" / "weather_advisory_templates.json"

RAIN_PROBABILITY_THRESHOLD = 0.5
RAIN_SOON_HOURS = 6
SPRAY_WINDOW_HOURS = 24
DRY_SPELL_DAYS = 3
MAX_WIND_FOR_SPRAY_KMH = 15


def _load_templates() -> dict:
    return json.loads(TEMPLATES_PATH.read_text())


def _render(templates: dict, key: str, language: str, **kwargs) -> tuple[str, str, str, str]:
    """Returns (title, body, urgency, actual_language) — actual_language is
    "en" when [language] has no translation, so callers save the language
    the text is actually in, not the one that was requested (matching
    AdvisoryMapper's fallback behavior in core/advisory_mapper.py)."""
    entry = templates[key]
    actual_language = language if language in entry else "en"
    translation = entry[actual_language]
    title = translation["title"]
    body = translation["body"].format(**kwargs)
    return title, body, entry["urgency"], actual_language


def _format_time(point: ForecastPoint) -> str:
    return point.timestamp.strftime("%-I:%M %p")


def generate_weather_advisories(
    provider: WeatherProvider,
    farmer,
    latitude: float,
    longitude: float,
    language: str = "en",
) -> list[Advisory]:
    """Fetches a forecast and creates Advisory rows for whatever timing
    alerts apply right now. Returns the created Advisory objects (may be
    empty — routine weather with no rain and no dry spell warrants no
    alert at all)."""
    forecast = provider.get_forecast(latitude, longitude)
    if not forecast:
        return []

    templates = _load_templates()
    now = forecast[0].timestamp  # "now" = earliest forecast point, not wall-clock,
    # so advisories are reproducible against whatever forecast data is passed in.
    advisories = []

    rain_soon = next(
        (
            p
            for p in forecast
            if p.timestamp <= now + timedelta(hours=RAIN_SOON_HOURS)
            and p.precipitation_probability >= RAIN_PROBABILITY_THRESHOLD
        ),
        None,
    )
    if rain_soon is not None:
        title, body, urgency, actual_language = _render(
            templates, "rain_expected_soon", language, time=_format_time(rain_soon)
        )
        advisories.append(_save(farmer, title, body, urgency, actual_language))
        # Rain imminent is the most actionable alert — don't also suggest a
        # spray window in the same batch, which would read as contradictory
        # advice. A real window past the rain, if any, surfaces next time
        # this is run (e.g. the next scheduled check).
        return advisories

    window_cutoff = now + timedelta(hours=SPRAY_WINDOW_HOURS)
    dry_calm_points = [
        p
        for p in forecast
        if p.timestamp <= window_cutoff
        and p.precipitation_probability < RAIN_PROBABILITY_THRESHOLD
        and p.wind_speed_kmh <= MAX_WIND_FOR_SPRAY_KMH
    ]
    if dry_calm_points:
        title, body, urgency, actual_language = _render(
            templates,
            "good_spray_window",
            language,
            start=_format_time(dry_calm_points[0]),
            end=_format_time(dry_calm_points[-1]),
        )
        advisories.append(_save(farmer, title, body, urgency, actual_language))

    dry_spell_cutoff = now + timedelta(days=DRY_SPELL_DAYS)
    rain_in_window = any(
        p.precipitation_probability >= RAIN_PROBABILITY_THRESHOLD
        for p in forecast
        if p.timestamp <= dry_spell_cutoff
    )
    if not rain_in_window:
        title, body, urgency, actual_language = _render(
            templates, "dry_spell_irrigate", language, days=DRY_SPELL_DAYS
        )
        advisories.append(_save(farmer, title, body, urgency, actual_language))

    return advisories


def _save(farmer, title: str, body: str, urgency: str, language: str) -> Advisory:
    return Advisory.objects.create(
        farmer=farmer,
        kind=Advisory.Kind.WEATHER,
        language=language,
        title=title,
        body=body,
        urgency=urgency,
    )
