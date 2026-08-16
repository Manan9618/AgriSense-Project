import uuid
from datetime import UTC, datetime

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase

from core.constants import DISEASE_CLASS_IDS, Urgency
from core.models import (
    Advisory,
    Answer,
    Diagnosis,
    Feedback,
    Question,
    Scan,
    TreatmentRecommendation,
)
from core.tests.helpers import MediaIsolatedTestCase, make_scan

User = get_user_model()


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
            urgency=Urgency.HIGH,
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


class FeedbackModelTests(MediaIsolatedTestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer5", password="x")
        self.scan = make_scan(self.farmer)
        self.diagnosis = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_late_blight",
            confidence=0.95,
            model_version="v0.1.0",
        )

    def test_treatment_outcome_and_notes_are_optional(self):
        feedback = Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.CORRECT,
        )
        self.assertEqual(feedback.treatment_outcome, "")
        self.assertEqual(feedback.notes, "")

    def test_a_diagnosis_can_have_multiple_feedback_entries(self):
        Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.CORRECT,
            treatment_outcome=Feedback.TreatmentOutcome.NO_CHANGE,
        )
        Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.CORRECT,
            treatment_outcome=Feedback.TreatmentOutcome.HELPED,
        )
        self.assertEqual(self.diagnosis.feedback_entries.count(), 2)

    def test_newest_feedback_ordered_first(self):
        older = Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.UNSURE,
        )
        newer = Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.INCORRECT,
        )
        self.assertEqual(list(Feedback.objects.all()), [newer, older])


class QuestionAnswerModelTests(MediaIsolatedTestCase):
    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer7", password="x")

    def test_crop_and_symptom_are_optional(self):
        question = Question.objects.create(farmer=self.farmer, title="General question")
        self.assertEqual(question.crop, "")
        self.assertEqual(question.symptom, "")

    def test_questions_ordered_newest_first(self):
        older = Question.objects.create(farmer=self.farmer, title="Older")
        newer = Question.objects.create(farmer=self.farmer, title="Newer")
        self.assertEqual(list(Question.objects.all()), [newer, older])

    def test_answer_can_have_no_author(self):
        question = Question.objects.create(farmer=self.farmer, title="Q")
        answer = Answer.objects.create(question=question, body="auto reply", is_auto_suggested=True)
        self.assertIsNone(answer.author)

    def test_answers_ordered_oldest_first(self):
        question = Question.objects.create(farmer=self.farmer, title="Q")
        first = Answer.objects.create(question=question, body="first reply")
        second = Answer.objects.create(question=question, body="second reply")
        self.assertEqual(list(question.answers.all()), [first, second])


class TreatmentRecommendationModelTests(TestCase):
    def test_class_and_language_pair_must_be_unique(self):
        TreatmentRecommendation.objects.create(
            class_id="tomato_healthy",
            language="en",
            title="Healthy",
            instructions="...",
            urgency=Urgency.LOW,
        )
        with self.assertRaises(IntegrityError), transaction.atomic():
            TreatmentRecommendation.objects.create(
                class_id="tomato_healthy",
                language="en",
                title="Dup",
                instructions="...",
                urgency=Urgency.LOW,
            )

    def test_same_class_different_language_is_allowed(self):
        TreatmentRecommendation.objects.create(
            class_id="tomato_healthy",
            language="en",
            title="Healthy",
            instructions="...",
            urgency=Urgency.LOW,
        )
        TreatmentRecommendation.objects.create(
            class_id="tomato_healthy",
            language="hi",
            title="स्वस्थ",
            instructions="...",
            urgency=Urgency.LOW,
        )
        self.assertEqual(
            TreatmentRecommendation.objects.filter(class_id="tomato_healthy").count(), 2
        )
