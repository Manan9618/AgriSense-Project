"""MandiPriceComparator (docs/classes.md component spec, Week 7).

Ranks nearby-market prices for a crop, and optionally raises a PRICE
Advisory when one market is meaningfully better than the worst option
nearby — the "distress sale" leverage the project's executive summary
calls out (Section 1.1: "gives farmers real bargaining leverage via live
price data"), not a notification for every routine price check.
"""

import json

from django.conf import settings

from core.models import Advisory
from core.price_provider import MandiPrice, MandiPriceProvider

TEMPLATES_PATH = settings.BASE_DIR.parent / "content" / "price_advisory_templates.json"

# A market has to beat the worst nearby option by at least this much before
# it's worth surfacing as an advisory — otherwise every price check would
# generate a "better price" alert for noise-level differences.
BETTER_PRICE_THRESHOLD = 0.10


def compare_prices(
    provider: MandiPriceProvider, commodity: str, state: str, district: str | None = None
) -> list[MandiPrice]:
    """Ranked nearby market prices, best (highest modal price) first."""
    prices = provider.get_prices(commodity, state, district)
    return sorted(prices, key=lambda p: p.modal_price, reverse=True)


def maybe_create_price_advisory(
    farmer, ranked_prices: list[MandiPrice], language: str = "en"
) -> Advisory | None:
    if len(ranked_prices) < 2:
        return None

    best, worst = ranked_prices[0], ranked_prices[-1]
    if worst.modal_price <= 0:
        return None

    improvement = (best.modal_price - worst.modal_price) / worst.modal_price
    if improvement < BETTER_PRICE_THRESHOLD:
        return None

    templates = json.loads(TEMPLATES_PATH.read_text())
    entry = templates["better_price_available"]
    actual_language = language if language in entry else "en"
    translation = entry[actual_language]

    title = translation["title"]
    body = translation["body"].format(
        market=best.market,
        commodity=best.commodity,
        price=f"{best.modal_price:,.0f}",
        pct=round(improvement * 100),
        worst_market=worst.market,
        worst_price=f"{worst.modal_price:,.0f}",
    )

    return Advisory.objects.create(
        farmer=farmer,
        kind=Advisory.Kind.PRICE,
        language=actual_language,
        title=title,
        body=body,
        urgency=entry["urgency"],
    )
