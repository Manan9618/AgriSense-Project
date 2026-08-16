import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/feedback_record.dart';
import '../services/feedback_repository.dart';
import '../state/language_provider.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for FeedbackCollector's UI (Week 12, docs/classes.md):
/// "Was this diagnosis correct?" / "Did the treatment help?" — the two
/// questions a farmer can only really answer some time after the scan,
/// which is why this is reachable from a past scan's result screen rather
/// than only right after capture.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({
    super.key,
    required this.scanId,
    required this.showTreatmentQuestion,
    required this.feedbackRepository,
  });

  final String scanId;

  /// False for a "healthy" diagnosis — there's no treatment to ask about.
  final bool showTreatmentQuestion;

  final FeedbackRepository feedbackRepository;

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  String? _accuracy;
  String _outcome = '';
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_accuracy == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    await widget.feedbackRepository.submitFeedback(
      scanId: widget.scanId,
      diagnosisAccuracy: _accuracy!,
      treatmentOutcome: _outcome,
      notes: _notesController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings['feedbackDiagnosisQuestion'],
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(strings['feedbackAccuracyCorrect']),
                  selected: _accuracy == DiagnosisAccuracy.correct,
                  onSelected: (_) =>
                      setState(() => _accuracy = DiagnosisAccuracy.correct),
                ),
                ChoiceChip(
                  label: Text(strings['feedbackAccuracyIncorrect']),
                  selected: _accuracy == DiagnosisAccuracy.incorrect,
                  onSelected: (_) =>
                      setState(() => _accuracy = DiagnosisAccuracy.incorrect),
                ),
                ChoiceChip(
                  label: Text(strings['feedbackAccuracyUnsure']),
                  selected: _accuracy == DiagnosisAccuracy.unsure,
                  onSelected: (_) =>
                      setState(() => _accuracy = DiagnosisAccuracy.unsure),
                ),
              ],
            ),
            if (widget.showTreatmentQuestion) ...[
              const SizedBox(height: 16),
              Text(
                strings['feedbackTreatmentQuestion'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(strings['feedbackOutcomeHelped']),
                    selected: _outcome == TreatmentOutcome.helped,
                    onSelected: (_) =>
                        setState(() => _outcome = TreatmentOutcome.helped),
                  ),
                  ChoiceChip(
                    label: Text(strings['feedbackOutcomeNoChange']),
                    selected: _outcome == TreatmentOutcome.noChange,
                    onSelected: (_) =>
                        setState(() => _outcome = TreatmentOutcome.noChange),
                  ),
                  ChoiceChip(
                    label: Text(strings['feedbackOutcomeWorsened']),
                    selected: _outcome == TreatmentOutcome.worsened,
                    onSelected: (_) =>
                        setState(() => _outcome = TreatmentOutcome.worsened),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: strings['feedbackNotesHint'],
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _accuracy == null ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(strings['submitFeedback']),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
