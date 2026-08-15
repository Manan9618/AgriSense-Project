import os

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from core.models import Diagnosis, Scan
from core.price_comparator import compare_prices
from core.price_provider import AgmarknetProvider, SampleMandiPriceProvider
from core.serializers import MandiPriceSerializer, ScanSyncSerializer

User = get_user_model()


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


class ScanSyncView(APIView):
    """POST /api/sync/scans/ (multipart/form-data) — OfflineSyncManager's
    sync target (docs/classes.md component spec: "Local scan/advisory queue
    -> Synced records when online").

    No farmer-account system exists yet (flagged as a gap since ADR 0008),
    so `device_id` auto-provisions a placeholder User
    (`device-<device_id>`) rather than requiring real auth first — see
    docs/adr/0010-offline-sync-architecture.md. Idempotent by `id`: syncing
    the same scan twice (e.g. after a dropped connection) creates it once.
    """

    parser_classes = [MultiPartParser, FormParser]

    def post(self, request: Request) -> Response:
        serializer = ScanSyncSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        farmer, _ = User.objects.get_or_create(username=f"device-{data['device_id']}")

        scan, created = Scan.objects.get_or_create(
            id=data["id"],
            defaults={
                "farmer": farmer,
                "image": data["image"],
                "captured_at": data["captured_at"],
                "language": data["language"],
                "synced_at": timezone.now(),
            },
        )

        if created:
            Diagnosis.objects.create(
                scan=scan,
                predicted_class=data["predicted_class"],
                confidence=data["confidence"],
                model_version=data["model_version"],
            )

        return Response(
            {"id": str(scan.id), "synced_at": scan.synced_at, "created": created},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )
