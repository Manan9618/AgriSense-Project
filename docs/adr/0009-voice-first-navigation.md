# ADR 0009: Voice-first navigation — asymmetric testing for TTS vs. STT

## Status
Accepted — Week 8

## Context
Week 8 needs two different voice capabilities: reading advisory text aloud (TTS) and recognizing
spoken navigation commands (STT). Both are platform-plugin-based, but the plugins are shaped very
differently: `flutter_tts`'s channel is a simple, stateless call/response (`setLanguage`, `speak`,
`stop`); `speech_to_text`'s is permission-gated and continuous (`initialize` -> `listen` with a
streaming result callback -> `stop`). That difference changes what's honestly testable in this
environment (no microphone, no emulator — same constraint as Week 4's camera).

## Decision
1. **TTS is tested for real**, not faked. `TtsService` wraps `FlutterTts` directly (no interface
   needed); `tts_service_test.dart` mocks the actual `'flutter_tts'` platform channel and asserts
   on the real method-call sequence (`setLanguage('hi-IN')` then `speak(...)`) — verifying the
   real plugin integration code path, the same confidence level as Week 4's on-device inference
   tests, just via channel mocking instead of FFI.
2. **STT uses the interface-plus-fake pattern** (`VoiceCommandSource`, same shape as
   `PhotoCaptureSource` from ADR 0006): `SpeechToTextVoiceCommandSource` is the real
   implementation, untested here — meaningfully mocking `initialize`/continuous `listen` would
   amount to reimplementing a fake anyway, so tests inject `FakeVoiceCommandSource` directly
   instead of pretending to verify plugin behavior that isn't really being verified.
3. **Command understanding is pure, testable logic**: `parseVoiceCommand()` (core/voice_command_parser.dart)
   is deliberately simple keyword matching, not NLU — a farmer says "scan" or "bhaav" and the app
   should do exactly that, transparently, with no model or network call (offline-first, same as
   the rest of the app). 14 tests cover all three languages plus edge cases (case-insensitivity,
   wrong-language input, empty/unrecognized speech).
4. Locale codes (`ttsLocale`, `sttLocale`) were added to the `AppLanguage` enum itself rather than
   scattered per-service maps — `AppLanguage.code` (en/hi/gu) already existed for UI strings and
   advisory content lookup, but TTS/STT engines need fuller locale tags (`hi-IN`, `hi_IN`).

## Consequences
- What's genuinely verified: TTS plugin call sequence and locale selection (real), voice-command
  keyword parsing across 3 languages (real, pure logic), the full "recognized text ->
  navigation" wiring in `HomeScreen._handleVoiceCommand` (real, via `FakeVoiceCommandSource`
  returning canned text). What's not: whether real speech recognition actually transcribes a
  farmer's voice correctly — needs a physical device, same caveat as camera capture (Week 4) and
  live weather/price API calls (Weeks 6-7).
- The "Hear Advice in {language}" button on the Diagnosis Result screen is the literal feature
  shown in the project plan's sample UI (Section 6) — Week 8 makes it real rather than a mockup.
- 17 new mobile tests (29 total, 1 of which self-skips — the Week 7 live-backend check).
