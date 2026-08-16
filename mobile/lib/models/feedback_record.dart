/// A farmer-confirmed outcome for one scan's diagnosis (Week 12,
/// FeedbackCollector — docs/classes.md: "farmer-confirmed outcome -> feeds
/// retraining pipeline"). Mirrors ScanRecord's offline-first shape: a
/// client-generated [id], stored locally first, synced to the backend's
/// Feedback model (backend/core/models.py) once online.
///
/// References [scanId] rather than a server-side diagnosis id, since the
/// app only ever learns the client-generated Scan id back from a sync —
/// see FeedbackSyncSerializer's docstring on the backend for why.
class FeedbackRecord {
  FeedbackRecord({
    required this.id,
    required this.scanId,
    required this.diagnosisAccuracy,
    this.treatmentOutcome = '',
    this.notes = '',
    required this.createdAt,
    this.syncedAt,
  });

  final String id;
  final String scanId;

  /// One of [DiagnosisAccuracy]'s values — matches
  /// backend Feedback.DiagnosisAccuracy choices.
  final String diagnosisAccuracy;

  /// One of [TreatmentOutcome]'s values, or '' if not applicable (matches
  /// backend Feedback.TreatmentOutcome choices).
  final String treatmentOutcome;

  final String notes;
  final DateTime createdAt;
  final DateTime? syncedAt;

  bool get isSynced => syncedAt != null;

  FeedbackRecord copyWith({DateTime? syncedAt}) {
    return FeedbackRecord(
      id: id,
      scanId: scanId,
      diagnosisAccuracy: diagnosisAccuracy,
      treatmentOutcome: treatmentOutcome,
      notes: notes,
      createdAt: createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}

/// String constants matching backend Feedback.DiagnosisAccuracy choices —
/// plain strings (not an enum) to mirror how ScanRecord.prediction.classId
/// and Advisory.urgency are already handled in this codebase.
class DiagnosisAccuracy {
  static const correct = 'correct';
  static const incorrect = 'incorrect';
  static const unsure = 'unsure';
}

/// String constants matching backend Feedback.TreatmentOutcome choices.
class TreatmentOutcome {
  static const helped = 'helped';
  static const noChange = 'no_change';
  static const worsened = 'worsened';
  static const notApplicable = 'not_applicable';
}
