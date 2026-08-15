import 'package:flutter/material.dart';

import '../state/app_language.dart';

/// Bottom nav matching the sample UI (Section 6): Home/Weather/Prices/
/// Community. Only Home is functional in Week 4 — the other tabs land in
/// Week 6 (weather), Week 7 (prices), and Week 14 (community Q&A).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.strings});

  final AppStrings strings;

  static const _comingSoonWeek = {1: 'Week 6', 2: 'Week 7', 3: 'Week 14'};

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        if (index == 0) return;
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
