import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/advisory_service.dart';
import 'services/camera_photo_capture_source.dart';
import 'services/inference_service.dart';
import 'services/photo_capture_source.dart';
import 'services/price_provider.dart';
import 'state/language_provider.dart';
import 'state/scan_history_provider.dart';
import 'theme/app_theme.dart';

/// No backend is deployed yet (that's Week 18) — 10.0.2.2 is the standard
/// Android-emulator alias for the host machine's localhost, useful for
/// local dev against `manage.py runserver`. Real builds need a real
/// backend URL supplied here once one exists.
const _devBackendBaseUrl = 'http://10.0.2.2:8000';

/// Root widget. [photoCaptureSource] and [priceProvider] default to the
/// real implementations but are overridable so widget tests can inject
/// fakes instead of driving actual camera hardware / network calls.
class AgriSenseApp extends StatelessWidget {
  AgriSenseApp({
    super.key,
    this.photoCaptureSource = const CameraPhotoCaptureSource(),
    PriceProvider? priceProvider,
  }) : priceProvider =
           priceProvider ?? HttpPriceProvider(baseUrl: _devBackendBaseUrl);

  final PhotoCaptureSource photoCaptureSource;
  final PriceProvider priceProvider;

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
        home: _AppRoot(
          photoCaptureSource: photoCaptureSource,
          priceProvider: priceProvider,
        ),
      ),
    );
  }
}

/// Bundle of everything loaded once at startup before HomeScreen can render.
class _StartupServices {
  const _StartupServices(this.inferenceService, this.advisoryService);

  final InferenceService inferenceService;
  final AdvisoryService advisoryService;
}

/// Loads the on-device model + bundled advisory content once at startup,
/// then hands off to HomeScreen.
class _AppRoot extends StatefulWidget {
  const _AppRoot({
    required this.photoCaptureSource,
    required this.priceProvider,
  });

  final PhotoCaptureSource photoCaptureSource;
  final PriceProvider priceProvider;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final Future<_StartupServices> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _load();
  }

  static Future<_StartupServices> _load() async {
    final inferenceService = await InferenceService.load();
    final advisoryService = await AdvisoryService.load();
    return _StartupServices(inferenceService, advisoryService);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupServices>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Failed to start app: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeScreen(
          inferenceService: snapshot.data!.inferenceService,
          advisoryService: snapshot.data!.advisoryService,
          photoCaptureSource: widget.photoCaptureSource,
          priceProvider: widget.priceProvider,
        );
      },
    );
  }
}
