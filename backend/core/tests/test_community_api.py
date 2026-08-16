import uuid

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.urls import reverse

from core.models import Answer, Question
from core.tests.helpers import MediaIsolatedTestCase

User = get_user_model()


def question_payload(**overrides):
    defaults = {
        "device_id": "device-abc",
        "crop": "tomato",
        "symptom": "wilting",
        "title": "Tomato leaves wilting fast, what is this?",
        "body": "Started on the lower leaves two days ago.",
        "language": "en",
    }
    defaults.update(overrides)
    return defaults


class QuestionListCreateViewTests(MediaIsolatedTestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")

    def test_posting_a_tagged_question_creates_it_with_an_auto_suggested_answer(self):
        response = self.client.post(
            reverse("question-list-create"),
            question_payload(),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        body = response.json()
        self.assertEqual(body["title"], "Tomato leaves wilting fast, what is this?")
        self.assertEqual(len(body["answers"]), 1)
        self.assertTrue(body["answers"][0]["is_auto_suggested"])

        question = Question.objects.get(id=body["id"])
        self.assertEqual(question.farmer.username, "device-device-abc")

    def test_posting_an_untagged_question_creates_it_with_no_answers(self):
        response = self.client.post(
            reverse("question-list-create"),
            question_payload(crop="", symptom="", title="General soil question"),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["answers"], [])

    def test_missing_title_is_rejected(self):
        payload = question_payload()
        del payload["title"]

        response = self.client.post(
            reverse("question-list-create"), payload, content_type="application/json"
        )

        self.assertEqual(response.status_code, 400)

    def test_invalid_crop_is_rejected(self):
        response = self.client.post(
            reverse("question-list-create"),
            question_payload(crop="cotton"),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)

    def test_lists_questions_newest_first(self):
        self.client.post(
            reverse("question-list-create"),
            question_payload(title="First question"),
            content_type="application/json",
        )
        self.client.post(
            reverse("question-list-create"),
            question_payload(title="Second question"),
            content_type="application/json",
        )

        response = self.client.get(reverse("question-list-create"))

        titles = [q["title"] for q in response.json()]
        self.assertEqual(titles, ["Second question", "First question"])

    def test_filters_by_crop(self):
        self.client.post(
            reverse("question-list-create"),
            question_payload(crop="tomato", symptom="wilting", title="Tomato Q"),
            content_type="application/json",
        )
        self.client.post(
            reverse("question-list-create"),
            question_payload(crop="potato", symptom="spots", title="Potato Q"),
            content_type="application/json",
        )

        response = self.client.get(reverse("question-list-create"), {"crop": "potato"})

        titles = [q["title"] for q in response.json()]
        self.assertEqual(titles, ["Potato Q"])


class QuestionDetailViewTests(MediaIsolatedTestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")

    def test_returns_404_for_an_unknown_question(self):
        response = self.client.get(reverse("question-detail", args=[uuid.uuid4()]))

        self.assertEqual(response.status_code, 404)

    def test_returns_the_question_with_its_answers(self):
        create_response = self.client.post(
            reverse("question-list-create"),
            question_payload(),
            content_type="application/json",
        )
        question_id = create_response.json()["id"]

        response = self.client.get(reverse("question-detail", args=[question_id]))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], question_id)
        self.assertEqual(len(response.json()["answers"]), 1)


class AnswerCreateViewTests(MediaIsolatedTestCase):
    def setUp(self):
        call_command("seed_treatment_recommendations")
        create_response = self.client.post(
            reverse("question-list-create"),
            question_payload(crop="", symptom="", title="Untagged question"),
            content_type="application/json",
        )
        self.question_id = create_response.json()["id"]

    def test_posting_a_reply_adds_it_to_the_question(self):
        response = self.client.post(
            reverse("answer-create", args=[self.question_id]),
            {"device_id": "device-xyz", "body": "Try neem oil spray."},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertFalse(response.json()["is_auto_suggested"])

        question = Question.objects.get(id=self.question_id)
        self.assertEqual(question.answers.count(), 1)
        self.assertEqual(question.answers.first().author.username, "device-device-xyz")

    def test_returns_404_for_an_unknown_question(self):
        response = self.client.post(
            reverse("answer-create", args=[uuid.uuid4()]),
            {"device_id": "device-xyz", "body": "Try neem oil spray."},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 404)

    def test_missing_body_is_rejected(self):
        response = self.client.post(
            reverse("answer-create", args=[self.question_id]),
            {"device_id": "device-xyz"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(Answer.objects.count(), 0)
