import 'dart:io';

import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/models/feedback_record.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/services/sync_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// Genuine end-to-end test, same self-skipping pattern as
/// sync_backend_live_backend_test.dart (Week 9): pushes a real scan, then a
/// real feedback entry for it, to an actually-running Django dev server.
/// Feedback has to follow a synced scan — see FeedbackSyncView's docstring
/// on the backend — so this test proves that dependency for real rather
/// than mocking around it. Run deliberately:
///   cd backend && source .venv/bin/activate && python manage.py runserver 127.0.0.1:8000 &
///   cd mobile && flutter test test/feedback_sync_backend_live_backend_test.dart
void main() {
  const baseUrl = 'http://127.0.0.1:8000';

  test(
    'HttpSyncBackend uploads real feedback for an already-synced scan',
    () async {
      final serverIsUp = await _isServerReachable(baseUrl);
      if (!serverIsUp) {
        markTestSkipped(
          'No Django dev server reachable at $baseUrl — start one to run this test '
          '(see the doc comment at the top of this file).',
        );
        return;
      }

      final tempDir = await Directory.systemTemp.createTemp(
        'agrisense_feedback_live_test_',
      );
      final imageFile = File('${tempDir.path}/leaf.png')
        ..writeAsBytesSync(_tinyPng);
      addTearDown(() => tempDir.delete(recursive: true));

      final backend = HttpSyncBackend(baseUrl: baseUrl);
      final scan = ScanRecord(
        id: const Uuid().v4(),
        imagePath: imageFile.path,
        prediction: const DiagnosisPrediction(
          classId: 'tomato_late_blight',
          confidence: 0.88,
        ),
        capturedAt: DateTime.now(),
        language: 'en',
      );
      await backend.pushScan(scan, deviceId: 'live-test-device');

      final feedback = FeedbackRecord(
        id: const Uuid().v4(),
        scanId: scan.id,
        diagnosisAccuracy: DiagnosisAccuracy.correct,
        treatmentOutcome: TreatmentOutcome.helped,
        notes: 'Live end-to-end test entry.',
        createdAt: DateTime.now(),
      );

      // Throws SyncBackendException on failure — the test itself is the
      // assertion that a real upload succeeds end-to-end.
      await backend.pushFeedback(feedback);

      // Re-pushing the same id should also succeed (idempotent get_or_create,
      // see backend/core/tests/test_feedback_api.py).
      await backend.pushFeedback(feedback);
    },
  );

  test(
    'feedback for a scan the backend has never seen is rejected',
    () async {
      final serverIsUp = await _isServerReachable(baseUrl);
      if (!serverIsUp) {
        markTestSkipped(
          'No Django dev server reachable at $baseUrl — start one to run this test '
          '(see the doc comment at the top of this file).',
        );
        return;
      }

      final backend = HttpSyncBackend(baseUrl: baseUrl);
      final feedback = FeedbackRecord(
        id: const Uuid().v4(),
        scanId: const Uuid().v4(), // never synced
        diagnosisAccuracy: DiagnosisAccuracy.correct,
        createdAt: DateTime.now(),
      );

      await expectLater(
        backend.pushFeedback(feedback),
        throwsA(isA<SyncBackendException>()),
      );
    },
  );
}

// 1x1 transparent PNG.
final _tinyPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

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
