import uuid

from django.contrib.auth import get_user_model
from django.urls import reverse

from core.models import Diagnosis, Feedback
from core.tests.helpers import MediaIsolatedTestCase, make_scan

User = get_user_model()


def feedback_payload(**overrides):
    defaults = {
        "id": str(uuid.uuid4()),
        "scan_id": None,  # must be overridden with a real, already-synced scan id
        "diagnosis_accuracy": "correct",
        "treatment_outcome": "helped",
        "notes": "Spots cleared up after the second spray.",
    }
    defaults.update(overrides)
    return defaults


class FeedbackSyncViewTests(MediaIsolatedTestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="device-farmer1", password="x")
        self.scan = make_scan(self.farmer)
        self.diagnosis = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_late_blight",
            confidence=0.92,
            model_version="v0.1.0",
        )

    def test_syncing_feedback_for_a_synced_scan_creates_it(self):
        response = self.client.post(
            reverse("feedback-sync"),
            feedback_payload(scan_id=str(self.scan.id)),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(response.json()["created"])
        feedback = Feedback.objects.get(id=response.json()["id"])
        self.assertEqual(feedback.diagnosis, self.diagnosis)
        self.assertEqual(feedback.farmer, self.farmer)
        self.assertEqual(feedback.diagnosis_accuracy, "correct")

    def test_attaches_to_the_most_recent_diagnosis_for_the_scan(self):
        newer = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_healthy",
            confidence=0.60,
            model_version="v0.2.0",
        )

        response = self.client.post(
            reverse("feedback-sync"),
            feedback_payload(scan_id=str(self.scan.id)),
            content_type="application/json",
        )

        feedback = Feedback.objects.get(id=response.json()["id"])
        self.assertEqual(feedback.diagnosis, newer)

    def test_resyncing_the_same_id_is_idempotent(self):
        payload = feedback_payload(scan_id=str(self.scan.id))

        first = self.client.post(reverse("feedback-sync"), payload, content_type="application/json")
        second = self.client.post(
            reverse("feedback-sync"),
            feedback_payload(id=payload["id"], scan_id=str(self.scan.id)),
            content_type="application/json",
        )

        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 200)
        self.assertFalse(second.json()["created"])
        self.assertEqual(Feedback.objects.filter(id=payload["id"]).count(), 1)

    def test_feedback_for_an_unsynced_scan_is_rejected(self):
        response = self.client.post(
            reverse("feedback-sync"),
            feedback_payload(scan_id=str(uuid.uuid4())),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 404)
        self.assertEqual(Feedback.objects.count(), 0)

    def test_treatment_outcome_and_notes_are_optional(self):
        payload = feedback_payload(scan_id=str(self.scan.id))
        del payload["treatment_outcome"]
        del payload["notes"]

        response = self.client.post(
            reverse("feedback-sync"), payload, content_type="application/json"
        )

        self.assertEqual(response.status_code, 201)
        feedback = Feedback.objects.get(id=response.json()["id"])
        self.assertEqual(feedback.treatment_outcome, "")
        self.assertEqual(feedback.notes, "")

    def test_invalid_diagnosis_accuracy_is_rejected(self):
        response = self.client.post(
            reverse("feedback-sync"),
            feedback_payload(scan_id=str(self.scan.id), diagnosis_accuracy="definitely"),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)

    def test_invalid_treatment_outcome_is_rejected(self):
        response = self.client.post(
            reverse("feedback-sync"),
            feedback_payload(scan_id=str(self.scan.id), treatment_outcome="magically_cured"),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
