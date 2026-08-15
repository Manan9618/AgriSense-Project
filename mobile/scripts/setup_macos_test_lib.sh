#!/usr/bin/env bash
# Makes `flutter test` able to run real TFLite inference on macOS.
#
# tflite_flutter uses dart:ffi to dlopen a native library directly (not
# platform channels), and on macOS it looks for that library under the
# Flutter SDK's engine cache, at a path CocoaPods would normally populate
# during a full `pod install` / Xcode build. Without Xcode + CocoaPods
# installed (not available in every dev/CI environment), that path is never
# populated — but the plugin already bundles the exact same dylib in its pub
# cache package, so we can just copy it into place ourselves.
#
# Run once per machine (or in CI setup) before `flutter test`:
#   ./scripts/setup_macos_test_lib.sh
set -euo pipefail

# Resolve the flutter binary through brew's symlink to the real SDK
# location (e.g. /opt/homebrew/bin/flutter -> .../Caskroom/flutter/.../flutter/bin/flutter)
# without relying on GNU-only `readlink -f`, which isn't on macOS by default.
resolve_symlink() {
  local target="$1"
  while [ -L "$target" ]; do
    local link
    link="$(readlink "$target")"
    case "$link" in
      /*) target="$link" ;;
      *) target="$(dirname "$target")/$link" ;;
    esac
  done
  echo "$target"
}

FLUTTER_BIN="$(resolve_symlink "$(command -v flutter)")"
FLUTTER_ROOT="$(dirname "$(dirname "$FLUTTER_BIN")")"
DEST_DIR="$FLUTTER_ROOT/bin/cache/artifacts/engine/resources"

PLUGIN_VERSION=$(grep -A7 '^  tflite_flutter:' pubspec.lock | grep version | sed -E 's/.*"(.*)"/\1/')
SRC="$HOME/.pub-cache/hosted/pub.dev/tflite_flutter-${PLUGIN_VERSION}/macos/libtensorflowlite_c-mac.dylib"

if [ ! -f "$SRC" ]; then
  echo "error: $SRC not found — run 'flutter pub get' first" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST_DIR/libtensorflowlite_c-mac.dylib"
echo "Copied tflite_flutter's macOS dylib to $DEST_DIR"
