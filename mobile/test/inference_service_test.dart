@Tags(['tflite'])
library;

// Tagged 'tflite': dlopens tflite_flutter's real native library, which
// `flutter test` alone doesn't populate on Linux (only a full
// `flutter build linux`/`flutter run -d linux` does — found running this
// in CI, see docs/adr/0017-dockerization-and-cicd.md and
// mobile/README.md). CI excludes this tag; run locally with the macOS
// setup script (mobile/scripts/setup_macos_test_lib.sh) or on a machine
// with a full Linux/Windows desktop build.

import 'dart:io';

import 'package:agrisense_ai/services/inference_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Fixtures are named `sample_<i>_<class_id>.jpg` (see mobile/test/fixtures/),
/// real held-out test-split images copied from ml/data/manifest.csv.
String _classIdFromFilename(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final withoutExt = name.substring(0, name.length - '.jpg'.length);
  return withoutExt.split('_').sublist(2).join('_');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'classifies real leaf photos using the bundled on-device model',
    () async {
      final service = await InferenceService.load();
      addTearDown(service.close);

      final fixtures = Directory('test/fixtures')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList();
      expect(fixtures, isNotEmpty);

      var correct = 0;
      for (final file in fixtures) {
        final expectedClass = _classIdFromFilename(file.path);
        final image = img.decodeImage(file.readAsBytesSync());
        expect(image, isNotNull, reason: 'failed to decode ${file.path}');

        final prediction = service.classify(image!);
        expect(service.classNames, contains(prediction.classId));
        expect(prediction.confidence, inInclusiveRange(0.0, 1.0));
        if (prediction.classId == expectedClass) correct++;
      }

      // Matches the ~95% test accuracy from ml/scripts/evaluate_tflite.py;
      // small fixture sample here, so allow at most one miss.
      expect(correct, greaterThanOrEqualTo(fixtures.length - 1));
    },
  );
}
