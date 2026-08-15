from django.core.management import call_command
from django.test import TestCase

from core.models import SmsSession
from core.sms_fallback_handler import handle_sms_message


class HandleSmsMessageTests(TestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")
        self.phone = "+15551234567"

    def test_first_contact_gets_a_welcome_and_crop_menu_regardless_of_content(self):
        reply = handle_sms_message(self.phone, "hi there, my plant looks sick")

        self.assertIn("Potato", reply)
        self.assertIn("Pepper", reply)
        self.assertIn("Tomato", reply)

    def test_full_happy_path_potato_wilting_returns_late_blight_advice(self):
        handle_sms_message(self.phone, "hello")  # first contact -> menu
        handle_sms_message(self.phone, "1")  # potato
        reply = handle_sms_message(self.phone, "2")  # wilting/fast-spreading

        self.assertIn("Late Blight", reply)
        self.assertFalse(SmsSession.objects.filter(phone_number=self.phone).exists())

    def test_full_happy_path_tomato_healthy(self):
        handle_sms_message(self.phone, "hello")
        handle_sms_message(self.phone, "3")  # tomato
        reply = handle_sms_message(self.phone, "3")  # healthy

        self.assertIn("Healthy", reply)

    def test_invalid_crop_choice_reprompts_without_advancing_state(self):
        handle_sms_message(self.phone, "hello")
        reply = handle_sms_message(self.phone, "9")

        self.assertIn("didn't understand", reply)
        session = SmsSession.objects.get(phone_number=self.phone)
        self.assertEqual(session.state, SmsSession.State.NEED_CROP)

    def test_invalid_symptom_choice_reprompts_without_completing(self):
        handle_sms_message(self.phone, "hello")
        handle_sms_message(self.phone, "2")  # pepper
        reply = handle_sms_message(self.phone, "9")

        self.assertIn("didn't understand", reply)
        session = SmsSession.objects.get(phone_number=self.phone)
        self.assertEqual(session.state, SmsSession.State.NEED_SYMPTOM)

    def test_recovers_after_an_invalid_choice(self):
        handle_sms_message(self.phone, "hello")
        handle_sms_message(self.phone, "9")  # invalid, re-prompted
        handle_sms_message(self.phone, "1")  # potato, now valid
        reply = handle_sms_message(self.phone, "3")  # healthy

        self.assertIn("Healthy", reply)

    def test_a_completed_conversation_does_not_carry_state_into_the_next_one(self):
        handle_sms_message(self.phone, "hello")
        handle_sms_message(self.phone, "1")
        handle_sms_message(self.phone, "1")  # completes: potato + spots

        # A brand new text from the same number starts over.
        reply = handle_sms_message(self.phone, "anything")
        self.assertIn("Potato", reply)  # welcome menu again, not a diagnosis

    def test_different_phone_numbers_have_independent_sessions(self):
        handle_sms_message("+1111", "hello")
        handle_sms_message("+1111", "1")  # potato

        handle_sms_message("+2222", "hello")
        reply = handle_sms_message("+2222", "3")  # tomato, independent of +1111

        session_1111 = SmsSession.objects.get(phone_number="+1111")
        self.assertEqual(session_1111.crop_choice, "1")
        self.assertIn("Spots", reply)  # tomato + symptom menu, not a diagnosis yet

    def test_replies_in_the_farmers_selected_language(self):
        handle_sms_message(self.phone, "hello", language="hi")
        handle_sms_message(self.phone, "1")
        reply = handle_sms_message(self.phone, "1")

        self.assertIn("झुलसा", reply)  # Hindi for blight, from seeded content
