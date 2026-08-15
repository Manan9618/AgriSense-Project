import 'package:agrisense_ai/models/mandi_price.dart';
import 'package:agrisense_ai/services/price_provider.dart';

/// Test double: returns a canned comparison result instead of calling a
/// real backend.
class FakePriceProvider implements PriceProvider {
  const FakePriceProvider(this.result);

  final PriceComparisonResult result;

  @override
  Future<PriceComparisonResult> comparePrices({
    required String commodity,
    required String state,
    String? district,
  }) async => result;
}
