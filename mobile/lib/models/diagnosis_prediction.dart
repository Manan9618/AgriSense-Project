/// Result of running the on-device classifier on one crop photo.
class DiagnosisPrediction {
  const DiagnosisPrediction({required this.classId, required this.confidence});

  /// Matches a class_id in docs/classes.md, e.g. "tomato_early_blight".
  final String classId;

  /// Softmax probability of [classId], in [0, 1].
  final double confidence;
}
