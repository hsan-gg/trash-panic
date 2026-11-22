#!/usr/bin/env bash
# Screenshot an offline host shift: tools/shot.sh <second> <out.png> [--creatures=elephant,pig] [--chaos=lowgrav]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
at="${1:-40}"; out="$(realpath -m "${2:-shot.png}")"; shift 2 || true
log="$(timeout 90 godot --path "$root/game" res://tests/shot.tscn -- --at="$at" --out="$out" "$@" 2>&1)"
echo "$log" | grep -E 'SCRIPT ERROR|Parse Error|^ERROR|draw calls' | grep -v 'resources still in use' | sort | uniq -c | sort -rn | head -15 || true
