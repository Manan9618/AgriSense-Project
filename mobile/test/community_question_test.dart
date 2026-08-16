import 'package:agrisense_ai/models/community_question.dart';
import 'package:flutter_test/flutter_test.dart';

/// CommunityQuestion/CommunityAnswer.fromJson are only otherwise exercised
/// by HttpCommunityQAProvider's real network calls, which self-skip
/// without a live backend — plain unit tests against literal JSON so the
/// parsing itself always has real coverage.
void main() {
  test('CommunityAnswer.fromJson matches AnswerSerializer field names', () {
    final answer = CommunityAnswer.fromJson({
      'id': 'a1',
      'body': 'Try neem oil spray.',
      'is_auto_suggested': false,
      'created_at': '2026-06-01T09:30:00Z',
    });

    expect(answer.id, 'a1');
    expect(answer.body, 'Try neem oil spray.');
    expect(answer.isAutoSuggested, isFalse);
    expect(answer.createdAt, DateTime.parse('2026-06-01T09:30:00Z'));
  });

  test('CommunityQuestion.fromJson parses a fully-tagged question with answers', () {
    final question = CommunityQuestion.fromJson({
      'id': 'q1',
      'crop': 'tomato',
      'symptom': 'wilting',
      'title': 'Why are my tomato leaves wilting?',
      'body': 'Started two days ago.',
      'language': 'en',
      'created_at': '2026-06-01T09:30:00Z',
      'answers': [
        {
          'id': 'a1',
          'body': 'Similar reports suggest this could be: Late Blight: ...',
          'is_auto_suggested': true,
          'created_at': '2026-06-01T09:31:00Z',
        },
      ],
    });

    expect(question.id, 'q1');
    expect(question.crop, 'tomato');
    expect(question.symptom, 'wilting');
    expect(question.title, 'Why are my tomato leaves wilting?');
    expect(question.body, 'Started two days ago.');
    expect(question.language, 'en');
    expect(question.answers, hasLength(1));
    expect(question.answers.first.isAutoSuggested, isTrue);
  });

  test('CommunityQuestion.fromJson defaults optional fields when absent', () {
    // QuestionSerializer's list view omits `answers`; crop/symptom/body
    // are all optional server-side (blank=True/allow_blank=True).
    final question = CommunityQuestion.fromJson({
      'id': 'q2',
      'title': 'General soil question',
      'language': 'en',
      'created_at': '2026-06-01T09:30:00Z',
    });

    expect(question.crop, '');
    expect(question.symptom, '');
    expect(question.body, '');
    expect(question.answers, isEmpty);
  });
}
