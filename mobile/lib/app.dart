import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/camera_photo_capture_source.dart';
import 'services/inference_service.dart';
import 'services/photo_capture_source.dart';
import 'state/language_provider.dart';
import 'state/scan_history_provider.dart';
import 'theme/app_theme.dart';

/// Root widget. [photoCaptureSource] defaults to the real camera but is
/// overridable so widget tests can inject a fake instead of driving actual
/// camera hardware.
class AgriSenseApp extends StatelessWidget {
  const AgriSenseApp({
    super.key,
    this.photoCaptureSource = const CameraPhotoCaptureSource(),
  });

  final PhotoCaptureSource photoCaptureSource;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ScanHistoryProvider()),
      ],
      child: MaterialApp(
        title: 'AgriSense AI',
        theme: AppTheme.light,
        home: _AppRoot(photoCaptureSource: photoCaptureSource),
      ),
    );
  }
}

/// Loads the on-device model once at startup, then hands off to HomeScreen.
class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.photoCaptureSource});

  final PhotoCaptureSource photoCaptureSource;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final Future<InferenceService> _serviceFuture;

  @override
  void initState() {
    super.initState();
    _serviceFuture = InferenceService.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InferenceService>(
      future: _serviceFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Failed to load model: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeScreen(
          inferenceService: snapshot.data!,
          photoCaptureSource: widget.photoCaptureSource,
        );
      },
    );
  }
}
