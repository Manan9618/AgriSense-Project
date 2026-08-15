import 'package:flutter/material.dart';

import '../screens/price_comparison_screen.dart';
import '../services/price_provider.dart';
import '../state/app_language.dart';

/// Bottom nav matching the sample UI (Section 6): Home/Weather/Prices/
/// Community. Home and Prices are functional; Weather and Community are
/// still "coming soon" — Weather stayed backend-only in Week 6 (no API
/// endpoint yet, see docs/adr/0007), Community lands in Week 14.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.strings,
    required this.priceProvider,
  });

  final AppStrings strings;
  final PriceProvider priceProvider;

  static const _comingSoonWeek = {
    1: 'Week 6 (backend only so far)',
    3: 'Week 14',
  };

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 0) return;
        if (index == 2) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PriceComparisonScreen(priceProvider: priceProvider),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Coming in ${_comingSoonWeek[index]}')),
        );
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: strings['homeTab'],
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.cloud),
          label: strings['weatherTab'],
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.storefront),
          label: strings['pricesTab'],
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.people),
          label: strings['communityTab'],
        ),
      ],
    );
  }
}
