# TRASH PANIC! — Build brief (v3, "Trash-is-Fun" remake, 21 Nov night)

Online 2-player co-op recycling chaos for phones and the web (Godot 4.7, GL Compatibility; Cloudflare Worker +
Durable Object relay, free plan). Design source: `~/Downloads/idk.md` (the Dropper, Rush Hour, Chaos State).
Look source: the reference shots in `design/refs/` (*Trash is Fun* screenshots, the cartoon bomb, the barrel, the elephant).
**Deadline Sun 22 Nov 15:00** (freeze 12:00, submit 14:30).

## 1. The pitch (what a tester must feel within 60 s)
Two workers keep a failing recycling floor alive. A giant, broken **Dropper** rains waste (and bombs, nuclear barrels,
leaking batteries, robots and an elephant) into the room. Catch it, sort it onto the **conveyor belts**, feed the
**Recycling Machine's** orders, and keep the **POLLUTION** meter under control, or the factory goes into **CHAOS STATE**.
Success = testers laugh and shout instructions at each other, ask for another shift, and can say where a bomb, a battery
and nuclear waste go.

## 2. What stays, what changes (decided)
| Keep (works, tested, online) | Rebuild |
|---|---|
| `net/`, `server/`, Match/Clock, host-authoritative `Shift` + `Mayhem` rules, sync format, tests | the room (layout + belts), every visual (`room_view`, `room_decor`, `item_art`, `creature_view`, `avatar`), the HUD, camera, colours, juice |

Non-goals: rooms 2+, accounts, leaderboards, bots, chat, shops, ads, analytics, ragdolls.

## 3. Art direction: match `design/refs/trash_is_fun_*.jpg`
- **Camera**: high three-quarter view (pitch about 58°, fov 40), the whole room on screen in landscape, slight perspective. No clipping at the edges.
- **Floor**: small square tiles (4 per game tile), white plus soft teal checker with thin grout; outer walk lanes in a darker teal.
- **Room edge**: a low dark steel wall with a red trim line, outside it a *harbour*: deep blue animated water with foam, a dock, and a moored boat or barge. Room = a platform on the water.
- **Machines**: chunky dark charcoal boxes (`#3A3F48`) with rounded bevels, coloured side panels with slot lights, **chevron conveyor belts** (grey with dark chevrons that scroll), **yellow/black hazard pads** at belt ends.
- **Floor decals**: round icon badges (dark disc, yellow ring, white icon) in front of every station, and **curved yellow arrows** painted on the floor that show the flow (drop zone → belt → machine).
- **Workers**: cute chunky characters standing on a **coloured ring** (P1 orange, P2 blue), big readable silhouettes.
- **Props**: cones, barrels, sandbags, crates, a red tool cart; all low-poly, flat-coloured (Kenney kits).
- **HUD** (thick white outline, black glyphs, chunky): top-left, the **POLLUTION** and **MACHINE** bars (segmented, green → red); top-right, the **order cards** as coloured bins with counts; bottom-left, a **dumpster** with the score; bottom-right, a **CRT monitor** with the timer, a skull counter (disasters) and a small Rush/Chaos clock.
- **Specials**: the bomb is a round purple-black bomb with a green LCD fuse (`bomb_prop.jpg`); nuclear waste is a rusty yellow barrel with a green glow; the elephant is big, grey and cute.
- **Lighting**: bright, warm sun plus cool sky ambient, soft shadow blobs under everything (no real-time shadows on mobile).

## 4. Room 1, "The Sorting Floor" (15 x 9 tiles, `game/rooms/sorting_room.txt`)
```
###############
#R.....|.MMMMM#     R shielded container   M machine inputs METAL PLASTIC PAPER WOOD GLASS
#...>>>>>>....#     belt A carries left → right
#......|......#
e..1...g...2..e     e exit doors (elephant), g gate, 1/2 spawns
#......|......#
#...<<<<<<....#     belt B carries right → left (hazards back to the bins)
#K..B..|......#     K emergency chute   B battery bin
###############
```
- 70 % of the waste lands on the LEFT, so worker 1 catches and sorts onto belt A; worker 2 feeds the machine.
- Hazards that land on the right go back on belt B (or get thrown over the rail): both workers matter.
- **Belts**: an item on a belt tile moves one tile every 0.55 s (0.35 s in Rush Hour) until the end tile; anyone next to a belt tile can place or grab. A blast can **jam** a belt tile or rail tile (hold USE 2.5 s to repair).

## 5. Rules (numbers live in `core/rules.gd`)
Unchanged from the tested build unless listed: 180 s shift, stars 150/400/650, +5 right input, −5 wrong, orders up to 3
(15 + 8 per item + speed tip), final contract at 150 s, Rush Hour 110–135 s (×2 points, faster drops/belts/orders),
specials from 30 s every 13 s (max 2 alive) with a shadow + alarm 1.8 s ahead.
**New:**
- **Belts** as above; **Reverse World** flips both belts (and nothing else; reversed controls were not fun on touch).
- **Chaos modifiers** (one random, 20 s): Blackout, Reverse World, Hurricane, Robot Invasion, **Low Gravity** (workers bounce, throws go 2 tiles further), **Magnetic Madness** (loose cans slide toward the machine every 0.6 s).
- **New intruders** in the Dropper's bag: **pig** (the goat's job: walks to paper/boxes and eats them, −3 each; hold USE 1 s, +10; the only goat model is CC-BY), **chicken** (knocks waste off belts; USE 0.6 s, +5), **monkey** (throws waste around; USE 1 s, +10).

## 6. Assets (CC0 only, credited in `CREDITS.md`)
In repo: Kenney Factory, Food, Survival, Mini Characters, City Industrial, Car, Particle, UI kits; Fluent emoji; Lilita One
and Fredoka fonts; CC0 music (Rhythm Factory, Melon Field); Kenney interface sounds.
Imported (CC0): Quaternius Panda/Rabbit/Cyan Rabbit workers (carry + work animations), Quaternius raccoon and robot,
Kenney Cube Pets elephant/monkey/chick/pig (`game/core/assets/3d/animals`); Fluent High Contrast glyphs for badges/HUD.
More options staged in `~/.cache/last-drop-assets/staging/` (README lists licences). Optional manual download:
Kenney Cube Pets latest (24 animals) from kenney.nl/assets/cube-pets.

## 7. Milestones (each ends with `tools/test.sh` green and a 1280x720 shot from `tests/shot.tscn`)
Status 22 Nov ~00:30: V0–V5 done (tests green, shots match the refs); V6 open: ask the user before build/deploy/install.

| # | Milestone | Check |
|---|---|---|
| V0 | Plan, refs, dev tools (screenshot tool, project skill, prompt) | this file, `design/refs/`, `.claude/skills/trashpanic-dev` |
| V1 | **Room + belts** (layout, belt sim in `Shift`, sync, validator + tests) | items ride belts across; tests cover belts, jam, reverse |
| V2 | **The look** (camera, tiled floor, harbour, machines, belts, decals, arrows, props, lighting) | side by side with `trash_is_fun_dock.jpg`, it reads as the same genre |
| V3 | **Characters + specials art** (animal workers with rings, bomb with LCD fuse, barrel, battery, creatures) | every item and creature recognisable at phone size |
| V4 | **HUD** (bars, order bins, dumpster score, CRT timer, banners for Rush Hour and Chaos State) | readable at arm's length on the S23 |
| V5 | **Chaos pack** (Low Gravity, Magnetic Madness, goat, chicken) + juice/audio pass | a muted 10 s capture looks like a trailer |
| V6 | **Ship**: security re-review, web build + APK, two-device playtest | ≥ 30 fps on the S23, live by 14:30 |

## 8. Tech constraints
Landscape 1280x720 base; 60 fps target / 30 floor on the S23 Ultra; static geometry and every item kind are merged into
one vertex-coloured mesh (`core/bake.gd`): 471 draw calls measured on desktop with shadows (was 1317); check fps on the
phone. APK ≤ 100 MB. Network: positions 10 Hz, deltas on change, snapshot every 3 s, messages
≤ 512 bytes. Keep the server's protections (Origin check, caps, rate limits). **Ask before** deploying, installing on the
phone, committing, pushing.
