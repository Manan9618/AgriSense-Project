import 'services/advisory_service.dart';
import 'services/feedback_repository.dart';
import 'services/inference_service.dart';
import 'services/local_database.dart';
import 'services/offline_sync_manager.dart';
import 'services/photo_capture_source.dart';
import 'services/price_provider.dart';
import 'services/scan_repository.dart';
import 'services/tts_service.dart';
import 'services/voice_command_source.dart';

/// Everything HomeScreen (the app's hub screen) needs, bundled into one
/// object instead of threaded through as individually growing constructor
/// parameters — by Week 9 that list had reached 8 and was still growing.
class AppServices {
  const AppServices({
    required this.inferenceService,
    required this.advisoryService,
    required this.photoCaptureSource,
    required this.priceProvider,
    required this.ttsService,
    required this.voiceCommandSource,
    required this.localDatabase,
    required this.scanRepository,
    required this.syncManager,
    required this.feedbackRepository,
  });

  final InferenceService inferenceService;
  final AdvisoryService advisoryService;
  final PhotoCaptureSource photoCaptureSource;
  final PriceProvider priceProvider;
  final TtsService ttsService;
  final VoiceCommandSource voiceCommandSource;

  /// Exposed alongside [scanRepository]/[syncManager] (which both wrap it
  /// internally) because the UI also needs it directly — refreshing
  /// ScanHistoryProvider after a sync run reads straight from the DB rather
  /// than duplicating "what changed" bookkeeping.
  final LocalDatabase localDatabase;

  final ScanRepository scanRepository;
  final OfflineSyncManager syncManager;

  /// Week 12: FeedbackCollector's local-write side (docs/classes.md).
  final FeedbackRepository feedbackRepository;
}
