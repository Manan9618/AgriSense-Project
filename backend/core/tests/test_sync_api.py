import uuid

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse

from core.models import Diagnosis, Scan
from core.tests.helpers import TINY_PNG, MediaIsolatedTestCase

User = get_user_model()


def sync_payload(**overrides):
    defaults = {
        "device_id": "abc123",
        "id": str(uuid.uuid4()),
        "predicted_class": "tomato_healthy",
        "confidence": "0.95",
        "model_version": "v0.1.0",
        "captured_at": "2026-06-01T09:30:00Z",
        "language": "en",
        "image": SimpleUploadedFile("leaf.png", TINY_PNG, content_type="image/png"),
    }
    defaults.update(overrides)
    return defaults


class ScanSyncViewTests(MediaIsolatedTestCase):
    def test_syncing_a_new_scan_creates_scan_diagnosis_and_device_user(self):
        scan_id = str(uuid.uuid4())
        response = self.client.post(
            reverse("scan-sync"), sync_payload(id=scan_id, device_id="device-xyz")
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.json()["created"])

        scan = Scan.objects.get(id=scan_id)
        self.assertEqual(scan.farmer.username, "device-device-xyz")
        self.assertIsNotNone(scan.synced_at)
        self.assertEqual(scan.diagnoses.count(), 1)
        self.assertEqual(scan.diagnoses.first().predicted_class, "tomato_healthy")

    def test_resyncing_the_same_id_is_idempotent(self):
        scan_id = str(uuid.uuid4())
        payload = sync_payload(id=scan_id)

        first = self.client.post(reverse("scan-sync"), payload)
        second = self.client.post(reverse("scan-sync"), sync_payload(id=scan_id))

        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertFalse(second.json()["created"])
        self.assertEqual(Scan.objects.filter(id=scan_id).count(), 1)
        self.assertEqual(Diagnosis.objects.filter(scan_id=scan_id).count(), 1)

    def test_same_device_reuses_the_same_user_across_scans(self):
        self.client.post(reverse("scan-sync"), sync_payload(device_id="farmer-device"))
        self.client.post(reverse("scan-sync"), sync_payload(device_id="farmer-device"))

        self.assertEqual(User.objects.filter(username="device-farmer-device").count(), 1)

    def test_different_devices_get_different_users(self):
        self.client.post(reverse("scan-sync"), sync_payload(device_id="device-a"))
        self.client.post(reverse("scan-sync"), sync_payload(device_id="device-b"))

        self.assertTrue(User.objects.filter(username="device-device-a").exists())
        self.assertTrue(User.objects.filter(username="device-device-b").exists())

    def test_missing_required_field_is_rejected(self):
        payload = sync_payload()
        del payload["predicted_class"]

        response = self.client.post(reverse("scan-sync"), payload)

        self.assertEqual(response.status_code, 400)

    def test_invalid_predicted_class_is_rejected(self):
        response = self.client.post(
            reverse("scan-sync"), sync_payload(predicted_class="not_a_real_class")
        )

        self.assertEqual(response.status_code, 400)

    def test_confidence_out_of_range_is_rejected(self):
        response = self.client.post(reverse("scan-sync"), sync_payload(confidence="1.5"))

        self.assertEqual(response.status_code, 400)
