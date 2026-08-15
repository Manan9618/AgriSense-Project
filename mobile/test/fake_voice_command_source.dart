import 'package:agrisense_ai/services/voice_command_source.dart';

/// Test double: returns a canned recognized-text result instead of
/// listening to a real microphone.
class FakeVoiceCommandSource implements VoiceCommandSource {
  const FakeVoiceCommandSource(this.result);

  final String? result;

  @override
  Future<String?> listen({required String localeId}) async => result;
}
