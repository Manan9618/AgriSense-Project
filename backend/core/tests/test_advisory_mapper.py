import json
import tempfile
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import TestCase

from core.advisory_mapper import NoRecommendationError, map_diagnosis_to_advisory
from core.constants import DISEASE_CLASS_IDS, Urgency
from core.models import Advisory, Diagnosis, TreatmentRecommendation
from core.tests.helpers import MediaIsolatedTestCase, make_scan

User = get_user_model()

CONTENT_PATH = settings.BASE_DIR.parent / "content" / "treatment_recommendations.json"


def _expected_languages() -> set[str]:
    """Discovered from the content file rather than hardcoded, so this test
    doesn't need editing every time a language is added (Week 11)."""
    data = json.loads(CONTENT_PATH.read_text())
    first_class = next(v for k, v in data.items() if not k.startswith("_"))
    return {k for k in first_class if k != "urgency"}


def _fixture_content() -> dict:
    """A minimal, valid content dict (every real class, one language) for
    the seed command's error-path tests (Week 17) — deliberately not the
    real content/treatment_recommendations.json, so these tests exercise
    the command's own validation, not the real file's current shape."""
    return {
        class_id: {
            "urgency": "low",
            "en": {"title": f"{class_id} title", "instructions": f"{class_id} instructions"},
        }
        for class_id in DISEASE_CLASS_IDS
    }


@contextmanager
def _content_file(data: dict):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "content.json"
        path.write_text(json.dumps(data))
        yield path


class SeedTreatmentRecommendationsCommandTests(TestCase):
    def test_seeds_every_class_in_every_supported_language(self):
        call_command("seed_treatment_recommendations")

        expected_languages = _expected_languages()
        self.assertEqual(
            TreatmentRecommendation.objects.count(),
            len(DISEASE_CLASS_IDS) * len(expected_languages),
        )
        for class_id in DISEASE_CLASS_IDS:
            languages = set(
                TreatmentRecommendation.objects.filter(class_id=class_id).values_list(
                    "language", flat=True
                )
            )
            self.assertEqual(languages, expected_languages, msg=f"incomplete for {class_id}")

    def test_rerunning_is_idempotent(self):
        call_command("seed_treatment_recommendations")
        call_command("seed_treatment_recommendations")
        expected_count = len(DISEASE_CLASS_IDS) * len(_expected_languages())
        self.assertEqual(TreatmentRecommendation.objects.count(), expected_count)

    def test_raises_when_content_file_is_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            missing_path = Path(tmp) / "does_not_exist.json"
            with (
                patch(
                    "core.management.commands.seed_treatment_recommendations.CONTENT_PATH",
                    missing_path,
                ),
                self.assertRaisesMessage(CommandError, "not found"),
            ):
                call_command("seed_treatment_recommendations")

    def test_raises_when_a_class_is_missing_from_the_content_file(self):
        data = _fixture_content()
        del data[DISEASE_CLASS_IDS[0]]

        with (
            _content_file(data) as path,
            patch("core.management.commands.seed_treatment_recommendations.CONTENT_PATH", path),
            self.assertRaisesMessage(CommandError, "Missing classes"),
        ):
            call_command("seed_treatment_recommendations")

    def test_raises_when_language_coverage_is_inconsistent_across_classes(self):
        data = _fixture_content()
        data[DISEASE_CLASS_IDS[0]]["hi"] = {"title": "t", "instructions": "i"}

        with (
            _content_file(data) as path,
            patch("core.management.commands.seed_treatment_recommendations.CONTENT_PATH", path),
            self.assertRaisesMessage(CommandError, "Inconsistent language coverage"),
        ):
            call_command("seed_treatment_recommendations")


class AdvisoryMapperTests(MediaIsolatedTestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")
        self.farmer = User.objects.create_user(username="farmer4", password="x")
        self.scan = make_scan(self.farmer, language="hi")
        self.diagnosis = Diagnosis.objects.create(
            scan=self.scan,
            predicted_class="tomato_late_blight",
            confidence=0.95,
            model_version="v0.1.0",
        )

    def test_maps_diagnosis_to_localized_advisory(self):
        advisory = map_diagnosis_to_advisory(self.diagnosis, language="hi")

        self.assertEqual(advisory.kind, Advisory.Kind.TREATMENT)
        self.assertEqual(advisory.diagnosis, self.diagnosis)
        self.assertEqual(advisory.farmer, self.farmer)
        self.assertEqual(advisory.language, "hi")
        self.assertEqual(advisory.urgency, Urgency.HIGH)  # late blight is high-urgency
        self.assertIn("झुलसा", advisory.title)

    def test_falls_back_to_english_when_language_not_seeded(self):
        TreatmentRecommendation.objects.filter(
            class_id="tomato_late_blight", language="fr"
        ).delete()  # never existed; proves the fallback path, not a no-op

        advisory = map_diagnosis_to_advisory(self.diagnosis, language="fr")

        self.assertEqual(advisory.language, "en")

    def test_raises_when_no_recommendation_exists_for_the_class_at_all(self):
        TreatmentRecommendation.objects.filter(class_id="tomato_late_blight").delete()

        with self.assertRaises(NoRecommendationError):
            map_diagnosis_to_advisory(self.diagnosis, language="hi")
