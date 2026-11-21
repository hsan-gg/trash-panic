# THE LAST DROP — 12-Hour Build Plan

Goal: a **playable, polished Chapter 1 slice** (~5–7 min of play) that proves the loop
**EXPLORE → SCAN → COLLECT → CLEAN/DISMANTLE → SORT → REPAIR → DISCOVER**.

"The whole game" in 12h = this slice. Chapters 2–5 live in the pitch, not the build.

**Assumptions:** solo dev, Godot 4.3+ (GDScript), 2D top-down, landscape, mobile touch.
Placeholder art first, real art only after the loop works.

**Online + 5G (hackathon requirement):** the game is a hosted web app with a live
**community recovery network** served from edge servers. See §9.

---

## 1. The slice in one screen

```
[ Settlement ] → [ Outer Dump ] →(Gate A)→ [ Sorting Centre ] →(Door B)→ [ Relay Tower ]
   intro          find FRU-01      repair      bench + 6 bins      opens      repair relay
                  collect items    w/ steel    sort everything     when       → signal
                                                                    sorted      → END
```

One level scene, left to right. No zone loading, no save system.

### Progression gates (each one teaches one idea)

| Gate | Requirement | Lesson |
|---|---|---|
| Scan unlocked | Pick up FRU-01 | Your tool for understanding materials |
| **Gate A** (dump → centre) | REPAIR with 2× Steel Scrap | Waste can be a resource (reuse) |
| **Door B** (centre → relay) | All sortable items sorted correctly | Sorting + contamination + hazards |
| **Relay** | REPAIR with Circuit Board + Copper Wire | Recovered components restore systems |

---

## 2. Items (the whole content list)

| id | Name | Scan text (FRU-01) | Route |
|---|---|---|---|
| `fru01` | Field Recovery Unit | — | Pickup → unlocks Scan |
| `steel_scrap` ×2 | Steel scrap | "Steel. Structurally sound. Reusable as-is." | Gate A repair |
| `can_alu` | Aluminium can | "Aluminium. Clean. Recyclable repeatedly without quality loss." | Metal bin |
| `cardboard` | Cardboard box | "Paper fibre. Dry, clean. Recoverable." | Paper bin |
| `bottle_full` | Plastic bottle (not empty) | "PET plastic. Contains liquid. Empty before recovery." | Bench CLEAN → `bottle_clean` → Plastic |
| `jar_dirty` | Glass jar (food residue) | "Glass. Food residue detected. Rinse first." | Bench CLEAN → `jar_clean` → Glass |
| `pizza_box` | Greasy pizza box | "Paper fibre saturated with grease. Fibre recovery not possible. Local rules vary; this facility composts it." | CLEAN fails → Organic bin |
| `peel` | Banana peel | "Organic. Compostable." | Organic bin |
| `cable` | Tangled cable | "Copper core, plastic sheath. Separate before recovery." | Bench DISMANTLE → `copper_wire` + `sheath` |
| `sheath` | Plastic sheath | "Plastic. Recoverable." | Plastic bin |
| `phone` | Broken phone | "E-waste. Contains a lithium battery. Do not bin. Dismantle with care." | Bench DISMANTLE → `circuit_board` + `battery_phone` |
| `battery_loose` | Swollen battery | "Lithium cell, swollen. Fire risk if crushed. Hazardous collection only." | Hazard point |
| `battery_phone` | Phone battery | "Lithium cell. Hazardous collection only." | Hazard point |
| `copper_wire` | Copper wire | "Recovered copper. Conductive." | Relay repair |
| `circuit_board` | Circuit board | "Salvageable components." | Relay repair |

**Bins:** Metal · Plastic · Paper · Glass · Organic · **Hazardous point** (red, separate).

**Sorting quota for Door B:** can, cardboard, bottle_clean, jar_clean, pizza_box, peel, sheath, battery_loose, battery_phone (9 deposits).

### Wrong-choice rules (no soft-locks, ever)
- Wrong bin → refused, item **stays in inventory**, contamination counter +1, FRU-01 says why.
- Dirty item in the right bin → refused: "Residue would contaminate the batch. Clean it first."
- Battery in any normal bin → red flash + screen shake: "Lithium in mixed waste causes fires in trucks and plants."
- Steel scrap / copper / board in a bin → "This is more useful reused. Keep it."
- End screen shows contamination count. That's the only penalty.

---

## 3. Mobile controls

- **Left:** virtual joystick (custom, ~40 lines).
- **Right:** big ACTION button whose label changes: COLLECT / REPAIR / SORT / USE BENCH / ACTIVATE.
- **Right, above:** SCAN button (hidden until FRU-01) — one tap scans the **nearest** interactable, highlighted with an outline.
- **Top-right:** BAG icon → inventory grid.
- **Top-left:** current objective (one line).
- **Bottom:** FRU-01 message box (typewriter text, tap to dismiss).

Interacting with a bin or bench opens the **same inventory grid in "pick an item" mode**.
No dragging. All buttons at least 96 px tall in a 1280×720 viewport.

---

## 4. Architecture (smallest thing that works)

```
res://
  game.gd            # autoload: ITEMS dict, shared state + players[slot], apply(action), snapshot()/restore()
  player.tscn/.gd    # CharacterBody2D + Area2D "reach"; tracks nearest interactable; driven by a slot number
  fru.tscn/.gd       # FRU-01 companion drone: FOLLOW / GOING_TO / SCANNING state machine
  interactable.gd    # Area2D, @export kind (pickup|bin|bench|hazard|gate|relay), item_id, bin
  hud.tscn/.gd       # joystick, buttons, prompt, objective, message box
  inventory.tscn/.gd # grid; mode = view | pick(callback)
  level.tscn         # the whole map, tiles + placed interactables
  intro.tscn         # 3 text cards + skip
  ending.tscn        # story fragment + field notes + stats
```

- **Data lives in one dict** in `game.gd`: `ITEMS[id] = {name, scan, bin, needs_clean, clean_to, dismantle_to, hazard}`.
- `interactable.gd` exposes `prompt()` and `interact()`; the player calls the nearest one. Everything else is `match kind:`.
- Progress = a few booleans in `game.gd` (`has_fru`, `gate_a_open`, `sorted_count`, `relay_fixed`). No quest system.
- **Multiplayer-ready (costs ~nothing now, saves a rewrite later):** every state change goes through
  `Game.apply(action) -> result`; world items have stable integer IDs; shared state is kept apart from
  `players[slot]`; `Game.snapshot()` / `Game.restore()` exist from the start. Rules in `MULTIPLAYER_PLAN.md` §6.
- **Self-check:** an `_ready()` assert loop in `game.gd` that verifies every quota item has a reachable route (bin exists, `clean_to`/`dismantle_to` targets exist). Catches typos in the item table, which is the most likely bug.
- **`net.gd`** (autoload): one WebSocket to the edge server, auto-reconnect, offline queue, ping every 5 s. The game never waits on it. See §9.
- **`server/`**: one Cloudflare Worker + one Durable Object (~120 lines JS), deployed separately from the game.

Project settings: viewport 1280×720, stretch `canvas_items` / `expand`, orientation landscape,
`emulate_touch_from_mouse = true` so you can test with a mouse.

---

## 5. Hour-by-hour schedule

| Time | Task | Done when |
|---|---|---|
| **0:00–1:00** | New Godot project, settings. **Deploy a blank web build + the echo Worker to Cloudflare, open it on your phone over 5G**, check the APK installs | Blank game loads from a public URL on mobile data and gets a WebSocket reply. All infra risk is gone by hour 1. |
| 1:00–2:15 | Level blockout (tiles + collision), player movement, joystick, camera follow | Can walk the whole map on phone |
| 2:15–3:15 | `interactable.gd`, nearest-target detection, highlight, ACTION button + prompt label | Prompts change as you walk past things |
| 3:15–4:30 | `game.gd` item table, pickup, inventory grid, SCAN + FRU-01 message box | Pick up FRU-01, scan and collect items |
| 4:30–6:00 | Bench (CLEAN / DISMANTLE), bins, hazard point, all feedback messages | Every item in §2 routes correctly |
| 6:00–7:00 | Gate A, Door B, relay repair, objective text, end trigger | Start → finish playable offline |
| **7:00** | **MECHANICS FREEZE.** Play it end to end twice. | No new mechanics after this point |
| 7:00–8:15 | **Online:** `net.gd`, recovery events, relay "network online" reveal, live counter, signal meter, end-screen leaderboard | Two phones see each other's recoveries live |
| 8:15–9:30 | Art pass: tilesets, item icons, bin colours, player sprite, zone tints | Readable on phone at arm's length |
| 9:30–10:00 | Intro cards, relay story fragment, ending screen | Story wraps around the loop |
| 10:00–10:30 | Juice: SFX (pickup, scan, correct/wrong, repair) + 2 tweens | Every action has feedback |
| 10:30–11:15 | Playtest on a phone **on 5G** with someone new. Fix the top 3 confusions only. | A stranger finishes without help |
| 11:15–12:00 | Final deploy, 60-s video **showing two phones and the live counter**, screenshots, pitch notes | Submitted with time to spare |

### If you're behind at 7:00, cut in this order
1. Dismantling the cable (put `copper_wire` in the world directly; drop `sheath`)
2. Glass jar (fewer items)
3. Leaderboard (keep the live counter)
4. Live event feed toasts (keep the live counter)
5. Intro cards (one line of text instead)
6. Typewriter effect, shake, particles
7. Android APK (ship web only)

**Never cut:** the battery/hazard moment, the greasy pizza box, the relay repair, the end screen,
**the live counter reveal and the signal meter** (they are the 5G demo).

---

## 6. Story text (write once, paste in)

**Intro (3 cards):**
1. "The settlement's last water filter is failing. Twelve days of clean water left."
2. "Last night, the old radio picked up a broken signal: *…the Last Drop… recovery network… Sector 01…*"
3. "Sector 01 is the Great Dump. Nobody goes there anymore."

**FRU-01 boot (on pickup):** "Field Recovery Unit 01. Owner record: corrupted. Storage: 4%. … Hello. You are not my operator."

**Relay restored (story fragment):**
"*Log 0417 — Recovery centre maintenance. Third budget cut this year. Sorting line B shut down. Batteries going straight to the pit again. I flagged it. Nobody came. If the network's still up when someone finds this: the treatment station in Sector 02 still has its records. Start there.*"

**Ending card:** "Signal restored. Next destination: Sector 02 — The Dead River."
→ **Field Notes** (unlocked lessons, one line each) + **Stats** (items recovered, contamination count, hazards secured)
→ "The world wasn't destroyed in a single day. And it won't be rebuilt in one either."

**Field Notes (shown at the end):**
- Discarded doesn't mean useless; steel and copper can be reused directly.
- Dirty items contaminate recycling batches. Empty and rinse first.
- Greasy paper can't be recycled as paper. Local rules vary.
- Lithium batteries never go in normal waste: they cause fires.
- E-waste hides both valuable parts and hazardous ones.

---

## 7. Assets (pre-made assets are allowed; 16×16 grid)

All candidates and licenses are in `assets_candidates/` (open `index.html`).

| Zone | Main pack | Supporting |
|---|---|---|
| Settlement | Zombie Apocalypse Tileset (farm, windmill, fences) | none |
| Outer Dump | LazyStone (Garbage tiles, Bleak-Yellow ground) | Zombie wrecked cars/barrels, Codemanu 8×8 debris on top |
| Sorting Centre | LazyStone brick walls/fences | Kenney Tiny Factory, 16× conveyor belt |
| Relay Tower | Antenna + communication terminal | Zombie radio prop |
| Player / UI | LazyStone `Character/Main`, LazyStone inventory + crafting UI | Kenney Mobile Controls |

- **Never use** the zombies, weapons or blood from these packs.
- **LazyStone is free for non-commercial use only** (commercial = $2). **Zombie + LazyStone forbid redistribution**: keep raw packs out of public git.
- Zone tints via CanvasModulate: settlement `#d8c8a8`, dump `#8a8070`, centre `#7a8a96`.
- Keep a `CREDITS.md` as you go; every pack has a `SOURCE.txt` with author and license.

---

## 8. Stretch goals (only if done before hour 10)

- **Repair vs dismantle:** a broken fan that can be repaired (lights the centre) or dismantled (gives a spare copper wire).
- Two-star rating on the end screen: zero contamination = ★★.
- Auto-collect for harmless small items.

---

## 9. Online & 5G design

### The pitch in one line
*"FRU-01 is a field device on a 5G recovery network: every item you recover is streamed live
to an edge server and shared with every other survivor, in tens of milliseconds."*

5G is the phone's network, not an API. The game shows it off by being **built for low
latency end to end**: 5G radio + an edge server close to the player + a persistent
connection + tiny messages. The game **measures and displays the real latency** instead of
claiming a number.

### Features (in the order players meet them)

1. **Signal meter** in the FRU-01 HUD: bars + live round-trip time in ms, measured with a
   ping every 5 s. Before the relay is fixed it reads "LOCAL MODE".
2. **Relay reveal (the story beat):** repairing the relay turns on the network view:
   *"Recovery network online. You are not alone: 12,408 items recovered by 312 survivors."*
   This ties straight into the design doc's "share the knowledge" ending.
3. **Live counter + event feed:** every correct sort sends one event. All connected players
   see the counter tick up and a short toast: *"SURVIVOR-4821 secured a lithium battery."*
4. **End-screen leaderboard:** fewest contamination errors, then fastest time.

### Architecture

```
Phone (5G) ──WebSocket──▶ Cloudflare edge (nearest city)
   Godot web build            Worker ─▶ Durable Object "network"
   net.gd                     (counter, top-10, broadcast to sockets)
```

- **Hosting:** Godot web export served by Cloudflare (Workers static assets).
  Export **single-threaded** (no COOP/COEP headers needed) with **PWA on**, so after the
  first load the game starts instantly from the phone's cache and can be added to the
  home screen.
- **Server:** one Worker + one Durable Object holding the counter and top-10, broadcasting
  to connected sockets (WebSocket hibernation API keeps it inside the free tier).
- **Why a persistent WebSocket:** one handshake, then each event is a single small frame.
  No HTTP request per event, so latency ≈ network round trip.

### Messages (JSON, all < 120 bytes)

| Direction | Message | Notes |
|---|---|---|
| C → S | `{"t":"hello","v":1}` | Server replies with a **server-assigned** callsign |
| C → S | `{"t":"rec","k":"hazard"}` | `k` ∈ metal, plastic, paper, glass, organic, hazard, repair |
| C → S | `{"t":"ping","id":17}` | Every 5 s |
| C → S | `{"t":"score","contam":0,"secs":312}` | Once, at the end |
| S → C | `{"t":"state","total":12408,"online":31,"call":"SURVIVOR-4821","top":[…]}` | On connect |
| S → C | `{"t":"ev","k":"hazard","call":"SURVIVOR-4821","total":12409}` | Broadcast |
| S → C | `{"t":"pong","id":17}` | Client computes RTT |

### Rules that keep it safe and robust
- **The game never waits on the network.** Fully playable offline; events queue and send
  when the connection returns. Hackathon Wi-Fi and mobile data will drop.
- **No player-typed text anywhere.** Callsigns are generated by the server, so there's
  nothing to moderate and no personal data is collected.
- **Validate everything on the server:** max message size 256 bytes, `t` and `k` from a
  fixed list, max 5 messages/s per socket, score bounds (`contam` 0–50, `secs` 60–3600).
  Bad messages are dropped.
- **No secrets in the client.** The WebSocket URL is public; the server's validation is
  the protection.
- shortcut: scores can still be faked by a determined player. That's acceptable for a
  hackathon; a real release would need server-side replay checks.

### Demo plan for judges
Two phones on 5G side by side. Recover a battery on phone A and the counter and toast
appear on phone B immediately; point at the ms reading on the signal meter. Then
turn on airplane mode on phone A, keep playing, and turn it off: the queued events sync.
