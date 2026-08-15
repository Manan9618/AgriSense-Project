# AgriSense AI — Mobile App

Flutter app shell: camera capture, on-device diagnosis, results screen, language selector.
See `docs/adr/0006-flutter-app-architecture.md` for the architecture rationale.

## Setup

```bash
flutter pub get
```

## Running tests

Real on-device inference tests (`test/inference_service_test.dart`,
`test/home_screen_flow_test.dart`) load the actual bundled quantized model
(`assets/models/agrisense_v1_int8.tflite`) and run it through `tflite_flutter`'s native FFI
bindings — not a mock. On macOS, that plugin normally gets its native library from a CocoaPods
build step (`pod install` -> Xcode build), which needs a full Xcode install. If you don't have
that:

```bash
./scripts/setup_macos_test_lib.sh   # one-time per machine
flutter test
```

The script copies the plugin's already-bundled macOS dylib into the Flutter SDK's cache where
`flutter test`'s host runner looks for it — see the script and ADR 0006 for why. Without it,
`flutter test` fails with `Failed to load dynamic library '...libtensorflowlite_c-mac.dylib'`. If
you *do* have Xcode + CocoaPods set up (or you're on Linux/Windows CI, or running on a real
device), you don't need this — the plugin resolves its native library normally.

## What's tested vs. not

- **Tested for real**: model loading, inference correctness (against real held-out test images,
  matching `ml/scripts/evaluate_tflite.py`'s ~95% accuracy), the full capture -> classify ->
  result-screen navigation flow, language switching.
- **Not testable in this environment**: actual camera hardware (`CameraCaptureScreen` /
  `CameraPhotoCaptureSource` — no Android emulator or physical device here). Structured behind
  the `PhotoCaptureSource` interface specifically so this is the *only* untested piece — verify
  it manually on a device before considering Week 4 fully done end-to-end.
- **TTS (Week 8) is tested for real** — `tts_service_test.dart` mocks flutter_tts's actual
  platform channel and asserts on the real call sequence, not a hand-rolled fake.
  **Speech-to-text is not** (`SpeechToTextVoiceCommandSource` — same hardware/emulator
  limitation as camera); tests inject `FakeVoiceCommandSource` instead. See
  `docs/adr/0009-voice-first-navigation.md`.

## Verifying the price comparison screen against a real backend

`test/price_provider_live_backend_test.dart` makes a genuine HTTP call to a running Django dev
server rather than mocking the network layer — the strongest verification available for Week 7's
backend<->app integration. It self-skips if no server is reachable, so normal `flutter test` runs
don't need one. To actually exercise it:

```bash
cd backend && source .venv/bin/activate && python manage.py runserver 127.0.0.1:8000 &
cd mobile && flutter test test/price_provider_live_backend_test.dart
```

## Regenerating the bundled model

`assets/models/agrisense_v1_int8.tflite` and `class_names.json` are copied from `ml/models/v1/`
(see `ml/scripts/convert_tflite.py`). If the model is retrained, re-copy:

```bash
cp ../ml/models/v1/model_int8.tflite assets/models/agrisense_v1_int8.tflite
cp ../ml/data/class_names.json assets/models/class_names.json
```

## Regenerating the bundled advisory content

`assets/content/treatment_recommendations.json` is a copy of the repo-root
`content/treatment_recommendations.json` — see `docs/advisory-content.md`. If that file changes,
re-copy:

```bash
cp ../content/treatment_recommendations.json assets/content/treatment_recommendations.json
```
