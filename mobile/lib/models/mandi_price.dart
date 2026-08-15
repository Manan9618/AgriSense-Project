/// One market's price quote for a commodity, in Rs per quintal. Mirrors
/// backend/core/price_provider.py's MandiPrice dataclass and
/// core/serializers.py's MandiPriceSerializer field-for-field.
class MandiPrice {
  const MandiPrice({
    required this.market,
    required this.district,
    required this.state,
    required this.commodity,
    required this.variety,
    required this.minPrice,
    required this.maxPrice,
    required this.modalPrice,
    required this.arrivalDate,
  });

  final String market;
  final String district;
  final String state;
  final String commodity;
  final String variety;
  final double minPrice;
  final double maxPrice;
  final double modalPrice;
  final String arrivalDate;

  factory MandiPrice.fromJson(Map<String, dynamic> json) {
    return MandiPrice(
      market: json['market'] as String,
      district: json['district'] as String,
      state: json['state'] as String,
      commodity: json['commodity'] as String,
      variety: json['variety'] as String,
      minPrice: (json['min_price'] as num).toDouble(),
      maxPrice: (json['max_price'] as num).toDouble(),
      modalPrice: (json['modal_price'] as num).toDouble(),
      arrivalDate: json['arrival_date'] as String,
    );
  }
}

class PriceComparisonResult {
  const PriceComparisonResult({
    required this.isSampleData,
    required this.prices,
  });

  /// True when the backend had no live data.gov.in credentials configured
  /// and served fixed sample data instead (backend/core/price_provider.py's
  /// SampleMandiPriceProvider) — the UI must show this plainly, never
  /// present sample prices as live quotes.
  final bool isSampleData;
  final List<MandiPrice> prices;

  factory PriceComparisonResult.fromJson(Map<String, dynamic> json) {
    return PriceComparisonResult(
      isSampleData: json['is_sample_data'] as bool,
      prices: (json['prices'] as List)
          .map((p) => MandiPrice.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
