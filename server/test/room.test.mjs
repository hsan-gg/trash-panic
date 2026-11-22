import { test } from "node:test";
import assert from "node:assert/strict";
import { makeHub } from "./helpers.mjs";
import { COUNTDOWN_MS, SHIFT_MS, IDLE_MS, RELAY_GRACE_MS } from "../src/room.js";

const S = { t: "s", p: [1, 2, 3], y: 0.5, a: 4, h: -1 };

// Players 1+2 paired at t=0, plus an unrelated pair 3+4.
function paired() {
  const hub = makeHub();
  const room = hub.hello(1, "quick", 0);
  hub.hello(2, "quick", 0);
  const other = hub.hello(3, "quick", 0);
  hub.hello(4, "quick", 0);
  return { ...hub, room, other };
}

test("start timing: 3.5 s countdown then 180 s shift, host = first player", () => {
  const { last } = paired();
  const start = last(2, "start");
  assert.equal(start.start_at, COUNTDOWN_MS);
  assert.equal(start.ends_at, COUNTDOWN_MS + SHIFT_MS);
  assert.equal(start.host, 1);
  assert.ok(Number.isInteger(start.seed));
  assert.deepEqual(start.players[0], { id: 1, name: "P1", skin: 0, tut: false, ch: 0 });
});

test("s and to are relayed to the partner only", () => {
  const { room, got } = paired();
  room.handle(1, S, 100);
  room.handle(2, { t: "to", d: { grab: 7 } }, 100);
  assert.deepEqual(got(2, "s"), [{ t: "s", id: 1, p: [1, 2, 3], y: 0.5, a: 4, h: -1 }]);
  assert.deepEqual(got(1, "from"), [{ t: "from", d: { grab: 7 } }]);
  assert.deepEqual(got(1, "s"), []);
  for (const id of [3, 4]) assert.deepEqual(got(id).map((m) => m.t), ["welcome", ...(id === 3 ? ["waiting"] : []), "start"]);
  room.handle(3, S, 100); // not in this room
  assert.equal(got(1, "s").length + got(4, "s").length, 0);
});

test("snap: host only, at most one per second", () => {
  const { room, got } = paired();
  room.handle(2, { t: "snap", d: { x: 1 } }, 100);
  assert.deepEqual(got(1, "snap"), []);
  room.handle(1, { t: "snap", d: { n: 1 } }, 100);
  room.handle(1, { t: "snap", d: { n: 2 } }, 900);
  room.handle(1, { t: "snap", d: { n: 3 } }, 1_100);
  assert.deepEqual(got(2, "snap").map((m) => m.d.n), [1, 3]);
});

test("end at ends_at; relay stops 10 s later", () => {
  const { room, got } = paired();
  const endsAt = COUNTDOWN_MS + SHIFT_MS;
  assert.equal(room.nextWake(), endsAt);
  room.tick(endsAt - 1);
  assert.equal(got(1, "end").length, 0);
  room.tick(endsAt);
  assert.equal(got(1, "end").length, 1);
  assert.equal(got(2, "end").length, 1);
  room.handle(1, S, endsAt + RELAY_GRACE_MS);
  room.handle(1, S, endsAt + RELAY_GRACE_MS + 1);
  assert.equal(got(2, "s").length, 1);
});

test("again from every player starts a new shift with a different seed", () => {
  const { room, got, last } = paired();
  const first = last(1, "start");
  room.handle(1, { t: "again" }, 1_000); // before end: ignored
  room.tick(first.ends_at);
  room.handle(1, { t: "again" }, first.ends_at + 50);
  assert.equal(got(1, "start").length, 1);
  room.handle(2, { t: "again" }, first.ends_at + 100);
  const second = last(2, "start");
  assert.notEqual(second.seed, first.seed);
  assert.equal(second.start_at, first.ends_at + 100 + COUNTDOWN_MS);
  assert.equal(second.solo, false);
});

test("left: remaining player becomes host and plays solo; again restarts solo", () => {
  const { mm, room, got, last } = paired();
  const before = got(1).length;
  mm.leave(1, 500);
  assert.deepEqual(last(2, "left"), { t: "left", id: 1 });
  assert.equal(room.host, 2);
  room.handle(2, S, 600);
  room.handle(2, { t: "snap", d: {} }, 600);
  assert.equal(got(1).length, before, "nothing reaches a player who left");
  room.tick(room.endsAt);
  room.handle(2, { t: "again" }, room.endsAt + 1);
  const start = last(2, "start");
  assert.equal(start.solo, true);
  assert.equal(start.host, 2);
});

test("partner leaving after end triggers the start the remaining player is waiting for", () => {
  const { mm, room, got } = paired();
  room.tick(room.endsAt);
  room.handle(2, { t: "again" }, room.endsAt + 1);
  mm.leave(1, room.endsAt + 2);
  assert.equal(got(2, "start").at(-1).solo, true);
});

test("room is finished when empty or idle for 10 min", () => {
  const { mm, room, other } = paired();
  mm.leave(1, 1);
  mm.leave(2, 2);
  assert.equal(room.finished, true);
  other.tick(other.endsAt);
  assert.equal(other.nextWake(), IDLE_MS);
  other.tick(IDLE_MS - 1);
  assert.equal(other.finished, false);
  other.tick(IDLE_MS);
  assert.equal(other.finished, true);
  mm.remove(other);
  assert.equal(mm.roomOf.has(3), false);
});
