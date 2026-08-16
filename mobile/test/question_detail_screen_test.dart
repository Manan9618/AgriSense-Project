import 'package:agrisense_ai/models/community_question.dart';
import 'package:agrisense_ai/screens/question_detail_screen.dart';
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
  testWidgets('posting a reply appends it to the answer list', (
    tester,
  ) async {
    final provider = FakeCommunityQAProvider(
      seed: [
        CommunityQuestion(
          id: 'q1',
          crop: '',
          symptom: '',
          title: 'General question',
          body: '',
          language: 'en',
          createdAt: DateTime(2026, 6, 1),
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        QuestionDetailScreen(
          questionId: 'q1',
          communityQAProvider: provider,
          deviceId: 'device-2',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No answers yet.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Try neem oil spray.');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Try neem oil spray.'), findsOneWidget);
    expect(find.text('No answers yet.'), findsNothing);

    final question = await provider.getQuestion('q1');
    expect(question.answers, hasLength(1));
    expect(question.answers.first.body, 'Try neem oil spray.');
  });

  testWidgets('shows an error message when posting a reply fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        QuestionDetailScreen(
          questionId: 'missing',
          communityQAProvider: FakeCommunityQAProvider(),
          deviceId: 'device-3',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('not found: missing'), findsOneWidget);
  });
}
