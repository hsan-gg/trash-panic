# THE LAST DROP — Asset Combination Plan

**Grid: 16×16.** World renders at 320×180 and scales ×4 to 1280×720 (Nearest filter). HUD on a separate layer at 1280×720.

Sources (all under `assets_candidates/`):
- **Z** = `9_manual/zombie-apocalypse/Zombie Apocalypse Tileset/Organized separated sprites/`
- **L** = `9_manual/lazystone-postapoc/`
- **G** = `10_generated/` (made for this game, CC0; regenerate with `gen_sprites.py`)
- **K** = Kenney packs in `1_tiles_environment/` and `3_ui_controls/`

---

## 1. Zone by zone

| Zone | Ground | Walls / borders | Props | Tint |
|---|---|---|---|---|
| **Settlement** | Z `Terrain Variations`, `Modular Terrain Path`, `Grass with Flowers` | Z `Modular Fences` | Z `Windmill with Fan Animation Frames`, `Different Crops Lengths`, `Scarecrow`, `Modular Barns`, `Trees`, `Modular Bushes` | `#d8c8a8` (warm, alive) |
| **Outer Dump** | L `Tiles/Background_Bleak-Yellow_TileSet.png` + L `Tiles/Garbage_TileSet.png` as piles | L `Tiles/Wire-Fence`, `Iron-Fence_TileSet.png` | L `Objects/`: Trash-bag, Garbage-Bin, Tire, Barrel_rust, Shopping-cart, Refrigerator, Washing-machine, Container, Traffic-cone, Street-Light (Overgrown), Vending-machine (Overgrown); Z `Broken Cars and Tires`, `Smoke Animation Frames` (smouldering piles) | `#8a8070` (darkest) |
| **Sorting Centre** | K `tiny-factory` floor tiles | L `Tiles/Brick-Wall_TileSet.png`, `Roof_TileSet.png`, `Gutter-And-Downspout.png` | K `16x-animated-conveyor-belt`, K `tiny-factory` machines, **G bins ×6**, **G `recovery_bench`** | `#7a8a96` (cold, industrial) |
| **Relay Tower** | Z `Modular Terrain Path` | L `Tiles/Iron-Fence_TileSet.png` | **G `relay_broken` → `relay_fixed`**, `1_tiles_environment/communication-terminal-32x32` | `#7a8a96` → brightens when repaired |

**Gates:** Gate A = L `Objects/Buildable/Wooden` (broken) → `Objects/Buildable/Reinforced` (repaired). Door B = Z `Urban Assets` door, or the conveyor shutter in K `tiny-factory`.

## 2. Characters

| Role | Asset | Notes |
|---|---|---|
| Player | L `Character/Main/` **`*NoHands*` / `*no-hands*` sheets**: Idle, Run, Pick-up (4 directions) | ~11×17 px. The no-hands versions carry no weapon. Never use Bat, Guns, Punch or Death. |
| FRU-01 | **G `fru01_a` + `fru01_b`** | 2-frame hover, follows the player at an offset. |
| Ambient life | Z `Black Bird Flying and Ground Eating Animation Frames` (eating/flying frames only) | Birds in the settlement only = the dump feels dead by contrast. |

**Never use:** any zombie, weapon, blood, corpse, explosion, money or ammo sprite.

## 3. Items (inventory + world pickups): all generated, one consistent set

`G/`: `steel_scrap`, `can_alu`, `cardboard`, `bottle_full` → `bottle_clean`, `jar_dirty` → `jar_clean`, `pizza_box`, `peel`, `cable` → `copper_wire` + `sheath`, `phone` → `circuit_board` + `battery_phone`, `battery_loose`.

Why generated: no pack has these 15 objects at 16×16 in one style, and inventory icons must read as a set.

## 4. UI

| Element | Asset |
|---|---|
| Joystick, ACTION, SCAN buttons | K `3_ui_controls/mobile-controls` (Style A). Large PNGs: scale down, keep ≥ 96 px on screen |
| Inventory grid / Bench panel | L `UI/Inventory`, `UI/Crafting` (cell, plus, arrow, equal) |
| Signal meter | **G `signal_0` … `signal_4`** + ms readout |
| Font | `7_fonts/boxy-bold-font` (CC0) for titles; **Pixelify Sans** (Google Fonts, download yourself) for body text |
| Dust particles | **G `dust`** in a GPUParticles2D over the whole map |

## 5. Audio

| Use | Asset |
|---|---|
| Scan beep, menu taps | `4_sfx/interface-sounds` |
| FRU-01 text | `4_sfx/typewriter-sounds` (play 1 random click every 2–3 letters) |
| Repair / plug in | `4_sfx/sfx-plug-in-plug-out`, `4_sfx/sci-fi-sounds` |
| Relay powered on | `4_sfx/electric-buzz` |
| Correct / wrong sort | `4_sfx/sci-fi-sounds` (two contrasting short ones) |
| Ambience | `4_sfx/loopable-dungeon-ambience` (low, under music) |
| Music | `5_music/lone-scavenger` (CC0) |

## 6. Rules for making it look like one game

1. Everything on the 16×16 grid. Codemanu 8×8 pieces only as scattered debris decals.
2. One CanvasModulate tint per zone, tweened over 1 s at zone borders.
3. Glow (WorldEnvironment) only on interactables, FRU-01's eye and the relay light: players see what's usable at a glance.
4. Shadows: a 50% black ellipse under the player, FRU-01 and big props.

## 7. Licences and credits

| Pack | Terms | Action |
|---|---|---|
| Zombie Apocalypse | Commercial OK, **no redistribution**, credit appreciated | Credit; keep raw pack out of public git |
| LazyStone | **Free non-commercial; commercial needs $2**, no redistribution | Fine for the hackathon; pay $2 before any commercial release |
| Kenney, generated, most OGA packs | CC0 | Credit optional (we credit anyway) |
| Any pack with an orange badge in `index.html` | CC-BY / OGA-BY | **Must** be credited in `CREDITS.md` |
