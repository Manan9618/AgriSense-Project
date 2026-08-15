"""Weather data source, abstracted behind WeatherProvider so the forecast
rule engine (core/weather_advisory_tool.py) is testable without a live API
key or network call — mirrors the PhotoCaptureSource pattern in the Flutter
app (mobile/lib/services/photo_capture_source.dart): isolate the boundary
that can't be exercised in this environment (no OPENWEATHERMAP_API_KEY),
keep everything downstream of it fully tested.
"""

import os
from dataclasses import dataclass
from datetime import UTC, datetime

import requests

FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"


@dataclass(frozen=True)
class ForecastPoint:
    """One 3-hour forecast step."""

    timestamp: datetime
    temp_c: float
    precipitation_probability: float  # 0-1
    wind_speed_kmh: float
    condition: str  # OpenWeatherMap's "main" category: Rain, Clear, Clouds, ...


class WeatherProviderError(Exception):
    pass


class WeatherProvider:
    """Interface — subclass and implement get_forecast."""

    def get_forecast(self, latitude: float, longitude: float) -> list[ForecastPoint]:
        raise NotImplementedError


class OpenWeatherMapProvider(WeatherProvider):
    """Real implementation: OpenWeatherMap's free 5-day/3-hour forecast endpoint.

    Needs OPENWEATHERMAP_API_KEY set (free tier: https://openweathermap.org/api).
    No key is available in this dev environment — exercised only by
    FakeWeatherProvider in tests, but this is the one meant to run in
    production, wired up the same way the Flutter app's
    CameraPhotoCaptureSource is the real counterpart to its test fake.
    """

    def __init__(self, api_key: str | None = None):
        self.api_key = api_key or os.environ.get("OPENWEATHERMAP_API_KEY")

    def get_forecast(self, latitude: float, longitude: float) -> list[ForecastPoint]:
        if not self.api_key:
            raise WeatherProviderError(
                "OPENWEATHERMAP_API_KEY is not set — cannot fetch a live forecast."
            )

        response = requests.get(
            FORECAST_URL,
            params={
                "lat": latitude,
                "lon": longitude,
                "appid": self.api_key,
                "units": "metric",
            },
            timeout=10,
        )
        if response.status_code != 200:
            raise WeatherProviderError(
                f"OpenWeatherMap request failed: {response.status_code} {response.text}"
            )

        data = response.json()
        return [
            ForecastPoint(
                timestamp=datetime.fromtimestamp(entry["dt"], tz=UTC),
                temp_c=entry["main"]["temp"],
                precipitation_probability=entry.get("pop", 0.0),
                wind_speed_kmh=entry["wind"]["speed"] * 3.6,  # m/s -> km/h
                condition=entry["weather"][0]["main"],
            )
            for entry in data["list"]
        ]
