import 'dart:convert';

import 'package:agrisense_ai/services/advisory_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _loadClassNames() async {
  final json = await rootBundle.loadString('assets/models/class_names.json');
  return (jsonDecode(json) as List).cast<String>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'covers every class the model can predict, in all 3 languages',
    () async {
      final advisoryService = await AdvisoryService.load();
      final classNames = await _loadClassNames();

      for (final classId in classNames) {
        for (final language in ['en', 'hi', 'gu']) {
          final advisory = advisoryService.forClass(
            classId,
            language: language,
          );
          expect(advisory, isNotNull, reason: '$classId ($language)');
          expect(advisory!.title, isNotEmpty);
          expect(advisory.instructions, isNotEmpty);
          expect(['low', 'medium', 'high'], contains(advisory.urgency));
        }
      }
    },
  );

  test('late blight classes are high urgency', () async {
    final advisoryService = await AdvisoryService.load();

    for (final classId in ['tomato_late_blight', 'potato_late_blight']) {
      final advisory = advisoryService.forClass(classId, language: 'en');
      expect(advisory!.urgency, 'high');
    }
  });

  test('healthy classes are low urgency', () async {
    final advisoryService = await AdvisoryService.load();

    for (final classId in [
      'tomato_healthy',
      'potato_healthy',
      'pepper_bell_healthy',
    ]) {
      final advisory = advisoryService.forClass(classId, language: 'en');
      expect(advisory!.urgency, 'low');
    }
  });

  test('falls back to English for an unsupported language', () async {
    final advisoryService = await AdvisoryService.load();

    final requested = advisoryService.forClass(
      'tomato_healthy',
      language: 'fr',
    );
    final english = advisoryService.forClass('tomato_healthy', language: 'en');

    expect(requested!.title, english!.title);
  });

  test('returns null for a class not in the bundled content', () async {
    final advisoryService = await AdvisoryService.load();

    expect(
      advisoryService.forClass('not_a_real_class', language: 'en'),
      isNull,
    );
  });
}
