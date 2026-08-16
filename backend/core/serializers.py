from rest_framework import serializers

from core.constants import DISEASE_CLASSES
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
