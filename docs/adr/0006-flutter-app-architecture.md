# ADR 0006: Flutter app architecture — capture-source abstraction + runAsync testing

## Status
Accepted — Week 4

## Context
Week 4 needed a testable camera-to-diagnosis flow in an environment with no Android
emulator/physical device and no full Xcode/CocoaPods install (`flutter doctor` confirms both
missing). Camera hardware itself is fundamentally untestable here — but everything else
(navigation, state, inference wiring, UI) doesn't have to be.

## Decision
1. **`PhotoCaptureSource` interface** (`mobile/lib/services/photo_capture_source.dart`):
   `HomeScreen` depends on this abstraction, not directly on the `camera` package.
   `CameraPhotoCaptureSource` is the real implementation (pushes a live camera preview screen);
   tests inject a `FakePhotoCaptureSource` that returns a real held-out test image path
   instantly. Everything downstream of "a photo was captured" — decode, classify, navigate,
   render results — is exercised for real in `flutter test`, using the actual bundled quantized
   model. The only thing genuinely untested is the literal camera hardware trigger.
2. **`tester.runAsync()` for any test that taps a button triggering real I/O or FFI.** Discovered
   the hard way: `testWidgets()`'s default fake-async zone lets a tap's `onPressed` callback
   start running, but if that callback does genuine `dart:io` file I/O or an FFI call (our
   `Interpreter.run`), the underlying Future never resolves inside the fake-async zone — the test
   hangs indefinitely (up to the 10-minute global timeout) with 0% CPU, not a slow computation.
   `tester.runAsync()` is Flutter's documented escape hatch: it runs the wrapped callback against
   the real event loop instead of the fake one. Every test in `home_screen_flow_test.dart` wraps
   its body in `runAsync()` for this reason.
3. **Bounded real-delay pumps instead of `pumpAndSettle()`** after actions that trigger the
   above. `pumpAndSettle()` repeatedly pumps until no frame is scheduled; combined with real
   async work inside `runAsync()`, it doesn't reliably wait for that work the way it does for
   pure-animation settling, and it timed out in practice. `pumpUntilFound()` (poll for a finder
   to match, with real delays between pumps) and `pumpFrames()` (fixed real-delay pump count, for
   animated transitions like the language popup menu whose target text exists in the tree before
   it's actually hit-testable) replace it — see `mobile/test/home_screen_flow_test.dart`.

## Consequences
- Weeks 8 and 9 (voice navigation, offline sync) will hit the same fake-async trap the moment
  their tests trigger real TTS/SQLite/Firebase calls from a widget callback — reuse
  `runAsync()` + bounded-pump helpers from the start rather than rediscovering this.
- The `PhotoCaptureSource` pattern is worth repeating for other hardware-dependent integrations
  (e.g. GPS for weather, in Week 6) — abstract the untestable boundary, keep everything on the
  app's side of it testable.
- macOS host testing of `tflite_flutter` needs a one-time local setup step
  (`mobile/scripts/setup_macos_test_lib.sh`) since this environment lacks the Xcode/CocoaPods
  pipeline that would normally place the plugin's native library where the test runner expects
  it. See `mobile/README.md`.
