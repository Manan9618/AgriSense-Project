from datetime import UTC, datetime, timedelta
from unittest.mock import Mock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase

from core.constants import Urgency
from core.models import Advisory
from core.weather_advisory_tool import generate_weather_advisories
from core.weather_provider import ForecastPoint, OpenWeatherMapProvider, WeatherProviderError

User = get_user_model()


def three_hourly(start: datetime, n: int, **overrides) -> list[ForecastPoint]:
    """n forecast points 3 hours apart, dry and calm by default."""
    defaults = {"precipitation_probability": 0.1, "wind_speed_kmh": 8.0, "condition": "Clear"}
    defaults.update(overrides)
    return [
        ForecastPoint(timestamp=start + timedelta(hours=3 * i), temp_c=28.0, **defaults)
        for i in range(n)
    ]


class FakeWeatherProvider:
    """Test double: returns a canned forecast instead of calling OpenWeatherMap."""

    def __init__(self, forecast: list[ForecastPoint]):
        self._forecast = forecast

    def get_forecast(self, latitude, longitude):
        return self._forecast


class OpenWeatherMapProviderTests(TestCase):
    def test_raises_without_an_api_key(self):
        provider = OpenWeatherMapProvider(api_key=None)
        with self.assertRaises(WeatherProviderError):
            provider.get_forecast(23.02, 72.57)

    @patch("core.weather_provider.requests.get")
    def test_parses_a_successful_response(self, mock_get):
        mock_get.return_value = Mock(
            status_code=200,
            json=lambda: {
                "list": [
                    {
                        "dt": 1750000000,
                        "main": {"temp": 31.5},
                        "pop": 0.8,
                        "wind": {"speed": 5.0},  # m/s
                        "weather": [{"main": "Rain"}],
                    }
                ]
            },
        )

        provider = OpenWeatherMapProvider(api_key="test-key")
        forecast = provider.get_forecast(23.02, 72.57)

        self.assertEqual(len(forecast), 1)
        point = forecast[0]
        self.assertEqual(point.temp_c, 31.5)
        self.assertEqual(point.precipitation_probability, 0.8)
        self.assertAlmostEqual(point.wind_speed_kmh, 18.0)  # 5 m/s * 3.6
        self.assertEqual(point.condition, "Rain")

    @patch("core.weather_provider.requests.get")
    def test_raises_on_non_200_response(self, mock_get):
        mock_get.return_value = Mock(status_code=401, text="Invalid API key")
        provider = OpenWeatherMapProvider(api_key="bad-key")
        with self.assertRaises(WeatherProviderError):
            provider.get_forecast(23.02, 72.57)


class WeatherAdvisoryToolTests(TestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer5", password="x")
        self.now = datetime(2026, 6, 1, 6, 0, tzinfo=UTC)

    def test_no_forecast_produces_no_advisories(self):
        result = generate_weather_advisories(FakeWeatherProvider([]), self.farmer, 23.0, 72.5)
        self.assertEqual(result, [])

    def test_rain_within_6_hours_produces_a_single_high_urgency_alert(self):
        forecast = three_hourly(self.now, 16)  # 48h of otherwise dry, calm weather
        forecast[1] = ForecastPoint(
            timestamp=self.now + timedelta(hours=3),
            temp_c=26.0,
            precipitation_probability=0.7,
            wind_speed_kmh=10.0,
            condition="Rain",
        )

        advisories = generate_weather_advisories(
            FakeWeatherProvider(forecast), self.farmer, 23.0, 72.5, language="en"
        )

        self.assertEqual(len(advisories), 1)
        self.assertEqual(advisories[0].kind, Advisory.Kind.WEATHER)
        self.assertEqual(advisories[0].urgency, Urgency.HIGH)
        self.assertIn("Rain expected soon", advisories[0].title)
        self.assertTrue(Advisory.objects.filter(pk=advisories[0].pk).exists())

    def test_dry_calm_week_produces_spray_window_and_dry_spell_alerts(self):
        forecast = three_hourly(self.now, 32)  # 4 days, fully dry and calm

        advisories = generate_weather_advisories(
            FakeWeatherProvider(forecast), self.farmer, 23.0, 72.5, language="en"
        )

        kinds = {a.title for a in advisories}
        self.assertEqual(len(advisories), 2)
        self.assertIn("Good spray window", kinds)
        self.assertIn("Dry spell ahead", kinds)
        for advisory in advisories:
            self.assertEqual(advisory.urgency, Urgency.MEDIUM)

    def test_rain_later_in_the_week_suppresses_dry_spell_but_not_spray_window(self):
        forecast = three_hourly(self.now, 32)
        # Rain on day 2 (within the 3-day dry-spell horizon, outside the 6h/24h windows)
        forecast[20] = ForecastPoint(
            timestamp=self.now + timedelta(hours=60),
            temp_c=25.0,
            precipitation_probability=0.9,
            wind_speed_kmh=12.0,
            condition="Rain",
        )

        advisories = generate_weather_advisories(
            FakeWeatherProvider(forecast), self.farmer, 23.0, 72.5, language="en"
        )

        titles = {a.title for a in advisories}
        self.assertIn("Good spray window", titles)
        self.assertNotIn("Dry spell ahead", titles)

    def test_windy_forecast_has_no_spray_window(self):
        forecast = three_hourly(self.now, 32, wind_speed_kmh=30.0)

        advisories = generate_weather_advisories(
            FakeWeatherProvider(forecast), self.farmer, 23.0, 72.5, language="en"
        )

        titles = {a.title for a in advisories}
        self.assertNotIn("Good spray window", titles)

    def test_localizes_into_hindi(self):
        forecast = three_hourly(self.now, 16)
        forecast[1] = ForecastPoint(
            timestamp=self.now + timedelta(hours=3),
            temp_c=26.0,
            precipitation_probability=0.7,
            wind_speed_kmh=10.0,
            condition="Rain",
        )

        advisories = generate_weather_advisories(
            FakeWeatherProvider(forecast), self.farmer, 23.0, 72.5, language="hi"
        )

        self.assertEqual(advisories[0].language, "hi")
        self.assertIn("बारिश", advisories[0].title)

    def test_falls_back_to_english_for_unsupported_language(self):
        forecast = three_hourly(self.now, 16)
        forecast[1] = ForecastPoint(
            timestamp=self.now + timedelta(hours=3),
            temp_c=26.0,
            precipitation_probability=0.7,
            wind_speed_kmh=10.0,
            condition="Rain",
        )

        advisories = generate_weather_advisories(
            FakeWeatherProvider(forecast), self.farmer, 23.0, 72.5, language="fr"
        )

        self.assertIn("Rain expected soon", advisories[0].title)
        self.assertEqual(advisories[0].language, "en")
