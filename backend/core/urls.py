from django.urls import path

from core.views import PriceComparisonView

urlpatterns = [
    path("prices/compare/", PriceComparisonView.as_view(), name="price-comparison"),
]
