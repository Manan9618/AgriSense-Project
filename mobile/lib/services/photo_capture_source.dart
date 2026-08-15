import 'package:flutter/widgets.dart';

/// Abstraction over "get a crop photo from the farmer" so the capture flow
/// (HomeScreen -> classify -> DiagnosisResultScreen) can be tested without a
/// physical camera. [CameraPhotoCaptureSource] (camera_photo_capture_source.dart)
/// is the real implementation used by the shipped app; tests inject a fake
/// that returns a fixture image path directly.
abstract class PhotoCaptureSource {
  /// Returns the file path of a captured photo, or null if the farmer
  /// cancelled (e.g. backed out of the camera screen).
  Future<String?> capturePhoto(BuildContext context);
}
