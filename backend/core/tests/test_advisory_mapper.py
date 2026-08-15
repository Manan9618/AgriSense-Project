from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase

from core.advisory_mapper import NoRecommendationError, map_diagnosis_to_advisory
from core.constants import DISEASE_CLASS_IDS, Urgency
from core.models import Advisory, Diagnosis, TreatmentRecommendation
from core.tests.helpers import MediaIsolatedTestCase, make_scan

User = get_user_model()


class SeedTreatmentRecommendationsCommandTests(TestCase):
    def test_seeds_every_class_in_all_three_languages(self):
        call_command("seed_treatment_recommendations")

        self.assertEqual(TreatmentRecommendation.objects.count(), len(DISEASE_CLASS_IDS) * 3)
        for class_id in DISEASE_CLASS_IDS:
            languages = set(
                TreatmentRecommendation.objects.filter(class_id=class_id).values_list(
                    "language", flat=True
                )
            )
            self.assertEqual(languages, {"en", "hi", "gu"}, msg=f"incomplete for {class_id}")

    def test_rerunning_is_idempotent(self):
        call_command("seed_treatment_recommendations")
        call_command("seed_treatment_recommendations")
        self.assertEqual(TreatmentRecommendation.objects.count(), len(DISEASE_CLASS_IDS) * 3)


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
