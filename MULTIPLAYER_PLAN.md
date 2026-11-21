# THE LAST DROP — Co-op Multiplayer Plan (1–3 players)

The design doc ends with a choice: keep the knowledge for yourself or **share it**. Co-op turns
that theme into the gameplay itself: **nobody restores the world alone.** One careless sort
contaminates the whole team's batch; one person can't lift the gate; the relay needs two hands.

**Rule zero:** multiplayer is added *after* the 12h single-player slice works, but the slice is
built **multiplayer-ready** from hour 1 (see §6), so adding it is wiring, not a rewrite.

---

## 1. What changes for players

### 1.1 FRU-01 becomes the team's companion

| Before (tool) | After (companion) |
|---|---|
| A device the player picks up | A **floating drone** that wakes up when the first player finds it and from then on serves the whole team |
| Scan = a private popup | **Ask FRU:** any player taps *SCAN* near an object → FRU **flies there**, scans it, and the result appears **for everyone** as a world label + a line in the shared Field Notes |
| Static text | **Context-aware lines:** FRU names who did what ("SURVIVOR-2 secured the battery. Good."), comments on mistakes, notices when the team is stuck |
| — | **Hint ladder:** if no progress for 90 s, FRU gives hint 1 (a nudge), at 180 s hint 2 (where), at 270 s hint 3 (what to do). Same for solo and co-op |
| — | **Solo stand-in:** in a 1-player room FRU performs the "second pair of hands" for co-op actions (§1.3), slower than a human |

FRU behaviour = a small state machine: `FOLLOW` (orbits the team's centre) → `GOING_TO` (a scan
request) → `SCANNING` (2 s beam) → `REPORTING` → back to `FOLLOW`. Scan requests queue, so two
players asking at once get answered in order: no conflicts to resolve.

> **"Intelligent" = scripted + reactive, not an LLM, for the hackathon.** FRU's facts must be
> scientifically checked (design doc §11); a live LLM can invent wrong recycling advice and adds
> latency, cost and an API key to protect. A constrained "ask FRU anything" mode is a stretch
> goal (§8), answered only from a curated, validated knowledge file, through the server.

### 1.2 Inventory and handing items over

- **Small bags:** 4 slots per player in co-op (8 in solo). Small bags make handoffs necessary.
- **DROP:** put an item on the ground; anyone can pick it up. Dropped items glow in the dropper's colour for 5 s.
- **PASS:** with a teammate within 3 tiles, the inventory shows a *PASS →* button; the item flies to them in a short arc (0.3 s). One tap, no dragging.
- **Hazard rule:** batteries can't be thrown. They go in a **containment case** that slows its carrier by 40%. Teammates escort: they open doors and clear the way.
- **Never lose an item:** if a player disconnects, their whole inventory drops where they stood. No soft-locks, ever.

### 1.3 Co-op missions (same story, redesigned beats)

| Beat | Solo (FRU helps) | 2–3 players |
|---|---|---|
| **Gate A: the heavy gate** | Repair with steel; FRU's tractor beam lifts it in 6 s | Repair with steel, then **two players hold LIFT together** (2 s) |
| **The split dump** | One path | The dump has **two halves divided by a crusher wall**. A lever on each side opens the other side's path: players must split up and pass items over the wall |
| **Recovery Bench** | One player does CLEAN / DISMANTLE | One player holds the vice (DISMANTLE takes both a holder and a worker; 2× faster with a partner) |
| **Sorting line (new set piece)** | Conveyor at slow speed | Items arrive **on a conveyor**; each player mans different bins. Speed and item count scale with team size. **One wrong item contaminates the team's batch**: the whole batch must be re-sorted. Collective responsibility, taught by consequence |
| **Hazard sweep** | Carry batteries one at a time | Carrier is slowed; teammates open the two-key hazard locker (both keys turned within 2 s) |
| **Relay repair** | FRU holds panel 2 | **Two panels, pressed within 0.5 s of each other.** Low latency matters, and players feel it: the 5G pitch moment |

Scaling rule: every co-op action has a solo path through FRU, so a room of 1 plays the same
level. Difficulty scales with team size (conveyor speed, number of items, hint timer).

### 1.4 Talking without chat

No text or voice chat: it needs moderation, breaks on mobile and collects personal data.
Instead:
- **Ping:** long-press anywhere → a marker visible to all for 4 s ("look here").
- **4 quick signals** on a small wheel: *Over here!* · *Need hands!* · *Take this* · *Nice work*.
- FRU repeats important pings out loud ("SURVIVOR-3 needs hands at the gate").

### 1.5 Identity

- **Server-assigned callsigns** (SURVIVOR-1 … 3) + a colour per slot (amber, teal, violet), applied as a palette swap on the player sprite and on their pings, drops and toasts.
- No accounts, no names, no free text. Nothing to moderate, nothing personal stored.

### 1.6 Team end screen

Shared results: items recovered, contamination count, hazards secured, time. Then one line per
player ("SURVIVOR-2: 7 sorted, 2 batteries secured, 3 handoffs"). No individual ranking: the
leaderboard ranks **teams**.

---

## 2. Rooms and lobby

```
Title ──▶ PLAY SOLO ─────────────────────────────▶ game (room of 1, can run offline)
      ├─▶ CREATE ROOM ─▶ max players [1][2][3] ─▶ lobby: code "K7QM" + QR ─▶ host taps START
      └─▶ JOIN ROOM ───▶ type code or scan QR ──▶ lobby ──────────────────▶ game
```

- **Room code:** 4 characters from `ACDEFHJKMNPQRTWXY3479` (no 0/O, 1/I/L, 5/S, 8/B), so codes are easy to read out loud.
- **QR code** on the host's lobby screen: a teammate scans it with their phone camera and lands straight in the room (`/?room=K7QM`). Great for the live demo.
- **Max players 1–3**, chosen by the host; the server enforces it. Room 4th player gets "Room full".
- **Late join:** allowed while slots are free; the newcomer receives a full snapshot.
- **Lobby shows** each player's callsign, colour, **live latency in ms** and ready state.
- **Rooms expire** after 30 min with nobody connected.

---

## 3. Network architecture

```
Phone A ─┐                     Cloudflare edge
Phone B ─┼── WebSocket ──▶  Worker ──▶ Durable Object "room:K7QM"   (one per room)
Phone C ─┘                            ├ membership, max players, slots, callsigns
                                      ├ relays messages, stores latest snapshot
                                      └ reports recoveries ──▶ Durable Object "network" (global counter)
```

### Who decides what: host-authoritative

- **The game rules run in GDScript on the host's phone** (the room creator), the same `game.gd`
  that runs single-player. One rules implementation, no duplicate logic in JavaScript.
- **The Durable Object** is a relay with memory: membership, slot limits, validation, rate
  limits, the latest snapshot, host selection. It doesn't know recycling rules.
- **Guests send *requests*** ("pick up item 14", "sort item 14 into metal"). The host applies
  them through `game.apply()`, which accepts or rejects, and broadcasts the result. Two
  players grabbing the same item → the host's order wins, the other gets "Too slow!"
- **Host migration:** the host sends a snapshot to the DO every 2 s and after every change. If
  the host drops, the DO promotes the next player and gives them the snapshot. Worst case: 2 s
  of progress replays.

Why not Godot's built-in multiplayer (RPC/MultiplayerSynchronizer)? Its WebSocket peer needs a
Godot server process, which a Cloudflare edge can't run, and WebRTC needs a signalling server
plus TURN for phones on mobile networks. A small custom protocol over one WebSocket works on
web and Android alike and keeps the edge/5G story.

### Movement

- Each client sends its own position + facing **15 times/s** (only when it changes).
- Others are drawn **100 ms in the past**, interpolated between received positions: smooth on
  5G, survivable on 4G.
- Your own character moves instantly (client authority for movement only; nothing to cheat in co-op).
- Bandwidth: ~30 bytes × 15/s × 2 others ≈ 1 KB/s per phone.

### Messages (JSON; all < 200 bytes except snapshots)

| From → To | Message | Notes |
|---|---|---|
| C → S | `{"t":"create","max":3}` | Returns `{"t":"room","code":"K7QM","slot":1,"host":true}` |
| C → S | `{"t":"join","code":"K7QM"}` | Or `"room full"` / `"no such room"` |
| C → S → all | `{"t":"pos","x":812,"y":96,"f":2}` | Relayed, never stored |
| guest → host | `{"t":"req","a":"sort","item":14,"bin":"metal","seq":31}` | Actions: pickup, drop, pass, clean, dismantle, sort, repair, lift, press, lever |
| host → all | `{"t":"ev","a":"sort","item":14,"by":2,"ok":true,"seq":31}` | `ok:false` carries the FRU reason |
| host → S | `{"t":"snap","s":{…}}` | Full shared state; ≤ 8 KB |
| C → S → all | `{"t":"sig","k":"need_hands","x":..,"y":..}` | Pings and quick signals |
| S → all | `{"t":"members","list":[{"slot":1,"call":"SURVIVOR-1","rtt":24,"host":true}]}` | On any membership change |
| C ↔ S | `{"t":"ping","id":n}` / `{"t":"pong","id":n}` | Every 2 s; RTT shown in lobby and HUD |

### Server rules (security)

- Validate every message: max 512 bytes (8 KB for `snap`, host only), `t`/`a`/`k` from fixed
  lists, integer coordinates within the map, room code format checked before any DO lookup.
- Rate limits per socket: `pos` 20/s, everything else 10/s; excess dropped, repeat offenders disconnected.
- Only the current host may send `snap` and `ev`.
- No secrets in the client; no personal data stored; callsigns assigned by the server.
- Rooms and their snapshots auto-delete after 30 min idle (Durable Object alarm).

---

## 4. Changes to the existing design and plan

| Area | Change |
|---|---|
| FRU-01 | From inventory tool to companion node with a state machine; scan = request to FRU; shared Field Notes |
| Inventory | Slot cap (4 co-op / 8 solo); DROP and PASS actions; containment case for hazards |
| Level | Outer Dump split by a crusher wall with two levers; sorting conveyor set piece; two-panel relay; heavy gate |
| HUD | Teammate markers at screen edges, ping wheel, room code + latency in the corner, team contamination meter |
| Title | PLAY SOLO / CREATE ROOM / JOIN ROOM; lobby screen with QR |
| End screen | Team results + per-player lines; team leaderboard |
| Server | `server/` gains a `Room` Durable Object next to the global `Network` one |
| Player sprite | 3 palette swaps (generated from the LazyStone sheets with the sprite script) |
| Online counter (§9 of build plan) | Unchanged; rooms report recoveries to it |

---

## 5. What you need to do, in order

| Phase | Work | Estimate | Done when |
|---|---|---|---|
| **0. During the 12h build** | Follow the multiplayer-ready rules in §6 | ~0 extra | Single-player works through `game.apply()` |
| **1. Rooms + presence** | `Room` Durable Object (create/join/max/slots/members), lobby UI, QR, other players visible and moving with interpolation | 3–4 h | 3 phones in one room see each other walk |
| **2. Shared state** | Guest requests → host `game.apply()` → broadcast; snapshots; DROP / PASS; inventory cap | 4 h | Items picked up on one phone vanish on all; handoffs work |
| **3. Co-op mechanics** | FRU companion state machine + shared scans; LIFT/levers/two-panel/vice actions; conveyor; scaling by team size; pings + quick signals | 4–5 h | The whole slice is beatable by 1, 2 and 3 players |
| **4. Robustness** | Reconnect with the same slot (token in local storage), host migration, late join, disconnect item drop, room expiry | 3 h | Kill the host's app mid-game: the others keep playing |
| **5. Test + polish** | Automated 3-client test (Playwright opening 3 browser contexts), latency display, team end screen | 2 h | Test passes; 60-s demo video with 3 phones |

Total: **~16–18 h** on top of the 12h slice. Phases 1–2 alone already give a strong co-op demo.

---

## 6. Multiplayer-ready rules for the 12h build (do these now; they cost nothing)

1. **Every shared-state change goes through one function:** `Game.apply(action: Dictionary) -> Dictionary`
   (e.g. `{"a":"sort","item":14,"bin":"metal","by":1}` → `{"ok":false,"reason":"dirty"}`).
   UI and interactables call it; they never edit inventory, bins or gates directly.
2. **World items have stable integer IDs** assigned in the level (`@export var item_uid`), not node paths.
3. **Separate shared from per-player state** in `game.gd`: `shared` (items in world, bins, gates,
   contamination, FRU notes) vs `players[slot]` (inventory, position).
4. **Player input never touches game state**, it only produces actions. The player node is
   driven by a slot number; slot 1 is you in single-player.
5. **FRU-01 is its own scene** (`fru.tscn`) with the `FOLLOW / GOING_TO / SCANNING` state machine,
   even in single-player (it's also just nicer).
6. **Shared state is serializable:** `Game.snapshot() -> Dictionary` and `Game.restore(d)` from
   the start. Free save/load bonus.
7. **One test** (gdUnit4) replays a list of actions through `Game.apply()` and checks the final
   state. It's the single-player test now and the sync test later.

---

## 7. Testing

- **Unit:** action replays through `Game.apply()` (all routes, wrong sorts, double pickups).
- **Server:** the Room DO with Vitest + Cloudflare's Workers test pool (create/join/full/rate limit/host migration).
- **3-player end-to-end:** Playwright opens the web build in 3 browser contexts, creates a room, joins twice, completes the gate LIFT and the two-panel relay with scripted inputs.
- **Real network:** one phone on 5G, one on 4G, one on Wi-Fi in the same room; check the lobby RTTs and that interpolation hides the difference.

---

## 8. Stretch ideas (only after phase 5)

- **Ask FRU anything:** free-text questions answered by Claude *only* from a validated
  knowledge file, through the Worker (API key server-side, rate-limited, answers cached). Use
  the `claude-api` skill to build it.
- **Cross-room events:** when the global counter hits a milestone, every room's FRU announces it ("The network just passed 10,000 items").
- **Spectator mode** for judges: a big-screen view of a room.
