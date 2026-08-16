import os

from django.contrib.auth import get_user_model
from django.http import HttpRequest, HttpResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView
from twilio.twiml.messaging_response import MessagingResponse
from twilio.twiml.voice_response import Gather, VoiceResponse

from core.fallback_diagnosis import (
    CROP_CHOICES,
    CROP_MENU_PROMPT,
    SYMPTOM_CHOICES,
    SYMPTOM_MENU_PROMPT,
    class_for_choice,
    get_treatment_text,
)
from core.models import Diagnosis, Feedback, Scan
from core.price_comparator import compare_prices
from core.price_provider import AgmarknetProvider, SampleMandiPriceProvider
from core.serializers import FeedbackSyncSerializer, MandiPriceSerializer, ScanSyncSerializer
from core.sms_fallback_handler import handle_sms_message

User = get_user_model()

VOICE_WELCOME_PROMPT = f"Welcome to AgriSense crop help. {CROP_MENU_PROMPT}"
VOICE_UNRECOGNIZED_PREFIX = "Sorry, that was not a valid choice. "
VOICE_NO_ADVICE_FOUND = "Sorry, we could not find advice for that right now. Goodbye."


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


class FeedbackSyncView(APIView):
    """POST /api/sync/feedback/ (JSON) — FeedbackCollector's sync target
    (Week 12, docs/classes.md: "farmer-confirmed outcome -> feeds
    retraining pipeline").

    Resolves the Diagnosis lazily from `scan_id` (the most recent Diagnosis
    for that scan) rather than requiring the client to know a server-side
    diagnosis id, since ScanSyncView never hands one back. Returns 404 if
    the scan itself hasn't synced yet — feedback for an offline-only scan
    has to wait for that scan to sync first (OfflineSyncManager syncs scans
    before feedback for exactly this reason). Idempotent by `id`, same
    pattern as ScanSyncView.
    """

    def post(self, request: Request) -> Response:
        serializer = FeedbackSyncSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            scan = Scan.objects.get(id=data["scan_id"])
        except Scan.DoesNotExist:
            return Response(
                {"error": "scan not found — sync the scan before its feedback"},
                status=status.HTTP_404_NOT_FOUND,
            )

        diagnosis = scan.diagnoses.order_by("-created_at").first()
        if diagnosis is None:
            return Response(
                {"error": "no diagnosis exists yet for this scan"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        feedback, created = Feedback.objects.get_or_create(
            id=data["id"],
            defaults={
                "diagnosis": diagnosis,
                "farmer": scan.farmer,
                "diagnosis_accuracy": data["diagnosis_accuracy"],
                "treatment_outcome": data["treatment_outcome"],
                "notes": data["notes"],
            },
        )

        return Response(
            {"id": str(feedback.id), "created": created},
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


@csrf_exempt
@require_POST
def sms_webhook(request: HttpRequest) -> HttpResponse:
    """POST /api/sms/webhook/ — Twilio SMS webhook, SMSFallbackHandler's
    entry point (Week 10). No API credentials needed to handle *incoming*
    messages: Twilio calls this URL and expects TwiML XML back, which is
    generated entirely locally (no outbound Twilio API call involved) —
    see docs/adr/0011-twilio-fallback-channels.md.
    """
    from_number = request.POST.get("From", "")
    body = request.POST.get("Body", "")

    reply_text = handle_sms_message(from_number, body)

    twiml = MessagingResponse()
    twiml.message(reply_text)
    return HttpResponse(str(twiml), content_type="text/xml")


@csrf_exempt
@require_POST
def voice_webhook(request: HttpRequest) -> HttpResponse:
    """POST /api/voice/webhook/?step=... — Twilio Voice webhook, IVR flow
    (Week 10). No SmsSession-style persistence needed here: each
    <Gather>'s `action` URL carries the already-collected choice forward
    as a query parameter, so the URL chain itself is the state machine —
    simpler than a session model for a flow this short.
    """
    step = request.GET.get("step", "crop")
    digits = request.POST.get("Digits")
    response = VoiceResponse()

    if step == "crop":
        gather = Gather(num_digits=1, action="/api/voice/webhook/?step=symptom", method="POST")
        gather.say(VOICE_WELCOME_PROMPT)
        response.append(gather)
        response.say(CROP_MENU_PROMPT)  # heard only if no key was pressed in time
        return HttpResponse(str(response), content_type="text/xml")

    if step == "symptom":
        if digits not in CROP_CHOICES:
            gather = Gather(num_digits=1, action="/api/voice/webhook/?step=symptom", method="POST")
            gather.say(VOICE_UNRECOGNIZED_PREFIX + CROP_MENU_PROMPT)
            response.append(gather)
            return HttpResponse(str(response), content_type="text/xml")

        gather = Gather(
            num_digits=1,
            action=f"/api/voice/webhook/?step=diagnosis&crop={digits}",
            method="POST",
        )
        gather.say(SYMPTOM_MENU_PROMPT)
        response.append(gather)
        return HttpResponse(str(response), content_type="text/xml")

    # step == "diagnosis"
    crop_choice = request.GET.get("crop", "")
    if digits not in SYMPTOM_CHOICES:
        gather = Gather(
            num_digits=1,
            action=f"/api/voice/webhook/?step=diagnosis&crop={crop_choice}",
            method="POST",
        )
        gather.say(VOICE_UNRECOGNIZED_PREFIX + SYMPTOM_MENU_PROMPT)
        response.append(gather)
        return HttpResponse(str(response), content_type="text/xml")

    class_id = class_for_choice(crop_choice, digits)
    text = get_treatment_text(class_id) if class_id else None
    response.say(text or VOICE_NO_ADVICE_FOUND)
    response.hangup()
    return HttpResponse(str(response), content_type="text/xml")
