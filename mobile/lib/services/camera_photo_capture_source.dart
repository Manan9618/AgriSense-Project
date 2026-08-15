import 'package:flutter/material.dart';

import '../screens/camera_capture_screen.dart';
import 'photo_capture_source.dart';

/// Real [PhotoCaptureSource]: pushes the live camera screen and awaits the
/// captured file path (or null if the farmer backs out).
class CameraPhotoCaptureSource implements PhotoCaptureSource {
  const CameraPhotoCaptureSource();

  @override
  Future<String?> capturePhoto(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
  }
}
