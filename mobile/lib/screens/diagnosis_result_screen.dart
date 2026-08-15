import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_record.dart';
import '../services/advisory_service.dart';
import '../state/app_language.dart';
import '../state/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_badge.dart';

/// Diagnosis result screen — layout matches the project plan's sample UI
/// (Section 6): confidence/crop/urgency badges, a detected-condition card,
/// and a treatment section with real localized advice (Week 5's
/// AdvisoryMapper content, bundled offline). TTS readback ("Hear Advice
/// in...") is Week 8.
class DiagnosisResultScreen extends StatelessWidget {
  const DiagnosisResultScreen({
    super.key,
    required this.scan,
    required this.advisoryService,
  });

  final ScanRecord scan;
  final AdvisoryService advisoryService;

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'high':
        return AppTheme.highUrgency;
      case 'medium':
        return AppTheme.mediumUrgency;
      default:
        return AppTheme.primaryGreen;
    }
  }

  String _urgencyLabel(String urgency, AppStrings strings) {
    switch (urgency) {
      case 'high':
        return strings['urgencyHigh'];
      case 'medium':
        return strings['urgencyMedium'];
      default:
        return strings['urgencyLow'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final strings = languageProvider.strings;
    final confidencePct = (scan.prediction.confidence * 100).toStringAsFixed(0);
    final advisory = advisoryService.forClass(
      scan.prediction.classId,
      language: languageProvider.language.code,
    );
    final urgencyColor = advisory != null
        ? _urgencyColor(advisory.urgency)
        : Colors.black87;

    return Scaffold(
      appBar: AppBar(title: Text(strings['diagnosisResult'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (File(scan.imagePath).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(scan.imagePath),
                  height: 200,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                StatBadge(
                  value: '$confidencePct%',
                  label: strings['confidence'],
                ),
                const SizedBox(width: 8),
                StatBadge(value: scan.cropLabel, label: strings['crop']),
                const SizedBox(width: 8),
                if (advisory != null)
                  StatBadge(
                    value: _urgencyLabel(advisory.urgency, strings),
                    label: strings['urgency'],
                    valueColor: urgencyColor,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCDE5D5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          advisory?.title ?? scan.conditionLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!scan.isHealthy)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: urgencyColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            strings['diseaseDetected'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (advisory != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      strings['recommendedTreatment'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      advisory.instructions,
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
