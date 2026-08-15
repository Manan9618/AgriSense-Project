import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../app_services.dart';
import '../core/voice_command_parser.dart';
import '../models/scan_record.dart';
import '../screens/price_comparison_screen.dart';
import '../state/language_provider.dart';
import '../state/scan_history_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/language_selector.dart';
import '../widgets/recent_scan_tile.dart';
import 'diagnosis_result_screen.dart';

/// Home screen: capture flow entry point + recent scan history + voice
/// navigation + offline sync status. Layout matches the project plan's
/// sample UI (Section 6).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessing = false;
  bool _isListening = false;
  bool _isSyncing = false;

  Future<void> _startScan() async {
    final path = await widget.services.photoCaptureSource.capturePhoto(context);
    if (path == null || !mounted) return;

    final language = context.read<LanguageProvider>().language;

    setState(() => _isProcessing = true);
    ScanRecord? scan;
    try {
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw const FormatException('Could not decode captured photo');
      }

      final prediction = widget.services.inferenceService.classify(image);
      scan = await widget.services.scanRepository.saveScan(
        capturedImagePath: path,
        prediction: prediction,
        language: language.code,
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
          advisoryService: widget.services.advisoryService,
          ttsService: widget.services.ttsService,
        ),
      ),
    );
  }

  void _openScan(ScanRecord scan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiagnosisResultScreen(
          scan: scan,
          advisoryService: widget.services.advisoryService,
          ttsService: widget.services.ttsService,
        ),
      ),
    );
  }

  Future<void> _handleVoiceCommand() async {
    final language = context.read<LanguageProvider>().language;
    final strings = context.read<LanguageProvider>().strings;

    setState(() => _isListening = true);
    String? recognized;
    try {
      recognized = await widget.services.voiceCommandSource.listen(
        localeId: language.sttLocale,
      );
    } finally {
      if (mounted) setState(() => _isListening = false);
    }
    if (!mounted || recognized == null) return;

    final intent = parseVoiceCommand(recognized, language);
    switch (intent) {
      case VoiceIntent.scan:
        await _startScan();
      case VoiceIntent.prices:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PriceComparisonScreen(
              priceProvider: widget.services.priceProvider,
            ),
          ),
        );
      case VoiceIntent.weather:
      case VoiceIntent.community:
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Coming soon')));
      case null:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings['voiceCommandNotRecognized'])),
        );
    }
  }

  Future<void> _syncNow() async {
    final strings = context.read<LanguageProvider>().strings;
    setState(() => _isSyncing = true);
    try {
      final summary = await widget.services.syncManager.syncPending();
      if (!mounted) return;
      await context.read<ScanHistoryProvider>().loadFromDatabase(
        widget.services.localDatabase,
      );
      if (!mounted) return;
      final message = summary.hadFailures
          ? strings['syncPartialFailure']
                .replaceAll('{synced}', '${summary.syncedCount}')
                .replaceAll('{failed}', '${summary.failedCount}')
          : strings['syncSuccess'].replaceAll(
              '{count}',
              '${summary.syncedCount}',
            );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    final scans = context.watch<ScanHistoryProvider>().scans;
    final pendingCount = context.watch<ScanHistoryProvider>().pendingSyncCount;

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
          const SizedBox(height: 8),
          Text(
            _isListening ? strings['listening'] : strings['voiceCommandHint'],
            style: TextStyle(
              fontSize: 12,
              color: _isListening ? AppTheme.primaryGreen : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          _SyncStatusBar(
            pendingCount: pendingCount,
            isSyncing: _isSyncing,
            strings: strings,
            onSyncNow: _syncNow,
          ),
          const SizedBox(height: 16),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _isListening ? null : _handleVoiceCommand,
        tooltip: strings['voiceCommandHint'],
        backgroundColor: _isListening ? Colors.grey : null,
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      ),
      bottomNavigationBar: AppBottomNav(
        strings: strings,
        priceProvider: widget.services.priceProvider,
      ),
    );
  }
}

class _SyncStatusBar extends StatelessWidget {
  const _SyncStatusBar({
    required this.pendingCount,
    required this.isSyncing,
    required this.strings,
    required this.onSyncNow,
  });

  final int pendingCount;
  final bool isSyncing;
  final dynamic strings;
  final VoidCallback onSyncNow;

  @override
  Widget build(BuildContext context) {
    final label = isSyncing
        ? strings['syncing']
        : (pendingCount == 0
              ? strings['allSynced']
              : strings['pendingSync'].replaceAll('{count}', '$pendingCount'));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              pendingCount == 0 ? Icons.cloud_done : Icons.cloud_upload,
              size: 16,
              color: pendingCount == 0 ? AppTheme.primaryGreen : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        if (pendingCount > 0)
          TextButton(
            onPressed: isSyncing ? null : onSyncNow,
            child: Text(strings['syncNow']),
          ),
      ],
    );
  }
}
