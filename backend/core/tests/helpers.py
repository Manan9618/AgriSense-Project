import shutil
import tempfile
from datetime import UTC, datetime

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings

from core.models import Scan

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
