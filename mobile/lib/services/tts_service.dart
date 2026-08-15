import 'package:flutter_tts/flutter_tts.dart';

import '../state/app_language.dart';

/// Wraps FlutterTts for advisory readback ("Hear Advice in Gujarati" on the
/// Diagnosis Result screen, per the project plan's sample UI). Real
/// implementation only — flutter_tts's platform channel is a simple,
/// stateless call/response (unlike speech_to_text's permission-gated
/// continuous listening), so it's mocked at the channel level in tests
/// rather than needing a separate fake implementation.
class TtsService {
  TtsService({FlutterTts? flutterTts}) : _tts = flutterTts ?? FlutterTts();

  final FlutterTts _tts;

  Future<void> speak(String text, AppLanguage language) async {
    await _tts.setLanguage(language.ttsLocale);
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
