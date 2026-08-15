import '../core/disease_classes.dart';
import 'diagnosis_prediction.dart';

/// A completed scan: the photo taken plus the on-device diagnosis.
///
/// SQLite-backed (Week 9, ScanRepository/LocalDatabase) so history survives
/// app restarts and can be synced to the backend's Scan/Diagnosis models
/// (backend/core/models.py) once online — [id] is the same client-generated
/// UUID design those models anticipated back in Week 1, letting a synced
/// scan use the identical primary key on both sides.
class ScanRecord {
  ScanRecord({
    required this.id,
    required this.imagePath,
    required this.prediction,
    required this.capturedAt,
    this.language = 'en',
    this.syncedAt,
  });

  final String id;
  final String imagePath;
  final DiagnosisPrediction prediction;
  final DateTime capturedAt;

  /// The farmer's selected UI language at capture time (see
  /// backend/core/models.py's Scan.language) — recorded per-scan since a
  /// farmer's language preference could change between scans.
  final String language;

  final DateTime? syncedAt;

  bool get isSynced => syncedAt != null;

  ScanRecord copyWith({DateTime? syncedAt}) {
    return ScanRecord(
      id: id,
      imagePath: imagePath,
      prediction: prediction,
      capturedAt: capturedAt,
      language: language,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  DiseaseClassInfo get classInfo =>
      diseaseClasses[prediction.classId] ??
      const DiseaseClassInfo(
        crop: 'Unknown',
        condition: 'Unknown',
        isHealthy: false,
      );

  String get cropLabel => classInfo.crop;
  String get conditionLabel => classInfo.condition;
  bool get isHealthy => classInfo.isHealthy;
}
