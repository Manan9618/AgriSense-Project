import 'package:agrisense_ai/services/photo_capture_source.dart';
import 'package:flutter/widgets.dart';

/// Test double: "captures" a fixture image immediately, no camera hardware
/// involved. Used to exercise the full HomeScreen -> classify ->
/// DiagnosisResultScreen flow in widget tests.
class FakePhotoCaptureSource implements PhotoCaptureSource {
  const FakePhotoCaptureSource(this.imagePath);

  final String imagePath;

  @override
  Future<String?> capturePhoto(BuildContext context) async => imagePath;
}
