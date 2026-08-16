"""CommunityQARouter (Week 14, docs/classes.md): when a Question is tagged
with the same crop/symptom vocabulary the SMS/voice fallback (Week 10)
already uses, immediately posts the matching TreatmentRecommendation as an
auto-suggested Answer — before any human replies.

Deterministic lookup against existing localized content, not free-text/NLP
guessing: exactly as precise (and exactly as imprecise) as the SMS
fallback's own crop+symptom triage — see
docs/adr/0011-twilio-fallback-channels.md for why that 3-option tradeoff is
intentional, not a shortcut taken here for convenience.
"""

from core.fallback_diagnosis import SYMPTOM_TO_CLASS, get_treatment_text


def route_question(question):
    """Creates and returns an auto-suggested Answer for `question` if its
    crop+symptom tags resolve to a known class with treatment content;
    otherwise returns None and leaves the question open for the community
    to answer."""
    from core.models import Answer

    class_id = SYMPTOM_TO_CLASS.get((question.crop, question.symptom))
    if class_id is None:
        return None

    text = get_treatment_text(class_id, language=question.language)
    if text is None:
        return None

    return Answer.objects.create(
        question=question,
        body=f"Similar reports suggest this could be: {text}",
        is_auto_suggested=True,
    )
