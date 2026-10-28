/**
 * Shared wire-protocol constants and validation used by both the Node server
 * and the Cloudflare Worker/Durable Object gateway.
 *
 * This module deliberately has no Node- or Worker-specific imports so the
 * authoritative room engine and its tests can use it everywhere.
 */

export const LANGUAGES = Object.freeze(["tr", "en"]);

export const EMOTE_IDS = Object.freeze(["hello", "nice", "wow", "gg"]);
const EMOTE_SET = new Set(EMOTE_IDS);

/** Unambiguous room-code alphabet (no I, O, 0, 1). */
export const ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const ROOM_CODE_LENGTH = 6;

export const LIMITS = Object.freeze({
  /** Raw client JSON message size. */
  maxMessageBytes: 4096,
  maxNameLength: 24,
  maxAnswerLength: 120,
  /** Rooms held by one engine / Durable Object hub. */
  maxRooms: 200,
  /** WebSocket connections held by one gateway / Durable Object hub. */
  maxConnections: 500,
  /** Waiting room lifetime before it is cancelled. */
  waitingMs: 15 * 60 * 1000,
  /** Countdown before starts_at. */
  countdownMs: 3000,
  /** Answer window after starts_at. */
  gameMs: 90 * 1000,
  /**
   * Close a gateway WebSocket that sends no client message for this long.
   * The real client pings every 15 seconds; this reaps dead/unjoined sockets.
   */
  maxIdleMs: 90 * 1000,
  scorePerWord: 100,
  emoteCooldownMs: 1500,
  /** Per-connection token bucket. */
  rateCapacity: 30,
  rateRefillPerSecond: 10,
});

const ROOM_CODE_RE = new RegExp(`^[${ROOM_CODE_ALPHABET}]{${ROOM_CODE_LENGTH}}$`);
const CONTROL_CHARS_RE = /[\u0000-\u001f\u007f-\u009f]/g;

export function normalizeLanguage(value) {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  if (normalized === "tr" || normalized.startsWith("tr-")) return "tr";
  if (normalized === "en" || normalized.startsWith("en-")) return "en";
  return null;
}

export function isRoomCode(value) {
  return typeof value === "string" && ROOM_CODE_RE.test(value);
}

export function normalizeRoomCode(value) {
  if (typeof value !== "string") return "";
  return value.trim().toUpperCase();
}

/**
 * Strict answer normalization.
 *
 * Turkish explicitly maps:
 *   I -> ı (dotless capital I) and İ -> i (dotted capital I)
 * before ordinary lowercasing, so it does not depend on host ICU locale data.
 * English uses ordinary uppercase and is not Turkish-locale folded.
 *
 * Only Unicode NFC, whitespace and case are normalized. Punctuation and
 * letters are otherwise exact.
 */
export function normalizeAnswer(value, language) {
  if (typeof value !== "string") return "";
  const collapsed = value.normalize("NFC").replace(/\s+/g, " ").trim();
  if (normalizeLanguage(language) === "tr") {
    return collapsed.replace(/I/g, "ı").replace(/İ/g, "i").toLowerCase();
  }
  return collapsed.toUpperCase();
}

export function sanitizeName(value) {
  if (typeof value !== "string") return null;
  const name = value
    .normalize("NFC")
    .replace(CONTROL_CHARS_RE, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (name.length === 0) return null;
  if (Array.from(name).length > LIMITS.maxNameLength) return null;
  return name;
}

export function isPlainObject(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

export function makeError(code, message) {
  return { type: "error", code, message };
}

/**
 * Validates raw text and parses it as a JSON object. The gateway performs this
 * before handing messages to the engine so oversized/binary input is bounded.
 */
export function parseClientMessage(raw) {
  if (typeof raw !== "string") {
    return {
      ok: false,
      error: {
        code: "binary_not_supported",
        message: "Messages must be UTF-8 text JSON.",
      },
    };
  }

  const byteLength = new TextEncoder().encode(raw).byteLength;
  if (byteLength > LIMITS.maxMessageBytes) {
    return {
      ok: false,
      error: {
        code: "message_too_large",
        message: `Messages must be at most ${LIMITS.maxMessageBytes} bytes.`,
      },
    };
  }

  let message;
  try {
    message = JSON.parse(raw);
  } catch {
    return {
      ok: false,
      error: { code: "invalid_json", message: "Message is not valid JSON." },
    };
  }

  if (!isPlainObject(message)) {
    return {
      ok: false,
      error: {
        code: "invalid_message",
        message: "Message must be a JSON object.",
      },
    };
  }

  if (typeof message.type !== "string" || message.type.length === 0) {
    return {
      ok: false,
      error: {
        code: "invalid_message",
        message: "Message must include a string type.",
      },
    };
  }

  return { ok: true, message };
}

/**
 * Small per-connection token bucket. `now` is injectable for tests.
 */
export function createRateLimiter(options = {}) {
  const capacity = options.capacity ?? LIMITS.rateCapacity;
  const refillPerSecond = options.refillPerSecond ?? LIMITS.rateRefillPerSecond;
  const clock = options.now ?? Date.now;

  let tokens = capacity;
  let last = clock();

  return {
    consume(at = clock()) {
      const elapsedMs = Math.max(0, at - last);
      last = at;
      tokens = Math.min(capacity, tokens + (elapsedMs / 1000) * refillPerSecond);
      if (tokens < 1) return false;
      tokens -= 1;
      return true;
    },
    get available() {
      return tokens;
    },
  };
}

/**
 * Cryptographically random 6-character room code. The 32-character alphabet
 * excludes I/O/0/1, and 256 is evenly divisible by 32, so every byte maps
 * uniformly without rejection.
 */
export function generateRoomCode() {
  const cryptoApi = globalThis.crypto;
  if (!cryptoApi || typeof cryptoApi.getRandomValues !== "function") {
    throw new Error("crypto.getRandomValues is required for room codes.");
  }

  let code = "";
  const bytes = new Uint8Array(ROOM_CODE_LENGTH * 2);
  while (code.length < ROOM_CODE_LENGTH) {
    cryptoApi.getRandomValues(bytes);
    for (const byte of bytes) {
      code += ROOM_CODE_ALPHABET[byte % ROOM_CODE_ALPHABET.length];
      if (code.length === ROOM_CODE_LENGTH) break;
    }
  }
  return code;
}

export function isEmoteId(value) {
  return typeof value === "string" && EMOTE_SET.has(value);
}
