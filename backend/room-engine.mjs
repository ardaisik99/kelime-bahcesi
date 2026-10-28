/**
 * Shared authoritative room engine for the bilingual "tamlama" game.
 *
 * The engine is deliberately transport agnostic:
 *   - `send(playerId, message)` is supplied by the gateway.
 *   - `now()` is an injectable clock.
 *   - `rng()` is used for level selection.
 *   - `roomCode()` is used for code generation (crypto by default).
 *
 * No timers live in the engine. Gateways call `tick(now)` and schedule the next
 * `nextDeadline()`. This keeps it deterministic under node:test.
 *
 * Match rules:
 *   - One room = two players.
 *   - Three levels, selected at room start.
 *   - The first word of every level is open/given (index 0).
 *   - Players are asked for word index 1, then 2, ... in level order.
 *   - Each accepted word scores 100 points.
 *   - A match finishes when both players finish, one player leaves/disconnects,
 *     or the 90 second play window ends.
 */

import { createLevelIndex } from "./data-adapter.mjs";
import {
  EMOTE_IDS,
  LIMITS,
  generateRoomCode,
  isEmoteId,
  isPlainObject,
  isRoomCode,
  normalizeAnswer,
  normalizeLanguage,
  normalizeRoomCode,
  sanitizeName,
} from "./protocol.mjs";

const MAX_PLAYERS_PER_ROOM = 2;
const SELECTED_LEVEL_COUNT = 3;

function answerableLevels(levels) {
  return levels.filter(
    (level) => Array.isArray(level.words) && level.words.length > 1,
  );
}

function firstProgress(levels) {
  for (let levelIndex = 0; levelIndex < levels.length; levelIndex += 1) {
    if (levels[levelIndex].words.length > 1) {
      return { levelIndex, wordIndex: 1 };
    }
  }
  return null;
}

function advanceProgress(levels, progress) {
  let levelIndex = progress.levelIndex;
  let wordIndex = progress.wordIndex + 1;

  while (levelIndex < levels.length) {
    const words = levels[levelIndex].words;
    if (wordIndex < words.length) {
      return { levelIndex, wordIndex };
    }
    levelIndex += 1;
    wordIndex = 1;
  }
  return null;
}

function pickLevels(levels, count, rng) {
  const pool = levels.slice();
  const picked = [];

  for (let i = 0; i < count && i < pool.length; i += 1) {
    const raw = Number(rng());
    const roll = Number.isFinite(raw) ? Math.min(0.999999999, Math.max(0, raw)) : 0;
    const j = i + Math.floor(roll * (pool.length - i));
    [pool[i], pool[j]] = [pool[j], pool[i]];
    picked.push(pool[i]);
  }
  return picked;
}

export function createRoomEngine(options = {}) {
  if (typeof options.send !== "function") {
    throw new TypeError("createRoomEngine requires a send(playerId, message) callback.");
  }

  const send = options.send;
  const clock = options.now ?? (() => Date.now());
  const rng = options.rng ?? Math.random;
  const roomCodeFactory = options.roomCode ?? generateRoomCode;
  const settings = {
    ...LIMITS,
    ...(options.limits ?? {}),
  };

  const levels = createLevelIndex(options.data ?? { tr: [], en: [] });
  const rooms = new Map();
  const playerRooms = new Map();

  function sendTo(playerId, message) {
    send(playerId, message);
  }

  function errorTo(playerId, code, message) {
    sendTo(playerId, { type: "error", code, message });
  }

  function publicPlayers(room) {
    return [...room.players.values()].map((player) => ({
      id: player.id,
      name: player.name,
      score: player.score,
      connected: player.connected,
    }));
  }

  function publicRoom(room) {
    return {
      type: "room",
      code: room.code,
      language: room.language,
      players: publicPlayers(room),
      status: "waiting",
    };
  }

  function makeCode() {
    for (let attempt = 0; attempt < 50; attempt += 1) {
      let candidate;
      try {
        candidate = roomCodeFactory();
      } catch {
        return null;
      }
      const code = normalizeRoomCode(candidate);
      if (isRoomCode(code) && !rooms.has(code)) return code;
    }
    return null;
  }

  function makePlayer(id, name) {
    return {
      id,
      name,
      score: 0,
      connected: true,
      finished: false,
      progress: null,
      lastEmoteAt: -Infinity,
    };
  }

  function finishRoom(room, reason, at) {
    if (room.status === "finished") return false;
    room.status = "finished";
    room.finishReason = reason;
    room.finishedAt = at;

    const players = publicPlayers(room);
    for (const player of room.players.values()) {
      if (player.connected) {
        sendTo(player.id, { type: "finish", players, reason });
      }
    }

    rooms.delete(room.code);
    for (const player of room.players.values()) {
      if (playerRooms.get(player.id) === room.code) {
        playerRooms.delete(player.id);
      }
    }
    return true;
  }

  function selectGameLevels(language) {
    const pool = answerableLevels(levels.get(language));
    if (pool.length < SELECTED_LEVEL_COUNT) return null;
    return pickLevels(pool, SELECTED_LEVEL_COUNT, rng);
  }

  function startRoom(room, at) {
    const selected = selectGameLevels(room.language);
    if (!selected) {
      const players = publicPlayers(room);
      for (const player of room.players.values()) {
        if (player.connected) {
          errorTo(
            player.id,
            "content_unavailable",
            `Not enough ${room.language} levels with at least two words.`,
          );
        }
        playerRooms.delete(player.id);
      }
      rooms.delete(room.code);
      return false;
    }

    room.levels = selected;
    room.status = "countdown";
    room.startsAt = at + settings.countdownMs;
    room.endsAt = room.startsAt + settings.gameMs;
    room.waitDeadline = null;

    for (const player of room.players.values()) {
      player.score = 0;
      player.finished = false;
      player.progress = firstProgress(selected);
    }

    const startMessage = {
      type: "start",
      starts_at: room.startsAt,
      ends_at: room.endsAt,
      levels: selected.map((level) => level.id),
      players: publicPlayers(room),
    };
    for (const player of room.players.values()) {
      if (player.connected) sendTo(player.id, startMessage);
    }
    return true;
  }

  function createRoom(playerId, message, at) {
    if (playerRooms.has(playerId)) {
      errorTo(playerId, "already_in_room", "You are already in a room.");
      return null;
    }

    const language = normalizeLanguage(message.language);
    if (!language) {
      errorTo(playerId, "invalid_language", "language must be 'tr' or 'en'.");
      return null;
    }

    const name = sanitizeName(message.name);
    if (!name) {
      errorTo(
        playerId,
        "invalid_name",
        `Name must be 1-${LIMITS.maxNameLength} printable characters.`,
      );
      return null;
    }

    if (answerableLevels(levels.get(language)).length < SELECTED_LEVEL_COUNT) {
      errorTo(
        playerId,
        "content_unavailable",
        `Not enough ${language} levels with at least two words.`,
      );
      return null;
    }

    if (rooms.size >= settings.maxRooms) {
      errorTo(playerId, "server_busy", "No room slots are currently available.");
      return null;
    }

    const code = makeCode();
    if (!code) {
      errorTo(playerId, "server_busy", "Could not allocate a unique room code.");
      return null;
    }

    const room = {
      code,
      language,
      status: "waiting",
      players: new Map(),
      createdAt: at,
      waitDeadline: at + settings.waitingMs,
      startsAt: null,
      endsAt: null,
      levels: [],
      finishReason: null,
      finishedAt: null,
    };
    room.players.set(playerId, makePlayer(playerId, name));
    rooms.set(code, room);
    playerRooms.set(playerId, code);

    sendTo(playerId, publicRoom(room));
    return room;
  }

  function joinRoom(playerId, message, at) {
    if (playerRooms.has(playerId)) {
      errorTo(playerId, "already_in_room", "You are already in a room.");
      return null;
    }

    const name = sanitizeName(message.name);
    if (!name) {
      errorTo(
        playerId,
        "invalid_name",
        `Name must be 1-${LIMITS.maxNameLength} printable characters.`,
      );
      return null;
    }

    const code = normalizeRoomCode(message.code);
    if (!isRoomCode(code)) {
      errorTo(playerId, "room_not_found", "Room code is not valid.");
      return null;
    }

    const room = rooms.get(code);
    if (!room) {
      errorTo(playerId, "room_not_found", "Room not found.");
      return null;
    }

    if (room.status !== "waiting") {
      errorTo(playerId, "room_unavailable", "This room has already started.");
      return null;
    }

    if (at >= room.waitDeadline) {
      finishRoom(room, "waiting_timeout", at);
      errorTo(playerId, "room_not_found", "Room not found.");
      return null;
    }

    if (room.players.size >= MAX_PLAYERS_PER_ROOM) {
      errorTo(playerId, "room_full", "This room is full.");
      return null;
    }

    room.players.set(playerId, makePlayer(playerId, name));
    playerRooms.set(playerId, code);

    const roomMessage = publicRoom(room);
    for (const player of room.players.values()) {
      if (player.connected) sendTo(player.id, roomMessage);
    }

    startRoom(room, at);
    return room;
  }

  function sendAnswerResult(playerId, room, player, correct, nextProgress) {
    sendTo(playerId, {
      type: "answer_result",
      correct,
      level_index: nextProgress ? nextProgress.levelIndex : correct ? -1 : player.progress.levelIndex,
      word_index: nextProgress ? nextProgress.wordIndex : correct ? -1 : player.progress.wordIndex,
      score: player.score,
      finished: player.finished,
    });
  }

  function broadcastScores(room) {
    const message = { type: "score", players: publicPlayers(room) };
    for (const player of room.players.values()) {
      if (player.connected) sendTo(player.id, message);
    }
  }

  function answer(playerId, message, at) {
    const code = playerRooms.get(playerId);
    if (!code) {
      errorTo(playerId, "no_room", "Join or create a room first.");
      return false;
    }
    const room = rooms.get(code);
    if (!room) {
      playerRooms.delete(playerId);
      errorTo(playerId, "no_room", "Join or create a room first.");
      return false;
    }

    if (room.status === "waiting" || at < room.startsAt) {
      errorTo(playerId, "not_started", "The countdown has not finished yet.");
      return false;
    }
    if (at >= room.endsAt) {
      finishRoom(room, "timeout", at);
      errorTo(playerId, "game_over", "The play window has ended.");
      return false;
    }

    room.status = "playing";
    const player = room.players.get(playerId);
    if (!player) {
      errorTo(playerId, "no_room", "Join or create a room first.");
      return false;
    }
    if (player.finished) {
      errorTo(playerId, "already_finished", "You have already finished all words.");
      return false;
    }

    if (typeof message.answer !== "string") {
      errorTo(playerId, "invalid_answer", "answer must be a string.");
      return false;
    }
    if (Array.from(message.answer).length > settings.maxAnswerLength) {
      errorTo(
        playerId,
        "invalid_answer",
        `answer must be at most ${settings.maxAnswerLength} characters.`,
      );
      return false;
    }
    if (
      !Number.isInteger(message.level_index) ||
      !Number.isInteger(message.word_index) ||
      message.level_index < 0 ||
      message.word_index < 0
    ) {
      errorTo(
        playerId,
        "invalid_coordinates",
        "level_index and word_index must be non-negative integers.",
      );
      return false;
    }

    const expected = player.progress;
    if (
      !expected ||
      message.level_index !== expected.levelIndex ||
      message.word_index !== expected.wordIndex
    ) {
      sendAnswerResult(playerId, room, player, false, null);
      return false;
    }

    const expectedWord = room.levels[expected.levelIndex]?.words[expected.wordIndex];
    if (expectedWord === undefined) {
      errorTo(playerId, "internal_error", "Level progress is out of range.");
      return false;
    }

    if (
      normalizeAnswer(message.answer, room.language) !==
      normalizeAnswer(expectedWord, room.language)
    ) {
      sendAnswerResult(playerId, room, player, false, null);
      return false;
    }

    player.score += settings.scorePerWord;
    const next = advanceProgress(room.levels, player.progress);
    player.progress = next;
    player.finished = next === null;

    sendAnswerResult(playerId, room, player, true, next);
    broadcastScores(room);

    if ([...room.players.values()].every((candidate) => candidate.finished)) {
      finishRoom(room, "completed", at);
    }
    return true;
  }

  function emote(playerId, message, at) {
    if (!isEmoteId(message.id)) {
      errorTo(playerId, "invalid_emote", `Emote id must be one of: ${EMOTE_IDS.join(", ")}.`);
      return false;
    }

    const code = playerRooms.get(playerId);
    if (!code) {
      errorTo(playerId, "no_room", "Join or create a room first.");
      return false;
    }
    const room = rooms.get(code);
    if (!room) {
      playerRooms.delete(playerId);
      errorTo(playerId, "no_room", "Join or create a room first.");
      return false;
    }

    const player = room.players.get(playerId);
    if (!player) {
      errorTo(playerId, "no_room", "Join or create a room first.");
      return false;
    }

    if (at - player.lastEmoteAt < settings.emoteCooldownMs) {
      errorTo(playerId, "rate_limited", "Emotes are rate limited.");
      return false;
    }
    player.lastEmoteAt = at;

    const outbound = { type: "emote", player_id: playerId, id: message.id };
    for (const candidate of room.players.values()) {
      if (candidate.connected) sendTo(candidate.id, outbound);
    }
    return true;
  }

  function leaveRoom(playerId) {
    const code = playerRooms.get(playerId);
    if (!code) return false;

    const room = rooms.get(code);
    if (!room) {
      playerRooms.delete(playerId);
      return false;
    }

    if (room.status === "waiting") {
      room.players.delete(playerId);
      playerRooms.delete(playerId);
      if (room.players.size === 0) rooms.delete(room.code);
      return true;
    }

    const player = room.players.get(playerId);
    if (player) player.connected = false;
    finishRoom(room, "opponent_left", clock());
    return true;
  }

  function disconnect(playerId) {
    const code = playerRooms.get(playerId);
    if (!code) return false;

    const room = rooms.get(code);
    if (!room) {
      playerRooms.delete(playerId);
      return false;
    }

    const player = room.players.get(playerId);
    if (!player) {
      playerRooms.delete(playerId);
      return false;
    }

    if (room.status === "waiting") {
      room.players.delete(playerId);
      playerRooms.delete(playerId);
      if (room.players.size === 0) rooms.delete(room.code);
      return true;
    }

    player.connected = false;
    finishRoom(room, "opponent_disconnected", clock());
    return true;
  }

  function tick(at = clock()) {
    let finished = 0;
    for (const room of [...rooms.values()]) {
      if (room.status === "waiting" && at >= room.waitDeadline) {
        if (finishRoom(room, "waiting_timeout", at)) finished += 1;
        continue;
      }
      if (room.status === "countdown" || room.status === "playing") {
        if (at >= room.endsAt) {
          if (finishRoom(room, "timeout", at)) finished += 1;
          continue;
        }
        if (room.status === "countdown" && at >= room.startsAt) {
          room.status = "playing";
        }
      }
    }
    return finished;
  }

  function nextDeadline() {
    let next = Infinity;
    for (const room of rooms.values()) {
      const deadline =
        room.status === "waiting"
          ? room.waitDeadline
          : room.status === "countdown" || room.status === "playing"
            ? room.endsAt
            : null;
      if (deadline !== null && deadline < next) next = deadline;
    }
    return Number.isFinite(next) ? next : null;
  }

  function inspectRoom(code) {
    const room = rooms.get(normalizeRoomCode(code));
    if (!room) return null;
    return {
      code: room.code,
      language: room.language,
      status: room.status,
      players: publicPlayers(room),
      levels: room.levels.map((level) => level.id),
      createdAt: room.createdAt,
      waitDeadline: room.waitDeadline,
      startsAt: room.startsAt,
      endsAt: room.endsAt,
      finishReason: room.finishReason,
    };
  }

  function handleMessage(playerId, message) {
    if (typeof playerId !== "string" || playerId.length === 0) return;
    if (!isPlainObject(message) || typeof message.type !== "string") {
      errorTo(playerId, "invalid_message", "Message must be an object with a type.");
      return;
    }

    const at = clock();
    switch (message.type) {
      case "create":
        createRoom(playerId, message, at);
        break;
      case "join":
        joinRoom(playerId, message, at);
        break;
      case "answer":
        answer(playerId, message, at);
        break;
      case "emote":
        emote(playerId, message, at);
        break;
      case "leave":
        leaveRoom(playerId);
        break;
      case "ping":
        sendTo(playerId, { type: "pong", server_time: at });
        break;
      default:
        errorTo(playerId, "unknown_type", `Unknown message type: ${message.type}`);
    }
  }

  return {
    handleMessage,
    tick,
    nextDeadline,
    disconnect,
    inspectRoom,
    playerRoomCode: (playerId) => playerRooms.get(playerId) ?? null,
    get roomCount() {
      return rooms.size;
    },
    settings,
    data: levels,
  };
}
