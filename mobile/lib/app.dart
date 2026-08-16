import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app_services.dart';
import 'screens/home_screen.dart';
import 'services/advisory_service.dart';
import 'services/camera_photo_capture_source.dart';
import 'services/community_qa_provider.dart';
import 'services/feedback_repository.dart';
import 'services/inference_service.dart';
import 'services/local_database.dart';
import 'services/offline_sync_manager.dart';
import 'services/photo_capture_source.dart';
import 'services/price_provider.dart';
import 'services/scan_repository.dart';
import 'services/speech_to_text_voice_command_source.dart';
import 'services/sync_backend.dart';
import 'services/tts_service.dart';
import 'services/voice_command_source.dart';
import 'state/language_provider.dart';
import 'state/scan_history_provider.dart';
import 'theme/app_theme.dart';

/// No backend is deployed yet (that's Week 18) — 10.0.2.2 is the standard
/// Android-emulator alias for the host machine's localhost, useful for
/// local dev against `manage.py runserver`. Real builds need a real
/// backend URL supplied here once one exists.
const _devBackendBaseUrl = 'http://10.0.2.2:8000';

/// Root widget. Everything is overridable so widget tests can inject fakes
/// instead of driving actual hardware/network calls; [database] and
/// [syncBackend] default to null and are created for real inside
/// [_AppRootState._load] since opening the real database is itself async.
class AgriSenseApp extends StatelessWidget {
  AgriSenseApp({
    super.key,
    this.photoCaptureSource = const CameraPhotoCaptureSource(),
    PriceProvider? priceProvider,
    TtsService? ttsService,
    VoiceCommandSource? voiceCommandSource,
    CommunityQAProvider? communityQAProvider,
    this.database,
    this.syncBackend,
  }) : priceProvider =
           priceProvider ?? HttpPriceProvider(baseUrl: _devBackendBaseUrl),
       ttsService = ttsService ?? TtsService(),
       voiceCommandSource =
           voiceCommandSource ?? SpeechToTextVoiceCommandSource(),
       communityQAProvider =
           communityQAProvider ??
           HttpCommunityQAProvider(baseUrl: _devBackendBaseUrl);

  final PhotoCaptureSource photoCaptureSource;
  final PriceProvider priceProvider;
  final TtsService ttsService;
  final VoiceCommandSource voiceCommandSource;
  final CommunityQAProvider communityQAProvider;
  final LocalDatabase? database;
  final SyncBackend? syncBackend;

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
          ttsService: ttsService,
          voiceCommandSource: voiceCommandSource,
          communityQAProvider: communityQAProvider,
          database: database,
          syncBackend: syncBackend,
        ),
      ),
    );
  }
}

Future<LocalDatabase> _openDefaultDatabase() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  return LocalDatabase.open(p.join(documentsDir.path, 'agrisense.db'));
}

/// Loads the on-device model, bundled advisory content, and local database
/// once at startup — including replaying the DB's scan history into
/// [ScanHistoryProvider] — then hands off to HomeScreen.
class _AppRoot extends StatefulWidget {
  const _AppRoot({
    required this.photoCaptureSource,
    required this.priceProvider,
    required this.ttsService,
    required this.voiceCommandSource,
    required this.communityQAProvider,
    required this.database,
    required this.syncBackend,
  });

  final PhotoCaptureSource photoCaptureSource;
  final PriceProvider priceProvider;
  final TtsService ttsService;
  final VoiceCommandSource voiceCommandSource;
  final CommunityQAProvider communityQAProvider;
  final LocalDatabase? database;
  final SyncBackend? syncBackend;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late final Future<AppServices> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _load();
  }

  Future<AppServices> _load() async {
    final inferenceService = await InferenceService.load();
    final advisoryService = await AdvisoryService.load();

    final database = widget.database ?? await _openDefaultDatabase();
    final documentsDir = await getApplicationDocumentsDirectory();
    final scanRepository = ScanRepository(
      database: database,
      storageDirectory: documentsDir,
    );
    final syncBackend =
        widget.syncBackend ?? HttpSyncBackend(baseUrl: _devBackendBaseUrl);
    final syncManager = OfflineSyncManager(
      database: database,
      backend: syncBackend,
    );
    final feedbackRepository = FeedbackRepository(database: database);
    final deviceId = await database.getOrCreateDeviceId();

    if (mounted) {
      await context.read<ScanHistoryProvider>().loadFromDatabase(database);
    }

    return AppServices(
      inferenceService: inferenceService,
      advisoryService: advisoryService,
      photoCaptureSource: widget.photoCaptureSource,
      priceProvider: widget.priceProvider,
      ttsService: widget.ttsService,
      voiceCommandSource: widget.voiceCommandSource,
      localDatabase: database,
      scanRepository: scanRepository,
      syncManager: syncManager,
      feedbackRepository: feedbackRepository,
      communityQAProvider: widget.communityQAProvider,
      deviceId: deviceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppServices>(
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
        return HomeScreen(services: snapshot.data!);
      },
    );
  }
}
