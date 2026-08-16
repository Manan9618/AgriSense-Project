from django.urls import path

from core.views import (
    FeedbackSyncView,
    PriceComparisonView,
    ScanSyncView,
    sms_webhook,
    voice_webhook,
)

urlpatterns = [
    path("prices/compare/", PriceComparisonView.as_view(), name="price-comparison"),
    path("sync/scans/", ScanSyncView.as_view(), name="scan-sync"),
    path("sync/feedback/", FeedbackSyncView.as_view(), name="feedback-sync"),
    path("sms/webhook/", sms_webhook, name="sms-webhook"),
    path("voice/webhook/", voice_webhook, name="voice-webhook"),
]
