import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { WebSocket } from "ws";

import { startLocalServer } from "../local-server.mjs";

const levels = {
  tr: [
    { id: "t1", words: ["açık", "cevap", "son"] },
    { id: "t2", words: ["başka", "cevap"] },
    { id: "t3", words: ["üçüncü", "cevap"] },
  ],
  en: [
    { id: "e1", words: ["open", "answer"] },
    { id: "e2", words: ["second", "answer"] },
    { id: "e3", words: ["third", "answer"] },
  ],
};

class TestClient {
  constructor(url) {
    this.ws = new WebSocket(url);
    this.queue = [];
    this.waiters = [];
    this.closed = new Promise((resolve) => this.ws.once("close", resolve));
    this.opened = new Promise((resolve, reject) => {
      this.ws.once("open", resolve);
      this.ws.once("error", reject);
    });
    this.ws.on("message", (data) => {
      const message = JSON.parse(data.toString());
      const waiter = this.waiters.shift();
      if (waiter) waiter.resolve(message);
      else this.queue.push(message);
    });
  }

  async open() {
    await this.opened;
    return this;
  }

  next(timeoutMs = 3000) {
    if (this.queue.length > 0) return Promise.resolve(this.queue.shift());
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const index = this.waiters.indexOf(waiter);
        if (index >= 0) this.waiters.splice(index, 1);
        reject(new Error("Timed out waiting for a WebSocket message"));
      }, timeoutMs);
      const waiter = {
        resolve: (message) => {
          clearTimeout(timer);
          resolve(message);
        },
      };
      this.waiters.push(waiter);
    });
  }

  async nextOfType(type, timeoutMs = 3000) {
    for (;;) {
      const message = await this.next(timeoutMs);
      if (message.type === type) return message;
    }
  }

  send(message) {
    this.ws.send(JSON.stringify(message));
  }

  close() {
    if (this.ws.readyState === WebSocket.CLOSED) return Promise.resolve();
    this.ws.close();
    return this.closed;
  }
}

test("local gateway merges split language files when levels.json is absent", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "tamlama-split-"));
  const levelsFile = path.join(dir, "levels.json");
  await writeFile(
    path.join(dir, "levels_tr.json"),
    JSON.stringify({
      language: "tr",
      levels: [
        { id: "tr_1", words: ["açık", "cevap"] },
        { id: "tr_2", words: ["başka", "cevap"] },
        { id: "tr_3", words: ["üçüncü", "cevap"] },
      ],
    }),
    "utf8",
  );
  await writeFile(
    path.join(dir, "levels_en.json"),
    JSON.stringify({
      language: "en",
      levels: [
        { id: "en_1", words: ["open", "answer"] },
        { id: "en_2", words: ["second", "answer"] },
        { id: "en_3", words: ["third", "answer"] },
      ],
    }),
    "utf8",
  );

  let server;
  try {
    server = await startLocalServer({
      host: "127.0.0.1",
      port: 0,
      levelsFile,
      splitFallback: true,
    });
    assert.equal(server.contentFiles.length, 2);
    const health = await (await fetch(server.healthUrl)).json();
    assert.deepEqual(health.levels, { tr: 3, en: 3 });
    assert.equal(health.content_files.length, 2);
  } finally {
    if (server) await server.close();
    await rm(dir, { recursive: true, force: true });
  }
});

test("local gateway: health, welcome/pong, create/join, answer, disconnect", async () => {
  const dir = await mkdtemp(path.join(tmpdir(), "tamlama-backend-"));
  const levelsFile = path.join(dir, "levels.json");
  await writeFile(levelsFile, JSON.stringify(levels), "utf8");

  let server;
  const clients = [];
  try {
    server = await startLocalServer({
      host: "127.0.0.1",
      port: 0,
      levelsFile,
      rng: () => 0,
      limits: { countdownMs: 0 },
    });

    const healthResponse = await fetch(server.healthUrl);
    assert.equal(healthResponse.status, 200);
    const health = await healthResponse.json();
    assert.equal(health.ok, true);
    assert.equal(health.rooms, 0);
    assert.equal(health.connections, 0);
    assert.equal(health.levels.tr, 3);

    const alice = await new TestClient(server.url).open();
    clients.push(alice);
    const welcome = await alice.next();
    assert.equal(welcome.type, "welcome");
    assert.equal(typeof welcome.player_id, "string");
    const pong = await alice.next();
    assert.equal(pong.type, "pong");
    assert.equal(typeof pong.server_time, "number");

    alice.send({ type: "create", language: "tr", name: "Ada" });
    const waiting = await alice.nextOfType("room");
    assert.equal(waiting.status, "waiting");
    assert.equal(waiting.code.length, 6);

    const bob = await new TestClient(server.url).open();
    clients.push(bob);
    await bob.nextOfType("welcome");
    await bob.nextOfType("pong");
    bob.send({ type: "join", code: waiting.code.toLowerCase(), name: "Bora" });

    const aliceRoom = await alice.nextOfType("room");
    const bobRoom = await bob.nextOfType("room");
    assert.equal(aliceRoom.players.length, 2);
    assert.equal(bobRoom.players.length, 2);

    const aliceStart = await alice.nextOfType("start");
    const bobStart = await bob.nextOfType("start");
    assert.deepEqual(aliceStart.levels, ["t1", "t2", "t3"]);
    assert.deepEqual(bobStart.levels, ["t1", "t2", "t3"]);
    assert.equal(aliceStart.ends_at - aliceStart.starts_at, 90_000);

    alice.send({
      type: "answer",
      answer: "cevap",
      level_index: 0,
      word_index: 1,
    });
    const result = await alice.nextOfType("answer_result");
    assert.equal(result.correct, true);
    assert.equal(result.score, 100);
    assert.equal(result.level_index, 0);
    assert.equal(result.word_index, 2);

    const score = await bob.nextOfType("score");
    assert.equal(score.players.find((player) => player.id === welcome.player_id).score, 100);

    const healthDuring = await (await fetch(server.healthUrl)).json();
    assert.equal(healthDuring.rooms, 1);
    assert.equal(healthDuring.connections, 2);

    await bob.close();
    const finish = await alice.nextOfType("finish");
    assert.equal(finish.reason, "opponent_disconnected");
  } finally {
    for (const client of clients) {
      try {
        await client.close();
      } catch {
        // ignore cleanup errors
      }
    }
    if (server) await server.close();
    await rm(dir, { recursive: true, force: true });
  }
});
