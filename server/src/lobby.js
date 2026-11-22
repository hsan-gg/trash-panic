// Durable Object "Lobby" (one instance, named "main"): owns the /play sockets, seats
// players through the Matchmaker and runs each Room's timers. Rooms live in memory,
// so this does not use the hibernation API.

import { Matchmaker } from "./match.js";
import { parseMessage, rateLimiter, ipKey } from "./validate.js";

const MAX_MESSAGES_PER_SECOND = 20; // a player needs ~12 (10 Hz state, pings, game data)
// Free-plan protection: every incoming frame is billed even when dropped, so abusers are cut off.
const MAX_SOCKETS = 200;
const MAX_SOCKETS_PER_IP = 16; // a venue's Wi-Fi puts many players behind one address
const MAX_STRIKES = 20; // over-limit frames within one second before the socket is closed
const BUDGET_PER_MIN = 15_000; // all /play frames: ~8 matches at once (~1.9k frames/min each); the free plan's 2M frames/day (100k requests at 20:1) is the daily cap, and the free plan cannot bill
const MAX_FAILED_JOINS = 3; // wrong room codes per address per minute (stops code guessing)
const MIN_TIMER_MS = 50;
const HELLO_MS = 10_000;
const IDLE_MS = 30_000; // clients ping every 2 s
const SWEEP_MS = 5_000;

export class Lobby {
  constructor() {
    this.seq = 0; // player ids
    this.sockets = new Map(); // player id → WebSocket
    this.match = new Matchmaker();
    this.timers = new Map(); // Room → timeout
    this.meta = new Map(); // player id → {ip, opened, seen}
    this.perIp = new Map(); // ip key → open sockets
    this.failedJoins = new Map(); // ip key → wrong codes in the current minute
    this.minuteFrames = 0; // all frames in the current minute, against BUDGET_PER_MIN
    this.sweeper = null;
  }

  fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected a WebSocket upgrade", { status: 426 });
    }
    const ip = ipKey(request.headers.get("CF-Connecting-IP") ?? "local");
    if (this.sockets.size >= MAX_SOCKETS) return new Response("Server full", { status: 503 });
    if ((this.perIp.get(ip) ?? 0) >= MAX_SOCKETS_PER_IP) return new Response("Too many connections", { status: 429 });
    const [client, server] = Object.values(new WebSocketPair());
    server.accept();
    const id = ++this.seq;
    const allow = rateLimiter(MAX_MESSAGES_PER_SECOND);
    let strikes = 0;
    let strikeWindow = 0;
    this.sockets.set(id, server);
    this.meta.set(id, { ip, opened: Date.now(), seen: Date.now(), frames: 0 });
    this.perIp.set(ip, (this.perIp.get(ip) ?? 0) + 1);
    this.sweeper ??= setInterval(() => this.sweep(Date.now()), SWEEP_MS);

    server.addEventListener("message", (event) => {
      const now = Date.now();
      const meta = this.meta.get(id);
      if (!meta) return;
      meta.frames++;
      if (++this.minuteFrames > BUDGET_PER_MIN) this.kickHeaviest();
      if (!allow(now)) {
        if (now - strikeWindow >= 1000) {
          strikeWindow = now;
          strikes = 0;
        }
        if (++strikes > MAX_STRIKES) this.kick(id, "rate limit");
        return;
      }
      const msg = parseMessage(event.data);
      if (!msg) return;
      meta.seen = now; // only valid frames count as activity
      try {
        this.onMessage(id, msg, now);
      } catch (err) {
        console.error("onMessage failed", err?.message);
        try {
          const room = this.match.roomOf.get(id);
          if (room) this.pump(room);
        } catch (pumpErr) {
          console.error("pump failed", pumpErr?.message);
        }
      }
    });
    const close = () => {
      if (!this.sockets.delete(id)) return;
      const left = this.meta.get(id);
      this.meta.delete(id);
      const n = (this.perIp.get(left.ip) ?? 1) - 1;
      if (n > 0) this.perIp.set(left.ip, n);
      else this.perIp.delete(left.ip);
      if (this.sockets.size === 0) {
        clearInterval(this.sweeper);
        this.sweeper = null;
      }
      try {
        const room = this.match.leave(id, Date.now());
        if (room) this.pump(room);
      } catch (err) {
        console.error("leave failed", err?.message);
      }
    };
    server.addEventListener("close", close);
    server.addEventListener("error", close);
    return new Response(null, { status: 101, webSocket: client });
  }

  onMessage(id, msg, now) {
    if (msg.t === "ping") {
      this.trySend(id, JSON.stringify({ t: "pong", id: msg.id, ct: msg.ct, st: now }));
      return;
    }
    let room = this.match.roomOf.get(id);
    if (msg.t === "hello") {
      if (room) return;
      room = this.match.hello(id, msg, now);
      if (typeof room === "string") {
        if (msg.mode === "join") this.failedJoin(id);
        return this.trySend(id, JSON.stringify({ t: "error", code: room }));
      }
    } else if (room) {
      room.handle(id, msg, now);
    } else {
      return;
    }
    this.pump(room);
  }

  // Sends the room's queued messages, then reschedules its timer or retires it.
  pump(room) {
    for (const { to, msg } of room.flush()) this.trySend(to, JSON.stringify(msg));
    clearTimeout(this.timers.get(room));
    if (room.finished) {
      this.timers.delete(room);
      this.match.remove(room);
      for (const pid of room.ids()) this.kick(pid, "room closed"); // idle rooms still hold players
      return;
    }
    const delay = Math.max(MIN_TIMER_MS, room.nextWake() - Date.now()); // never spin, even if tick keeps failing
    this.timers.set(room, setTimeout(() => {
      try {
        room.tick(Date.now());
      } catch (err) {
        console.error("room tick failed", err?.message);
      }
      this.pump(room); // always reschedule, so one bad tick can't strand a room
    }, delay));
  }

  // Closes sockets that never got a seat (pinging doesn't count), or went silent; resets minute budgets.
  sweep(now) {
    for (const [id, m] of this.meta) {
      if (!this.match.roomOf.has(id) && now - m.opened > HELLO_MS) this.kick(id, "no hello");
      else if (now - m.seen > IDLE_MS) this.kick(id, "idle");
    }
    if (now - (this.minuteStart ?? 0) >= 60_000) {
      this.minuteStart = now;
      this.minuteFrames = 0;
      this.failedJoins.clear();
      for (const m of this.meta.values()) m.frames = 0;
    }
  }

  // Over the global budget: drop whoever sent the most this minute.
  kickHeaviest() {
    let worst = null;
    for (const [id, m] of this.meta) if (!worst || m.frames > worst[1]) worst = [id, m.frames];
    if (worst) this.kick(worst[0], "budget");
  }

  failedJoin(id) {
    const ip = this.meta.get(id)?.ip;
    const n = (this.failedJoins.get(ip) ?? 0) + 1;
    this.failedJoins.set(ip, n);
    if (n >= MAX_FAILED_JOINS) this.kick(id, "too many codes");
  }

  kick(id, reason) {
    try {
      this.sockets.get(id)?.close(1008, reason);
    } catch {
      // Already closing.
    }
  }

  trySend(pid, data) {
    try {
      this.sockets.get(pid)?.send(data);
    } catch {
      // The socket is closing; its close event removes the player.
    }
  }
}
