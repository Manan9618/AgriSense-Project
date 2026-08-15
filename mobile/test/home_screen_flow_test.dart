import 'package:agrisense_ai/screens/home_screen.dart';
import 'package:agrisense_ai/state/language_provider.dart';
import 'package:agrisense_ai/state/scan_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_photo_capture_source.dart';
import 'fake_voice_command_source.dart';
import 'test_app_services.dart';

/// End-to-end widget test: tap "Capture Photo" -> fake camera returns a
/// real held-out test image -> real on-device inference runs -> real
/// SQLite persistence (Week 9) -> app navigates to the Diagnosis Result
/// screen showing the correct crop and condition. The only thing NOT
/// exercised here is actual camera hardware (see mobile/README.md) —
/// everything else in the flow is real.
///
/// Wrapped in tester.runAsync(): the capture flow does genuine dart:io file
/// I/O, real SQLite queries, and a real FFI call into the TFLite
/// interpreter, and testWidgets()'s default fake-async zone never lets that
/// kind of real async work complete — it just hangs forever. runAsync()
/// breaks out of the fake zone for real I/O/FFI, which is Flutter's
/// documented fix for exactly this.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 30,
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

/// For animated transitions (page routes, popup menus): the target widget
/// can exist in the tree before it's actually hit-testable at its final
/// position, so pumpUntilFound's "does it exist yet" check isn't enough —
/// this just pumps a fixed number of real-time frames to let the animation
/// finish.
Future<void> pumpFrames(WidgetTester tester, {int times = 10}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'capture -> classify -> result screen shows the right diagnosis',
    (tester) async {
      await tester.runAsync(() async {
        final built = await buildTestAppServices(
          photoCaptureSource: const FakePhotoCaptureSource(
            'test/fixtures/sample_2_pepper_bell_healthy.jpg',
          ),
        );
        addTearDown(built.services.inferenceService.close);
        addTearDown(() => built.tempDir.delete(recursive: true));

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LanguageProvider()),
              ChangeNotifierProvider(create: (_) => ScanHistoryProvider()),
            ],
            child: MaterialApp(home: HomeScreen(services: built.services)),
          ),
        );
        await tester.pump();

        expect(find.text('Recent Scans'), findsOneWidget);
        expect(
          find.text('No scans yet — capture your first crop photo above.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Capture Photo'));
        await pumpUntilFound(tester, find.text('Diagnosis Result'));

        expect(find.text('Diagnosis Result'), findsOneWidget);
        expect(find.text('Healthy'), findsWidgets);
        expect(find.text('Pepper (bell)'), findsOneWidget);
        expect(find.text('Recommended Treatment'), findsOneWidget);
        expect(
          find.text(
            'No treatment needed. Continue regular watering and check '
            'weekly for early signs of leaf spots or wilting.',
          ),
          findsOneWidget,
        );
        expect(find.text('Hear Advice in English'), findsOneWidget);

        await tester.pageBack();
        await tester.pump();

        expect(find.text('Pepper (bell) — Healthy'), findsOneWidget);
        // The scan is now persisted (Week 9) and unsynced.
        expect(find.text('1 scan(s) waiting to sync'), findsOneWidget);
      });
    },
  );

  testWidgets('language selector switches UI chrome strings', (tester) async {
    await tester.runAsync(() async {
      final built = await buildTestAppServices(
        photoCaptureSource: const FakePhotoCaptureSource(
          'test/fixtures/sample_2_pepper_bell_healthy.jpg',
        ),
      );
      addTearDown(built.services.inferenceService.close);
      addTearDown(() => built.tempDir.delete(recursive: true));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => ScanHistoryProvider()),
          ],
          child: MaterialApp(home: HomeScreen(services: built.services)),
        ),
      );
      await tester.pump();

      expect(find.text('Recent Scans'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.language));
      await pumpFrames(tester);
      await tester.tap(find.text('ગુજરાતી'));
      await pumpFrames(tester);

      expect(find.text('તાજેતરના સ્કેન'), findsOneWidget);

      // Marathi (Week 11) — same selector, so this mostly proves the 4th
      // language is actually wired into the menu, not just AppStrings.
      await tester.tap(find.byIcon(Icons.language));
      await pumpFrames(tester);
      await tester.tap(find.text('मराठी'));
      await pumpFrames(tester);

      expect(find.text('अलीकडील स्कॅन'), findsOneWidget);
    });
  });

  testWidgets('saying "prices" navigates to the price comparison screen', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final built = await buildTestAppServices(
        voiceCommandSource: const FakeVoiceCommandSource('show me prices'),
      );
      addTearDown(built.services.inferenceService.close);
      addTearDown(() => built.tempDir.delete(recursive: true));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider(create: (_) => ScanHistoryProvider()),
          ],
          child: MaterialApp(home: HomeScreen(services: built.services)),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.mic_none));
      await pumpUntilFound(tester, find.text('Price Comparison'));

      expect(find.text('Price Comparison'), findsOneWidget);
    });
  });
}
