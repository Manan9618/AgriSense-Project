from django.contrib import admin

from core.models import Advisory, Diagnosis, Scan, TreatmentRecommendation


@admin.register(Scan)
class ScanAdmin(admin.ModelAdmin):
    list_display = ("id", "farmer", "captured_at", "synced_at", "language")
    list_filter = ("language",)
    date_hierarchy = "captured_at"


@admin.register(Diagnosis)
class DiagnosisAdmin(admin.ModelAdmin):
    list_display = ("id", "scan", "predicted_class", "confidence", "model_version", "source")
    list_filter = ("predicted_class", "source", "model_version")


@admin.register(Advisory)
class AdvisoryAdmin(admin.ModelAdmin):
    list_display = ("id", "farmer", "kind", "urgency", "delivered_via", "created_at")
    list_filter = ("kind", "urgency", "delivered_via")


@admin.register(TreatmentRecommendation)
class TreatmentRecommendationAdmin(admin.ModelAdmin):
    list_display = ("class_id", "language", "title", "urgency")
    list_filter = ("language", "urgency")
