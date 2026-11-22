import { Matchmaker } from "../src/match.js";

// Deterministic, non-constant rand so seeds and codes differ.
export function seqRand() {
  let x = 0.123;
  return () => (x = (x * 9301 + 0.49297) % 1);
}

// Matchmaker plus a log of every message each player received.
export function makeHub() {
  const mm = new Matchmaker(seqRand());
  const log = [];
  const sync = () => {
    for (const r of mm.rooms) log.push(...r.flush());
  };
  const hello = (id, mode, now = 0, extra = {}) => {
    const res = mm.hello(id, { t: "hello", name: `P${id}`, skin: 0, mode, ...extra }, now);
    sync();
    return res;
  };
  const got = (id, t) => (sync(), log.filter((o) => o.to === id && (!t || o.msg.t === t)).map((o) => o.msg));
  const last = (id, t) => got(id, t).at(-1);
  return { mm, hello, got, last, sync };
}
