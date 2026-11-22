// One co-op room for up to 2 players. The host's client simulates the game; the room only
// pairs, keeps the shift clock and relays. Pure: no Cloudflare APIs, callers pass `now`
// (server ms) and drain outgoing messages with flush() as [{to, msg}].

import { rateLimiter } from "./validate.js";

export const COUNTDOWN_MS = 3_500;
export const SHIFT_MS = 180_000;
export const RELAY_GRACE_MS = 10_000; // late frames right after `end` still reach the partner
export const IDLE_MS = 10 * 60_000;
export const SNAP_MS = 1_000;
const STATE_PER_SECOND = 15; // clients send 10 Hz
const DATA_PER_SECOND = 20; // game data: host deltas at 10 Hz plus bursts

export class Room {
  // `code` is set for private rooms; quick-match rooms have none.
  constructor({ now, code, v = 0, rand = Math.random }) {
    this.code = code;
    this.v = v; // game build: both players must run the same one
    this.rand = rand;
    this.players = new Map(); // id → {id, name, skin, tut, ch}, in join order
    this.phase = "wait"; // wait → play → over (→ play again)
    this.seed = null;
    this.startAt = 0;
    this.endsAt = 0;
    this.host = null;
    this.ready = new Set(); // players who sent `again`
    this.lastSnap = -Infinity;
    this.limits = new Map(); // player id → {s, to} per-second limiters, so a partner can't flood the other phone
    this.lastActive = now;
    this.closed = false;
    this.out = [];
  }

  get quick() {
    return this.code === undefined;
  }

  get open() {
    return this.phase === "wait" && this.players.size < 2;
  }

  get finished() {
    return this.closed || this.players.size === 0;
  }

  ids() {
    return [...this.players.keys()];
  }

  flush() {
    const out = this.out;
    this.out = [];
    return out;
  }

  nextWake() {
    const idleAt = this.lastActive + IDLE_MS;
    if (this.phase === "play") return Math.min(idleAt, this.endsAt);
    return idleAt;
  }

  join(id, name, skin, now, tut = false, ch = 0) {
    this.players.set(id, { id, name, skin, tut, ch });
    this.lastActive = now;
    this.send(id, { t: "welcome", id, st: now });
    if (this.players.size === 2) return this.start(now);
    if (this.quick) this.send(id, { t: "waiting", mode: "quick" });
    else this.send(id, { t: "waiting", mode: "create", code: this.code });
  }

  leave(id, now) {
    if (!this.players.delete(id)) return;
    this.ready.delete(id);
    this.host = this.ids()[0] ?? null;
    this.broadcast({ t: "left", id });
    if (this.phase === "over") this.startIfReady(now);
  }

  tick(now) {
    if (now - this.lastActive >= IDLE_MS) this.closed = true;
    else if (this.phase === "play" && now >= this.endsAt) this.end();
  }

  handle(id, msg, now) {
    if (!this.players.has(id)) return;
    this.lastActive = now;
    if (msg.t === "again") {
      if (this.phase !== "over") return;
      this.ready.add(id);
      this.startIfReady(now);
    } else if (this.relaying(now)) {
      this.relay(id, msg, now);
    }
  }

  // ── internals ──

  relaying(now) {
    return this.phase !== "wait" && now >= this.startAt - COUNTDOWN_MS && now <= this.endsAt + RELAY_GRACE_MS;
  }

  relay(id, msg, now) {
    const partner = this.ids().find((pid) => pid !== id);
    if (partner === undefined) return;
    if (!this.limits.has(id)) this.limits.set(id, { s: rateLimiter(STATE_PER_SECOND), to: rateLimiter(DATA_PER_SECOND) });
    const limit = this.limits.get(id)[msg.t];
    if (limit && !limit(now)) return;
    if (msg.t === "s") {
      const { p, y, a, h } = msg;
      this.send(partner, { t: "s", id, p, y, a, h });
    } else if (msg.t === "to") {
      this.send(partner, { t: "from", d: msg.d });
    } else if (msg.t === "snap" && id === this.host && now - this.lastSnap >= SNAP_MS) {
      this.lastSnap = now;
      this.send(partner, { t: "snap", d: msg.d });
    }
  }

  startIfReady(now) {
    if (this.players.size > 0 && this.ready.size === this.players.size) this.start(now);
  }

  start(now) {
    let seed = Math.floor(this.rand() * 2 ** 31);
    if (seed === this.seed) seed = (seed + 1) % 2 ** 31; // every shift gets a new layout
    this.seed = seed;
    this.phase = "play";
    this.startAt = now + COUNTDOWN_MS;
    this.endsAt = this.startAt + SHIFT_MS;
    this.host = this.ids()[0];
    this.ready.clear();
    this.lastSnap = -Infinity;
    this.limits = new Map(); // player id → {s, to} per-second limiters, so a partner can't flood the other phone
    this.lastActive = now;
    const players = [...this.players.values()].map(({ id, name, skin, tut, ch }) => ({ id, name, skin, tut, ch }));
    this.broadcast({
      t: "start", seed, start_at: this.startAt, ends_at: this.endsAt,
      host: this.host, solo: players.length === 1, players,
    });
  }

  end() {
    this.phase = "over";
    this.broadcast({ t: "end" });
  }

  send(to, msg) {
    this.out.push({ to, msg });
  }

  broadcast(msg) {
    for (const to of this.players.keys()) this.send(to, msg);
  }
}
