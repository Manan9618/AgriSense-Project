import 'package:agrisense_ai/core/voice_command_parser.dart';
import 'package:agrisense_ai/state/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('English', () {
    test('recognizes scan commands', () {
      expect(parseVoiceCommand('scan', AppLanguage.english), VoiceIntent.scan);
      expect(
        parseVoiceCommand('take a photo', AppLanguage.english),
        VoiceIntent.scan,
      );
      expect(
        parseVoiceCommand('capture the leaf', AppLanguage.english),
        VoiceIntent.scan,
      );
    });

    test('recognizes price commands', () {
      expect(
        parseVoiceCommand('show prices', AppLanguage.english),
        VoiceIntent.prices,
      );
      expect(
        parseVoiceCommand('mandi rates', AppLanguage.english),
        VoiceIntent.prices,
      );
    });

    test('recognizes weather commands', () {
      expect(
        parseVoiceCommand('what is the weather', AppLanguage.english),
        VoiceIntent.weather,
      );
      expect(
        parseVoiceCommand('will it rain', AppLanguage.english),
        VoiceIntent.weather,
      );
    });

    test('recognizes community commands', () {
      expect(
        parseVoiceCommand('ask a question', AppLanguage.english),
        VoiceIntent.community,
      );
    });

    test('is case-insensitive', () {
      expect(parseVoiceCommand('SCAN', AppLanguage.english), VoiceIntent.scan);
      expect(
        parseVoiceCommand('ScAn my crop', AppLanguage.english),
        VoiceIntent.scan,
      );
    });
  });

  group('Hindi', () {
    test('recognizes scan commands', () {
      expect(
        parseVoiceCommand('स्कैन करो', AppLanguage.hindi),
        VoiceIntent.scan,
      );
    });

    test('recognizes price commands', () {
      expect(
        parseVoiceCommand('भाव बताओ', AppLanguage.hindi),
        VoiceIntent.prices,
      );
      expect(
        parseVoiceCommand('मंडी का भाव', AppLanguage.hindi),
        VoiceIntent.prices,
      );
    });

    test('recognizes weather commands', () {
      expect(
        parseVoiceCommand('मौसम कैसा है', AppLanguage.hindi),
        VoiceIntent.weather,
      );
    });
  });

  group('Gujarati', () {
    test('recognizes scan commands', () {
      expect(
        parseVoiceCommand('સ્કેન કરો', AppLanguage.gujarati),
        VoiceIntent.scan,
      );
    });

    test('recognizes price commands', () {
      expect(
        parseVoiceCommand('ભાવ કહો', AppLanguage.gujarati),
        VoiceIntent.prices,
      );
    });

    test('recognizes weather commands', () {
      expect(
        parseVoiceCommand('હવામાન કેવું છે', AppLanguage.gujarati),
        VoiceIntent.weather,
      );
    });
  });

  group('Marathi', () {
    test('recognizes scan commands', () {
      expect(
        parseVoiceCommand('स्कॅन करा', AppLanguage.marathi),
        VoiceIntent.scan,
      );
    });

    test('recognizes price commands', () {
      expect(
        parseVoiceCommand('भाव सांगा', AppLanguage.marathi),
        VoiceIntent.prices,
      );
    });

    test('recognizes weather commands', () {
      expect(
        parseVoiceCommand('हवामान कसे आहे', AppLanguage.marathi),
        VoiceIntent.weather,
      );
    });

    test('recognizes community commands', () {
      expect(
        parseVoiceCommand('समुदाय प्रश्न', AppLanguage.marathi),
        VoiceIntent.community,
      );
    });
  });

  group('edge cases', () {
    test('returns null for unrecognized speech', () {
      expect(parseVoiceCommand('good morning', AppLanguage.english), isNull);
    });

    test('returns null for empty or whitespace-only input', () {
      expect(parseVoiceCommand('', AppLanguage.english), isNull);
      expect(parseVoiceCommand('   ', AppLanguage.english), isNull);
    });

    test('a command in the wrong language for the parser does not match', () {
      expect(parseVoiceCommand('स्कैन करो', AppLanguage.english), isNull);
    });
  });
}
