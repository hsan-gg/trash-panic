// Regressions for the co-op security review: IPv6 grouping, parse bombs, partner flooding.
import test from "node:test";
import assert from "node:assert/strict";
import { ipKey, maxDepth, parseMessage } from "../src/validate.js";
import { Room } from "../src/room.js";

test("IPv6 addresses share a cap per /64; IPv4 stays as is", () => {
  assert.equal(ipKey("2001:db8:1:2:aaaa::1"), ipKey("2001:db8:1:2:bbbb::9"));
  assert.notEqual(ipKey("2001:db8:1:2::1"), ipKey("2001:db8:1:3::1"));
  assert.equal(ipKey("203.0.113.7"), "203.0.113.7");
});

test("deeply nested game data is rejected before parsing", () => {
  assert.equal(maxDepth('{"a":[{"b":"[[[["}]}'), 3, "brackets inside strings don't count");
  const bomb = `{"t":"to","d":{"x":${"[".repeat(20)}${"]".repeat(20)}}}`;
  assert.equal(parseMessage(bomb), null);
  assert.ok(parseMessage(JSON.stringify({ t: "to", d: { k: "d", d: { i: { 3: ["can", "", 1, 2, -1, "", false] } } } })));
});

test("a partner can't flood the other phone: state 15/s, data 20/s", () => {
  const room = new Room({ now: 0, code: "BCDF", rand: () => 0.5 });
  room.join(1, "A", 0, 0);
  room.join(2, "B", 0, 0);
  room.flush();
  const t = room.startAt;
  for (let i = 0; i < 40; i++) room.handle(1, { t: "to", d: { n: i } }, t + i);
  for (let i = 0; i < 40; i++) room.handle(1, { t: "s", p: [0, 0, 0], y: 0, a: 0, h: -1 }, t + i);
  const out = room.flush();
  assert.equal(out.filter((o) => o.msg.t === "from").length, 20);
  assert.equal(out.filter((o) => o.msg.t === "s").length, 15);
});

test("connection attempts are rate limited per address when the binding exists", async () => {
  const { connectAllowed } = await import("../src/index.js");
  const req = (ip) => new Request("https://x/play", { headers: { "CF-Connecting-IP": ip } });
  assert.equal(await connectAllowed({}, req("1.2.3.4")), true, "no binding (local dev): allowed");
  const seen = [];
  const env = { CONNECT_LIMIT: { limit: async ({ key }) => (seen.push(key), { success: seen.length <= 1 }) } };
  assert.equal(await connectAllowed(env, req("2001:db8:1:2::5")), true);
  assert.equal(await connectAllowed(env, req("2001:db8:1:2::6")), false);
  assert.deepEqual(seen, ["2001:db8:1:2", "2001:db8:1:2"], "IPv6 keyed per /64");
});
