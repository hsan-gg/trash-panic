#!/usr/bin/env bash
# Run all tests. Fails on any test failure, any GDScript error, or a missing result line,
# because the Godot runner can print "0 failures" even when a script didn't compile.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
timeout 120 godot --headless --path "$root/game" --import >/dev/null 2>&1  # refresh the class cache for new class_name scripts
out="$(timeout 120 godot --headless --path "$root/game" --script res://tests/run_tests.gd 2>&1)"
echo "$out" | grep -E 'tests:|FAIL|SCRIPT ERROR|Parse Error' || true
if echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error|FAIL' || ! echo "$out" | grep -q 'tests: 0 failures'; then
  echo "GODOT TESTS FAILED"; exit 1
fi
soak="$(timeout 120 godot --headless --path "$root/game" --script res://tests/soak.gd -- --seeds=10 2>&1)"
echo "$soak" | grep -E '^soak|FAIL|SCRIPT ERROR' | head -5
if ! echo "$soak" | grep -q 'failures 0'; then
  echo "SOAK FAILED"; exit 1
fi
slide="$(timeout 60 godot --headless --path "$root/game" --script res://tests/slide_check.gd 2>&1)"
echo "$slide" | grep -E '^slide|SCRIPT ERROR' | head -3
if ! echo "$slide" | grep -q '^slide: ok'; then
  echo "SLIDE CHECK FAILED"; exit 1
fi
walk="$(timeout 600 godot --headless --path "$root/game" --script res://tests/room_walk.gd 2>&1)"
echo "$walk" | grep -E '^room_walk|^  |SCRIPT ERROR' | head -5
if ! echo "$walk" | grep -q '^room_walk: ok'; then
  echo "ROOM WALK FAILED"; exit 1
fi
node_out="$(cd "$root/server" && node --test test/ 2>&1)"
node_status=$?
echo "$node_out" | grep -E '^ℹ (pass|fail)'
if [ $node_status -ne 0 ]; then
  echo "$node_out" | grep -E '^not ok|✖' | head -20
  echo "SERVER TESTS FAILED"; exit 1
fi
echo "ALL TESTS PASSED"
