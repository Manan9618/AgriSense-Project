"""SMSFallbackHandler (docs/classes.md component spec, Week 10): "SMS
symptom description -> Text-based diagnosis reply."

Twilio's SMS webhook is one stateless HTTP POST per incoming message, so
the crop -> symptom -> diagnosis conversation state lives in SmsSession,
keyed by phone number (the only identity a feature-phone farmer has).
"""

from core.fallback_diagnosis import (
    CROP_CHOICES,
    CROP_MENU_PROMPT,
    SYMPTOM_CHOICES,
    SYMPTOM_MENU_PROMPT,
    class_for_choice,
    get_treatment_text,
)
from core.models import SmsSession

WELCOME_PROMPT = f"Welcome to AgriSense crop help. {CROP_MENU_PROMPT}"
UNRECOGNIZED_PREFIX = "Sorry, I didn't understand. "
NO_ADVICE_FOUND = "Sorry, we could not find advice for that right now. Please try again later."


def handle_sms_message(phone_number: str, body: str, language: str = "en") -> str:
    session, created = SmsSession.objects.get_or_create(
        phone_number=phone_number, defaults={"language": language}
    )
    choice = body.strip()[:1]

    if session.state == SmsSession.State.NEED_CROP:
        if created:
            # First-ever contact from this number — they haven't seen the
            # menu yet, so greet + ask regardless of what they texted.
            return WELCOME_PROMPT

        if choice not in CROP_CHOICES:
            return UNRECOGNIZED_PREFIX + CROP_MENU_PROMPT

        session.crop_choice = choice
        session.state = SmsSession.State.NEED_SYMPTOM
        session.save()
        return SYMPTOM_MENU_PROMPT

    # state == NEED_SYMPTOM
    if choice not in SYMPTOM_CHOICES:
        return UNRECOGNIZED_PREFIX + SYMPTOM_MENU_PROMPT

    class_id = class_for_choice(session.crop_choice, choice)
    reply_language = session.language
    session.delete()  # conversation complete; the next text starts fresh

    return get_treatment_text(class_id, reply_language) or NO_ADVICE_FOUND
