"""Crop + symptom -> best-matching disease class, for the SMS/voice
fallback channels (Week 10) where no photo exists to run through the
on-device model. Menus capped at 3 options each (project plan Section
11.2's explicit guidance for non-literate/SMS UX), so a text description
can't distinguish diseases as precisely as a photo — this maps to the most
likely class in docs/classes.md and leans on general "leaf disease" advice
being broadly correct across the small number of classes per crop, not a
false promise of photo-level precision.
"""

CROP_CHOICES = {"1": "potato", "2": "pepper_bell", "3": "tomato"}

CROP_MENU_PROMPT = "Which crop? Reply: 1 Potato, 2 Pepper, 3 Tomato"

SYMPTOM_CHOICES = {"1": "spots", "2": "wilting", "3": "healthy"}

SYMPTOM_MENU_PROMPT = (
    "What do you see? Reply: 1 Spots/blight on leaves, 2 Wilting or fast-spreading "
    "damage, 3 Looks healthy"
)

# (crop, symptom) -> class_id (docs/classes.md). "spots" maps to the more common,
# slower-spreading condition per crop; "wilting" maps to the more aggressive one —
# the same distinction the treatment advice actually depends on (urgency).
SYMPTOM_TO_CLASS = {
    ("potato", "spots"): "potato_early_blight",
    ("potato", "wilting"): "potato_late_blight",
    ("potato", "healthy"): "potato_healthy",
    ("pepper_bell", "spots"): "pepper_bell_bacterial_spot",
    ("pepper_bell", "wilting"): "pepper_bell_bacterial_spot",
    ("pepper_bell", "healthy"): "pepper_bell_healthy",
    ("tomato", "spots"): "tomato_early_blight",
    ("tomato", "wilting"): "tomato_late_blight",
    ("tomato", "healthy"): "tomato_healthy",
}


def class_for_choice(crop_choice: str, symptom_choice: str) -> str | None:
    """Returns a class_id, or None if either choice digit is invalid."""
    crop = CROP_CHOICES.get(crop_choice)
    symptom = SYMPTOM_CHOICES.get(symptom_choice)
    if crop is None or symptom is None:
        return None
    return SYMPTOM_TO_CLASS[(crop, symptom)]


def get_treatment_text(class_id: str, language: str = "en") -> str | None:
    """Localized 'Title: instructions' text for a class, falling back to
    English — shared by both the SMS and voice fallback handlers so the
    same lookup-with-fallback behavior (AdvisoryMapper's pattern, Week 5)
    isn't duplicated across channels."""
    from core.models import TreatmentRecommendation

    recommendation = (
        TreatmentRecommendation.objects.filter(class_id=class_id, language=language).first()
        or TreatmentRecommendation.objects.filter(class_id=class_id, language="en").first()
    )
    if recommendation is None:
        return None
    return f"{recommendation.title}: {recommendation.instructions}"
