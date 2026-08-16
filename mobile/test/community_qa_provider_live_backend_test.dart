import 'dart:io';

import 'package:agrisense_ai/services/community_qa_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Genuine end-to-end test, same self-skipping pattern as
/// sync_backend_live_backend_test.dart (Week 9): real HTTP calls from
/// HttpCommunityQAProvider to an actually-running Django dev server. Run
/// deliberately:
///   cd backend && source .venv/bin/activate && python manage.py runserver 127.0.0.1:8000 &
///   cd mobile && flutter test test/community_qa_provider_live_backend_test.dart
void main() {
  const baseUrl = 'http://127.0.0.1:8000';

  test(
    'posting a tagged question gets a real auto-suggested answer back',
    () async {
      final serverIsUp = await _isServerReachable(baseUrl);
      if (!serverIsUp) {
        markTestSkipped(
          'No Django dev server reachable at $baseUrl — start one to run this test '
          '(see the doc comment at the top of this file).',
        );
        return;
      }

      final provider = HttpCommunityQAProvider(baseUrl: baseUrl);

      final question = await provider.postQuestion(
        deviceId: 'live-test-device',
        crop: 'tomato',
        symptom: 'wilting',
        title: 'Live test: tomato leaves wilting',
        language: 'en',
      );

      expect(question.answers, hasLength(1));
      expect(question.answers.first.isAutoSuggested, isTrue);

      final fetched = await provider.getQuestion(question.id);
      expect(fetched.answers, hasLength(1));

      final reply = await provider.postAnswer(
        questionId: question.id,
        deviceId: 'live-test-device-2',
        body: 'Also try improving drainage.',
      );
      expect(reply.isAutoSuggested, isFalse);

      final refetched = await provider.getQuestion(question.id);
      expect(refetched.answers, hasLength(2));

      final list = await provider.listQuestions(crop: 'tomato');
      expect(list.map((q) => q.id), contains(question.id));
    },
  );
}

Future<bool> _isServerReachable(String baseUrl) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.getUrl(
      Uri.parse('$baseUrl/api/prices/compare/?commodity=Tomato&state=Gujarat'),
    );
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}
