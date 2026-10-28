/**
 * Local Node WebSocket gateway.
 *
 * Defaults: ws://127.0.0.1:8787 (bare root; /ws is the canonical alias),
 * health at http://127.0.0.1:8787/health
 * Environment: HOST, PORT, LEVELS_FILE
 */

import { randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { WebSocket, WebSocketServer } from "ws";

import { createLevelIndex } from "./data-adapter.mjs";
import { LIMITS, createRateLimiter, parseClientMessage } from "./protocol.mjs";
import { createRoomEngine } from "./room-engine.mjs";

export const DEFAULT_LEVELS_FILE = fileURLToPath(
  new URL("../data/levels.json", import.meta.url),
);

function writeJson(response, status, body, extraHeaders = {}) {
  const payload = JSON.stringify(body);
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(payload),
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    ...extraHeaders,
  });
  response.end(payload);
}

function rejectUpgrade(socket, status, message) {
  const body = JSON.stringify({ ok: false, error: message });
  socket.write(
    `HTTP/1.1 ${status} ${message}\r\n` +
      "Connection: close\r\n" +
      "Content-Type: application/json; charset=utf-8\r\n" +
      `Content-Length: ${Buffer.byteLength(body)}\r\n` +
      "\r\n" +
      body,
  );
  socket.destroy();
}

async function parseLevelsFile(file, text) {
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`Levels file is not valid JSON: ${file}. (${error.message})`, {
      cause: error,
    });
  }
}

async function loadSource(levelsFile, allowSplitFallback = false) {
  let text;
  try {
    text = await readFile(levelsFile, "utf8");
  } catch (error) {
    if (allowSplitFallback && error.code === "ENOENT") {
      const directory = path.dirname(levelsFile);
      const trFile = path.join(directory, "levels_tr.json");
      const enFile = path.join(directory, "levels_en.json");
      try {
        const [trText, enText] = await Promise.all([
          readFile(trFile, "utf8"),
          readFile(enFile, "utf8"),
        ]);
        return {
          source: {
            tr: await parseLevelsFile(trFile, trText),
            en: await parseLevelsFile(enFile, enText),
          },
          files: [trFile, enFile],
        };
      } catch {
        // Fall through to the original, more useful missing-file error.
      }
    }

    throw new Error(
      `Cannot read levels file at ${levelsFile}. Set LEVELS_FILE or create ../data/levels.json. (${error.message})`,
      { cause: error },
    );
  }

  return {
    source: await parseLevelsFile(levelsFile, text),
    files: [levelsFile],
  };
}

export async function startLocalServer(options = {}) {
  const host = options.host ?? "127.0.0.1";
  const port = options.port ?? 8787;
  const log = options.log ?? (() => {});
  const levelsFile = options.levelsFile ?? DEFAULT_LEVELS_FILE;
  const maxConnections = options.maxConnections ?? LIMITS.maxConnections;
  const clock = options.now ?? (() => Date.now());

  const allowSplitFallback =
    options.splitFallback ??
    (options.data === undefined &&
      path.resolve(levelsFile) === path.resolve(DEFAULT_LEVELS_FILE));

  let source = options.data;
  let contentFiles = [];
  if (source === undefined) {
    const loaded = await loadSource(levelsFile, allowSplitFallback);
    source = loaded.source;
    contentFiles = loaded.files;
    if (contentFiles.length > 1) {
      log(
        `[content] ${levelsFile} not found; merged ${contentFiles
          .map((file) => path.basename(file))
          .join(" + ")} for local development.`,
      );
    }
  }
  const levelIndex = createLevelIndex(source);
  if (levelIndex.warnings.length > 0) {
    for (const warning of levelIndex.warnings) log(`[content] ${warning}`);
  }
  if (levelIndex.counts.tr < 3 || levelIndex.counts.en < 3) {
    log(
      `[content] Warning: need at least 3 two-word levels per language (tr=${levelIndex.counts.tr}, en=${levelIndex.counts.en}).`,
    );
  }

  const sessions = new Map();
  let timer = null;
  let heartbeat = null;
  let closed = false;

  function send(playerId, message) {
    const session = sessions.get(playerId);
    if (!session || session.closed || session.ws.readyState !== WebSocket.OPEN) return;
    try {
      session.ws.send(JSON.stringify(message));
    } catch {
      // The close/error handler performs cleanup.
    }
  }

  const engine = createRoomEngine({
    data: source,
    send,
    now: clock,
    rng: options.rng,
    roomCode: options.roomCode,
    limits: options.limits,
  });

  function schedule() {
    if (closed) return;
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    const deadline = engine.nextDeadline();
    if (deadline === null) return;
    const delay = Math.max(0, deadline - clock());
    timer = setTimeout(() => {
      timer = null;
      engine.tick(clock());
      schedule();
    }, delay);
    if (typeof timer.unref === "function") timer.unref();
  }

  const httpServer = createServer((request, response) => {
    let url;
    try {
      url = new URL(request.url ?? "/", "http://localhost");
    } catch {
      writeJson(response, 400, { ok: false, error: "bad_request" });
      return;
    }

    if (url.pathname === "/health") {
      if (request.method !== "GET") {
        writeJson(response, 405, { ok: false, error: "method_not_allowed" }, {
          allow: "GET",
        });
        return;
      }
      writeJson(response, 200, {
        ok: true,
        service: "tamlama-room-hub-local",
        rooms: engine.roomCount,
        connections: sessions.size,
        levels: levelIndex.counts,
        server_time: clock(),
        content_files: contentFiles.map((file) => path.basename(file)),
      });
      return;
    }

    writeJson(response, 404, { ok: false, error: "not_found" });
  });

  const wss = new WebSocketServer({
    noServer: true,
    maxPayload: LIMITS.maxMessageBytes,
  });

  httpServer.on("upgrade", (request, socket, head) => {
    let url;
    try {
      url = new URL(request.url ?? "/", "http://localhost");
    } catch {
      rejectUpgrade(socket, 400, "Bad Request");
      return;
    }
    if (url.pathname !== "/ws" && url.pathname !== "/") {
      rejectUpgrade(socket, 404, "Not Found");
      return;
    }
    if (sessions.size >= maxConnections) {
      rejectUpgrade(socket, 503, "Service Unavailable");
      return;
    }
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit("connection", ws, request);
    });
  });

  wss.on("connection", (ws) => {
    const playerId = randomUUID();
    const session = {
      playerId,
      ws,
      limiter: createRateLimiter(),
      closed: false,
      isAlive: true,
    };
    sessions.set(playerId, session);

    function cleanup() {
      if (session.closed) return;
      session.closed = true;
      sessions.delete(playerId);
      engine.disconnect(playerId);
      schedule();
    }

    ws.on("pong", () => {
      session.isAlive = true;
    });
    ws.on("close", cleanup);
    ws.on("error", cleanup);

    ws.on("message", (data, isBinary) => {
      if (session.closed) return;

      if (isBinary) {
        send(playerId, {
          type: "error",
          code: "binary_not_supported",
          message: "Messages must be UTF-8 text JSON.",
        });
        return;
      }

      if (!session.limiter.consume()) {
        send(playerId, {
          type: "error",
          code: "rate_limited",
          message: "Too many messages.",
        });
        return;
      }

      const parsed = parseClientMessage(data.toString("utf8"));
      if (!parsed.ok) {
        send(playerId, {
          type: "error",
          code: parsed.error.code,
          message: parsed.error.message,
        });
        return;
      }

      try {
        engine.handleMessage(playerId, parsed.message);
      } catch (error) {
        log(`[server] message handler error: ${error?.stack ?? error}`);
        send(playerId, {
          type: "error",
          code: "internal_error",
          message: "Could not process the message.",
        });
      }
      schedule();
    });

    send(playerId, { type: "welcome", player_id: playerId });
    send(playerId, { type: "pong", server_time: clock() });
    schedule();
  });

  heartbeat = setInterval(() => {
    for (const session of sessions.values()) {
      if (!session.isAlive) {
        session.ws.terminate();
        continue;
      }
      session.isAlive = false;
      try {
        session.ws.ping();
      } catch {
        // The close/error handler performs cleanup.
      }
    }
  }, 30_000);
  if (typeof heartbeat.unref === "function") heartbeat.unref();

  try {
    await new Promise((resolve, reject) => {
      const onError = (error) => {
        httpServer.off("listening", onListening);
        reject(error);
      };
      const onListening = () => {
        httpServer.off("error", onError);
        resolve();
      };
      httpServer.once("error", onError);
      httpServer.once("listening", onListening);
      httpServer.listen(port, host);
    });
  } catch (error) {
    closed = true;
    clearInterval(heartbeat);
    await new Promise((resolve) => wss.close(() => resolve()));
    throw error;
  }

  const address = httpServer.address();
  const actualPort = typeof address === "object" && address ? address.port : port;

  async function close() {
    if (closed) return;
    closed = true;
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    if (heartbeat) clearInterval(heartbeat);

    for (const session of sessions.values()) {
      try {
        session.ws.close(1001, "Server shutting down");
      } catch {
        session.ws.terminate();
      }
    }
    sessions.clear();

    await new Promise((resolve) => {
      wss.close(() => resolve());
      for (const client of wss.clients) client.terminate();
    });
    httpServer.closeIdleConnections?.();
    httpServer.closeAllConnections?.();
    await new Promise((resolve) => httpServer.close(() => resolve()));
  }

  return {
    host,
    port: actualPort,
    url: `ws://${host}:${actualPort}/ws`,
    healthUrl: `http://${host}:${actualPort}/health`,
    engine,
    levelIndex,
    contentFiles,
    sessions,
    close,
  };
}

function parsePort(raw) {
  const port = Number.parseInt(raw, 10);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error(`Invalid PORT: ${raw}`);
  }
  return port;
}

const isMain =
  typeof process.argv[1] === "string" &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  const host = process.env.HOST?.trim() || "127.0.0.1";
  const port = parsePort(process.env.PORT?.trim() || "8787");
  const levelsFile = process.env.LEVELS_FILE
    ? path.resolve(process.env.LEVELS_FILE)
    : DEFAULT_LEVELS_FILE;

  try {
    const server = await startLocalServer({
      host,
      port,
      levelsFile,
      log: (message) => console.log(message),
    });
    console.log(`[server] listening on ${server.url}`);
    console.log(`[server] health at ${server.healthUrl}`);
    console.log(
      `[server] levels: tr=${server.levelIndex.counts.tr} en=${server.levelIndex.counts.en}`,
    );

    let stopping = false;
    const shutdown = async (signal) => {
      if (stopping) return;
      stopping = true;
      console.log(`[server] ${signal}; shutting down`);
      try {
        await server.close();
      } finally {
        process.exit(0);
      }
    };
    process.once("SIGINT", () => void shutdown("SIGINT"));
    process.once("SIGTERM", () => void shutdown("SIGTERM"));
  } catch (error) {
    console.error(`[server] startup failed: ${error?.message ?? error}`);
    process.exitCode = 1;
  }
}
