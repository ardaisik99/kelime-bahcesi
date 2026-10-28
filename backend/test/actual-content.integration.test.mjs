/**
 * Real WebSocket integration against the actual repository content.
 *
 * These tests do not use fixture levels. They read the live
 * data/levels_tr.json + data/levels_en.json files, let the local gateway load
 * its default source (split fallback when data/levels.json is absent), and play
 * one word on both the canonical /ws path and the bare root alias.
 *
 * IDs and words are looked up from the same live files, so content corrections
 * do not require editing these tests as long as 3+ two-word levels remain.
 */

import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { WebSocket } from "ws";

import { createLevelIndex } from "../data-adapter.mjs";
import { startLocalServer } from "../local-server.mjs";

const TR_FILE = new URL("../../data/levels_tr.json", import.meta.url);
const EN_FILE = new URL("../../data/levels_en.json", import.meta.url);

async function loadActualContent() {
  const [trText, enText] = await Promise.all([
    readFile(TR_FILE, "utf8"),
    readFile(EN_FILE, "utf8"),
  ]);
  return {
    tr: JSON.parse(trText),
    en: JSON.parse(enText),
  };
}

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

test("actual repo content works over both /ws and the bare root alias", async (t) => {
  const actual = await loadActualContent();
  const content = createLevelIndex(actual);
  assert.ok(content.counts.tr >= 3, "actual Turkish content needs at least 3 levels");
  assert.ok(content.counts.en >= 3, "actual English content needs at least 3 levels");
  t.diagnostic(`actual content counts: tr=${content.counts.tr}, en=${content.counts.en}`);

  let server;
  try {
    server = await startLocalServer({
      host: "127.0.0.1",
      port: 0,
      limits: { countdownMs: 0 },
    });

    const healthResponse = await fetch(server.healthUrl);
    assert.equal(healthResponse.status, 200);
    const health = await healthResponse.json();
    assert.equal(health.ok, true);
    assert.deepEqual(health.levels, content.counts);
    assert.ok(health.levels.tr > 0 && health.levels.en > 0);

    // The root alias is WebSocket-only; a plain GET / is not a page or health.
    const rootHttp = await fetch(`http://${server.host}:${server.port}/`);
    assert.equal(rootHttp.status, 404);

    for (const pathname of ["/ws", "/"]) {
      await t.test(`path ${pathname}`, async () => {
        const base = `ws://${server.host}:${server.port}${pathname}`;
        const clients = [];
        try {
          const alice = await new TestClient(base).open();
          clients.push(alice);
          const welcome = await alice.nextOfType("welcome");
          assert.equal(typeof welcome.player_id, "string");
          const pong = await alice.nextOfType("pong");
          assert.equal(typeof pong.server_time, "number");

          alice.send({ type: "create", language: "tr", name: "Ada" });
          const waiting = await alice.nextOfType("room");
          assert.equal(waiting.status, "waiting");
          assert.equal(waiting.code.length, 6);

          const bob = await new TestClient(base).open();
          clients.push(bob);
          await bob.nextOfType("welcome");
          await bob.nextOfType("pong");
          bob.send({ type: "join", code: waiting.code, name: "Bora" });

          const aliceRoom = await alice.nextOfType("room");
          const bobRoom = await bob.nextOfType("room");
          assert.equal(aliceRoom.players.length, 2);
          assert.equal(bobRoom.players.length, 2);

          const start = await alice.nextOfType("start");
          await bob.nextOfType("start");
          assert.equal(start.levels.length, 3);
          assert.equal(start.ends_at - start.starts_at, 90_000);

          const levelId = start.levels[0];
          const level = content.getLevel("tr", levelId);
          assert.ok(level, `selected level ${String(levelId)} must exist in live Turkish content`);
          assert.ok(level.words.length >= 2);

          alice.send({
            type: "answer",
            answer: level.words[1],
            level_index: 0,
            word_index: 1,
          });
          const result = await alice.nextOfType("answer_result");
          assert.equal(result.correct, true);
          assert.equal(result.score, 100);
          assert.equal(result.level_index, level.words.length > 2 ? 0 : 1);
          assert.equal(result.word_index, level.words.length > 2 ? 2 : 1);

          const score = await bob.nextOfType("score");
          assert.equal(
            score.players.find((player) => player.id === welcome.player_id).score,
            100,
          );

          await bob.close();
          const finish = await alice.nextOfType("finish");
          assert.equal(finish.reason, "opponent_disconnected");
        } finally {
          for (const client of clients) {
            try {
              await client.close();
            } catch {
              // Ignore cleanup errors.
            }
          }
        }
      });
    }
  } finally {
    if (server) await server.close();
  }
});
