import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class TreatmentAdvisory {
  const TreatmentAdvisory({
    required this.title,
    required this.instructions,
    required this.urgency,
  });

  final String title;
  final String instructions;

  /// One of 'low' / 'medium' / 'high' — matches core.constants.Urgency on
  /// the backend.
  final String urgency;
}

/// Loads the bundled treatment-recommendation content and looks up
/// localized advice by class_id + language.
///
/// content/treatment_recommendations.json (repo root) is the single shared
/// source: the Django backend seeds TreatmentRecommendation rows from the
/// same file (Week 5, seed_treatment_recommendations). Bundling a copy here
/// means the app shows real treatment advice with no network call — in
/// keeping with the project's offline-first design, not a corner cut for
/// this week's scope.
class AdvisoryService {
  AdvisoryService._(this._data);

  static const contentAsset = 'assets/content/treatment_recommendations.json';

  final Map<String, dynamic> _data;

  static Future<AdvisoryService> load() async {
    final jsonStr = await rootBundle.loadString(contentAsset);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AdvisoryService._(data);
  }

  /// Returns null only if [classId] isn't in the bundled content at all —
  /// shouldn't happen for any class the on-device model can actually
  /// predict, since the same 10 classes back both. Falls back to English
  /// if [language] isn't one of the file's translations.
  TreatmentAdvisory? forClass(String classId, {required String language}) {
    final entry = _data[classId] as Map<String, dynamic>?;
    if (entry == null) return null;

    final translation =
        (entry[language] ?? entry['en']) as Map<String, dynamic>?;
    if (translation == null) return null;

    return TreatmentAdvisory(
      title: translation['title'] as String,
      instructions: translation['instructions'] as String,
      urgency: entry['urgency'] as String,
    );
  }
}
