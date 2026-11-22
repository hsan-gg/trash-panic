#!/usr/bin/env bash
# Synthesises the factory sound effects with sox (our own sounds, no licence needed) into game/core/assets/sfx.
set -euo pipefail
out="$(cd "$(dirname "$0")/.." && pwd)/game/core/assets/sfx"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mk() { sox -n -r 44100 -c 1 "$tmp/$1.wav" "${@:2}"; ffmpeg -v error -y -i "$tmp/$1.wav" -c:a libvorbis -b:a 64k "$out/$1.ogg"; }
# Crusher: a heavy metal clank (noise burst + low resonant thud).
sox -n -r 44100 -c 1 "$tmp/a.wav" synth 0.25 brownnoise fade q 0.002 0.25 0.2 gain -3
sox -n -r 44100 -c 1 "$tmp/b.wav" synth 0.3 sine 70 fade q 0.002 0.3 0.25
sox -m "$tmp/a.wav" "$tmp/b.wav" "$tmp/crunch.wav" gain -n -2
ffmpeg -v error -y -i "$tmp/crunch.wav" -c:a libvorbis -b:a 64k "$out/sfx_crunch.ogg"
# Truck horn: two detuned square tones.
mk sfx_horn synth 0.45 square 311 square 370 fade q 0.01 0.45 0.08 gain -12
# Rush-hour alarm: a rising siren sweep, twice.
mk sfx_alarm synth 0.5 sawtooth 500-900 synth 0.5 sawtooth 500-900 fade q 0.01 0.5 0.05 repeat 1 gain -14
# Sink splash: filtered noise swell.
mk sfx_splash synth 0.4 pinknoise highpass 900 fade q 0.05 0.4 0.3 gain -6
# Whoosh: a band-passed noise sweep (throws, dashes).
mk sfx_whoosh synth 0.3 pinknoise bandpass 1200 900 fade q 0.08 0.3 0.15 gain -6
# Bale: a thick pneumatic thunk.
mk sfx_thunk synth 0.22 sine 120-55 fade q 0.002 0.22 0.15 gain -2
ls -1 "$out" | grep sfx_
