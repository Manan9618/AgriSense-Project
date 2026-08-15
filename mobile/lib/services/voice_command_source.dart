/// Abstraction over "listen for one spoken command and return the
/// recognized text" — same interface-plus-fake pattern as
/// PhotoCaptureSource (Week 4, docs/adr/0006): speech_to_text's platform
/// channel is permission-gated and continuous (unlike flutter_tts's
/// simple call/response, which is mocked directly in tts_service_test.dart),
/// so meaningfully simulating it would amount to re-implementing a fake
/// anyway. [SpeechToTextVoiceCommandSource] is the real implementation,
/// untested here the same way CameraPhotoCaptureSource is — needs an
/// actual device/microphone to verify.
abstract class VoiceCommandSource {
  /// Returns the recognized words, or null if nothing was recognized
  /// (silence, timeout, permission denied, no microphone).
  Future<String?> listen({required String localeId});
}
