# TRASH PANIC! — v5 plan: one game, three maps (22 Nov 07:30)

The user's call (22 Nov): no chapters. TRASH PANIC! is ONE game (the co-op Sorting Floor). It gets **different maps**,
each with its own **theme, layout, animals and obstacles**. ROT & ROLL must tilt **often**. Better **scoring and
quests**, **3 stars reachable**, difficulty that **ramps up over the shift**, **soundtracks + visual effects**, a better
looking **UI** (bars, buttons, quests). Workers: remove the man and the woman, **add a monkey**.

## 1. Remove
- Chapters 2-3 (forest, beach): `core/worlds/*`, `core/world.gd`, `rooms/forest.txt`, `rooms/beach.txt`, every World hook
  (Shift, Mayhem, Guide, HUD goal card, Session branches, RoomView decor choice, CreatureView smog/turtle/gull/boar,
  ItemArt seed/water/compost/bag/net/turtle/oil, glyphs tree/turtle/seed/water, their tests, soak bots, credits, models).
- Workers MOHAWK MAX and RIOT ROXY (`characters/punk_a|b`). The monkey intruder (the monkey is a hero now).

## 2. Maps (menu picker "MAP", the room's host picks; every map is the same co-op game)
| # | Map | Theme / look | Layout | Machine inputs | Animals | Obstacles | Music |
|---|---|---|---|---|---|---|---|
| 1 | THE SORTING FLOOR | harbour, day, teal | `sorting_room` (belts rows 2/6) | metal plastic paper wood glass | raccoon, elephant, chicken, pig | bombs, nuclear barrels, batteries, shark, jams | Rhythm Factory |
| 2 | ROT & ROLL | compost yard, mossy green | `rot_room` (long belts by the gate, crates) | metal plastic paper COMPOST glass | pig, raccoon, chicken | food rots after 12 s, **the floor tilts every 8 s** (first at 6 s) and round waste rolls to the shark | Chiptune Adventures "Stage 1" |
| 3 | CIRCUIT BREAKERS | e-waste plant, purple night | `circuit_room` (bins swapped, counters by the gate) | metal plastic CIRCUITS COPPER glass | robot, raccoon, elephant | inputs trip (hold USE), many batteries, magnet chaos | Chiptune Adventures "Stage 2" |
RUSH HOUR on every map switches to "Boss Fight" (Chiptune Adventures, CC0).

## 3. Difficulty ramps up: 5 levels, one every 36 s (`Rules.level()`)
| Level | Waste every | Specials every / max alive | Order every | Belt step |
|---|---|---|---|---|
| 1 | 4.4 s | 20 s / 1 | 14 s | 0.60 s |
| 2 | 3.8 s | 17 s / 2 | 12 s | 0.55 s |
| 3 | 3.2 s | 14 s / 2 | 10 s | 0.50 s |
| 4 | 2.7 s | 12 s / 3 | 9 s | 0.45 s |
| 5 | 2.2 s | 10 s / 3 | 8 s | 0.40 s |
RUSH HOUR (110-135 s) stays on top (x2 points, faster). Each level-up: banner, flash, music a little faster.

## 4. Scoring, combo, quests, stars
- **Combo**: each right delivery (input, bin, order) within 6 s of the last adds 1; multiplier x1 → x1.5 (3) → x2 (6) →
  x3 (10). A wrong input resets it. Shown as a flaming COMBO pill.
- **Quests**: 3 per shift drawn from the map's pool with the seed (both phones agree): sort 20 right · fill 4 orders ·
  make 3 hazards safe · catch 2 intruders · reach x2 combo · fix 2 jams/breakers (map 3) · compost 6 food (map 2) ·
  end under 40 % pollution. +40 coins each, stamped DONE on a quest card.
- **Stars**: 80 / 200 / 340 coins (with combo + quests a decent team gets 3).

## 5. Audio + visual effects
Music per map + rush track (CC0, Juhani Junkala). VFX: level-up shockwave + flash, combo fire pill, quest stamp + confetti,
order-complete confetti, dash sparkle trail, star burst on the star bar.

## 6. UI
Glossy 3D buttons (light top, dark bottom edge, press-down), segmented bars with rounded segments and shine, star bar with
glowing star slots, quest panel (left, under the stars: icon, text, progress bar, check), rounder order cards.

## 7. Workers
PANDA, BUNNY, PUNK BUNNY, **MONKEY** (Quaternius Monkroose, CC0, animated).

## 8. Done when
`tools/test.sh` green (maps validated, combo, quests, levels, soak on all 3 maps with sync), shots of each map + title,
web + APK built (deploy/install on the user's go).

## 9. Status (22 Nov 07:40)
Done: chapters 2-3 removed; 3 maps (rooms `sorting_room`, `rot_room`, `circuit_room`), map picker + map backdrop on the
menu; MONKEY worker (Kenney Cube Pets monkey: the Quaternius Monkroose looked like a green alien), punks removed, monkey
intruder removed; 5 difficulty levels; combo + 3 quests + stars 80/200/340; per-map music + boss track in RUSH HOUR;
VFX (level shockwave, rush speed lines, quest stamp confetti, ship confetti, combo sparks, dash sparkles); glossy 3D
buttons, rounded glossy meter, rimmed star bar, quest cards, combo pill, level badge. Game version 10.
Tests: maps validated, scoring test (levels, combo, quests, guest sync); soak plays all 3 maps (bots 260-1450 coins).
Web + debug APK built locally; deploy/install waits for the user's go.
