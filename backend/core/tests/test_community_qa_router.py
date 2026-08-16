from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase

from core.community_qa_router import route_question
from core.models import Answer, Question

User = get_user_model()


class RouteQuestionTests(TestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")
        self.farmer = User.objects.create_user(username="farmer-qa", password="x")

    def test_matching_crop_and_symptom_gets_an_auto_suggested_answer(self):
        question = Question.objects.create(
            farmer=self.farmer,
            crop="tomato",
            symptom="wilting",
            title="My tomato leaves are wilting fast",
            language="en",
        )

        answer = route_question(question)

        self.assertIsNotNone(answer)
        self.assertTrue(answer.is_auto_suggested)
        self.assertIsNone(answer.author)
        self.assertIn("Late Blight", answer.body)
        self.assertEqual(list(question.answers.all()), [answer])

    def test_answer_is_localized_to_the_question_language(self):
        question = Question.objects.create(
            farmer=self.farmer,
            crop="potato",
            symptom="spots",
            title="Spots on potato leaves",
            language="hi",
        )

        answer = route_question(question)

        self.assertIn("झुलसा", answer.body)

    def test_question_with_no_crop_or_symptom_gets_no_auto_suggestion(self):
        question = Question.objects.create(
            farmer=self.farmer,
            title="General question about soil pH",
        )

        answer = route_question(question)

        self.assertIsNone(answer)
        self.assertEqual(Answer.objects.count(), 0)

    def test_healthy_symptom_still_gets_a_no_treatment_needed_style_answer(self):
        question = Question.objects.create(
            farmer=self.farmer,
            crop="pepper_bell",
            symptom="healthy",
            title="Is my pepper plant okay?",
        )

        answer = route_question(question)

        self.assertIsNotNone(answer)
        self.assertTrue(answer.is_auto_suggested)
