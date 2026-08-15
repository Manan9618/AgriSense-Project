import 'dart:io';

import 'package:agrisense_ai/models/diagnosis_prediction.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/services/sync_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// Genuine end-to-end test, same pattern as
/// price_provider_live_backend_test.dart (Week 7): a real HTTP multipart
/// upload from HttpSyncBackend to an actually-running Django dev server,
/// not a mock. Self-skips if the server isn't reachable, so `flutter test`
/// still passes in CI/on other machines. Run deliberately:
///   cd backend && source .venv/bin/activate && python manage.py runserver 127.0.0.1:8000 &
///   cd mobile && flutter test test/sync_backend_live_backend_test.dart
void main() {
  const baseUrl = 'http://127.0.0.1:8000';

  test('HttpSyncBackend uploads a real scan to a live Django server', () async {
    final serverIsUp = await _isServerReachable(baseUrl);
    if (!serverIsUp) {
      markTestSkipped(
        'No Django dev server reachable at $baseUrl — start one to run this test '
        '(see the doc comment at the top of this file).',
      );
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'agrisense_sync_live_test_',
    );
    final imageFile = File('${tempDir.path}/leaf.png')
      ..writeAsBytesSync(_tinyPng);
    addTearDown(() => tempDir.delete(recursive: true));

    final backend = HttpSyncBackend(baseUrl: baseUrl);
    final scan = ScanRecord(
      id: const Uuid().v4(),
      imagePath: imageFile.path,
      prediction: const DiagnosisPrediction(
        classId: 'tomato_healthy',
        confidence: 0.93,
      ),
      capturedAt: DateTime.now(),
      language: 'en',
    );

    // Throws SyncBackendException on failure — the test itself is the
    // assertion that a real upload succeeds end-to-end.
    await backend.pushScan(scan, deviceId: 'live-test-device');

    // Re-pushing the same id should also succeed (backend's idempotent
    // get_or_create — see backend/core/tests/test_sync_api.py).
    await backend.pushScan(scan, deviceId: 'live-test-device');
  });
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
