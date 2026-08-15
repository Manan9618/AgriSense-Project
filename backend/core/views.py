import os

from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from core.price_comparator import compare_prices
from core.price_provider import AgmarknetProvider, SampleMandiPriceProvider
from core.serializers import MandiPriceSerializer


class PriceComparisonView(APIView):
    """GET /api/prices/compare/?commodity=Tomato&state=Gujarat&district=Ahmedabad

    Uses AgmarknetProvider (data.gov.in) when DATA_GOV_IN_API_KEY is
    configured; otherwise falls back to SampleMandiPriceProvider so the
    endpoint has something real to serve in this dev environment.
    `is_sample_data` in the response makes that explicit — the app must
    never present sample prices as live quotes.
    """

    def get(self, request: Request) -> Response:
        commodity = request.query_params.get("commodity")
        state = request.query_params.get("state")
        district = request.query_params.get("district")

        if not commodity or not state:
            return Response(
                {"error": "commodity and state query parameters are required"}, status=400
            )

        is_sample_data = not os.environ.get("DATA_GOV_IN_API_KEY")
        provider = SampleMandiPriceProvider() if is_sample_data else AgmarknetProvider()

        ranked = compare_prices(provider, commodity, state, district)
        serializer = MandiPriceSerializer(ranked, many=True)

        return Response({"is_sample_data": is_sample_data, "prices": serializer.data})
