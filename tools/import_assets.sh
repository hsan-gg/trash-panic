#!/usr/bin/env bash
# Copies only the assets listed in ASSETS.md from ~/Downloads into game/core/assets and writes CREDITS.md.
# Re-runnable; never modifies the source folder.
set -euo pipefail

SRC="${ASSETS_SRC:-$HOME/Downloads}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/game/core/assets"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"/{emoji,fonts,music,sfx,ui,3d,particles} "$ROOT/game/core/shaders"

EMOJI=(
  "Canned food" "Lotion bottle" "Newspaper" "Package" "Jar" "Wine glass" "Banana" "Red apple" "Battery"
  "Recycling symbol" "Wastebasket" "Fire" "Fire extinguisher" "Star" "Glowing star" "Money bag" "Stopwatch"
  "Party popper" "Trophy" "Robot" "Delivery truck" "Soap" "Hammer" "Elephant" "Raccoon" "Bomb" "Radioactive" "Collision" "Warning" "Bubbles" "Sparkles" "Handshake"
  "Coin" "Police car light" "Droplet"
)
for name in "${EMOJI[@]}"; do
  snake="$(echo "$name" | tr 'A-Z ' 'a-z_')"
  cp "$SRC/fluentui-emoji/assets/$name/3D/${snake}_3d.png" "$OUT/emoji/$snake.png"
done
cp "$SRC/fluentui-emoji/LICENSE" "$OUT/emoji/LICENSE.txt"

unzip -qo "$SRC/Baloo_2,Fredoka,Lilita_One,Pixelify_Sans.zip" \
  "Fredoka/static/Fredoka-Medium.ttf" "Fredoka/static/Fredoka-Bold.ttf" "Fredoka/OFL.txt" \
  "Lilita_One/LilitaOne-Regular.ttf" "Lilita_One/OFL.txt" -d "$TMP/fonts"
cp "$TMP/fonts/Fredoka/static/"*.ttf "$TMP/fonts/Lilita_One/"*.ttf "$OUT/fonts/"
cp "$TMP/fonts/Fredoka/OFL.txt" "$OUT/fonts/Fredoka-OFL.txt"
cp "$TMP/fonts/Lilita_One/OFL.txt" "$OUT/fonts/LilitaOne-OFL.txt"

# Music: 96 kbps stereo OGG Vorbis.
music() { ffmpeg -v error -y -i "$1" -c:a libvorbis -b:a 96k "$OUT/music/$2.ogg"; }
music "$SRC/cozy_puzzle_stage_select_bpm100.ogg" lobby
music "$SRC/HappyClappyLoop.wav" happy_clappy

# Shift, title and result music (OpenGameArt, CC0), cached in ~/.cache/last-drop-assets:
# rhythm_factory.mp3 = "Rhythm Factory" (Zane Little Music); melon_*.ogg = "The War Over A Melon Field - Themes and Jingles" (Spring).
MUSIC_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/last-drop-assets"
music "$MUSIC_CACHE/rhythm_factory.mp3" match
music "$MUSIC_CACHE/melon_short_theme.ogg" title
music "$MUSIC_CACHE/melon_win.ogg" result_win
music "$MUSIC_CACHE/melon_lose.ogg" result_lose

# SFX: mono 64 kbps OGG.
sfx() { ffmpeg -v error -y -i "$1" -ac 1 -c:a libvorbis -b:a 64k "$OUT/sfx/$2.ogg"; }
for i in 1 2 3; do sfx "$SRC/pop$i.ogg" "pop_$i"; done
sfx "$SRC/coin.wav" coin
sfx "$SRC/pickupCoin.wav" pickup_coin
sfx "$SRC/gem-gather-stereo.wav" gem_gather
unzip -qo "$SRC/kenney_interfaceSounds.zip" -d "$TMP/kenney"
for f in click_001 confirmation_001 back_001 tick_001 error_001 bong_001 maximize_001 pluck_001 drop_001 scratch_001; do
  sfx "$TMP/kenney/Audio/$f.ogg" "ui_${f%_001}"
done

# Kenney packs (CC0) come from Kenney's own OpenGameArt uploads (kenney.nl hides zips behind a dialog).
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/last-drop-assets"
mkdir -p "$CACHE"
kenney() {
  local zip="$CACHE/$1.zip"
  [ -f "$zip" ] || curl -sfL -A "Mozilla/5.0" -o "$zip" "https://opengameart.org/sites/default/files/$1.zip"
  echo "$zip"
}

# UI: Kenney UI Pack 2.0. Grey glossy pieces are tinted to the palette in code.
unzip -qo "$(kenney kenney_ui-pack)" "PNG/Grey/Double/*" "PNG/Yellow/Double/star.png" "License.txt" -d "$TMP/kenney"
for f in button_rectangle_depth_gloss button_rectangle_gloss button_square_depth_gloss button_round_depth_gloss button_round_gloss slide_horizontal_grey; do
  cp "$TMP/kenney/PNG/Grey/Double/$f.png" "$OUT/ui/$f.png"
done
cp "$TMP/kenney/PNG/Yellow/Double/star.png" "$OUT/ui/star.png"
cp "$TMP/kenney/License.txt" "$OUT/ui/LICENSE.txt"

# Particles: Kenney Particle Pack (CC0), white-on-transparent sprites tinted in code.
unzip -qo "$SRC/kenney_particle-pack.zip" "PNG (Transparent)/star_01.png" "PNG (Transparent)/smoke_01.png" \
  "PNG (Transparent)/flame_04.png" "License.txt" -d "$TMP/particles"
cp "$TMP/particles/PNG (Transparent)/"*.png "$OUT/particles/"
cp "$TMP/particles/License.txt" "$OUT/particles/LICENSE.txt"

# 3D: one folder per pack, each with the shared colormap its GLBs reference.
model_pack() {  # model_pack <zip name> <folder> <glb dir in zip> <models...>
  local zip; zip="$(kenney "$1")"; local dest="$OUT/3d/$2" dir="$3"; shift 3
  rm -rf "$TMP/m" "$dest" && mkdir -p "$dest" "$TMP/m"
  unzip -qo "$zip" "$dir/*" -d "$TMP/m"
  [ -d "$TMP/m/$dir/Textures" ] && mkdir -p "$dest/Textures" && cp "$TMP/m/$dir/Textures/colormap.png" "$dest/Textures/"
  for m in "$@"; do cp "$TMP/m/$dir/$m.glb" "$dest/"; done
}
model_pack kenney_mini-characters_2.0 characters "Models/GLB format" \
  character-worker character-male-c character-female-c character-female-a character-robot
model_pack kenney_factory-kit_3.0 factory "Models/GLB format" \
  conveyor conveyor-long conveyor-stripe conveyor-long-stripe conveyor-sides conveyor-corner crane crane-magnet \
  piston-round piston-square hopper-square hopper-round hopper-high-square machine machine-window machine-fortified \
  scanner-high scanner-low structure-wall structure-tall structure-medium structure-short structure-yellow-tall \
  structure-window structure-doorway-wide floor floor-large top-large top-large-checkerboard warning-orange \
  warning-traffic cone box-large box-small box-long cog-a cog-b robot-arm-a robot-arm-b catwalk-straight \
  screen-wide screen-hanging-wide screen-panel-wide door-wide-open indicator-special-lines indicator-special-cross \
  pipe-large-long pipe-large-bend pipe-large-valve lever-single lever-double button-floor-round
model_pack kenney_food-kit food "Models/GLB format" \
  soda-can soda-can-crushed soda-bottle carton carton-small peanut-butter honey bag bag-flat pizza-box apple \
  banana candy-bar-wrapper styrofoam glass can
model_pack kenney_car-kit_3.1 vehicles "Models/GLB format" \
  garbage-truck truck-flat tractor-shovel debris-plate-a debris-nut debris-bolt debris-tire cone
model_pack kenney_survival-kit survival "Models/GLB format" barrel barrel-open box-large metal-panel-screws
rm -rf "$OUT/3d/platformer" "$OUT/3d/city"

# Screen shaders from Juicee (MIT).
unzip -qo "$SRC/Juicee-main.zip" "Juicee-main/addons/juicee/shaders/shockwave.gdshader" \
  "Juicee-main/addons/juicee/shaders/speed_lines.gdshader" "Juicee-main/addons/juicee/LICENSE.md" -d "$TMP/juicee"
cp "$TMP/juicee/Juicee-main/addons/juicee/shaders/"*.gdshader "$ROOT/game/core/shaders/"
cp "$TMP/juicee/Juicee-main/addons/juicee/LICENSE.md" "$ROOT/game/core/shaders/JUICEE-LICENSE.md"

# Metal impacts: OpenGameArt "100 CC0 metal and wood SFX" (CC0).
OGA="$CACHE/100-CC0-wood-metal-SFX.zip"
[ -f "$OGA" ] || curl -sfL -A "Mozilla/5.0" -o "$OGA" https://opengameart.org/sites/default/files/100-CC0-wood-metal-SFX.zip
unzip -qo "$OGA" metal_slam_01.ogg metal_hit_03.ogg metal_falling_01.ogg -d "$TMP/metal"
sfx "$TMP/metal/metal_slam_01.ogg" mx_slam
sfx "$TMP/metal/metal_hit_03.ogg" mx_clank
sfx "$TMP/metal/metal_falling_01.ogg" mx_fall

"$ROOT/tools/make_sfx.sh" >/dev/null  # our own synthesised factory sounds

cat > "$ROOT/CREDITS.md" <<'CREDITS'
# Credits

| Asset | Author | License |
|---|---|---|
| Fluent Emoji 3D (`game/core/assets/emoji`) | Microsoft | MIT (`emoji/LICENSE.txt`) |
| Fredoka, Lilita One (`game/core/assets/fonts`) | Fredoka Project Authors; Juan Montoreano | SIL OFL 1.1 (`fonts/*-OFL.txt`) |
| Cozy Puzzle lobby music | MintoDog | CC0 |
| Rhythm Factory (in-game music) | Zane Little Music | CC0 |
| The War Over A Melon Field - Themes and Jingles (title, win, lose) | Spring | CC0 |
| Happy Clappy Loop | OwlishMedia | CC0 |
| Interface Sounds (`ui_*`), UI Pack 2.0 (`ui/`), Mini Characters 2.0, Factory Kit 3.0, Food Kit 2.0, Survival Kit, Car Kit 3.1, Retro Urban Kit (dumpsters, pallets) (`3d/`), Particle Pack (`particles/`) | Kenney (www.kenney.nl) | CC0 |
| Shockwave and speed-lines shaders (`game/core/shaders`) | kelpekk / frogy (Juicee) | MIT (`shaders/JUICEE-LICENSE.md`) |
| Factory sounds `sfx_*` (crunch, horn, alarm, splash, whoosh, thunk) | Synthesised for this game with sox (`tools/make_sfx.sh`) | CC0 |
| Metal slam, hit and falling sounds `mx_*` (100 CC0 metal and wood SFX) | OpenGameArt contributor (see the pack page) | CC0 |
| Pop, coin, pickup-coin and gem-gather sounds | Author not recorded in the download (verify before release) | CC0 |

Files were converted to OGG Vorbis and renamed; the audio was otherwise left unchanged.
CREDITS
du -sh "$OUT"/*
