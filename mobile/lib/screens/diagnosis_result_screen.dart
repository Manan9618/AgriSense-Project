import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/scan_record.dart';
import '../state/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_badge.dart';

/// Diagnosis result screen — layout matches the project plan's sample UI
/// (Section 6): confidence/crop/status badges, a detected-condition card,
/// and a treatment section. Treatment content itself is a Week 5 stub here
/// (AdvisoryMapper isn't built yet); TTS readback ("Hear Advice in...") is
/// Week 8.
class DiagnosisResultScreen extends StatelessWidget {
  const DiagnosisResultScreen({super.key, required this.scan});

  final ScanRecord scan;

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final confidencePct = (scan.prediction.confidence * 100).toStringAsFixed(0);

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
                StatBadge(
                  value: scan.isHealthy
                      ? strings['healthy']
                      : strings['diseaseDetected'],
                  label: scan.conditionLabel,
                  valueColor: scan.isHealthy
                      ? AppTheme.primaryGreen
                      : AppTheme.highUrgency,
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
                          scan.conditionLabel,
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
                            color: AppTheme.highUrgency,
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
                  const SizedBox(height: 12),
                  Text(
                    strings['advisoryComingSoon'],
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
