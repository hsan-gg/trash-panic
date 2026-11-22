// Matchmaking: which Room a `hello` lands in. Pure, like Room, so it is node-testable;
// the Lobby Durable Object owns the sockets and timers around it.

import { Room } from "./room.js";
import { CODE_LETTERS } from "./validate.js";

// Codes and seeds are sent to clients, so they come from a CSPRNG (Math.random's state is recoverable).
export const secureRandom = () => crypto.getRandomValues(new Uint32Array(1))[0] / 2 ** 32;

export class Matchmaker {
  constructor(rand = secureRandom) {
    this.rand = rand;
    this.rooms = new Set(); // insertion order = oldest first
    this.codes = new Map(); // private code → Room
    this.roomOf = new Map(); // player id → Room
  }

  // Seats player `id`; returns its Room, or an error code for `{t:"error"}`.
  hello(id, msg, now) {
    if (msg.bad) return "bad_hello";
    const v = msg.v ?? 0;
    let room;
    if (msg.mode === "join") {
      room = this.codes.get(msg.code);
      // A started room looks the same as a missing one, so codes can't be probed.
      if (!room || !room.open) return "no_room";
      if (room.v !== v) return "old_version"; // different builds would play different games
    } else if (msg.mode === "quick") {
      // At most one quick room waits at a time, so this pairs the two oldest quick players.
      room = [...this.rooms].find((r) => r.quick && r.open && r.v === v);
    }
    if (!room) {
      room = new Room({ now, rand: this.rand, v, code: msg.mode === "create" ? this.newCode() : undefined });
      this.rooms.add(room);
      if (room.code) this.codes.set(room.code, room);
    }
    this.roomOf.set(id, room);
    room.join(id, msg.name, msg.skin, now, msg.tut, msg.ch);
    return room;
  }

  leave(id, now) {
    const room = this.roomOf.get(id);
    this.roomOf.delete(id);
    room?.leave(id, now);
    return room;
  }

  remove(room) {
    this.rooms.delete(room);
    if (this.codes.get(room.code) === room) this.codes.delete(room.code);
    for (const id of room.ids()) this.roomOf.delete(id);
  }

  newCode() {
    let code;
    do {
      code = Array.from({ length: 4 }, () => CODE_LETTERS[Math.floor(this.rand() * CODE_LETTERS.length)]).join("");
    } while (this.codes.has(code));
    return code;
  }
}
