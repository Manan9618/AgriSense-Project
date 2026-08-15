import 'package:agrisense_ai/models/mandi_price.dart';
import 'package:agrisense_ai/screens/price_comparison_screen.dart';
import 'package:agrisense_ai/services/price_provider.dart';
import 'package:agrisense_ai/state/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_price_provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => LanguageProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows ranked prices with the best one highlighted', (
    tester,
  ) async {
    const result = PriceComparisonResult(
      isSampleData: true,
      prices: [
        MandiPrice(
          market: 'Anand',
          district: 'Anand',
          state: 'Gujarat',
          commodity: 'Tomato',
          variety: 'Local',
          minPrice: 950,
          maxPrice: 1350,
          modalPrice: 1150,
          arrivalDate: 'sample',
        ),
        MandiPrice(
          market: 'Vadodara',
          district: 'Vadodara',
          state: 'Gujarat',
          commodity: 'Tomato',
          variety: 'Local',
          minPrice: 700,
          maxPrice: 1000,
          modalPrice: 850,
          arrivalDate: 'sample',
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        PriceComparisonScreen(priceProvider: const FakePriceProvider(result)),
      ),
    );

    await tester.tap(find.text('Compare Prices'));
    await tester.pumpAndSettle();

    expect(find.text('Anand'), findsOneWidget);
    expect(find.text('Vadodara'), findsOneWidget);
    expect(find.text('₹1150/quintal'), findsOneWidget);
    expect(find.text('₹850/quintal'), findsOneWidget);
    expect(find.text('Best price'), findsOneWidget);
    expect(
      find.text('Sample data — live market feed not yet connected.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a message when no prices are found', (tester) async {
    const result = PriceComparisonResult(isSampleData: false, prices: []);

    await tester.pumpWidget(
      _wrap(
        PriceComparisonScreen(priceProvider: const FakePriceProvider(result)),
      ),
    );

    await tester.tap(find.text('Compare Prices'));
    await tester.pumpAndSettle();

    expect(
      find.text('No prices found for this crop/location.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error message when the provider throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(PriceComparisonScreen(priceProvider: _ThrowingPriceProvider())),
    );

    await tester.tap(find.text('Compare Prices'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not reach the price service: connection refused'),
      findsOneWidget,
    );
  });
}

class _ThrowingPriceProvider implements PriceProvider {
  @override
  Future<PriceComparisonResult> comparePrices({
    required String commodity,
    required String state,
    String? district,
  }) async {
    throw PriceProviderException(
      'Could not reach the price service: connection refused',
    );
  }
}
