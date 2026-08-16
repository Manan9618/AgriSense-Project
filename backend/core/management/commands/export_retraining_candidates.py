import csv
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand

from core.models import Feedback

DEFAULT_OUTPUT = settings.BASE_DIR.parent / "ml" / "data" / "retraining_candidates.csv"


class Command(BaseCommand):
    """Week 12 FeedbackCollector's retraining-pipeline handoff (docs/classes.md:
    "farmer-confirmed outcome -> feeds retraining pipeline", docs/classes.md's
    "Revising this list" section, and docs/adr/0013-model-feedback-loop.md).

    Exports every scan whose farmer feedback flagged the diagnosis as
    incorrect into a CSV manifest, for a human to review (and, once field
    images exist from the Week 13-16 pilot, relabel and route into
    ml/scripts/prepare_dataset.py) before the next retrain. This command
    only moves data that already exists in Feedback rows — it never
    invents feedback, and produces an empty CSV until real farmer feedback
    (pilot or otherwise) exists.

    The `corrected_class` column is left blank here on purpose — a human
    reviewer fills it in (with a valid docs/classes.md class id) after
    looking at the actual image, and only reviewed rows are picked up by
    ml/scripts/incorporate_feedback.py (Week 16, see
    docs/adr/0016-retraining-pipeline-mechanics.md).
    """

    help = "Export scans flagged as incorrectly diagnosed into a retraining-review CSV."

    def add_arguments(self, parser):
        parser.add_argument(
            "--output",
            type=str,
            default=str(DEFAULT_OUTPUT),
            help=f"CSV output path (default: {DEFAULT_OUTPUT})",
        )

    def handle(self, *args, **options):
        output_path = Path(options["output"])
        output_path.parent.mkdir(parents=True, exist_ok=True)

        candidates = (
            Feedback.objects.filter(diagnosis_accuracy=Feedback.DiagnosisAccuracy.INCORRECT)
            .select_related("diagnosis", "diagnosis__scan")
            .order_by("-created_at")
        )

        count = 0
        with output_path.open("w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(
                [
                    "feedback_id",
                    "scan_id",
                    "image",
                    "predicted_class",
                    "confidence",
                    "model_version",
                    "farmer_notes",
                    "feedback_created_at",
                    "corrected_class",
                ]
            )
            for feedback in candidates:
                diagnosis = feedback.diagnosis
                scan = diagnosis.scan
                writer.writerow(
                    [
                        feedback.id,
                        scan.id,
                        scan.image.name if scan.image else "",
                        diagnosis.predicted_class,
                        diagnosis.confidence,
                        diagnosis.model_version,
                        feedback.notes,
                        feedback.created_at.isoformat(),
                        "",
                    ]
                )
                count += 1

        self.stdout.write(
            self.style.SUCCESS(f"Exported {count} retraining candidate(s) to {output_path}")
        )
