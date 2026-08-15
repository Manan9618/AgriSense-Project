from unittest.mock import Mock, patch

from django.contrib.auth import get_user_model
from django.test import TestCase

from core.constants import Urgency
from core.models import Advisory
from core.price_comparator import compare_prices, maybe_create_price_advisory
from core.price_provider import AgmarknetProvider, MandiPrice, MandiPriceProviderError

User = get_user_model()


def price(market, modal, min_price=None, max_price=None, **overrides):
    defaults = {
        "market": market,
        "district": "Ahmedabad",
        "state": "Gujarat",
        "commodity": "Tomato",
        "variety": "Local",
        "min_price": min_price if min_price is not None else modal - 100,
        "max_price": max_price if max_price is not None else modal + 100,
        "modal_price": modal,
        "arrival_date": "14/08/2026",
    }
    defaults.update(overrides)
    return MandiPrice(**defaults)


class FakeMandiPriceProvider:
    def __init__(self, prices: list[MandiPrice]):
        self._prices = prices

    def get_prices(self, commodity, state, district=None):
        return self._prices


class AgmarknetProviderTests(TestCase):
    def test_raises_without_an_api_key(self):
        provider = AgmarknetProvider(api_key=None)
        with self.assertRaises(MandiPriceProviderError):
            provider.get_prices("Tomato", "Gujarat")

    @patch("core.price_provider.requests.get")
    def test_parses_a_successful_response(self, mock_get):
        mock_get.return_value = Mock(
            status_code=200,
            json=lambda: {
                "records": [
                    {
                        "market": "Ahmedabad(Jetalpur)",
                        "district": "Ahmedabad",
                        "state": "Gujarat",
                        "commodity": "Tomato",
                        "variety": "Local",
                        "min_price": "800",
                        "max_price": "1200",
                        "modal_price": "1000",
                        "arrival_date": "14/08/2026",
                    }
                ]
            },
        )

        provider = AgmarknetProvider(api_key="test-key")
        prices = provider.get_prices("Tomato", "Gujarat", district="Ahmedabad")

        self.assertEqual(len(prices), 1)
        self.assertEqual(prices[0].market, "Ahmedabad(Jetalpur)")
        self.assertEqual(prices[0].modal_price, 1000.0)

    @patch("core.price_provider.requests.get")
    def test_raises_on_non_200_response(self, mock_get):
        mock_get.return_value = Mock(status_code=403, text="Invalid api-key")
        provider = AgmarknetProvider(api_key="bad-key")
        with self.assertRaises(MandiPriceProviderError):
            provider.get_prices("Tomato", "Gujarat")


class ComparePricesTests(TestCase):
    def test_ranks_best_price_first(self):
        prices = [price("Low Market", 900), price("High Market", 1200), price("Mid Market", 1000)]

        ranked = compare_prices(FakeMandiPriceProvider(prices), "Tomato", "Gujarat")

        self.assertEqual([p.market for p in ranked], ["High Market", "Mid Market", "Low Market"])

    def test_empty_provider_result_is_empty_list(self):
        ranked = compare_prices(FakeMandiPriceProvider([]), "Tomato", "Gujarat")
        self.assertEqual(ranked, [])


class MaybeCreatePriceAdvisoryTests(TestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer6", password="x")

    def test_creates_advisory_when_price_gap_exceeds_threshold(self):
        ranked = [price("High Market", 1200), price("Low Market", 900)]  # 33% gap

        advisory = maybe_create_price_advisory(self.farmer, ranked, language="en")

        self.assertIsNotNone(advisory)
        self.assertEqual(advisory.kind, Advisory.Kind.PRICE)
        self.assertEqual(advisory.urgency, Urgency.MEDIUM)
        self.assertIn("High Market", advisory.body)
        self.assertIn("33%", advisory.body)
        self.assertTrue(Advisory.objects.filter(pk=advisory.pk).exists())

    def test_no_advisory_when_prices_are_close(self):
        ranked = [price("Market A", 1020), price("Market B", 1000)]  # 2% gap

        advisory = maybe_create_price_advisory(self.farmer, ranked, language="en")

        self.assertIsNone(advisory)

    def test_no_advisory_with_fewer_than_two_markets(self):
        advisory = maybe_create_price_advisory(self.farmer, [price("Only Market", 1000)])
        self.assertIsNone(advisory)

    def test_no_advisory_with_no_markets(self):
        advisory = maybe_create_price_advisory(self.farmer, [])
        self.assertIsNone(advisory)

    def test_localizes_into_gujarati(self):
        ranked = [price("High Market", 1200), price("Low Market", 900)]

        advisory = maybe_create_price_advisory(self.farmer, ranked, language="gu")

        self.assertEqual(advisory.language, "gu")
        self.assertIn("ભાવ", advisory.title)

    def test_falls_back_to_english_for_unsupported_language(self):
        ranked = [price("High Market", 1200), price("Low Market", 900)]

        advisory = maybe_create_price_advisory(self.farmer, ranked, language="fr")

        self.assertEqual(advisory.language, "en")
        self.assertIn("Better price nearby", advisory.title)
