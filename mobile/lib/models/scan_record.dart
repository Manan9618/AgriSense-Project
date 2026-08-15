import '../core/disease_classes.dart';
import 'diagnosis_prediction.dart';

/// A completed scan: the photo taken plus the on-device diagnosis.
///
/// In-memory only for now (Week 4) — Week 9 (Offline-First Sync) adds a
/// SQLite-backed store so history survives app restarts and syncs to the
/// backend's Scan/Diagnosis models (see backend/core/models.py) once online.
class ScanRecord {
  ScanRecord({
    required this.imagePath,
    required this.prediction,
    required this.capturedAt,
  });

  final String imagePath;
  final DiagnosisPrediction prediction;
  final DateTime capturedAt;

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
