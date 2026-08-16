import 'package:agrisense_ai/models/community_question.dart';
import 'package:agrisense_ai/services/community_qa_provider.dart';

/// In-memory test double: stores what's posted and returns it back, so
/// tests can assert on the real request/response round trip a widget makes
/// without a live backend.
class FakeCommunityQAProvider implements CommunityQAProvider {
  FakeCommunityQAProvider({List<CommunityQuestion>? seed})
    : _questions = seed ?? [];

  final List<CommunityQuestion> _questions;
  int _nextId = 1;

  @override
  Future<List<CommunityQuestion>> listQuestions({String? crop}) async {
    if (crop == null || crop.isEmpty) return List.of(_questions);
    return _questions.where((q) => q.crop == crop).toList();
  }

  @override
  Future<CommunityQuestion> getQuestion(String id) async {
    return _questions.firstWhere(
      (q) => q.id == id,
      orElse: () => throw CommunityQAException('not found: $id'),
    );
  }

  @override
  Future<CommunityQuestion> postQuestion({
    required String deviceId,
    String crop = '',
    String symptom = '',
    required String title,
    String body = '',
    required String language,
  }) async {
    final question = CommunityQuestion(
      id: 'q${_nextId++}',
      crop: crop,
      symptom: symptom,
      title: title,
      body: body,
      language: language,
      createdAt: DateTime.now(),
      answers: const [],
    );
    _questions.insert(0, question);
    return question;
  }

  @override
  Future<CommunityAnswer> postAnswer({
    required String questionId,
    required String deviceId,
    required String body,
  }) async {
    final index = _questions.indexWhere((q) => q.id == questionId);
    if (index == -1) {
      throw CommunityQAException('not found: $questionId');
    }
    final answer = CommunityAnswer(
      id: 'a${_nextId++}',
      body: body,
      isAutoSuggested: false,
      createdAt: DateTime.now(),
    );
    final question = _questions[index];
    _questions[index] = CommunityQuestion(
      id: question.id,
      crop: question.crop,
      symptom: question.symptom,
      title: question.title,
      body: question.body,
      language: question.language,
      createdAt: question.createdAt,
      answers: [...question.answers, answer],
    );
    return answer;
  }
}
