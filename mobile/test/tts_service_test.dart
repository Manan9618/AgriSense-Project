import 'package:agrisense_ai/services/tts_service.dart';
import 'package:agrisense_ai/state/app_language.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mocks flutter_tts's actual platform channel ('flutter_tts') rather than
/// faking TtsService itself — this verifies the real plugin call sequence
/// (setLanguage then speak, with the right locale) the way the native side
/// would receive it, not just that our wrapper class compiles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return 1;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'speak sets the locale for the requested language, then speaks',
    () async {
      final service = TtsService();

      await service.speak('Apply copper-based fungicide.', AppLanguage.hindi);

      expect(calls, hasLength(2));
      expect(calls[0].method, 'setLanguage');
      expect(calls[0].arguments, 'hi-IN');
      expect(calls[1].method, 'speak');
    },
  );

  test('uses the correct locale per language', () async {
    final service = TtsService();

    await service.speak('Hello', AppLanguage.gujarati);
    expect(calls[0].arguments, 'gu-IN');

    calls.clear();
    await service.speak('Hello', AppLanguage.english);
    expect(calls[0].arguments, 'en-IN');
  });

  test('stop calls through to the plugin', () async {
    final service = TtsService();

    await service.stop();

    expect(calls, hasLength(1));
    expect(calls[0].method, 'stop');
  });
}
