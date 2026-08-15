import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mandi_price.dart';
import '../services/price_provider.dart';
import '../state/language_provider.dart';
import '../theme/app_theme.dart';

/// Price comparison screen (Week 7): crop + location -> ranked nearby
/// market prices, via the backend's MandiPriceComparator
/// (backend/core/price_comparator.py). [priceProvider] is injected so
/// tests can supply a fake instead of requiring a reachable backend.
class PriceComparisonScreen extends StatefulWidget {
  const PriceComparisonScreen({super.key, required this.priceProvider});

  final PriceProvider priceProvider;

  @override
  State<PriceComparisonScreen> createState() => _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  static const _crops = ['Tomato', 'Potato', 'Pepper'];

  String _selectedCrop = _crops.first;
  final _stateController = TextEditingController(text: 'Gujarat');
  final _districtController = TextEditingController(text: 'Ahmedabad');

  bool _isLoading = false;
  String? _error;
  PriceComparisonResult? _result;

  @override
  void dispose() {
    _stateController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  Future<void> _compare() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.priceProvider.comparePrices(
        commodity: _selectedCrop,
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on PriceProviderException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings['priceComparison'])),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedCrop,
            decoration: InputDecoration(labelText: strings['selectCrop']),
            items: [
              for (final crop in _crops)
                DropdownMenuItem(value: crop, child: Text(crop)),
            ],
            onChanged: (value) =>
                setState(() => _selectedCrop = value ?? _selectedCrop),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stateController,
            decoration: InputDecoration(labelText: strings['state']),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _districtController,
            decoration: InputDecoration(labelText: strings['district']),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _compare,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(strings['comparePrices']),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTheme.highUrgency)),
          if (_result != null) ..._buildResults(_result!, strings),
        ],
      ),
    );
  }

  List<Widget> _buildResults(PriceComparisonResult result, dynamic strings) {
    if (result.prices.isEmpty) {
      return [Text(strings['noPricesFound'])];
    }

    return [
      if (result.isSampleData)
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            strings['sampleDataWarning'],
            style: const TextStyle(color: AppTheme.mediumUrgency, fontSize: 12),
          ),
        ),
      for (var i = 0; i < result.prices.length; i++)
        _PriceTile(price: result.prices[i], isBest: i == 0, strings: strings),
    ];
  }
}

class _PriceTile extends StatelessWidget {
  const _PriceTile({
    required this.price,
    required this.isBest,
    required this.strings,
  });

  final MandiPrice price;
  final bool isBest;
  final dynamic strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isBest ? AppTheme.lightGreenBg : null,
      child: ListTile(
        title: Text(price.market),
        subtitle: Text('${price.district}, ${price.state}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${price.modalPrice.toStringAsFixed(0)}${strings['perQuintal']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isBest ? AppTheme.primaryGreen : Colors.black87,
              ),
            ),
            if (isBest)
              Text(
                strings['bestPrice'],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primaryGreen,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
