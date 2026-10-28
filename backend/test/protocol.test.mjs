import assert from "node:assert/strict";
import test from "node:test";

import {
  LIMITS,
  createRateLimiter,
  generateRoomCode,
  isRoomCode,
  normalizeAnswer,
  parseClientMessage,
  sanitizeName,
} from "../protocol.mjs";

test("Turkish normalization is strict about dotted/dotless I", () => {
  assert.equal(normalizeAnswer(" İZMİR ", "tr"), "izmir");
  assert.equal(normalizeAnswer("IZMIR", "tr"), "ızmır");
  assert.equal(normalizeAnswer("IŞIK", "tr"), "ışık");
  assert.notEqual(normalizeAnswer("IZMIR", "tr"), normalizeAnswer("İZMİR", "tr"));
  assert.equal(normalizeAnswer("  iki   kelime  ", "tr"), "iki kelime");
});

test("English normalization uses ordinary uppercase", () => {
  assert.equal(normalizeAnswer("  new   york ", "en"), "NEW YORK");
  assert.equal(normalizeAnswer("İstanbul", "en"), "İSTANBUL");
});

test("names are bounded and control characters are removed", () => {
  assert.equal(sanitizeName("  Ada \u0007 Lovelace  "), "Ada Lovelace");
  assert.equal(sanitizeName("   "), null);
  assert.equal(sanitizeName("x".repeat(LIMITS.maxNameLength)), "x".repeat(LIMITS.maxNameLength));
  assert.equal(sanitizeName("x".repeat(LIMITS.maxNameLength + 1)), null);
  assert.equal(sanitizeName(42), null);
});

test("client JSON parsing enforces size and shape", () => {
  assert.equal(parseClientMessage(JSON.stringify({ type: "ping" })).ok, true);
  assert.equal(parseClientMessage("not json").error.code, "invalid_json");
  assert.equal(parseClientMessage("[]").error.code, "invalid_message");
  assert.equal(parseClientMessage('{"type":""}').error.code, "invalid_message");
  assert.equal(parseClientMessage("x".repeat(LIMITS.maxMessageBytes + 1)).error.code, "message_too_large");
  assert.equal(parseClientMessage(Buffer.from("{}")).error.code, "binary_not_supported");
});

test("room codes are cryptographically generated and unambiguous", () => {
  const codes = new Set();
  for (let i = 0; i < 500; i += 1) {
    const code = generateRoomCode();
    assert.equal(code.length, 6);
    assert.equal(isRoomCode(code), true);
    assert.equal(/[IO01]/.test(code), false);
    codes.add(code);
  }
  assert.equal(codes.size, 500);
  assert.equal(isRoomCode("ABC12"), false);
  assert.equal(isRoomCode("abc234"), false);
});

test("token bucket limits bursts and refills over time", () => {
  let now = 0;
  const limiter = createRateLimiter({ capacity: 2, refillPerSecond: 1, now: () => now });
  assert.equal(limiter.consume(), true);
  assert.equal(limiter.consume(), true);
  assert.equal(limiter.consume(), false);
  now += 1000;
  assert.equal(limiter.consume(), true);
  assert.equal(limiter.consume(), false);
  now += 500;
  assert.equal(limiter.consume(), false);
});
