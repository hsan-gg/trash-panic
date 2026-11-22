import { test } from "node:test";
import assert from "node:assert/strict";
import { makeHub } from "./helpers.mjs";

test("quick match pairs players in arrival order", () => {
  const { hello, last } = makeHub();
  const a = hello(1, "quick", 0);
  assert.deepEqual(last(1, "waiting"), { t: "waiting", mode: "quick" });
  const b = hello(2, "quick", 100);
  assert.equal(a, b);
  hello(3, "quick", 200);
  const d = hello(4, "quick", 300);
  assert.notEqual(d, a);
  assert.deepEqual(last(1, "start").players.map((p) => p.id), [1, 2]);
  assert.deepEqual(last(4, "start").players.map((p) => p.id), [3, 4]);
  assert.equal(last(1, "start").host, 1);
  assert.equal(last(3, "start").solo, false);
});

test("a quick player who left is not paired", () => {
  const { mm, hello, last } = makeHub();
  const a = hello(1, "quick", 0);
  mm.leave(1, 10);
  assert.equal(a.finished, true);
  mm.remove(a);
  hello(2, "quick", 20);
  assert.equal(last(2, "start"), undefined);
  assert.equal(last(2, "waiting").mode, "quick");
});

test("a lone player keeps waiting: shifts are for two", () => {
  const { hello, last } = makeHub();
  const room = hello(1, "quick", 1_000);
  room.tick(10 * 60_000 - 1);
  assert.equal(last(1, "start"), undefined);
});

test("private rooms: create gives a code, join starts at once, then full", () => {
  const { hello, last } = makeHub();
  const room = hello(1, "create", 0);
  const { code, mode } = last(1, "waiting");
  assert.equal(mode, "create");
  assert.match(code, /^[BCDFGHJKLMNPQRSTVWXZ]{4}$/);
  assert.equal(hello(2, "join", 50_000, { code }), room);
  assert.equal(last(2, "start").start_at, 53_500);
  assert.equal(hello(3, "join", 50_001, { code }), "no_room"); // started rooms look missing: codes can't be probed
});

test("join with an unknown code, bad hello", () => {
  const { mm, hello } = makeHub();
  hello(1, "create", 0);
  assert.equal(hello(2, "join", 0, { code: "QQQQ" }), "no_room");
  assert.equal(mm.hello(3, { t: "hello", bad: true }, 0), "bad_hello");
  assert.equal(mm.roomOf.has(2), false);
});

test("codes are unique and removed with the room", () => {
  const { mm, hello, last } = makeHub();
  const codes = new Set();
  for (let id = 1; id <= 50; id++) {
    hello(id, "create", 0);
    codes.add(last(id, "waiting").code);
  }
  assert.equal(codes.size, 50);
  const room = mm.leave(1, 1);
  mm.remove(room);
  assert.equal(mm.codes.size, 49);
  assert.equal(mm.rooms.size, 49);
});

test("quick match only pairs players running the same game version", () => {
  const { hello, last } = makeHub();
  const a = hello(1, "quick", 0, { v: 3 });
  const b = hello(2, "quick", 10, { v: 2 });
  assert.notEqual(a, b);
  assert.equal(last(1, "start"), undefined);
  const c = hello(3, "quick", 20, { v: 3 });
  assert.equal(a, c);
  assert.ok(last(1, "start"));
});

test("joining a room from another version is refused, and tutorial flags reach both players", () => {
  const { mm, hello, last } = makeHub();
  const room = hello(1, "create", 0, { v: 3, tut: true });
  assert.equal(mm.hello(2, { t: "hello", name: "P2", skin: 0, mode: "join", code: room.code, v: 2 }, 5), "old_version");
  hello(3, "join", 10, { code: room.code, v: 3, tut: false });
  assert.deepEqual(last(1, "start").players.map((p) => p.tut), [true, false]);
});
