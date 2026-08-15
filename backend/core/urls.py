from django.urls import path

from core.views import PriceComparisonView, ScanSyncView

urlpatterns = [
    path("prices/compare/", PriceComparisonView.as_view(), name="price-comparison"),
    path("sync/scans/", ScanSyncView.as_view(), name="scan-sync"),
]
