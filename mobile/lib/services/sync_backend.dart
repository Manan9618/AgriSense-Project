import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/feedback_record.dart';
import '../models/scan_record.dart';

/// Abstraction over "upload one offline-captured scan or feedback entry" —
/// same interface-plus-real-implementation pattern as PriceProvider (ADR
/// 0006): [HttpSyncBackend] is the real implementation (calls the Django
/// backend's POST /api/sync/scans/ and POST /api/sync/feedback/ —
/// backend/core/views.py's ScanSyncView and FeedbackSyncView), tests inject
/// a fake.
abstract class SyncBackend {
  Future<void> pushScan(ScanRecord scan, {required String deviceId});

  /// Week 12: uploads one FeedbackCollector entry. The backend resolves
  /// which Diagnosis this belongs to from [FeedbackRecord.scanId] itself,
  /// so no device id is needed here — see FeedbackSyncSerializer's
  /// docstring on the backend for why.
  Future<void> pushFeedback(FeedbackRecord feedback);
}

class SyncBackendException implements Exception {
  SyncBackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

class HttpSyncBackend implements SyncBackend {
  HttpSyncBackend({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<void> pushScan(ScanRecord scan, {required String deviceId}) async {
    final uri = Uri.parse('$baseUrl/api/sync/scans/');
    final request = http.MultipartRequest('POST', uri)
      ..fields['device_id'] = deviceId
      ..fields['id'] = scan.id
      ..fields['predicted_class'] = scan.prediction.classId
      ..fields['confidence'] = scan.prediction.confidence.toString()
      ..fields['model_version'] = scan.prediction.modelVersion
      ..fields['captured_at'] = scan.capturedAt.toUtc().toIso8601String()
      ..fields['language'] = scan.language;

    try {
      request.files.add(
        await http.MultipartFile.fromPath('image', scan.imagePath),
      );
    } on FileSystemException catch (e) {
      throw SyncBackendException(
        'Could not read scan image at ${scan.imagePath}: $e',
      );
    }

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request);
    } catch (e) {
      throw SyncBackendException('Could not reach the sync service: $e');
    }
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SyncBackendException(
        'Sync failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  @override
  Future<void> pushFeedback(FeedbackRecord feedback) async {
    final uri = Uri.parse('$baseUrl/api/sync/feedback/');
    final body = jsonEncode({
      'id': feedback.id,
      'scan_id': feedback.scanId,
      'diagnosis_accuracy': feedback.diagnosisAccuracy,
      'treatment_outcome': feedback.treatmentOutcome,
      'notes': feedback.notes,
    });

    final http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (e) {
      throw SyncBackendException('Could not reach the sync service: $e');
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw SyncBackendException(
        'Feedback sync failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
