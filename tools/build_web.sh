#!/usr/bin/env bash
# Export the web build and gzip the wasm so it fits Cloudflare's 25 MiB per-file limit.
# usage: tools/build_web.sh [debug|release]
set -euo pipefail
mode="${1:-debug}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/build/web"
rm -rf "$out" && mkdir -p "$out"
godot --headless --path "$root/game" "--export-$mode" "Web" "$out/index.html"
gzip -9 "$out/index.wasm"   # -> index.wasm.gz, served by server/src/index.js as /index.wasm
ls -lh "$out/index.wasm.gz" "$out/index.pck"
