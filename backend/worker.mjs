/**
 * Cloudflare Worker + single SQLite-backed Durable Object room hub.
 *
 * All WebSocket sessions share one Durable Object instance for this casual
 * prototype. That is intentional and keeps free/casual deployment simple, but
 * it is not horizontally scalable. Rooms and sockets are in memory only; a DO
 * restart cancels active matches and clients must create/join again.
 *
 * The fixed client protocol does not use a URL room code. Clients connect once
 * to /ws (or the / alias) and send create/join on that same socket.
 *
 * Content is bundled from the split repository files data/levels_tr.json and
 * data/levels_en.json. No combined data/levels.json is required.
 */

import enSource from "../data/levels_en.json";
import trSource from "../data/levels_tr.json";

import { LIMITS, createRateLimiter, parseClientMessage } from "./protocol.mjs";
import { createRoomEngine } from "./room-engine.mjs";

const HUB_NAME = "global";
const MAX_TIMER_CHUNK_MS = 30_000;
const IDLE_CLOSE_CODE = 1001;

function isWebSocketUpgrade(request) {
  return (request.headers.get("Upgrade") ?? "").toLowerCase() === "websocket";
}

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

export class RoomHub {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.sessions = new Map();
    this.timer = null;

    this.engine = createRoomEngine({
      data: { tr: trSource, en: enSource },
      send: (playerId, message) => this.send(playerId, message),
      now: () => Date.now(),
    });
  }

  armIdleTimer(session, delay = LIMITS.maxIdleMs) {
    if (session.idleTimer !== null) {
      clearTimeout(session.idleTimer);
    }
    session.idleTimer = setTimeout(() => {
      session.idleTimer = null;
      if (session.closed) return;
      this.cleanupSession(session);
      try {
        session.ws.close(IDLE_CLOSE_CODE, "Idle timeout");
      } catch {
        // Already closed; cleanup already ran.
      }
    }, delay);
  }

  touch(session) {
    if (session.closed) return;
    session.lastSeenAt = Date.now();
    this.armIdleTimer(session);
  }

  send(playerId, message) {
    const session = this.sessions.get(playerId);
    if (!session || session.closed) return;
    try {
      session.ws.send(JSON.stringify(message));
    } catch {
      // The close/error listener removes the session.
    }
  }

  schedule() {
    if (this.timer !== null) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    const deadline = this.engine.nextDeadline();
    if (deadline === null) return;

    // Keep each timer short enough to be safe in Workers. Long waiting-room
    // and match deadlines are re-checked periodically while this DO is alive.
    const delay = Math.max(0, Math.min(deadline - Date.now(), MAX_TIMER_CHUNK_MS));
    this.timer = setTimeout(() => {
      this.timer = null;
      this.engine.tick(Date.now());
      this.schedule();
    }, delay);
  }

  onMessage(session, event) {
    if (session.closed) return;
    this.touch(session);

    let raw = event.data;
    if (typeof raw !== "string") {
      if (raw instanceof ArrayBuffer) {
        raw = new TextDecoder().decode(new Uint8Array(raw));
      } else if (ArrayBuffer.isView(raw)) {
        raw = new TextDecoder().decode(raw);
      } else {
        this.send(session.playerId, {
          type: "error",
          code: "binary_not_supported",
          message: "Messages must be UTF-8 text JSON.",
        });
        return;
      }
    }

    if (!session.limiter.consume()) {
      this.send(session.playerId, {
        type: "error",
        code: "rate_limited",
        message: "Too many messages.",
      });
      return;
    }

    const parsed = parseClientMessage(raw);
    if (!parsed.ok) {
      this.send(session.playerId, {
        type: "error",
        code: parsed.error.code,
        message: parsed.error.message,
      });
      return;
    }

    try {
      this.engine.handleMessage(session.playerId, parsed.message);
    } catch (error) {
      console.error("Room message handler failed", error);
      this.send(session.playerId, {
        type: "error",
        code: "internal_error",
        message: "Could not process the message.",
      });
    }
    this.schedule();
  }

  cleanupSession(session) {
    if (session.closed) return false;
    session.closed = true;
    if (session.idleTimer !== null) {
      clearTimeout(session.idleTimer);
      session.idleTimer = null;
    }
    this.sessions.delete(session.playerId);
    try {
      this.engine.disconnect(session.playerId);
    } catch (error) {
      console.error("Room disconnect cleanup failed", error);
    }
    this.schedule();
    return true;
  }

  onClose(session) {
    this.cleanupSession(session);
  }

  async fetch(request) {
    const url = new URL(request.url);
    const upgrade = (request.headers.get("Upgrade") ?? "").toLowerCase();

    if (url.pathname === "/health") {
      return json({
        ok: true,
        service: "tamlama-room-hub",
        rooms: this.engine.roomCount,
        connections: this.sessions.size,
        levels: this.engine.data.counts,
        server_time: Date.now(),
      });
    }

    // /ws is canonical. The bare root is a WebSocket-only compatibility alias:
    // a plain GET / stays a 404 and never acts as an HTTP endpoint.
    const isRootAlias = url.pathname === "/" && upgrade === "websocket";
    if (url.pathname !== "/ws" && !isRootAlias) {
      return json({ ok: false, error: "not_found" }, 404);
    }

    if (upgrade !== "websocket") {
      return json({ ok: false, error: "upgrade_required" }, 426);
    }

    if (this.sessions.size >= LIMITS.maxConnections) {
      return json({ ok: false, error: "server_full" }, 503);
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();

    const playerId = crypto.randomUUID();
    const session = {
      playerId,
      ws: server,
      limiter: createRateLimiter(),
      closed: false,
      lastSeenAt: Date.now(),
      idleTimer: null,
    };
    this.sessions.set(playerId, session);
    this.armIdleTimer(session);

    server.addEventListener("message", (event) => this.onMessage(session, event));
    server.addEventListener("close", () => this.onClose(session));
    server.addEventListener("error", () => this.onClose(session));

    this.send(playerId, { type: "welcome", player_id: playerId });
    this.send(playerId, { type: "pong", server_time: Date.now() });
    this.schedule();

    return new Response(null, { status: 101, webSocket: client });
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      if (request.method !== "GET") {
        return json({ ok: false, error: "method_not_allowed" }, 405);
      }
      const hub = env.ROOM_HUB.get(env.ROOM_HUB.idFromName(HUB_NAME));
      return hub.fetch(new Request(new URL("/health", url.origin), { method: "GET" }));
    }

    if (url.pathname === "/ws" || (url.pathname === "/" && isWebSocketUpgrade(request))) {
      const hub = env.ROOM_HUB.get(env.ROOM_HUB.idFromName(HUB_NAME));
      return hub.fetch(request);
    }

    return json({ ok: false, error: "not_found" }, 404);
  },
};
