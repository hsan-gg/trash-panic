import { test } from "node:test";
import assert from "node:assert/strict";
import { parseMessage, rateLimiter, cleanName, cleanCode } from "../src/validate.js";
import { originAllowed } from "../src/index.js";

const frame = (m) => JSON.stringify(m);
const S = { t: "s", p: [1.234, 2, 3], y: 0.5, a: 3, h: -1 };

test("names are sanitized to 12 chars of [A-Za-z0-9 _-] with a fallback", () => {
  assert.equal(cleanName("  Ana<script>  "), "Anascript");
  assert.equal(cleanName("abcdefghijklmnop"), "abcdefghijkl");
  assert.equal(cleanName("Zoë_-1"), "Zo_-1");
  for (const bad of ["", "   ", "<<>>", 42, null, undefined]) assert.equal(cleanName(bad), "Player");
});

test("codes: exactly 4 allowed letters, uppercased", () => {
  assert.equal(cleanCode("bcdf"), "BCDF");
  for (const bad of ["BCD", "BCDFG", "ABCD", "BC1F", "BCD ", 1234, null, undefined]) assert.equal(cleanCode(bad), null, String(bad));
});

test("hello: name cleaned, skin 0-7 else 0, mode and code checked", () => {
  assert.deepEqual(parseMessage(frame({ t: "hello", name: "Bo!", skin: 3, v: 2, mode: "quick" })),
    { t: "hello", name: "Bo", skin: 3, mode: "quick", v: 2, tut: false, ch: 0 });
  assert.equal(parseMessage(frame({ t: "hello", ch: 2, mode: "create" })).ch, 2);
  assert.equal(parseMessage(frame({ t: "hello", ch: 3, mode: "create" })).ch, 0);
  assert.equal(parseMessage(frame({ t: "hello", skin: 8, mode: "create" })).skin, 0);
  assert.equal(parseMessage(frame({ t: "hello", skin: 4, mode: "create" })).skin, 4);
  assert.equal(parseMessage(frame({ t: "hello", skin: 1.5, mode: "create" })).skin, 0);
  assert.equal(parseMessage(frame({ t: "hello", mode: "join", code: "xzqw" })).code, "XZQW");
  assert.equal(parseMessage(frame({ t: "hello", mode: "quick", code: "XZQW" })).code, undefined);
  for (const bad of [{ mode: "race" }, {}, { mode: "join" }, { mode: "join", code: "AEIO" }]) {
    assert.deepEqual(parseMessage(frame({ t: "hello", ...bad })), { t: "hello", bad: true });
  }
});

test("ping echoes id and ct", () => {
  assert.deepEqual(parseMessage(frame({ t: "ping", id: 3, ct: 123.5 })), { t: "ping", id: 3, ct: 123.5 });
  assert.equal(parseMessage(frame({ t: "ping", id: 3 })), null);
});

test("s: numbers rounded and clamped to ±500, extra fields dropped", () => {
  assert.deepEqual(parseMessage(frame({ ...S, p: [1.234, 9999, -9999], y: -600, x: 1 })),
    { t: "s", p: [1.23, 500, -500], y: -500, a: 3, h: -1 });
  assert.equal(parseMessage(frame({ ...S, h: 12 })).h, 12);
});

test("to/snap: d must be a plain object and is kept as-is", () => {
  const d = { k: [1, { z: "x" }], n: 1.23456 };
  assert.deepEqual(parseMessage(frame({ t: "to", d, x: 1 })), { t: "to", d });
  assert.deepEqual(parseMessage(frame({ t: "snap", d })), { t: "snap", d });
  for (const t of ["to", "snap"]) {
    for (const bad of [[1], null, 5, "x", undefined]) assert.equal(parseMessage(frame({ t, d: bad })), null);
  }
});

test("rejects junk, unknown types, bad numbers and out-of-range ints", () => {
  for (const bad of [
    "not json", "null", "[1,2]", "42", '"s"', '{"t":"teleport"}', '{"t":"constructor"}', '{"t":"start"}',
    frame({ ...S, a: 32 }), frame({ ...S, a: -1 }), frame({ ...S, a: 1.5 }),
    frame({ ...S, h: -2 }), frame({ ...S, h: 1.5 }), frame({ ...S, h: "1" }),
    frame({ ...S, p: [1, 2] }), frame({ ...S, p: [1, 2, "3"] }), frame({ ...S, y: "0" }),
    '{"t":"s","p":[1e999,0,0],"y":0,"a":0,"h":-1}',
  ]) {
    assert.equal(parseMessage(bad), null, bad);
  }
  assert.equal(parseMessage(new ArrayBuffer(4)), null);
  assert.deepEqual(parseMessage('{"t":"again"}'), { t: "again" });
  assert.equal(parseMessage('{"t":"solo"}'), null);
});

test("frames over 512 bytes are dropped, except snap up to 4096", () => {
  assert.equal(parseMessage(frame({ t: "to", d: { pad: "x".repeat(500) } })), null);
  assert.equal(parseMessage(frame({ t: "to", d: { pad: "é".repeat(250) } })), null); // < 512 chars, > 512 bytes
  assert.ok(parseMessage(frame({ t: "to", d: { pad: "x".repeat(480) } })));
  assert.ok(parseMessage(frame({ t: "snap", d: { pad: "x".repeat(4000) } })));
  assert.equal(parseMessage(frame({ t: "snap", d: { pad: "x".repeat(4100) } })), null);
  assert.equal(parseMessage(frame({ t: "snap", d: { pad: "é".repeat(2040) } })), null);
});

test("rate limiter allows 40 per second then drops", () => {
  const allow = rateLimiter(40);
  const results = Array.from({ length: 45 }, (_, i) => allow(1000 + i));
  assert.equal(results.filter(Boolean).length, 40);
  assert.equal(allow(2000), true);
});

test("sockets: only our own pages (or native apps, which send no Origin) may connect", () => {
  assert.equal(originAllowed(null, "game.example.dev"), true);
  assert.equal(originAllowed("https://game.example.dev", "game.example.dev"), true);
  assert.equal(originAllowed("https://evil.example", "game.example.dev"), false);
  assert.equal(originAllowed("not a url", "game.example.dev"), false);
});
