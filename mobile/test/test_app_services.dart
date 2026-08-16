import 'dart:io';

import 'package:agrisense_ai/app_services.dart';
import 'package:agrisense_ai/models/community_question.dart';
import 'package:agrisense_ai/models/feedback_record.dart';
import 'package:agrisense_ai/models/mandi_price.dart';
import 'package:agrisense_ai/models/scan_record.dart';
import 'package:agrisense_ai/services/advisory_service.dart';
import 'package:agrisense_ai/services/community_qa_provider.dart';
import 'package:agrisense_ai/services/feedback_repository.dart';
import 'package:agrisense_ai/services/inference_service.dart';
import 'package:agrisense_ai/services/local_database.dart';
import 'package:agrisense_ai/services/offline_sync_manager.dart';
import 'package:agrisense_ai/services/photo_capture_source.dart';
import 'package:agrisense_ai/services/price_provider.dart';
import 'package:agrisense_ai/services/scan_repository.dart';
import 'package:agrisense_ai/services/sync_backend.dart';
import 'package:agrisense_ai/services/tts_service.dart';
import 'package:agrisense_ai/services/voice_command_source.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a real AppServices for widget tests: real InferenceService (FFI
/// TFLite), real AdvisoryService, real LocalDatabase (FFI SQLite, in a temp
/// directory so it's genuinely persisted, not in-memory-only) and real
/// ScanRepository/OfflineSyncManager wired to it. Only the hardware/network
/// boundaries (camera, price API, voice) are swapped for fakes — same
/// "real except the untestable edge" bar as every other service in this
/// app. Callers must delete [tempDir] in tearDown.
class TestAppServicesResult {
  const TestAppServicesResult(this.services, this.tempDir);
  final AppServices services;
  final Directory tempDir;
}

Future<TestAppServicesResult> buildTestAppServices({
  PhotoCaptureSource photoCaptureSource = const _NullPhotoCaptureSource(),
  PriceProvider? priceProvider,
  VoiceCommandSource? voiceCommandSource,
  SyncBackend? syncBackend,
  CommunityQAProvider? communityQAProvider,
}) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final tempDir = await Directory.systemTemp.createTemp(
    'agrisense_widget_test_',
  );
  final database = await LocalDatabase.open(inMemoryDatabasePath);
  final scanRepository = ScanRepository(
    database: database,
    storageDirectory: tempDir,
  );
  final backend = syncBackend ?? _NullSyncBackend();
  final syncManager = OfflineSyncManager(database: database, backend: backend);
  final feedbackRepository = FeedbackRepository(database: database);
  final deviceId = await database.getOrCreateDeviceId();

  final inferenceService = await InferenceService.load();
  final advisoryService = await AdvisoryService.load();

  final services = AppServices(
    inferenceService: inferenceService,
    advisoryService: advisoryService,
    photoCaptureSource: photoCaptureSource,
    priceProvider: priceProvider ?? _NullPriceProvider(),
    ttsService: TtsService(),
    voiceCommandSource: voiceCommandSource ?? const _NullVoiceCommandSource(),
    localDatabase: database,
    scanRepository: scanRepository,
    syncManager: syncManager,
    feedbackRepository: feedbackRepository,
    communityQAProvider: communityQAProvider ?? const _NullCommunityQAProvider(),
    deviceId: deviceId,
  );

  return TestAppServicesResult(services, tempDir);
}

class _NullPhotoCaptureSource implements PhotoCaptureSource {
  const _NullPhotoCaptureSource();
  @override
  Future<String?> capturePhoto(BuildContext context) async => null;
}

class _NullVoiceCommandSource implements VoiceCommandSource {
  const _NullVoiceCommandSource();
  @override
  Future<String?> listen({required String localeId}) async => null;
}

class _NullPriceProvider implements PriceProvider {
  @override
  Future<PriceComparisonResult> comparePrices({
    required String commodity,
    required String state,
    String? district,
  }) async => const PriceComparisonResult(isSampleData: true, prices: []);
}

class _NullSyncBackend implements SyncBackend {
  @override
  Future<void> pushScan(ScanRecord scan, {required String deviceId}) async {}

  @override
  Future<void> pushFeedback(FeedbackRecord feedback) async {}
}

class _NullCommunityQAProvider implements CommunityQAProvider {
  const _NullCommunityQAProvider();

  @override
  Future<List<CommunityQuestion>> listQuestions({String? crop}) async => [];

  @override
  Future<CommunityQuestion> getQuestion(String id) {
    throw CommunityQAException('not implemented in tests');
  }

  @override
  Future<CommunityQuestion> postQuestion({
    required String deviceId,
    String crop = '',
    String symptom = '',
    required String title,
    String body = '',
    required String language,
  }) {
    throw CommunityQAException('not implemented in tests');
  }

  @override
  Future<CommunityAnswer> postAnswer({
    required String questionId,
    required String deviceId,
    required String body,
  }) {
    throw CommunityQAException('not implemented in tests');
  }
}
