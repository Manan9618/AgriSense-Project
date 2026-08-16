import 'package:flutter/material.dart';

import '../screens/community_screen.dart';
import '../screens/price_comparison_screen.dart';
import '../services/community_qa_provider.dart';
import '../services/price_provider.dart';
import '../state/app_language.dart';

/// Bottom nav matching the sample UI (Section 6): Home/Weather/Prices/
/// Community. Home, Prices, and Community are functional; Weather stayed
/// backend-only in Week 6 (no API endpoint yet, see docs/adr/0007).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.strings,
    required this.priceProvider,
    required this.communityQAProvider,
    required this.deviceId,
  });

  final AppStrings strings;
  final PriceProvider priceProvider;
  final CommunityQAProvider communityQAProvider;
  final String deviceId;

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
        if (index == 3) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CommunityScreen(
                communityQAProvider: communityQAProvider,
                deviceId: deviceId,
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coming in Week 6 (backend only so far)')),
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
