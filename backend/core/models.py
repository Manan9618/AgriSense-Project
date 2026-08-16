import uuid

from django.conf import settings
from django.db import models

from core.constants import DISEASE_CLASSES, CropChoice, SymptomChoice, Urgency


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


class TreatmentRecommendation(models.Model):
    """AdvisoryMapper's source data: one row per (class_id, language).

    Seeded from content/treatment_recommendations.json — a source shared
    with the Flutter app's bundled copy of the same file, so the identical
    localized advice ships offline in the app *and* is queryable here (for
    the Week 21 FPO dashboard, Week 14 community Q&A routing, etc.) rather
    than existing in two hand-maintained places. Re-run
    `manage.py seed_treatment_recommendations` after editing the JSON.
    """

    class_id = models.CharField(max_length=64, choices=DISEASE_CLASSES)
    language = models.CharField(max_length=10)
    title = models.CharField(max_length=200)
    instructions = models.TextField()
    urgency = models.CharField(max_length=10, choices=Urgency.choices)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["class_id", "language"], name="unique_treatment_class_language"
            )
        ]
        ordering = ["class_id", "language"]

    def __str__(self):
        return f"{self.class_id} ({self.language}): {self.title}"


class SmsSession(models.Model):
    """Tracks an in-progress SMS fallback conversation (Week 10,
    SMSFallbackHandler component — docs/classes.md).

    Twilio's SMS webhook is stateless — one HTTP POST per incoming
    message — so the crop/symptom-menu state has to live somewhere between
    messages. Keyed by phone number since that's the only stable identity
    an SMS conversation has (no app account, no device id — a feature-phone
    farmer has neither). Deleted once a diagnosis is delivered, so a new
    text starts a fresh conversation rather than resuming a stale one.
    """

    class State(models.TextChoices):
        NEED_CROP = "need_crop", "Waiting for crop selection"
        NEED_SYMPTOM = "need_symptom", "Waiting for symptom selection"

    phone_number = models.CharField(max_length=20, primary_key=True)
    state = models.CharField(max_length=20, choices=State.choices, default=State.NEED_CROP)
    crop_choice = models.CharField(max_length=1, blank=True)
    language = models.CharField(max_length=10, default="en")
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.phone_number} ({self.state})"


class Feedback(models.Model):
    """A farmer-confirmed outcome for a Diagnosis (Week 12, FeedbackCollector
    component — docs/classes.md: "farmer-confirmed outcome -> feeds
    retraining pipeline").

    Its own model rather than fields bolted onto Diagnosis (flagged as
    deferred back in docs/data-models.md), since feedback usually arrives
    well after the diagnosis itself — a farmer can only say whether a
    treatment helped once it's had days to take effect — and a diagnosis
    could in principle receive more than one round of feedback.

    FK to Diagnosis, not Scan: a scan can be re-diagnosed after a model
    retrain (see Diagnosis's own docstring), and feedback is about a
    specific prediction, not the photo itself.
    """

    class DiagnosisAccuracy(models.TextChoices):
        CORRECT = "correct", "Diagnosis looked right"
        INCORRECT = "incorrect", "Diagnosis looked wrong"
        UNSURE = "unsure", "Not sure"

    class TreatmentOutcome(models.TextChoices):
        HELPED = "helped", "Treatment helped"
        NO_CHANGE = "no_change", "No change yet"
        WORSENED = "worsened", "Got worse"
        NOT_APPLICABLE = "not_applicable", "No treatment applied"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    diagnosis = models.ForeignKey(
        Diagnosis, on_delete=models.CASCADE, related_name="feedback_entries"
    )
    farmer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="feedback_entries"
    )
    diagnosis_accuracy = models.CharField(max_length=16, choices=DiagnosisAccuracy.choices)
    treatment_outcome = models.CharField(
        max_length=16, choices=TreatmentOutcome.choices, blank=True
    )
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name_plural = "feedback"

    def __str__(self):
        return f"Feedback on diagnosis {self.diagnosis_id}: {self.diagnosis_accuracy}"


class Question(models.Model):
    """A farmer's community question (Week 14, `CommunityQARouter` —
    docs/classes.md).

    `crop`/`symptom` are optional tags using the exact same vocabulary as
    the SMS/voice fallback's crop+symptom menu (Week 10,
    `fallback_diagnosis.py`) — deliberately not free text, so
    `community_qa_router.route_question()` can look up an existing
    `TreatmentRecommendation` deterministically instead of guessing from
    prose. A question can still be posted with neither tag, for anything
    that doesn't fit that triage (general farming questions, etc.) — it
    just won't get an auto-suggested answer.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    farmer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="questions"
    )
    crop = models.CharField(max_length=16, choices=CropChoice.choices, blank=True)
    symptom = models.CharField(max_length=16, choices=SymptomChoice.choices, blank=True)
    title = models.CharField(max_length=200)
    body = models.TextField(blank=True)
    language = models.CharField(max_length=10, default="en")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Q: {self.title}"


class Answer(models.Model):
    """A reply to a Question — either from another farmer/coordinator
    (`author` set), or auto-suggested by `CommunityQARouter` from existing
    `TreatmentRecommendation` content the moment a crop+symptom-tagged
    Question is created (`author` null, `is_auto_suggested=True`)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name="answers")
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="answers",
    )
    body = models.TextField()
    is_auto_suggested = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"A on question {self.question_id}"
