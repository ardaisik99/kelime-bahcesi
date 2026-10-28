import assert from "node:assert/strict";
import test from "node:test";

import { createRoomEngine, } from "../room-engine.mjs";

const fixture = {
  tr: [
    { id: "tr-1", words: ["elma", "armut", "muz"] },
    { id: "tr-2", words: ["başlangıç", "İZMİR", "IŞIK"] },
    { id: "tr-3", words: ["gece", "gündüz"] },
    { id: "tr-4", words: ["deniz", "dalga"] },
  ],
  en: [
    { id: "en-1", words: ["start", "apple", "banana"] },
    { id: "en-2", words: ["open", "New York", "London"] },
    { id: "en-3", words: ["night", "day"] },
    { id: "en-4", words: ["sea", "wave"] },
  ],
};

const TURKISH_RUN = [
  { level: 0, word: 1, answer: "armut" },
  { level: 0, word: 2, answer: "muz" },
  { level: 1, word: 1, answer: "izmir" },
  { level: 1, word: 2, answer: "IŞIK" },
  { level: 2, word: 1, answer: "gündüz" },
];

function setup(options = {}) {
  let now = 1_700_000_000_000;
  const sent = [];
  const engine = createRoomEngine({
    data: fixture,
    send: (playerId, message) => sent.push({ playerId, message: { ...message } }),
    now: () => now,
    rng: options.rng ?? (() => 0),
    roomCode: options.roomCode,
    limits: options.limits,
  });

  function to(playerId, type) {
    return sent
      .filter((entry) => entry.playerId === playerId && (!type || entry.message.type === type))
      .map((entry) => entry.message);
  }

  function last(playerId, type) {
    return to(playerId, type).at(-1);
  }

  function createAndJoin({ language = "tr", first = "Ada", second = "Bora" } = {}) {
    engine.handleMessage("p1", { type: "create", language, name: first });
    const room = last("p1", "room");
    assert.ok(room, "creator should receive a room message");
    engine.handleMessage("p2", { type: "join", code: room.code, name: second });
    const start = last("p1", "start");
    assert.ok(start, "join should start the match");
    return { code: room.code, start };
  }

  function answer(level, word, text, playerId = "p1", extra = {}) {
    engine.handleMessage(playerId, {
      type: "answer",
      answer: text,
      level_index: level,
      word_index: word,
      ...extra,
    });
    return last(playerId, "answer_result");
  }

  return {
    engine,
    sent,
    get now() {
      return now;
    },
    setNow(value) {
      now = value;
    },
    advance(ms) {
      now += ms;
    },
    to,
    last,
    createAndJoin,
    answer,
  };
}

test("create and join: waiting room, three level ids, 3 second countdown", () => {
  const ctx = setup();
  ctx.engine.handleMessage("p1", { type: "create", language: "tr", name: "  Ada  " });

  const waiting = ctx.last("p1", "room");
  assert.equal(waiting.status, "waiting");
  assert.equal(waiting.language, "tr");
  assert.equal(waiting.players.length, 1);
  assert.equal(waiting.players[0].name, "Ada");
  assert.equal(waiting.players[0].score, 0);
  assert.equal(waiting.players[0].connected, true);
  assert.match(waiting.code, /^[A-HJ-NP-Z2-9]{6}$/);

  const joinAt = ctx.now;
  ctx.engine.handleMessage("p2", { type: "join", code: waiting.code.toLowerCase(), name: "Bora" });

  const updated = ctx.last("p1", "room");
  assert.equal(updated.players.length, 2);
  assert.deepEqual(
    updated.players.map((player) => player.name),
    ["Ada", "Bora"],
  );

  for (const playerId of ["p1", "p2"]) {
    const start = ctx.last(playerId, "start");
    assert.ok(start);
    assert.equal(start.levels.length, 3);
    assert.deepEqual(start.levels, ["tr-1", "tr-2", "tr-3"]);
    assert.equal(new Set(start.levels).size, 3);
    assert.equal(start.starts_at, joinAt + 3000);
    assert.equal(start.ends_at, start.starts_at + 90_000);
    assert.equal(start.players.length, 2);
  }

  const room = ctx.engine.inspectRoom(waiting.code);
  assert.equal(room.status, "countdown");
  assert.deepEqual(room.levels, ["tr-1", "tr-2", "tr-3"]);
  assert.equal(ctx.engine.nextDeadline(), room.endsAt);
});

test("validation window: answers before starts_at are rejected and cannot score", () => {
  const ctx = setup();
  const { start } = ctx.createAndJoin();

  ctx.setNow(start.starts_at - 1);
  ctx.answer(0, 1, "armut", "p1", { score: 999_999 });

  const error = ctx.last("p1", "error");
  assert.equal(error.code, "not_started");
  assert.equal(ctx.last("p1", "answer_result"), undefined);
  assert.equal(ctx.last("p1", "score"), undefined);
  assert.equal(ctx.engine.inspectRoom(ctx.last("p1", "room").code).players[0].score, 0);

  ctx.setNow(start.starts_at);
  const result = ctx.answer(0, 1, "armut", "p1", { score: 999_999 });
  assert.equal(result.correct, true);
  assert.equal(result.score, 100);
  assert.equal(result.level_index, 0);
  assert.equal(result.word_index, 2);
  assert.equal(result.finished, false);

  const score = ctx.last("p1", "score");
  assert.equal(score.players.find((player) => player.id === "p1").score, 100);
  assert.equal(score.players.find((player) => player.id === "p2").score, 0);
});

test("server ignores forged score messages and does not trust client state", () => {
  const ctx = setup();
  const { start } = ctx.createAndJoin();
  ctx.setNow(start.starts_at);

  ctx.engine.handleMessage("p1", {
    type: "score",
    players: [{ id: "p1", name: "Ada", score: 999_999, connected: true }],
  });
  assert.equal(ctx.last("p1", "error").code, "unknown_type");

  const result = ctx.answer(0, 1, "armut", "p1", {
    score: 999_999,
    players: [{ id: "p1", name: "Ada", score: 999_999, connected: true }],
  });
  assert.equal(result.correct, true);
  assert.equal(result.score, 100);

  const room = ctx.engine.inspectRoom(ctx.last("p1", "room").code);
  assert.equal(room.players.find((player) => player.id === "p1").score, 100);
});

test("wrong and stale coordinates/answers preserve current expected progress", () => {
  const ctx = setup();
  const { start } = ctx.createAndJoin();
  ctx.setNow(start.starts_at);

  const wrong = ctx.answer(0, 1, "elma");
  assert.equal(wrong.correct, false);
  assert.equal(wrong.level_index, 0);
  assert.equal(wrong.word_index, 1);
  assert.equal(wrong.score, 0);

  const skipped = ctx.answer(0, 2, "armut");
  assert.equal(skipped.correct, false);
  assert.equal(skipped.level_index, 0);
  assert.equal(skipped.word_index, 1);

  const correct = ctx.answer(0, 1, "armut");
  assert.equal(correct.correct, true);
  assert.equal(correct.word_index, 2);
  assert.equal(correct.score, 100);

  const stale = ctx.answer(0, 1, "muz");
  assert.equal(stale.correct, false);
  assert.equal(stale.level_index, 0);
  assert.equal(stale.word_index, 2);
  assert.equal(stale.score, 100);

  const next = ctx.answer(0, 2, "muz");
  assert.equal(next.correct, true);
  assert.equal(next.level_index, 1);
  assert.equal(next.word_index, 1);
  assert.equal(next.score, 200);
});

test("Turkish normalization uses strict İ/i and I/ı mapping", () => {
  const ctx = setup();
  const { start } = ctx.createAndJoin();
  ctx.setNow(start.starts_at);
  ctx.answer(0, 1, "armut");
  ctx.answer(0, 2, "muz");

  const wrongI = ctx.answer(1, 1, "IZMIR");
  assert.equal(wrongI.correct, false, "I must normalize to ı, not i");

  const dotted = ctx.answer(1, 1, "izmir");
  assert.equal(dotted.correct, true, "İZMİR should accept izmir");

  const dotless = ctx.answer(1, 2, "IŞIK");
  assert.equal(dotless.correct, true, "IŞIK should normalize to ışık");
  assert.equal(dotless.level_index, 2);
  assert.equal(dotless.word_index, 1);
});

test("English normalization is ordinary case folding", () => {
  const ctx = setup();
  const { start } = ctx.createAndJoin({ language: "en" });
  ctx.setNow(start.starts_at);

  const result = ctx.answer(0, 1, "APPLE");
  assert.equal(result.correct, true);
  assert.equal(result.level_index, 0);
  assert.equal(result.word_index, 2);
});

test("both players finishing ends the room and marks the final answer done", () => {
  const ctx = setup();
  const { code, start } = ctx.createAndJoin();
  ctx.setNow(start.starts_at);

  for (const step of TURKISH_RUN) {
    ctx.answer(step.level, step.word, step.answer, "p1");
  }
  const finalP1 = ctx.last("p1", "answer_result");
  assert.equal(finalP1.finished, true);
  assert.equal(finalP1.level_index, -1);
  assert.equal(finalP1.word_index, -1);
  assert.equal(finalP1.score, 500);
  assert.equal(ctx.sent.filter((entry) => entry.message.type === "finish").length, 0);

  for (const step of TURKISH_RUN) {
    ctx.answer(step.level, step.word, step.answer, "p2");
  }
  const finalP2 = ctx.last("p2", "answer_result");
  assert.equal(finalP2.finished, true);
  assert.equal(finalP2.score, 500);

  for (const playerId of ["p1", "p2"]) {
    const finish = ctx.last(playerId, "finish");
    assert.equal(finish.reason, "completed");
    assert.deepEqual(
      finish.players.map((player) => player.score),
      [500, 500],
    );
  }
  assert.equal(ctx.engine.inspectRoom(code), null);
  assert.equal(ctx.engine.roomCount, 0);
  assert.equal(ctx.engine.nextDeadline(), null);
});

test("timer finishes the match at ends_at and rejects later answers", () => {
  const ctx = setup();
  const { code, start } = ctx.createAndJoin();
  ctx.setNow(start.starts_at);
  ctx.answer(0, 1, "armut");

  ctx.setNow(start.ends_at - 1);
  ctx.engine.tick();
  assert.equal(ctx.engine.inspectRoom(code).status, "playing");

  ctx.setNow(start.ends_at);
  const finished = ctx.engine.tick();
  assert.equal(finished, 1);
  for (const playerId of ["p1", "p2"]) {
    assert.equal(ctx.last(playerId, "finish").reason, "timeout");
  }
  assert.equal(ctx.engine.inspectRoom(code), null);

  const before = ctx.to("p1", "answer_result").length;
  ctx.engine.handleMessage("p1", {
    type: "answer",
    answer: "muz",
    level_index: 0,
    word_index: 2,
  });
  assert.equal(ctx.last("p1", "error").code, "no_room");
  assert.equal(ctx.to("p1", "answer_result").length, before);
});

test("answer exactly at ends_at is rejected and finishes the room", () => {
  const ctx = setup();
  const { code, start } = ctx.createAndJoin();
  ctx.setNow(start.ends_at);

  ctx.engine.handleMessage("p1", {
    type: "answer",
    answer: "armut",
    level_index: 0,
    word_index: 1,
  });
  assert.equal(ctx.last("p1", "error").code, "game_over");
  assert.equal(ctx.last("p1", "finish").reason, "timeout");
  assert.equal(ctx.engine.inspectRoom(code), null);
});

test("disconnect cancels an active match and cleans up the waiting room", () => {
  const waiting = setup();
  waiting.engine.handleMessage("p1", { type: "create", language: "tr", name: "Ada" });
  const waitingCode = waiting.last("p1", "room").code;
  assert.equal(waiting.engine.disconnect("p1"), true);
  assert.equal(waiting.engine.roomCount, 0);
  assert.equal(waiting.engine.inspectRoom(waitingCode), null);

  const ctx = setup();
  const { code, start } = ctx.createAndJoin();
  ctx.setNow(start.starts_at);
  assert.equal(ctx.engine.disconnect("p2"), true);

  const finish = ctx.last("p1", "finish");
  assert.equal(finish.reason, "opponent_disconnected");
  assert.equal(finish.players.find((player) => player.id === "p2").connected, false);
  assert.equal(ctx.engine.inspectRoom(code), null);
  assert.equal(ctx.engine.playerRoomCode("p1"), null);
  assert.equal(ctx.engine.nextDeadline(), null);

  // The remaining session can create a fresh room immediately.
  ctx.engine.handleMessage("p1", { type: "create", language: "tr", name: "Ada" });
  assert.equal(ctx.engine.roomCount, 1);
});

test("explicit leave notifies the opponent with opponent_left", () => {
  const ctx = setup();
  ctx.createAndJoin();
  ctx.engine.handleMessage("p2", { type: "leave" });
  assert.equal(ctx.last("p1", "finish").reason, "opponent_left");
  assert.equal(ctx.engine.roomCount, 0);
});

test("waiting rooms expire after the 15 minute deadline", () => {
  const ctx = setup();
  ctx.engine.handleMessage("p1", { type: "create", language: "tr", name: "Ada" });
  const code = ctx.last("p1", "room").code;

  ctx.advance(ctx.engine.settings.waitingMs);
  assert.equal(ctx.engine.tick(), 1);
  assert.equal(ctx.last("p1", "finish").reason, "waiting_timeout");
  assert.equal(ctx.engine.inspectRoom(code), null);
  assert.equal(ctx.engine.nextDeadline(), null);

  ctx.engine.handleMessage("p2", { type: "join", code, name: "Bora" });
  assert.equal(ctx.last("p2", "error").code, "room_not_found");
});

test("room codes are six unambiguous characters and unique", () => {
  const ctx = setup();
  const codes = new Set();

  for (let i = 0; i < 150; i += 1) {
    const playerId = `player-${i}`;
    ctx.engine.handleMessage(playerId, {
      type: "create",
      language: "tr",
      name: `Player ${i}`,
    });
    const room = ctx.last(playerId, "room");
    assert.ok(room, `room ${i} should be created`);
    assert.match(room.code, /^[A-HJ-NP-Z2-9]{6}$/);
    codes.add(room.code);
  }

  assert.equal(codes.size, 150);
  assert.equal(ctx.engine.roomCount, 150);
});

test("room capacity is bounded", () => {
  const ctx = setup({ limits: { maxRooms: 2 } });
  ctx.engine.handleMessage("p1", { type: "create", language: "tr", name: "Ada" });
  ctx.engine.handleMessage("p2", { type: "create", language: "tr", name: "Bora" });
  ctx.engine.handleMessage("p3", { type: "create", language: "tr", name: "Cem" });

  assert.equal(ctx.last("p3", "error").code, "server_busy");
  assert.equal(ctx.engine.roomCount, 2);
});

test("names, emotes, and emote rate limits are enforced", () => {
  const ctx = setup();
  const { start } = ctx.createAndJoin();
  ctx.setNow(start.starts_at);

  ctx.engine.handleMessage("p3", {
    type: "create",
    language: "tr",
    name: "x".repeat(25),
  });
  assert.equal(ctx.last("p3", "error").code, "invalid_name");

  ctx.engine.handleMessage("p1", { type: "emote", id: "hello" });
  assert.equal(ctx.last("p1", "emote").id, "hello");
  assert.equal(ctx.last("p2", "emote").player_id, "p1");

  ctx.engine.handleMessage("p1", { type: "emote", id: "nice" });
  assert.equal(ctx.last("p1", "error").code, "rate_limited");

  ctx.advance(1500);
  ctx.engine.handleMessage("p1", { type: "emote", id: "wow" });
  assert.equal(ctx.last("p1", "emote").id, "wow");

  ctx.engine.handleMessage("p1", { type: "emote", id: "hint" });
  assert.equal(ctx.last("p1", "error").code, "invalid_emote");
});

test("ping returns server time without needing a room", () => {
  const ctx = setup();
  ctx.engine.handleMessage("p1", { type: "ping" });
  assert.deepEqual(ctx.last("p1", "pong"), { type: "pong", server_time: ctx.now });
});

test("join errors are explicit for missing/full/unstarted rooms", () => {
  const ctx = setup();
  ctx.engine.handleMessage("p1", { type: "join", code: "ZZZZZZ", name: "Ada" });
  assert.equal(ctx.last("p1", "error").code, "room_not_found");

  ctx.engine.handleMessage("p1", { type: "join", code: "low", name: "Ada" });
  assert.equal(ctx.last("p1", "error").code, "room_not_found");

  const { code } = ctx.createAndJoin();
  ctx.engine.handleMessage("p3", { type: "join", code, name: "Cem" });
  assert.equal(ctx.last("p3", "error").code, "room_unavailable");
});
