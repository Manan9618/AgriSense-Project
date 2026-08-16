import 'package:uuid/uuid.dart';

import '../models/feedback_record.dart';
import 'local_database.dart';

/// Turns a farmer's feedback answers into a durable FeedbackRecord — same
/// centralizing role as ScanRepository plays for scans (Week 9), tested
/// with a real SQLite database rather than a fake.
class FeedbackRepository {
  FeedbackRepository({required this.database});

  final LocalDatabase database;

  Future<FeedbackRecord> submitFeedback({
    required String scanId,
    required String diagnosisAccuracy,
    String treatmentOutcome = '',
    String notes = '',
  }) async {
    final feedback = FeedbackRecord(
      id: const Uuid().v4(),
      scanId: scanId,
      diagnosisAccuracy: diagnosisAccuracy,
      treatmentOutcome: treatmentOutcome,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await database.insertFeedback(feedback);
    return feedback;
  }

  Future<bool> hasFeedback(String scanId) =>
      database.hasFeedbackForScan(scanId);
}
