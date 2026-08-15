import xml.etree.ElementTree as ET

from django.core.management import call_command
from django.test import TestCase
from django.urls import reverse

from core.models import SmsSession


def xml_text(response) -> str:
    """All human-readable text in a TwiML response, concatenated — lets
    tests assert on content without depending on exact XML structure."""
    root = ET.fromstring(response.content)
    return " ".join(elem.text.strip() for elem in root.iter() if elem.text and elem.text.strip())


class SmsWebhookTests(TestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")
        self.url = reverse("sms-webhook")

    def test_rejects_get(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 405)

    def test_first_message_returns_twiml_with_the_crop_menu(self):
        response = self.client.post(self.url, {"From": "+15550001111", "Body": "help"})

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "text/xml")
        self.assertIn("Potato", xml_text(response))

    def test_full_conversation_across_three_requests_returns_diagnosis(self):
        phone = "+15550002222"
        self.client.post(self.url, {"From": phone, "Body": "hi"})
        self.client.post(self.url, {"From": phone, "Body": "1"})  # potato
        response = self.client.post(self.url, {"From": phone, "Body": "3"})  # healthy

        self.assertIn("Healthy", xml_text(response))
        self.assertFalse(SmsSession.objects.filter(phone_number=phone).exists())

    def test_missing_body_is_treated_as_an_empty_reply(self):
        response = self.client.post(self.url, {"From": "+15550003333"})
        self.assertEqual(response.status_code, 200)


class VoiceWebhookTests(TestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")
        self.url = reverse("voice-webhook")

    def test_rejects_get(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 405)

    def test_initial_call_gathers_the_crop_menu(self):
        response = self.client.post(self.url, {"From": "+15550004444"})

        self.assertEqual(response.status_code, 200)
        self.assertIn("Potato", xml_text(response))
        self.assertIn('action="/api/voice/webhook/?step=symptom"', response.content.decode())

    def test_valid_crop_digit_gathers_the_symptom_menu(self):
        response = self.client.post(
            f"{self.url}?step=symptom", {"From": "+15550005555", "Digits": "2"}
        )

        self.assertIn("Spots", xml_text(response))
        self.assertIn("crop=2", response.content.decode())

    def test_invalid_crop_digit_reprompts_the_same_step(self):
        response = self.client.post(
            f"{self.url}?step=symptom", {"From": "+15550006666", "Digits": "9"}
        )

        self.assertIn("not a valid choice", xml_text(response))
        self.assertIn("Potato", xml_text(response))

    def test_valid_symptom_digit_speaks_the_diagnosis_and_hangs_up(self):
        response = self.client.post(
            f"{self.url}?step=diagnosis&crop=3",  # tomato
            {"From": "+15550007777", "Digits": "1"},  # spots -> early blight
        )

        self.assertIn("Early Blight", xml_text(response))
        self.assertIn("<Hangup", response.content.decode())

    def test_invalid_symptom_digit_reprompts_with_crop_preserved(self):
        response = self.client.post(
            f"{self.url}?step=diagnosis&crop=1", {"From": "+15550008888", "Digits": "9"}
        )

        self.assertIn("not a valid choice", xml_text(response))
        self.assertIn("crop=1", response.content.decode())

    def test_full_call_flow_across_three_requests(self):
        phone = "+15550009999"
        step1 = self.client.post(self.url, {"From": phone})
        self.assertIn("Potato", xml_text(step1))

        step2 = self.client.post(f"{self.url}?step=symptom", {"From": phone, "Digits": "1"})
        self.assertIn("Spots", xml_text(step2))

        step3 = self.client.post(
            f"{self.url}?step=diagnosis&crop=1", {"From": phone, "Digits": "3"}
        )
        self.assertIn("Healthy", xml_text(step3))
