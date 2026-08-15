"""AdvisoryMapper (docs/classes.md component spec, Week 5).

Turns a Diagnosis into a localized, saved Advisory the farmer can act on.
Weather (Week 6) and price (Week 7) advisories are produced by separate
functions that create Advisory rows directly — this module only owns the
diagnosis -> treatment-recommendation mapping.
"""

from core.models import Advisory, Diagnosis, TreatmentRecommendation

DEFAULT_LANGUAGE = "en"


class NoRecommendationError(Exception):
    """Raised when a Diagnosis's class has no seeded TreatmentRecommendation.

    Shouldn't happen in practice — seed_treatment_recommendations covers
    every class in DISEASE_CLASSES — but a diagnosis referencing an unseeded
    class is a data problem worth surfacing loudly rather than silently
    falling back to placeholder text a farmer might act on.
    """


def map_diagnosis_to_advisory(diagnosis: Diagnosis, language: str = DEFAULT_LANGUAGE) -> Advisory:
    recommendation = TreatmentRecommendation.objects.filter(
        class_id=diagnosis.predicted_class, language=language
    ).first()
    if recommendation is None:
        recommendation = TreatmentRecommendation.objects.filter(
            class_id=diagnosis.predicted_class, language=DEFAULT_LANGUAGE
        ).first()
    if recommendation is None:
        raise NoRecommendationError(
            f"No TreatmentRecommendation for class '{diagnosis.predicted_class}' "
            f"(language '{language}' or fallback '{DEFAULT_LANGUAGE}')"
        )

    return Advisory.objects.create(
        farmer=diagnosis.scan.farmer,
        diagnosis=diagnosis,
        kind=Advisory.Kind.TREATMENT,
        language=recommendation.language,
        title=recommendation.title,
        body=recommendation.instructions,
        urgency=recommendation.urgency,
    )
