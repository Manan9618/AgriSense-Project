/// Result of running the on-device classifier on one crop photo.
class DiagnosisPrediction {
  const DiagnosisPrediction({
    required this.classId,
    required this.confidence,
    this.modelVersion = InferenceModelVersion.current,
  });

  /// Matches a class_id in docs/classes.md, e.g. "tomato_early_blight".
  final String classId;

  /// Softmax probability of [classId], in [0, 1].
  final double confidence;

  /// Which bundled model produced this — recorded per-prediction (not just
  /// globally) so the Week 22 field-vs-lab evaluation and Week 9 sync
  /// payload both know exactly which model version a diagnosis came from,
  /// matching backend/core/models.py's Diagnosis.model_version field.
  final String modelVersion;
}

/// Matches the model bundled at assets/models/agrisense_v1_int8.tflite —
/// see docs/model-card.md. Update this alongside
/// InferenceService.modelAsset whenever the bundled model is retrained.
class InferenceModelVersion {
  static const current = 'v1';
}
