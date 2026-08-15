import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../models/scan_record.dart';
import '../services/advisory_service.dart';
import '../services/inference_service.dart';
import '../services/photo_capture_source.dart';
import '../services/price_provider.dart';
import '../state/language_provider.dart';
import '../state/scan_history_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/language_selector.dart';
import '../widgets/recent_scan_tile.dart';
import 'diagnosis_result_screen.dart';

/// Home screen: capture flow entry point + recent scan history. Layout
/// matches the project plan's sample UI (Section 6).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.inferenceService,
    required this.advisoryService,
    required this.photoCaptureSource,
    required this.priceProvider,
  });

  final InferenceService inferenceService;
  final AdvisoryService advisoryService;
  final PhotoCaptureSource photoCaptureSource;
  final PriceProvider priceProvider;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessing = false;

  Future<void> _startScan() async {
    final path = await widget.photoCaptureSource.capturePhoto(context);
    if (path == null || !mounted) return;

    setState(() => _isProcessing = true);
    ScanRecord? scan;
    try {
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw const FormatException('Could not decode captured photo');
      }

      final prediction = widget.inferenceService.classify(image);
      scan = ScanRecord(
        imagePath: path,
        prediction: prediction,
        capturedAt: DateTime.now(),
      );
    } finally {
      // Reset before navigating, not after: the spinner represents
      // "capturing + classifying," which is done once we have a
      // prediction — it must not keep animating underneath the pushed
      // result screen for as long as that screen stays open.
      if (mounted) setState(() => _isProcessing = false);
    }

    if (!mounted) return;
    final result =
        scan; // try only completes without throwing after assigning scan
    context.read<ScanHistoryProvider>().add(result);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosisResultScreen(
          scan: result,
          advisoryService: widget.advisoryService,
        ),
      ),
    );
  }

  void _openScan(ScanRecord scan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosisResultScreen(
          scan: scan,
          advisoryService: widget.advisoryService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final scans = context.watch<ScanHistoryProvider>().scans;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings['appTitle']),
        actions: const [LanguageSelector()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF1B7A3D),
                style: BorderStyle.solid,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              strings['tapToScan'],
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _startScan,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.camera_alt),
            label: Text(strings['capturePhoto']),
          ),
          const SizedBox(height: 24),
          Text(
            strings['recentScans'],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (scans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                strings['noScansYet'],
                style: const TextStyle(color: Colors.black54),
              ),
            )
          else
            ...scans.map(
              (scan) =>
                  RecentScanTile(scan: scan, onTap: () => _openScan(scan)),
            ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        strings: strings,
        priceProvider: widget.priceProvider,
      ),
    );
  }
}
