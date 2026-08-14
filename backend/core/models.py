import uuid

from django.conf import settings
from django.db import models

from core.constants import DISEASE_CLASSES


class Scan(models.Model):
    """A single crop-photo capture event, created on-device (possibly offline).

    Uses a client-generated UUID primary key rather than an auto-incrementing
    integer: the Flutter app creates Scan records while offline (Week 9,
    OfflineSyncManager) and must be able to assign a durable ID before it ever
    talks to the backend, so two farmers' offline scans can never collide on
    sync.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    farmer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="scans"
    )
    image = models.ImageField(upload_to="scans/%Y/%m/")
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    language = models.CharField(
        max_length=10,
        default="en",
        help_text="BCP-47-ish language code the farmer captured this in, e.g. 'gu', 'hi'.",
    )
    captured_at = models.DateTimeField(
        help_text="Device-local timestamp of when the photo was taken (may be offline)."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    synced_at = models.DateTimeField(
        null=True, blank=True, help_text="When this record first reached the backend."
    )

    class Meta:
        ordering = ["-captured_at"]

    def __str__(self):
        return f"Scan {self.id} by {self.farmer_id} at {self.captured_at:%Y-%m-%d %H:%M}"


class Diagnosis(models.Model):
    """A classification result for a Scan.

    ForeignKey rather than OneToOne on purpose: a scan's image can be
    re-diagnosed after a model retrain (Week 12/16 feedback loop), and we want
    that history preserved rather than overwritten, so the Week 22 field-vs-lab
    evaluation can compare how the same field image scored across model
    versions.
    """

    class Source(models.TextChoices):
        ON_DEVICE = "on_device", "On-device TFLite inference"
        SMS_FALLBACK = "sms_fallback", "SMS symptom-description fallback"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    scan = models.ForeignKey(Scan, on_delete=models.CASCADE, related_name="diagnoses")
    predicted_class = models.CharField(max_length=64, choices=DISEASE_CLASSES)
    confidence = models.FloatField(help_text="Model confidence in [0, 1].")
    model_version = models.CharField(
        max_length=32, help_text="e.g. 'v0.1.0' — the TFLite model build that produced this."
    )
    source = models.CharField(max_length=16, choices=Source.choices, default=Source.ON_DEVICE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name_plural = "diagnoses"

    def __str__(self):
        return f"{self.predicted_class} ({self.confidence:.0%}) for scan {self.scan_id}"


class Advisory(models.Model):
    """A single piece of localized, actionable content delivered to a farmer.

    Deliberately generic rather than three separate models (treatment/weather/
    price), because the app's Advisory Orchestration Layer (Section 2.2 of the
    project plan) delivers all three through the same channel — app push, TTS
    readback, or SMS/voice fallback — built incrementally across Weeks 5-10.
    `diagnosis` is nullable because weather and price advisories aren't
    triggered by a diagnosis at all.
    """

    class Kind(models.TextChoices):
        TREATMENT = "treatment", "Treatment recommendation"
        WEATHER = "weather", "Weather / spray-window alert"
        PRICE = "price", "Mandi price comparison"

    class Urgency(models.TextChoices):
        LOW = "low", "Low"
        MEDIUM = "medium", "Medium"
        HIGH = "high", "High"

    class DeliveryChannel(models.TextChoices):
        APP_PUSH = "app_push", "In-app / push notification"
        SMS = "sms", "SMS"
        VOICE_CALL = "voice_call", "Voice call (IVR)"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    farmer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="advisories"
    )
    diagnosis = models.ForeignKey(
        Diagnosis, on_delete=models.CASCADE, null=True, blank=True, related_name="advisories"
    )
    kind = models.CharField(max_length=16, choices=Kind.choices)
    language = models.CharField(max_length=10, default="en")
    title = models.CharField(max_length=200)
    body = models.TextField()
    urgency = models.CharField(max_length=10, choices=Urgency.choices, default=Urgency.MEDIUM)
    delivered_via = models.CharField(
        max_length=16, choices=DeliveryChannel.choices, null=True, blank=True
    )
    created_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name_plural = "advisories"

    def __str__(self):
        return f"[{self.kind}] {self.title} -> {self.farmer_id}"
