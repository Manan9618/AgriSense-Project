import 'dart:io';

import 'package:agrisense_ai/services/price_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Genuine end-to-end test: real HTTP call from HttpPriceProvider to an
/// actually-running Django dev server (`manage.py runserver 127.0.0.1:8000`
/// from the backend/ directory), verifying the full stack — Dart HTTP
/// client -> Django URL routing -> PriceComparisonView -> MandiPriceComparator
/// -> JSON response -> Dart model parsing — actually works, not just each
/// half in isolation.
///
/// Self-skips if the server isn't reachable, so `flutter test` still passes
/// in CI/on other machines without a backend running — this is a manual
/// verification step, not part of the default suite's guarantees. Run it
/// deliberately:
///   cd backend && source .venv/bin/activate && python manage.py runserver 127.0.0.1:8000 &
///   cd mobile && flutter test test/price_provider_live_backend_test.dart
void main() {
  const baseUrl = 'http://127.0.0.1:8000';

  test('HttpPriceProvider gets real ranked prices from a live Django server', () async {
    final serverIsUp = await _isServerReachable(baseUrl);
    if (!serverIsUp) {
      markTestSkipped(
        'No Django dev server reachable at $baseUrl — start one to run this test '
        '(see the doc comment at the top of this file).',
      );
      return;
    }

    final provider = HttpPriceProvider(baseUrl: baseUrl);

    final result = await provider.comparePrices(
      commodity: 'Tomato',
      state: 'Gujarat',
    );

    expect(result.prices, isNotEmpty);
    // Ranked best (highest modal price) first.
    for (var i = 1; i < result.prices.length; i++) {
      expect(
        result.prices[i - 1].modalPrice,
        greaterThanOrEqualTo(result.prices[i].modalPrice),
      );
    }
    for (final price in result.prices) {
      expect(price.commodity, 'Tomato');
      expect(price.state, 'Gujarat');
    }
  });
}

Future<bool> _isServerReachable(String baseUrl) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.getUrl(
      Uri.parse('$baseUrl/api/prices/compare/?commodity=Tomato&state=Gujarat'),
    );
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}
