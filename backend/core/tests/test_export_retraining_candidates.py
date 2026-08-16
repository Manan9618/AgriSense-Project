import csv
import shutil
import tempfile
from pathlib import Path

from django.contrib.auth import get_user_model
from django.core.management import call_command

from core.models import Diagnosis, Feedback
from core.tests.helpers import MediaIsolatedTestCase, make_scan

User = get_user_model()


class ExportRetrainingCandidatesCommandTests(MediaIsolatedTestCase):
    """Exercises the Week 12 retraining-pipeline handoff against fixture
    data — not real pilot feedback, which doesn't exist yet (see
    docs/adr/0013-model-feedback-loop.md). Proves the export mechanism
    works; says nothing about actual model quality or field usage."""

    def setUp(self):
        self.farmer = User.objects.create_user(username="farmer6", password="x")
        self.scan = make_scan(self.farmer)
        self.diagnosis = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_late_blight",
            confidence=0.55,
            model_version="v0.1.0",
        )
        self.tmpdir = tempfile.mkdtemp(prefix="agrisense-retraining-export-")
        self.addCleanup(lambda: shutil.rmtree(self.tmpdir, ignore_errors=True))
        self.output_path = Path(self.tmpdir) / "candidates.csv"

    def _run(self):
        call_command("export_retraining_candidates", output=str(self.output_path))
        with self.output_path.open(newline="") as f:
            return list(csv.DictReader(f))

    def test_only_diagnoses_flagged_incorrect_are_exported(self):
        Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.CORRECT,
        )
        Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.INCORRECT,
            notes="Leaves had spots, not the wilting late blight causes.",
        )

        rows = self._run()

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["predicted_class"], "tomato_late_blight")
        self.assertIn("spots", rows[0]["farmer_notes"])
        # Left blank for a human reviewer to fill in — see
        # ml/scripts/incorporate_feedback.py (Week 16).
        self.assertEqual(rows[0]["corrected_class"], "")

    def test_no_flagged_feedback_produces_an_empty_csv_not_an_error(self):
        Feedback.objects.create(
            diagnosis=self.diagnosis,
            farmer=self.farmer,
            diagnosis_accuracy=Feedback.DiagnosisAccuracy.CORRECT,
        )

        rows = self._run()

        self.assertEqual(rows, [])

    def test_creates_missing_output_directory(self):
        nested = Path(self.tmpdir) / "nested" / "candidates.csv"
        call_command("export_retraining_candidates", output=str(nested))
        self.assertTrue(nested.exists())
