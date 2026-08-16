import 'package:agrisense_ai/models/mandi_price.dart';
import 'package:agrisense_ai/screens/community_screen.dart';
import 'package:agrisense_ai/screens/price_comparison_screen.dart';
import 'package:agrisense_ai/state/app_language.dart';
import 'package:agrisense_ai/state/language_provider.dart';
import 'package:agrisense_ai/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_community_qa_provider.dart';
import 'fake_price_provider.dart';

void main() {
  Widget buildNav() {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            strings: AppStrings.of(AppLanguage.english),
            priceProvider: const FakePriceProvider(
              PriceComparisonResult(isSampleData: true, prices: []),
            ),
            communityQAProvider: FakeCommunityQAProvider(),
            deviceId: 'device-1',
          ),
        ),
      ),
    );
  }

  testWidgets('tapping Home does nothing', (tester) async {
    await tester.pumpWidget(buildNav());

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(PriceComparisonScreen), findsNothing);
    expect(find.byType(CommunityScreen), findsNothing);
  });

  testWidgets('tapping Weather shows a "coming soon" message', (
    tester,
  ) async {
    await tester.pumpWidget(buildNav());

    await tester.tap(find.text('Weather'));
    await tester.pumpAndSettle();

    expect(
      find.text('Coming in Week 6 (backend only so far)'),
      findsOneWidget,
    );
  });

  testWidgets('tapping Prices navigates to PriceComparisonScreen', (
    tester,
  ) async {
    await tester.pumpWidget(buildNav());

    await tester.tap(find.text('Prices'));
    await tester.pumpAndSettle();

    expect(find.byType(PriceComparisonScreen), findsOneWidget);
  });

  testWidgets('tapping Community navigates to CommunityScreen', (
    tester,
  ) async {
    await tester.pumpWidget(buildNav());

    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityScreen), findsOneWidget);
  });
}
