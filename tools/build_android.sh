#!/usr/bin/env bash
# Build the Android APK. Release = the demo/submission build that forces 5G SA mobile data.
# usage: tools/build_android.sh [debug|release] [--install]
# Release signing comes from ~/.config/the-last-drop/release-signing.env (never in git).
set -euo pipefail
mode="${1:-debug}"
root="$(cd "$(dirname "$0")/.." && pwd)"
apk="$root/build/trash-panic-$mode.apk"
mkdir -p "$root/build"
if [ "$mode" = release ]; then
  # shellcheck source=/dev/null
  source "$HOME/.config/the-last-drop/release-signing.env"
fi
godot --headless --path "$root/game" "--export-$mode" "Android" "$apk" > "$root/build/android_export.log" 2>&1 \
  || { grep -iE 'error|what went wrong' -A3 "$root/build/android_export.log" | head -30; exit 1; }
ls -lh "$apk"
if [ "${2:-}" = --install ]; then
  # Debug and release are signed with different keys, so replace rather than update.
  adb uninstall com.trashpanic.game >/dev/null 2>&1 || true
  adb install "$apk"
  adb shell monkey -p com.trashpanic.game -c android.intent.category.LAUNCHER 1 >/dev/null
fi
