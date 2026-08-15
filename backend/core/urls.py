from django.urls import path

from core.views import PriceComparisonView, ScanSyncView, sms_webhook, voice_webhook

urlpatterns = [
    path("prices/compare/", PriceComparisonView.as_view(), name="price-comparison"),
    path("sync/scans/", ScanSyncView.as_view(), name="scan-sync"),
    path("sms/webhook/", sms_webhook, name="sms-webhook"),
    path("voice/webhook/", voice_webhook, name="voice-webhook"),
]
