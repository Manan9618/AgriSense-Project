from rest_framework import serializers

from core.constants import DISEASE_CLASSES, CropChoice, SymptomChoice
from core.models import Feedback


class ScanSyncSerializer(serializers.Serializer):
    """Validates the multipart payload OfflineSyncManager (mobile,
    core/sync_backend.dart) uploads for one offline-captured scan. `id` is
    the client-generated UUID (Scan.id, see backend/core/models.py) — the
    same value on both sides is what makes re-syncing idempotent rather
    than creating duplicates."""

    device_id = serializers.CharField(max_length=64)
    id = serializers.UUIDField()
    predicted_class = serializers.ChoiceField(choices=DISEASE_CLASSES)
    confidence = serializers.FloatField(min_value=0, max_value=1)
    model_version = serializers.CharField(max_length=32)
    captured_at = serializers.DateTimeField()
    language = serializers.CharField(max_length=10, default="en")
    image = serializers.ImageField()


class FeedbackSyncSerializer(serializers.Serializer):
    """Validates FeedbackRepository's (mobile, core/sync_backend.dart) sync
    payload for one farmer-confirmed outcome. Keyed by `scan_id`, not a
    diagnosis id: the mobile app only ever learns the client-generated Scan
    id (ScanSyncView's response never echoes back a server-assigned
    Diagnosis id), so FeedbackSyncView resolves the diagnosis itself from
    the scan rather than requiring the client to track a second server-side
    identifier."""

    id = serializers.UUIDField()
    scan_id = serializers.UUIDField()
    diagnosis_accuracy = serializers.ChoiceField(choices=Feedback.DiagnosisAccuracy.choices)
    treatment_outcome = serializers.ChoiceField(
        choices=Feedback.TreatmentOutcome.choices, required=False, default=""
    )
    notes = serializers.CharField(required=False, default="", allow_blank=True)


class AnswerSerializer(serializers.Serializer):
    """Output shape for one Answer, nested inside QuestionDetailSerializer
    and returned directly by AnswerCreateView."""

    id = serializers.UUIDField(read_only=True)
    body = serializers.CharField()
    is_auto_suggested = serializers.BooleanField(read_only=True)
    created_at = serializers.DateTimeField(read_only=True)


class QuestionSerializer(serializers.Serializer):
    """Validates a new community Question (Week 14) and serializes existing
    ones for the list view. `device_id` is write-only, same auto-provisioned
    device-identity pattern as ScanSyncSerializer (Week 9) — no real farmer
    accounts exist yet, see docs/adr/0010-offline-sync-architecture.md."""

    id = serializers.UUIDField(read_only=True)
    device_id = serializers.CharField(max_length=64, write_only=True)
    crop = serializers.ChoiceField(
        choices=CropChoice.choices, required=False, default="", allow_blank=True
    )
    symptom = serializers.ChoiceField(
        choices=SymptomChoice.choices, required=False, default="", allow_blank=True
    )
    title = serializers.CharField(max_length=200)
    body = serializers.CharField(required=False, default="", allow_blank=True)
    language = serializers.CharField(max_length=10, default="en")
    created_at = serializers.DateTimeField(read_only=True)


class QuestionDetailSerializer(QuestionSerializer):
    """QuestionSerializer plus its answers — the detail view's response
    shape, and what QuestionListCreateView.post() returns right after
    creating a question, so the client sees any auto-suggested answer
    immediately without a second request."""

    answers = AnswerSerializer(many=True, read_only=True)


class AnswerCreateSerializer(serializers.Serializer):
    """Validates a new reply to an existing Question."""

    device_id = serializers.CharField(max_length=64, write_only=True)
    body = serializers.CharField()


class MandiPriceSerializer(serializers.Serializer):
    """Plain Serializer, not ModelSerializer — MandiPrice is a dataclass
    (core/price_provider.py), not a Django model; there's nothing to persist
    per-quote, only to render."""

    market = serializers.CharField()
    district = serializers.CharField()
    state = serializers.CharField()
    commodity = serializers.CharField()
    variety = serializers.CharField()
    min_price = serializers.FloatField()
    max_price = serializers.FloatField()
    modal_price = serializers.FloatField()
    arrival_date = serializers.CharField()
