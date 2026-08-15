from django.test import TestCase

from core.constants import DISEASE_CLASS_IDS
from core.fallback_diagnosis import CROP_CHOICES, SYMPTOM_CHOICES, class_for_choice


class ClassForChoiceTests(TestCase):
    def test_every_valid_combination_maps_to_a_known_class(self):
        for crop_choice in CROP_CHOICES:
            for symptom_choice in SYMPTOM_CHOICES:
                class_id = class_for_choice(crop_choice, symptom_choice)
                self.assertIn(class_id, DISEASE_CLASS_IDS, f"{crop_choice}, {symptom_choice}")

    def test_healthy_symptom_always_maps_to_a_healthy_class(self):
        for crop_choice in CROP_CHOICES:
            class_id = class_for_choice(crop_choice, "3")
            self.assertTrue(class_id.endswith("_healthy"), class_id)

    def test_wilting_symptom_maps_to_the_more_urgent_class_where_available(self):
        # potato and tomato both distinguish spots (early blight) from
        # wilting (late blight) — the more time-critical condition.
        self.assertEqual(class_for_choice("1", "2"), "potato_late_blight")
        self.assertEqual(class_for_choice("3", "2"), "tomato_late_blight")

    def test_invalid_crop_choice_returns_none(self):
        self.assertIsNone(class_for_choice("9", "1"))

    def test_invalid_symptom_choice_returns_none(self):
        self.assertIsNone(class_for_choice("1", "9"))

    def test_both_invalid_returns_none(self):
        self.assertIsNone(class_for_choice("x", "y"))
