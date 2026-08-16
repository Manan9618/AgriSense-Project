import json
from datetime import timedelta
from pathlib import Path

from django.core.management.base import BaseCommand
from django.db.models import Avg, Count
from django.utils import timezone

from core.models import Answer, Diagnosis, Feedback, Question, Scan


class Command(BaseCommand):
    """Week 15 pilot-monitoring tool (docs/pilot/pilot-launch-readiness.md):
    summarizes real app usage and diagnosis accuracy over a trailing window,
    from whatever Scan/Diagnosis/Feedback/Question data actually exists.

    This is not a dashboard and reports nothing until real usage exists —
    running it today prints all-zero/empty sections, honestly, since no
    pilot has launched yet (see docs/adr/0015-pilot-launch-monitoring.md).
    No public API endpoint wraps this: it's a command a project operator
    runs against the backend directly, since no auth/staff-permission
    system exists yet to safely gate an endpoint that aggregates real
    farmer activity.
    """

    help = "Summarize real Scan/Diagnosis/Feedback/Question activity over the last N days."

    def add_arguments(self, parser):
        parser.add_argument(
            "--days", type=int, default=7, help="Trailing window in days (default 7)."
        )
        parser.add_argument(
            "--output",
            type=str,
            default=None,
            help="Write JSON to this path instead of printing a human-readable report.",
        )

    def handle(self, *args, **options):
        days = options["days"]
        since = timezone.now() - timedelta(days=days)

        scans = Scan.objects.filter(created_at__gte=since)
        diagnoses = Diagnosis.objects.filter(created_at__gte=since)
        feedback = Feedback.objects.filter(created_at__gte=since)
        questions = Question.objects.filter(created_at__gte=since)
        answers = Answer.objects.filter(created_at__gte=since)

        report = {
            "period_days": days,
            "generated_at": timezone.now().isoformat(),
            "scans": {
                "total": scans.count(),
                "by_language": _counts_by(scans, "language"),
            },
            "diagnoses": {
                "total": diagnoses.count(),
                "by_predicted_class": _counts_by(diagnoses, "predicted_class"),
                "average_confidence": diagnoses.aggregate(avg=Avg("confidence"))["avg"],
            },
            "feedback": {
                "total": feedback.count(),
                "diagnosis_accuracy_rate": _rate(
                    feedback, Feedback.DiagnosisAccuracy.CORRECT, "diagnosis_accuracy"
                ),
                "treatment_helped_rate": _rate(
                    feedback.exclude(treatment_outcome=""),
                    Feedback.TreatmentOutcome.HELPED,
                    "treatment_outcome",
                ),
            },
            "community": {
                "questions": questions.count(),
                "answers": answers.count(),
                "auto_suggested_answers": answers.filter(is_auto_suggested=True).count(),
            },
        }

        output_path = options["output"]
        if output_path:
            Path(output_path).write_text(json.dumps(report, indent=2))
            self.stdout.write(self.style.SUCCESS(f"Wrote usage report to {output_path}"))
        else:
            self._print_report(report)

    def _print_report(self, report):
        w = self.stdout.write
        w(f"Pilot usage report — last {report['period_days']} day(s)")
        w(f"  Scans: {report['scans']['total']}")
        for language, count in report["scans"]["by_language"].items():
            w(f"    {language}: {count}")
        w(f"  Diagnoses: {report['diagnoses']['total']}")
        avg_confidence = report["diagnoses"]["average_confidence"]
        w(
            "    average confidence: "
            + (f"{avg_confidence:.1%}" if avg_confidence is not None else "no data yet")
        )
        w(f"  Feedback: {report['feedback']['total']}")
        accuracy = report["feedback"]["diagnosis_accuracy_rate"]
        w(
            "    diagnosis accuracy rate: "
            + (f"{accuracy:.1%}" if accuracy is not None else "no data yet")
        )
        helped = report["feedback"]["treatment_helped_rate"]
        w(
            "    treatment helped rate: "
            + (f"{helped:.1%}" if helped is not None else "no data yet")
        )
        w(
            f"  Community: {report['community']['questions']} question(s), "
            f"{report['community']['answers']} answer(s) "
            f"({report['community']['auto_suggested_answers']} auto-suggested)"
        )


def _counts_by(queryset, field):
    return {
        str(row[field]): row["count"]
        for row in queryset.values(field).annotate(count=Count("id")).order_by("-count")
    }


def _rate(queryset, target_value, field):
    """Fraction of `queryset` rows where `field == target_value`, or None if
    `queryset` is empty — never a misleading 0% for "no data collected"."""
    total = queryset.count()
    if total == 0:
        return None
    matching = queryset.filter(**{field: target_value}).count()
    return matching / total
