/// One reply to a CommunityQuestion. Mirrors
/// backend/core/serializers.py's AnswerSerializer field-for-field.
class CommunityAnswer {
  const CommunityAnswer({
    required this.id,
    required this.body,
    required this.isAutoSuggested,
    required this.createdAt,
  });

  final String id;
  final String body;

  /// True when CommunityQARouter (backend/core/community_qa_router.py)
  /// generated this from existing TreatmentRecommendation content rather
  /// than a farmer/coordinator typing a reply — the UI should badge these
  /// differently so a farmer knows it's an automated suggestion, not a
  /// human's answer.
  final bool isAutoSuggested;

  final DateTime createdAt;

  factory CommunityAnswer.fromJson(Map<String, dynamic> json) {
    return CommunityAnswer(
      id: json['id'] as String,
      body: json['body'] as String,
      isAutoSuggested: json['is_auto_suggested'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// A community question (Week 14, CommunityQARouter). Mirrors
/// backend/core/serializers.py's QuestionSerializer/QuestionDetailSerializer.
/// `crop`/`symptom` use the same fixed vocabulary as the SMS/voice fallback
/// (Week 10) — see backend/core/fallback_diagnosis.py — not free text.
class CommunityQuestion {
  const CommunityQuestion({
    required this.id,
    required this.crop,
    required this.symptom,
    required this.title,
    required this.body,
    required this.language,
    required this.createdAt,
    this.answers = const [],
  });

  final String id;
  final String crop;
  final String symptom;
  final String title;
  final String body;
  final String language;
  final DateTime createdAt;
  final List<CommunityAnswer> answers;

  factory CommunityQuestion.fromJson(Map<String, dynamic> json) {
    return CommunityQuestion(
      id: json['id'] as String,
      crop: json['crop'] as String? ?? '',
      symptom: json['symptom'] as String? ?? '',
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      language: json['language'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      answers: json['answers'] == null
          ? const []
          : (json['answers'] as List)
                .map((a) => CommunityAnswer.fromJson(a as Map<String, dynamic>))
                .toList(),
    );
  }
}
