"""Mandi (wholesale market) price data source, abstracted behind
MandiPriceProvider — same reasoning as WeatherProvider (core/weather_provider.py):
isolate the boundary that needs a credential this environment doesn't have
(DATA_GOV_IN_API_KEY), keep the comparison/ranking logic downstream of it
fully tested.
"""

import os
from dataclasses import dataclass

import requests

# data.gov.in's "Variety-wise Daily Market Prices Data of Commodity" resource —
# the standard public Agmarknet mirror. Resource ID is a dataset identifier,
# not a credential, so it's safe to commit; the api-key is what's secret.
AGMARKNET_RESOURCE_ID = "9ef84268-d588-465a-a308-a864a43d0070"
AGMARKNET_URL = f"https://api.data.gov.in/resource/{AGMARKNET_RESOURCE_ID}"


@dataclass(frozen=True)
class MandiPrice:
    """One market's price quote for a commodity, in Rs per quintal."""

    market: str
    district: str
    state: str
    commodity: str
    variety: str
    min_price: float
    max_price: float
    modal_price: float
    arrival_date: str


class MandiPriceProviderError(Exception):
    pass


class MandiPriceProvider:
    """Interface — subclass and implement get_prices."""

    def get_prices(
        self, commodity: str, state: str, district: str | None = None
    ) -> list[MandiPrice]:
        raise NotImplementedError


class SampleMandiPriceProvider(MandiPriceProvider):
    """Realistic-looking fixed sample data, used when DATA_GOV_IN_API_KEY
    isn't configured — e.g. this dev environment — so the API endpoint and
    app UI have something real to render end-to-end instead of only ever
    exercising an error path. Callers must surface `is_sample_data=True`
    (see core/views.py) so this is never mistaken for a live quote."""

    _SAMPLE = {
        "tomato": [
            MandiPrice(
                "Ahmedabad(Jetalpur)",
                "Ahmedabad",
                "Gujarat",
                "Tomato",
                "Local",
                800,
                1200,
                1000,
                "sample",
            ),
            MandiPrice("Anand", "Anand", "Gujarat", "Tomato", "Local", 950, 1350, 1150, "sample"),
            MandiPrice(
                "Vadodara", "Vadodara", "Gujarat", "Tomato", "Local", 700, 1000, 850, "sample"
            ),
        ],
        "potato": [
            MandiPrice(
                "Deesa", "Banaskantha", "Gujarat", "Potato", "Local", 900, 1100, 1000, "sample"
            ),
            MandiPrice(
                "Ahmedabad(Jetalpur)",
                "Ahmedabad",
                "Gujarat",
                "Potato",
                "Local",
                750,
                950,
                850,
                "sample",
            ),
        ],
        "pepper": [
            MandiPrice("Anand", "Anand", "Gujarat", "Pepper", "Bell", 2200, 2800, 2500, "sample"),
            MandiPrice(
                "Vadodara", "Vadodara", "Gujarat", "Pepper", "Bell", 1900, 2400, 2100, "sample"
            ),
        ],
    }

    def get_prices(
        self, commodity: str, state: str, district: str | None = None
    ) -> list[MandiPrice]:
        return list(self._SAMPLE.get(commodity.lower(), []))


class AgmarknetProvider(MandiPriceProvider):
    """Real implementation: data.gov.in's Agmarknet mirror.

    Needs DATA_GOV_IN_API_KEY set (free registration:
    https://data.gov.in/user/register). No key is available in this dev
    environment — exercised only by a fake provider in tests, the real
    counterpart the same way OpenWeatherMapProvider is Week 6's.

    Field names/shape follow data.gov.in's documented datastore_search
    response for this resource; not verified against a live call here for
    the reason above — verify against the real API before this goes live.
    """

    def __init__(self, api_key: str | None = None):
        self.api_key = api_key or os.environ.get("DATA_GOV_IN_API_KEY")

    def get_prices(
        self, commodity: str, state: str, district: str | None = None
    ) -> list[MandiPrice]:
        if not self.api_key:
            raise MandiPriceProviderError(
                "DATA_GOV_IN_API_KEY is not set — cannot fetch live mandi prices."
            )

        filters = {"filters[commodity]": commodity, "filters[state]": state}
        if district:
            filters["filters[district]"] = district

        response = requests.get(
            AGMARKNET_URL,
            params={"api-key": self.api_key, "format": "json", "limit": 50, **filters},
            timeout=10,
        )
        if response.status_code != 200:
            raise MandiPriceProviderError(
                f"data.gov.in request failed: {response.status_code} {response.text}"
            )

        data = response.json()
        return [
            MandiPrice(
                market=record["market"],
                district=record["district"],
                state=record["state"],
                commodity=record["commodity"],
                variety=record.get("variety", ""),
                min_price=float(record["min_price"]),
                max_price=float(record["max_price"]),
                modal_price=float(record["modal_price"]),
                arrival_date=record.get("arrival_date", ""),
            )
            for record in data.get("records", [])
        ]
