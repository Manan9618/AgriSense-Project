import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'voice_command_source.dart';

/// Real [VoiceCommandSource]: wraps the speech_to_text plugin. Requires a
/// physical microphone and OS speech-recognition support — cannot be
/// exercised by `flutter test` (see mobile/README.md). Tests inject a fake
/// instead of going through this class at all, same as
/// CameraPhotoCaptureSource for the camera.
class SpeechToTextVoiceCommandSource implements VoiceCommandSource {
  SpeechToTextVoiceCommandSource({stt.SpeechToText? speechToText})
    : _speech = speechToText ?? stt.SpeechToText();

  final stt.SpeechToText _speech;

  @override
  Future<String?> listen({required String localeId}) async {
    final available = await _speech.initialize();
    if (!available) return null;

    final completer = Completer<String?>();
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(
            result.recognizedWords.isEmpty ? null : result.recognizedWords,
          );
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: false,
        listenFor: const Duration(seconds: 6),
        localeId: localeId,
      ),
    );

    final result = await completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
    await _speech.stop();
    return result;
  }
}
