# Co-op protocol (WebSocket `/play`, JSON text frames)

TRASH PANIC! is a 2-player co-op game. The server **pairs players, keeps the shift clock and relays**;
the **host's phone simulates the room** (items, stations, orders, score). One Durable Object (`Lobby`,
named "main") holds every room in memory. Server time = `Date.now()` ms; all `*_at` fields are server time.

## Client → server
| msg | meaning |
|---|---|
| `{t:"ping", id, ct}` | clock sync; reply `{t:"pong", id, ct, st}`. Works before `hello` |
| `{t:"hello", name, skin, v:2, mode, code?}` | `mode`: `"quick"` (random partner; waits until one arrives), `"create"` (private room, get a code), `"join"` (with `code`, 4 letters). name ≤ 12 chars `[A-Za-z0-9 _-]`, skin 0–3 |
| `{t:"s", p, y, a, h}` | my state, ≤ 10 Hz: pos `[x,y,z]`, yaw, anim id 0–31, held item id or -1 |
| `{t:"to", d}` | game payload for my partner (host → guest: events; guest → host: intents). `d` is any JSON object; frame ≤ 512 bytes |
| `{t:"snap", d}` | host only: full room snapshot for the guest, ≤ 4096 bytes, at most 1 per second |
| `{t:"again"}` | after `end`: ready for another shift with the same partner |

## Server → client
| msg | meaning |
|---|---|
| `{t:"welcome", id, st}` | your player id |
| `{t:"waiting", mode, code?}` | waiting for a partner; `code` for private rooms |
| `{t:"start", seed, start_at, ends_at, host, solo, players:[{id,name,skin}]}` | a shift begins: 3.5 s countdown, then 180 s. `host` simulates the room |
| `{t:"s", id, p, y, a, h}` | partner state (relayed) |
| `{t:"from", d}` / `{t:"snap", d}` | partner payload / host snapshot (relayed) |
| `{t:"left", id}` | partner disconnected: the remaining player becomes host and plays solo |
| `{t:"end"}` | at `ends_at` |
| `{t:"error", code}` | `"no_room"` (bad code, or a room that already started), `"bad_hello"` |

## Rules
- Quick match pairs the two oldest waiting quick players. Shifts need two players; nobody starts alone.
- Private rooms: `create` returns a 4-letter code from `BCDFGHJKLMNPQRSTVWXZ` (no vowels); `join` with that code starts the shift at once.
- After `end`, when every remaining player has sent `again`, a new `start` follows (new seed). A room with nobody left is deleted; a room idle for 10 min is deleted.
- Only the host may send `snap`; `to` is relayed only between the two players of one room; nothing is relayed outside `start_at`-3.5 s … `ends_at`+10 s.
- Limits (security reviews): Origin check (browsers), ≤ 200 sockets, ≤ 8 per IP (IPv6 per /64), 20 frames/s per socket (closed after 20 over-limit frames in one second), a global 6,000 frames/min budget that closes the heaviest sender, close 10 s after connecting without a seat (pings don't count) or after 30 s without a valid frame, 3 wrong room codes per address per minute, frames ≤ 512 bytes except `snap` ≤ 4096, JSON nesting ≤ 8, relay ≤ 15 `s`/s and ≤ 20 `to`/s per player, codes and seeds from a CSPRNG.

## Notes
- `waiting.mode` is `"quick"` or `"create"` (with `code`). A joiner of a private room gets no `waiting`, only `welcome` then `start`.
- `welcome` is sent only once a `hello` is accepted. After an `error` the socket stays open with no room: the client may send another `hello` (e.g. a corrected code) within 10 s, or it is closed.
- `bad_hello`: `mode` missing/unknown, or `join` without a valid code. Codes are case-insensitive (uppercased by the server). Joining a room that has already started returns `"no_room"` (indistinguishable from a missing code).
- Invalid frames of any other type are dropped silently. `s` numbers are clamped to ±500 and rounded to 2 decimals; `h` is an integer ≥ -1.
- Relay window: from `start` until `ends_at` + 10 s. Before the first `start` (waiting) and after that, `s`/`to`/`snap` are dropped. A `snap` arriving < 1 s after the last accepted one is dropped (not queued).
- `again` before `end` is ignored. If the partner leaves after `end`, a remaining player who already sent `again` gets a new solo `start` at once.
- After `left`, the room is no longer joinable; the remaining player keeps the same room until they leave.
- Idle = no `hello`/`again`/`s`/`to`/`snap` in the room for 10 min (pings don't count). An idle room is deleted and its sockets are closed (code 1008, "room closed").
- Every new `start` (including after `again`) carries a seed different from the previous one, and `host` is the first remaining player.
