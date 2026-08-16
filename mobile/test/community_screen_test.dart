import 'package:agrisense_ai/models/community_question.dart';
import 'package:agrisense_ai/screens/community_screen.dart';
import 'package:agrisense_ai/state/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_community_qa_provider.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => LanguageProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('shows the empty state when there are no questions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CommunityScreen(
          communityQAProvider: FakeCommunityQAProvider(),
          deviceId: 'device-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No questions yet — be the first to ask.'),
      findsOneWidget,
    );
  });

  testWidgets('lists existing questions and opens one on tap', (
    tester,
  ) async {
    final provider = FakeCommunityQAProvider(
      seed: [
        CommunityQuestion(
          id: 'q1',
          crop: 'tomato',
          symptom: 'wilting',
          title: 'Why are my tomato leaves wilting?',
          body: 'Started two days ago.',
          language: 'en',
          createdAt: DateTime(2026, 6, 1),
          answers: [
            CommunityAnswer(
              id: 'a1',
              body: 'Similar reports suggest this could be: Late Blight: ...',
              isAutoSuggested: true,
              createdAt: DateTime(2026, 6, 1),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(CommunityScreen(communityQAProvider: provider, deviceId: 'd1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Why are my tomato leaves wilting?'), findsOneWidget);

    await tester.tap(find.text('Why are my tomato leaves wilting?'));
    await tester.pumpAndSettle();

    expect(find.text('Started two days ago.'), findsOneWidget);
    expect(find.text('Automated suggestion'), findsOneWidget);
  });

  testWidgets('asking a question posts it and navigates to its detail', (
    tester,
  ) async {
    final provider = FakeCommunityQAProvider();

    await tester.pumpWidget(
      _wrap(CommunityScreen(communityQAProvider: provider, deviceId: 'd1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask a Question'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Can I plant potatoes near tomatoes?',
    );
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    // Now on the detail screen for the just-created question.
    expect(find.text('Can I plant potatoes near tomatoes?'), findsOneWidget);
    expect(find.text('No answers yet.'), findsOneWidget);

    final stored = await provider.listQuestions();
    expect(stored, hasLength(1));
    expect(stored.first.title, 'Can I plant potatoes near tomatoes?');
  });
}
