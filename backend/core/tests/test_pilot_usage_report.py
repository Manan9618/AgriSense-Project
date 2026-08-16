import json
import shutil
import tempfile
from datetime import UTC, datetime
from pathlib import Path

from django.contrib.auth import get_user_model
from django.core.management import call_command

from core.models import Answer, Diagnosis, Feedback, Question
from core.tests.helpers import MediaIsolatedTestCase, make_scan

User = get_user_model()


class PilotUsageReportCommandTests(MediaIsolatedTestCase):
    """Exercises the Week 15 pilot-monitoring command against fixture data —
    not real pilot activity, which doesn't exist yet (see
    docs/adr/0015-pilot-launch-monitoring.md). Proves the aggregation logic
    is correct; says nothing about real usage."""

    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer-pilot", password="x")
        self.tmpdir = tempfile.mkdtemp(prefix="agrisense-pilot-report-")
        self.addCleanup(lambda: shutil.rmtree(self.tmpdir, ignore_errors=True))
        self.output_path = Path(self.tmpdir) / "report.json"

    def _run(self, **options):
        call_command("pilot_usage_report", output=str(self.output_path), **options)
        return json.loads(self.output_path.read_text())

    def test_reports_all_zero_and_none_when_nothing_exists(self):
        report = self._run()

        self.assertEqual(report["scans"]["total"], 0)
        self.assertEqual(report["diagnoses"]["total"], 0)
        self.assertIsNone(report["diagnoses"]["average_confidence"])
        self.assertEqual(report["feedback"]["total"], 0)
        self.assertIsNone(report["feedback"]["diagnosis_accuracy_rate"])
        self.assertIsNone(report["feedback"]["treatment_helped_rate"])
        self.assertEqual(report["community"]["questions"], 0)

    def test_counts_scans_and_diagnoses_within_the_window(self):
        scan_en = make_scan(self.farmer, language="en")
        make_scan(self.farmer, language="hi")
        Diagnosis.objects.create(
            scan=scan_en,
            predicted_class="tomato_late_blight",
            confidence=0.9,
            model_version="v0.1.0",
        )
        Diagnosis.objects.create(
            scan=scan_en,
            predicted_class="tomato_late_blight",
            confidence=0.7,
            model_version="v0.1.0",
        )

        report = self._run()

        self.assertEqual(report["scans"]["total"], 2)
        self.assertEqual(report["scans"]["by_language"], {"en": 1, "hi": 1})
        self.assertEqual(report["diagnoses"]["total"], 2)
        self.assertEqual(report["diagnoses"]["by_predicted_class"], {"tomato_late_blight": 2})
        self.assertAlmostEqual(report["diagnoses"]["average_confidence"], 0.8)

    def test_excludes_records_outside_the_requested_window(self):
        old_scan = make_scan(self.farmer)
        old_scan.created_at = datetime(2020, 1, 1, tzinfo=UTC)
        old_scan.save(update_fields=["created_at"])
        make_scan(self.farmer)

        report = self._run(days=7)

        self.assertEqual(report["scans"]["total"], 1)

    def test_diagnosis_accuracy_rate_reflects_feedback_correctness(self):
        scan = make_scan(self.farmer)
        diagnosis = Diagnosis.objects.create(
            scan=scan, predicted_class="tomato_healthy", confidence=0.95, model_version="v0.1.0"
        )
        Feedback.objects.create(
            diagnosis=diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.CORRECT,
        )
        Feedback.objects.create(
            diagnosis=diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.INCORRECT,
        )
        Feedback.objects.create(
            diagnosis=diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.CORRECT,
            treatment_outcome=Feedback.TreatmentOutcome.HELPED,
        )

        report = self._run()

        self.assertEqual(report["feedback"]["total"], 3)
        self.assertAlmostEqual(report["feedback"]["diagnosis_accuracy_rate"], 2 / 3)
        self.assertEqual(report["feedback"]["treatment_helped_rate"], 1.0)

    def test_counts_community_questions_and_auto_suggested_answers(self):
        question = Question.objects.create(farmer=self.farmer, title="Why wilting?")
        Answer.objects.create(question=question, body="auto reply", is_auto_suggested=True)
        Answer.objects.create(question=question, author=self.farmer, body="human reply")

        report = self._run()

        self.assertEqual(report["community"]["questions"], 1)
        self.assertEqual(report["community"]["answers"], 2)
        self.assertEqual(report["community"]["auto_suggested_answers"], 1)

    def test_human_readable_output_does_not_error(self):
        # No --output: exercises the print path, not just the JSON path.
        call_command("pilot_usage_report")
