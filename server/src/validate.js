// Boundary checks for /play frames: everything a client sends passes through parseMessage.

const MAX_BYTES = 512;
const MAX_SNAP_BYTES = 4096; // only `snap` may be this large; Room enforces host-only and 1/s
const MAX_DEPTH = 8; // the game's deepest frame (a snapshot) nests 5 levels
const MAX_ID = 2 ** 31;
const MODES = new Set(["quick", "create", "join"]);
export const CODE_LETTERS = "BCDFGHJKLMNPQRSTVWXZ";
const CODE_RE = new RegExp(`^[${CODE_LETTERS}]{4}$`);
const encoder = new TextEncoder();

const finite = (x) => typeof x === "number" && Number.isFinite(x);
const num = (x) => (finite(x) ? Math.round(Math.min(500, Math.max(-500, x)) * 100) / 100 : null);
const int = (x, lo, hi) => (Number.isInteger(x) && x >= lo && x <= hi ? x : null);
const vec3 = (x) => (Array.isArray(x) && x.length === 3 && x.every(finite) ? x.map(num) : null);
const plainObject = (x) => (x !== null && typeof x === "object" && !Array.isArray(x) ? x : null);
// Any null field means the message is invalid.
const ok = (msg) => (Object.values(msg).includes(null) ? null : msg);

export function cleanName(x) {
  const name = typeof x === "string" ? x.replace(/[^A-Za-z0-9 _-]/g, "").trim().slice(0, 12).trim() : "";
  return name || "Player";
}

export function cleanCode(x) {
  if (typeof x !== "string") return null;
  const code = x.toUpperCase();
  return CODE_RE.test(code) ? code : null;
}

// A bad hello still parses, as {t:"hello", bad:true}, so the client can be told "bad_hello".
function hello(m) {
  const mode = MODES.has(m.mode) ? m.mode : null;
  const code = mode === "join" ? cleanCode(m.code) : undefined;
  if (mode === null || code === null) return { bad: true };
  // v: the game build (players only meet the same version); tut: this player finished the tutorial;
  // ch: the chapter this player picked (the host's pick is played).
  const msg = { name: cleanName(m.name), skin: int(m.skin, 0, 7) ?? 0, mode, v: int(m.v, 0, 9999) ?? 0, tut: m.tut === true, ch: int(m.ch, 0, 2) ?? 0 };
  return code ? { ...msg, code } : msg;
}

const CHECKS = new Map([
  ["hello", hello],
  ["ping", (m) => ({ id: int(m.id, 0, MAX_ID), ct: finite(m.ct) ? m.ct : null })],
  ["s", (m) => ({ p: vec3(m.p), y: num(m.y), a: int(m.a, 0, 31), h: int(m.h, -1, MAX_ID) })],
  ["to", (m) => ({ d: plainObject(m.d) })],
  ["snap", (m) => ({ d: plainObject(m.d) })],
  ["again", () => ({})],
]);

// Returns a normalized message ({t, ...validated fields}) or null to drop the frame.
export function parseMessage(data) {
  if (typeof data !== "string" || data.length > MAX_SNAP_BYTES) return null;
  const bytes = encoder.encode(data).byteLength;
  if (bytes > MAX_SNAP_BYTES || maxDepth(data) > MAX_DEPTH) return null;
  let msg;
  try {
    msg = JSON.parse(data);
  } catch {
    return null;
  }
  if (plainObject(msg) === null) return null;
  if (bytes > MAX_BYTES && msg.t !== "snap") return null;
  const check = CHECKS.get(msg.t);
  return check ? ok({ t: msg.t, ...check(msg) }) : null;
}

// Fixed one-second window; returns false for messages over the limit.
// IPv6 users control a whole /64, so per-address caps key on the prefix.
export function ipKey(ip) {
  return ip.includes(":") ? ip.split(":").slice(0, 4).join(":") : ip;
}

// Deepest {…}/[…] nesting in a JSON text (strings skipped). Relayed `d` objects are capped so a
// tiny frame can't carry a parse bomb to the partner's phone.
export function maxDepth(text) {
  let depth = 0;
  let max = 0;
  let inString = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inString) {
      if (c === "\\") i++;
      else if (c === '"') inString = false;
    } else if (c === '"') inString = true;
    else if (c === "{" || c === "[") max = Math.max(max, ++depth);
    else if (c === "}" || c === "]") depth--;
  }
  return max;
}

export function rateLimiter(maxPerSecond) {
  let windowStart = -Infinity;
  let count = 0;
  return (now) => {
    if (now - windowStart >= 1000) {
      windowStart = now;
      count = 0;
    }
    return ++count <= maxPerSecond;
  };
}
