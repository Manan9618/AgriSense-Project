import 'package:agrisense_ai/models/mandi_price.dart';
import 'package:flutter_test/flutter_test.dart';

/// MandiPrice/PriceComparisonResult.fromJson are only otherwise exercised
/// by HttpPriceProvider's real network call, which self-skips without a
/// live backend (price_provider_live_backend_test.dart) — these are plain
/// unit tests against literal JSON so the parsing itself always has real
/// coverage, independent of a server being reachable.
void main() {
  test('MandiPrice.fromJson matches backend/core/serializers.py field names', () {
    final price = MandiPrice.fromJson({
      'market': 'Anand',
      'district': 'Anand',
      'state': 'Gujarat',
      'commodity': 'Tomato',
      'variety': 'Local',
      'min_price': 950,
      'max_price': 1350,
      'modal_price': 1150,
      'arrival_date': '2026-06-01',
    });

    expect(price.market, 'Anand');
    expect(price.district, 'Anand');
    expect(price.state, 'Gujarat');
    expect(price.commodity, 'Tomato');
    expect(price.variety, 'Local');
    expect(price.minPrice, 950.0);
    expect(price.maxPrice, 1350.0);
    expect(price.modalPrice, 1150.0);
    expect(price.arrivalDate, '2026-06-01');
  });

  test('MandiPrice.fromJson accepts integer or double price fields', () {
    // Django/DRF can serialize a FloatField as either depending on the
    // value — .toDouble() must handle both.
    final price = MandiPrice.fromJson({
      'market': 'Vadodara',
      'district': 'Vadodara',
      'state': 'Gujarat',
      'commodity': 'Tomato',
      'variety': 'Local',
      'min_price': 700,
      'max_price': 1000.5,
      'modal_price': 850,
      'arrival_date': 'sample',
    });

    expect(price.minPrice, 700.0);
    expect(price.maxPrice, 1000.5);
  });

  test('PriceComparisonResult.fromJson parses is_sample_data and prices', () {
    final result = PriceComparisonResult.fromJson({
      'is_sample_data': true,
      'prices': [
        {
          'market': 'Anand',
          'district': 'Anand',
          'state': 'Gujarat',
          'commodity': 'Tomato',
          'variety': 'Local',
          'min_price': 950,
          'max_price': 1350,
          'modal_price': 1150,
          'arrival_date': 'sample',
        },
      ],
    });

    expect(result.isSampleData, isTrue);
    expect(result.prices, hasLength(1));
    expect(result.prices.first.market, 'Anand');
  });

  test('PriceComparisonResult.fromJson handles an empty prices list', () {
    final result = PriceComparisonResult.fromJson({
      'is_sample_data': false,
      'prices': [],
    });

    expect(result.isSampleData, isFalse);
    expect(result.prices, isEmpty);
  });
}
