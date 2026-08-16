from django.urls import path

from core.views import (
    AnswerCreateView,
    FeedbackSyncView,
    PriceComparisonView,
    QuestionDetailView,
    QuestionListCreateView,
    ScanSyncView,
    sms_webhook,
    voice_webhook,
)

urlpatterns = [
    path("prices/compare/", PriceComparisonView.as_view(), name="price-comparison"),
    path("sync/scans/", ScanSyncView.as_view(), name="scan-sync"),
    path("sync/feedback/", FeedbackSyncView.as_view(), name="feedback-sync"),
    path("community/questions/", QuestionListCreateView.as_view(), name="question-list-create"),
    path(
        "community/questions/<uuid:question_id>/",
        QuestionDetailView.as_view(),
        name="question-detail",
    ),
    path(
        "community/questions/<uuid:question_id>/answers/",
        AnswerCreateView.as_view(),
        name="answer-create",
    ),
    path("sms/webhook/", sms_webhook, name="sms-webhook"),
    path("voice/webhook/", voice_webhook, name="voice-webhook"),
]
