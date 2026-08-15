import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mandi_price.dart';

/// Abstraction over "get ranked market prices for a crop" — same
/// interface-plus-fake pattern as PhotoCaptureSource (Week 4) and the
/// backend's WeatherProvider/MandiPriceProvider (Weeks 6-7): isolate the
/// boundary that needs something this environment doesn't have (a running,
/// reachable backend), keep the screen built and tested against it either
/// way.
abstract class PriceProvider {
  Future<PriceComparisonResult> comparePrices({
    required String commodity,
    required String state,
    String? district,
  });
}

class PriceProviderException implements Exception {
  PriceProviderException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Real implementation: calls the Django backend's
/// GET /api/prices/compare/ (backend/core/views.py). [baseUrl] has no safe
/// production default — there's no deployed backend yet (that's Week 18) —
/// so it must be supplied explicitly by whatever wires this up for a real
/// device.
class HttpPriceProvider implements PriceProvider {
  HttpPriceProvider({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<PriceComparisonResult> comparePrices({
    required String commodity,
    required String state,
    String? district,
  }) async {
    final uri = Uri.parse('$baseUrl/api/prices/compare/').replace(
      queryParameters: {
        'commodity': commodity,
        'state': state,
        if (district != null && district.isNotEmpty) 'district': district,
      },
    );

    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw PriceProviderException('Could not reach the price service: $e');
    }

    if (response.statusCode != 200) {
      throw PriceProviderException(
        'Price service returned ${response.statusCode}: ${response.body}',
      );
    }

    return PriceComparisonResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
