import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/screens/diagnosis_result_screen.dart';
import 'package:agrisense_ai/services/advisory_service.dart';
import 'package:agrisense_ai/services/feedback_repository.dart';
import 'package:agrisense_ai/services/local_database.dart';
import 'package:agrisense_ai/services/tts_service.dart';
import 'package:agrisense_ai/state/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// End-to-end feedback flow (Week 12, FeedbackCollector): tap "Give
/// Feedback" on a diagnosis, answer both questions, submit -> a real row
/// lands in a real SQLite database (FFI, same pattern as
/// local_database_test.dart), and the UI flips to "already submitted"
/// without needing to reopen the screen.
///
/// Wrapped in tester.runAsync() throughout — FeedbackRepository does real
/// dart:io-adjacent SQLite calls, which hang forever under testWidgets()'s
/// default fake-async zone (see home_screen_flow_test.dart's doc comment
/// for the established fix).
/// FutureBuilder-driven content (the "has feedback already?" check, the
/// sheet's async submit) doesn't reliably settle under pumpAndSettle() the
/// way animation-driven content does — same real-async caveat as
/// home_screen_flow_test.dart's pumpUntilFound, reused here.
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

/// "Give Feedback" is the button's label whether or not the
/// hasFeedback-check FutureBuilder has resolved yet — only `onPressed`
/// (null while loading) differs, so pumpUntilFound on the text alone can
/// return before the button is actually tappable. A few unconditional real
/// pumps give that FutureBuilder time to settle before tapping.
Future<void> pumpSettleReal(WidgetTester tester, {int times = 10}) async {
  for (var i = 0; i < times; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget wrap(Widget child) {
    return ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(home: child),
    );
  }

  testWidgets(
    'submitting feedback for a diseased scan records both answers and updates the UI',
    (tester) async {
      await tester.runAsync(() async {
        final database = await LocalDatabase.open(inMemoryDatabasePath);
        addTearDown(database.close);
        final feedbackRepository = FeedbackRepository(database: database);
        final advisoryService = await AdvisoryService.load();

        final scan = ScanRecord(
          id: 'scan-feedback-1',
          imagePath: '/tmp/does-not-exist.jpg',
          prediction: const DiagnosisPrediction(
            classId: 'tomato_late_blight',
            confidence: 0.9,
          ),
          capturedAt: DateTime(2026, 6, 1),
        );

        await tester.pumpWidget(
          wrap(
            DiagnosisResultScreen(
              scan: scan,
              advisoryService: advisoryService,
              ttsService: TtsService(),
              feedbackRepository: feedbackRepository,
            ),
          ),
        );
        await pumpSettleReal(tester);

        expect(find.text('Give Feedback'), findsOneWidget);
        expect(await feedbackRepository.hasFeedback(scan.id), isFalse);

        await tester.ensureVisible(find.text('Give Feedback'));
        await tester.tap(find.text('Give Feedback'));
        await pumpUntilFound(tester, find.text('Was this diagnosis correct?'));
        await tester.pumpAndSettle();

        expect(find.text('Was this diagnosis correct?'), findsOneWidget);
        expect(find.text('Did the treatment help?'), findsOneWidget);

        await tester.tap(find.text('Yes'));
        await tester.pump();
        await tester.tap(find.text('Helped'));
        await tester.pump();
        await tester.enterText(
          find.byType(TextField),
          'Spots cleared up within a week.',
        );

        await tester.ensureVisible(find.text('Submit'));
        await tester.tap(find.text('Submit'));
        await pumpUntilFound(tester, find.text('Thanks — feedback recorded'));

        expect(find.text('Thanks — feedback recorded'), findsOneWidget);
        expect(find.text('Give Feedback'), findsNothing);

        expect(await feedbackRepository.hasFeedback(scan.id), isTrue);
        final pending = await database.getPendingFeedback();
        expect(pending, hasLength(1));
        expect(pending.first.diagnosisAccuracy, 'correct');
        expect(pending.first.treatmentOutcome, 'helped');
        expect(pending.first.notes, 'Spots cleared up within a week.');
      });
    },
  );

  testWidgets(
    'a healthy diagnosis does not ask whether treatment helped',
    (tester) async {
      await tester.runAsync(() async {
        final database = await LocalDatabase.open(inMemoryDatabasePath);
        addTearDown(database.close);
        final feedbackRepository = FeedbackRepository(database: database);
        final advisoryService = await AdvisoryService.load();

        final scan = ScanRecord(
          id: 'scan-feedback-2',
          imagePath: '/tmp/does-not-exist.jpg',
          prediction: const DiagnosisPrediction(
            classId: 'tomato_healthy',
            confidence: 0.97,
          ),
          capturedAt: DateTime(2026, 6, 1),
        );

        await tester.pumpWidget(
          wrap(
            DiagnosisResultScreen(
              scan: scan,
              advisoryService: advisoryService,
              ttsService: TtsService(),
              feedbackRepository: feedbackRepository,
            ),
          ),
        );
        await pumpSettleReal(tester);

        await tester.ensureVisible(find.text('Give Feedback'));
        await tester.tap(find.text('Give Feedback'));
        await pumpUntilFound(tester, find.text('Was this diagnosis correct?'));
        await tester.pumpAndSettle();

        expect(find.text('Was this diagnosis correct?'), findsOneWidget);
        expect(find.text('Did the treatment help?'), findsNothing);
      });
    },
  );

  testWidgets(
    'a scan that already has feedback shows the thank-you state on open',
    (tester) async {
      await tester.runAsync(() async {
        final database = await LocalDatabase.open(inMemoryDatabasePath);
        addTearDown(database.close);
        final feedbackRepository = FeedbackRepository(database: database);
        final advisoryService = await AdvisoryService.load();

        final scan = ScanRecord(
          id: 'scan-feedback-3',
          imagePath: '/tmp/does-not-exist.jpg',
          prediction: const DiagnosisPrediction(
            classId: 'tomato_healthy',
            confidence: 0.97,
          ),
          capturedAt: DateTime(2026, 6, 1),
        );
        await feedbackRepository.submitFeedback(
          scanId: scan.id,
          diagnosisAccuracy: 'unsure',
        );

        await tester.pumpWidget(
          wrap(
            DiagnosisResultScreen(
              scan: scan,
              advisoryService: advisoryService,
              ttsService: TtsService(),
              feedbackRepository: feedbackRepository,
            ),
          ),
        );
        await pumpUntilFound(tester, find.text('Thanks — feedback recorded'));

        expect(find.text('Thanks — feedback recorded'), findsOneWidget);
        expect(find.text('Give Feedback'), findsNothing);
      });
    },
  );
}
