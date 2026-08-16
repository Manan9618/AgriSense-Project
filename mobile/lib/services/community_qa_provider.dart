import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/community_question.dart';

/// Abstraction over the Community Q&A backend (Week 14) — same
/// interface-plus-real-implementation pattern as PriceProvider (ADR 0006)
/// and SyncBackend: [HttpCommunityQAProvider] is the real implementation
/// (backend/core/views.py's QuestionListCreateView/QuestionDetailView/
/// AnswerCreateView), tests inject a fake.
abstract class CommunityQAProvider {
  Future<List<CommunityQuestion>> listQuestions({String? crop});

  Future<CommunityQuestion> getQuestion(String id);

  Future<CommunityQuestion> postQuestion({
    required String deviceId,
    String crop = '',
    String symptom = '',
    required String title,
    String body = '',
    required String language,
  });

  Future<CommunityAnswer> postAnswer({
    required String questionId,
    required String deviceId,
    required String body,
  });
}

class CommunityQAException implements Exception {
  CommunityQAException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HttpCommunityQAProvider implements CommunityQAProvider {
  HttpCommunityQAProvider({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<List<CommunityQuestion>> listQuestions({String? crop}) async {
    final uri = Uri.parse('$baseUrl/api/community/questions/').replace(
      queryParameters: crop == null || crop.isEmpty ? null : {'crop': crop},
    );
    final response = await _get(uri);
    return (jsonDecode(response.body) as List)
        .map((q) => CommunityQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CommunityQuestion> getQuestion(String id) async {
    final uri = Uri.parse('$baseUrl/api/community/questions/$id/');
    final response = await _get(uri);
    return CommunityQuestion.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
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
    final uri = Uri.parse('$baseUrl/api/community/questions/');
    final response = await _post(uri, {
      'device_id': deviceId,
      'crop': crop,
      'symptom': symptom,
      'title': title,
      'body': body,
      'language': language,
    });
    return CommunityQuestion.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  @override
  Future<CommunityAnswer> postAnswer({
    required String questionId,
    required String deviceId,
    required String body,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/community/questions/$questionId/answers/',
    );
    final response = await _post(uri, {'device_id': deviceId, 'body': body});
    return CommunityAnswer.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<http.Response> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw CommunityQAException('Could not reach the community service: $e');
    }
    if (response.statusCode != 200) {
      throw CommunityQAException(
        'Community service returned ${response.statusCode}: ${response.body}',
      );
    }
    return response;
  }

  Future<http.Response> _post(Uri uri, Map<String, String> fields) async {
    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(fields),
      );
    } catch (e) {
      throw CommunityQAException('Could not reach the community service: $e');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CommunityQAException(
        'Community service returned ${response.statusCode}: ${response.body}',
      );
    }
    return response;
  }
}
