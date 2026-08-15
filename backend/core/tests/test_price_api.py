import os
from unittest.mock import Mock, patch

from django.test import TestCase
from django.urls import reverse


class PriceComparisonViewTests(TestCase):
    def test_requires_commodity_and_state(self):
        response = self.client.get(reverse("price-comparison"))
        self.assertEqual(response.status_code, 400)

    def test_requires_state_even_if_commodity_given(self):
        response = self.client.get(reverse("price-comparison"), {"commodity": "Tomato"})
        self.assertEqual(response.status_code, 400)

    @patch.dict(os.environ, {}, clear=False)
    def test_falls_back_to_sample_data_without_an_api_key(self):
        os.environ.pop("DATA_GOV_IN_API_KEY", None)

        response = self.client.get(
            reverse("price-comparison"), {"commodity": "Tomato", "state": "Gujarat"}
        )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["is_sample_data"])
        self.assertGreater(len(data["prices"]), 0)
        # ranked best-first
        modal_prices = [p["modal_price"] for p in data["prices"]]
        self.assertEqual(modal_prices, sorted(modal_prices, reverse=True))

    def test_unknown_commodity_returns_empty_ranked_list(self):
        response = self.client.get(
            reverse("price-comparison"), {"commodity": "Dragonfruit", "state": "Gujarat"}
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["prices"], [])

    @patch.dict(os.environ, {"DATA_GOV_IN_API_KEY": "test-key"})
    @patch("core.price_provider.requests.get")
    def test_uses_agmarknet_when_api_key_is_configured(self, mock_get):
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

        response = self.client.get(
            reverse("price-comparison"), {"commodity": "Tomato", "state": "Gujarat"}
        )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertFalse(data["is_sample_data"])
        self.assertEqual(len(data["prices"]), 1)
        mock_get.assert_called_once()
