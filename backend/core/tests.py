import shutil
import tempfile
import uuid
from datetime import UTC, datetime

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings

from core.constants import DISEASE_CLASS_IDS
from core.models import Advisory, Diagnosis, Scan

User = get_user_model()

# 1x1 transparent PNG, used so ImageField validation has real image bytes to work with.
TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01"
    b"\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
)


def make_scan(farmer, **overrides):
    defaults = {
        "farmer": farmer,
        "image": SimpleUploadedFile("leaf.png", TINY_PNG, content_type="image/png"),
        "captured_at": datetime(2026, 6, 1, 9, 30, tzinfo=UTC),
        "language": "gu",
    }
    defaults.update(overrides)
    return Scan.objects.create(**defaults)


class MediaIsolatedTestCase(TestCase):
    """Base for tests that create Scans: ImageField writes real files, and
    TestCase only rolls back the DB — so route them to a throwaway MEDIA_ROOT
    instead of littering the real media/ directory on every test run."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls._media_root = tempfile.mkdtemp(prefix="agrisense-test-media-")
        cls._media_override = override_settings(MEDIA_ROOT=cls._media_root)
        cls._media_override.enable()

    @classmethod
    def tearDownClass(cls):
        cls._media_override.disable()
        shutil.rmtree(cls._media_root, ignore_errors=True)
        super().tearDownClass()


class ScanModelTests(MediaIsolatedTestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer1", password="x")

    def test_scan_gets_uuid_primary_key(self):
        scan = make_scan(self.farmer)
        self.assertIsInstance(scan.id, uuid.UUID)

    def test_scan_starts_unsynced(self):
        scan = make_scan(self.farmer)
        self.assertIsNone(scan.synced_at)

    def test_scans_ordered_newest_capture_first(self):
        older = make_scan(self.farmer, captured_at=datetime(2026, 1, 1, tzinfo=UTC))
        newer = make_scan(self.farmer, captured_at=datetime(2026, 6, 1, tzinfo=UTC))
        self.assertEqual(list(Scan.objects.all()), [newer, older])


class DiagnosisModelTests(MediaIsolatedTestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer2", password="x")
        self.scan = make_scan(self.farmer)

    def test_predicted_class_must_be_a_known_class(self):
        diagnosis = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_early_blight",
            confidence=0.91,
            model_version="v0.1.0",
        )
        self.assertIn(diagnosis.predicted_class, DISEASE_CLASS_IDS)

    def test_a_scan_can_have_multiple_diagnoses_across_model_versions(self):
        Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_early_blight",
            confidence=0.80,
            model_version="v0.1.0",
        )
        Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_late_blight",
            confidence=0.93,
            model_version="v0.2.0",
        )
        self.assertEqual(self.scan.diagnoses.count(), 2)

    def test_defaults_to_on_device_source(self):
        diagnosis = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_healthy",
            confidence=0.99,
            model_version="v0.1.0",
        )
        self.assertEqual(diagnosis.source, Diagnosis.Source.ON_DEVICE)


class AdvisoryModelTests(MediaIsolatedTestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer3", password="x")
        self.scan = make_scan(self.farmer)
        self.diagnosis = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_late_blight",
            confidence=0.95,
            model_version="v0.1.0",
        )

    def test_treatment_advisory_links_to_diagnosis(self):
        advisory = Advisory.objects.create(
            farmer=self.farmer,
            diagnosis=self.diagnosis,
            kind=Advisory.Kind.TREATMENT,
            title="Copper-based fungicide",
            body="Apply every 7 days for 3 weeks.",
            urgency=Advisory.Urgency.HIGH,
        )
        self.assertEqual(advisory.diagnosis, self.diagnosis)

    def test_weather_advisory_has_no_diagnosis(self):
        advisory = Advisory.objects.create(
            farmer=self.farmer,
            kind=Advisory.Kind.WEATHER,
            title="Spray window closing",
            body="Rain expected in 6 hours — spray before then.",
        )
        self.assertIsNone(advisory.diagnosis)

    def test_undelivered_advisory_has_no_delivered_at(self):
        advisory = Advisory.objects.create(
            farmer=self.farmer,
            kind=Advisory.Kind.PRICE,
            title="Better price 12km away",
            body="Cotton is fetching Rs 200 more per quintal at Anand mandi.",
        )
        self.assertIsNone(advisory.delivered_at)
        self.assertIsNone(advisory.delivered_via)
