// Edge server: serves the web build, the network-check WebSocket at /ws and the
// match WebSocket at /play (Lobby Durable Object, see PROTOCOL.md).

import { ipKey } from "./validate.js";

export { Lobby } from "./lobby.js";

const NETS = new Set(["5G_SA", "5G_NSA", "4G", "3G", "CELL", "NO_MOBILE_DATA", "WIFI", "ETHERNET", "OTHER", "NONE", "WEB"]);
const MAX_MESSAGE_BYTES = 256;
const MAX_MESSAGES_PER_SECOND = 10;
const MAX_STRIKES = 40; // over-limit frames before the socket is closed (each one is billed)
const WS_IDLE_MS = 30_000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/ws" || url.pathname === "/play") {
      if (!originAllowed(request.headers.get("Origin"), url.host)) return new Response("Forbidden", { status: 403 });
      if (!(await connectAllowed(env, request))) return new Response("Too many connections", { status: 429 });
    }
    if (url.pathname === "/ws") return handleSocket(request);
    if (url.pathname === "/play") return env.LOBBY.get(env.LOBBY.idFromName("main")).fetch(request);
    if (url.pathname === "/index.wasm") return serveWasm(request, env);
    return env.ASSETS.fetch(request);
  },
};

// Godot's 38 MB wasm exceeds the 25 MiB static-asset limit, so it ships gzipped
// (tools/build_web.sh) and the browser decompresses it.
async function serveWasm(request, env) {
  const gz = await env.ASSETS.fetch(new URL("/index.wasm.gz", request.url));
  if (!gz.ok) return gz;
  return new Response(gz.body, {
    headers: {
      "Content-Type": "application/wasm",
      "Content-Encoding": "gzip",
      "Cache-Control": "public, max-age=3600",
    },
    encodeBody: "manual",
  });
}

function handleSocket(request) {
  if (request.headers.get("Upgrade") !== "websocket") {
    return new Response("Expected a WebSocket upgrade", { status: 426 });
  }
  const [client, server] = Object.values(new WebSocketPair());
  server.accept();

  let windowStart = Date.now();
  let count = 0;
  let strikes = 0;
  let last = Date.now();
  server.addEventListener("message", (event) => {
    const now = Date.now();
    if (now - windowStart >= 1000) {
      windowStart = now;
      count = 0;
    }
    if (++count > MAX_MESSAGES_PER_SECOND) {
      if (++strikes > MAX_STRIKES) server.close(1008, "rate limit");
      return;
    }
    last = now;
    const reply = handleMessage(event.data);
    try {
      if (reply) server.send(JSON.stringify(reply));
    } catch {
      // The socket is closing.
    }
  });
  // Clients ping every 2 s; a silent socket only costs us, so close it.
  const idle = setInterval(() => {
    if (Date.now() - last > WS_IDLE_MS) server.close(1008, "idle");
  }, WS_IDLE_MS / 3);
  server.addEventListener("close", () => clearInterval(idle));
  server.addEventListener("error", () => clearInterval(idle));
  return new Response(null, { status: 101, webSocket: client });
}

// Connection attempts per address, counted at the edge before they wake the Durable Object.
// Uses the free Workers Rate Limiting binding; local dev without it allows everything.
export async function connectAllowed(env, request) {
  if (!env.CONNECT_LIMIT) return true;
  const ip = ipKey(request.headers.get("CF-Connecting-IP") ?? "local");
  const { success } = await env.CONNECT_LIMIT.limit({ key: ip });
  return success;
}

// Native apps send no Origin; browsers may only connect from pages we serve, so other sites
// can't spend our free-plan quota through their visitors. Exported for tests.
export function originAllowed(origin, host) {
  if (!origin) return true;
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}

// Returns the reply for one client message, or null to drop it. Exported for tests.
export function handleMessage(data) {
  if (typeof data !== "string" || data.length > MAX_MESSAGE_BYTES) return null;
  let msg;
  try {
    msg = JSON.parse(data);
  } catch {
    return null;
  }
  if (msg === null || typeof msg !== "object") return null;
  if (msg.t === "ping" && Number.isInteger(msg.id) && msg.id >= 0 && NETS.has(msg.net)) {
    return { t: "pong", id: msg.id };
  }
  return null;
}
