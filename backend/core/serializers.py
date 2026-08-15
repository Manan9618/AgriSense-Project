from rest_framework import serializers


class MandiPriceSerializer(serializers.Serializer):
    """Plain Serializer, not ModelSerializer — MandiPrice is a dataclass
    (core/price_provider.py), not a Django model; there's nothing to persist
    per-quote, only to render."""

    market = serializers.CharField()
    district = serializers.CharField()
    state = serializers.CharField()
    commodity = serializers.CharField()
    variety = serializers.CharField()
    min_price = serializers.FloatField()
    max_price = serializers.FloatField()
    modal_price = serializers.FloatField()
    arrival_date = serializers.CharField()


class AdvisorySerializer(serializers.Serializer):
    kind = serializers.CharField()
    language = serializers.CharField()
    title = serializers.CharField()
    body = serializers.CharField()
    urgency = serializers.CharField()
