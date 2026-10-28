import assert from "node:assert/strict";
import test from "node:test";

import { createLevelIndex } from "../data-adapter.mjs";

test("preferred language-array shape is preserved", () => {
  const index = createLevelIndex({
    tr: [
      { id: "tr-1", words: ["açık", "cevap", "son"] },
      { id: 2, words: ["bir", "iki"] },
    ],
    en: [{ id: "en-1", words: ["open", "answer"] }],
  });

  assert.equal(index.counts.tr, 2);
  assert.equal(index.counts.en, 1);
  assert.deepEqual(index.ids("tr"), ["tr-1", 2]);
  assert.deepEqual(index.getLevel("tr", 2).words, ["bir", "iki"]);
  assert.equal(index.getLevel("tr", "missing"), null);
});

test("levels array with language fields is accepted", () => {
  const index = createLevelIndex({
    levels: [
      { id: "t1", language: "tr", words: ["a", "b"] },
      { id: "e1", lang: "en", words: ["a", "b"] },
      { id: "skip", language: "de", words: ["a", "b"] },
    ],
  });

  assert.deepEqual(index.ids("tr"), ["t1"]);
  assert.deepEqual(index.ids("en"), ["e1"]);
  assert.ok(index.warnings.some((warning) => warning.includes("without a tr/en language")));
});

test("nested language levels and id-keyed maps are accepted", () => {
  const index = createLevelIndex({
    tr: {
      levels: [
        { id: "t1", words: ["a", "b"] },
        { words: ["c", "d"] },
      ],
    },
    en: {
      "e1": { words: ["a", "b"] },
      "e2": { words: ["c", "d"] },
    },
  });

  assert.deepEqual(index.ids("tr"), ["t1", "tr-2"]);
  assert.deepEqual(index.ids("en"), ["e1", "e2"]);
});

test("bilingual levels produce one level per language", () => {
  const index = createLevelIndex({
    levels: [
      { id: "b1", tr: ["açık", "cevap"], en: ["open", "answer"] },
      {
        id: "b2",
        tr: { prompt: "Türkiye'nin başkenti", answer: "Ankara" },
        en: { prompt: "Capital of France", answer: "Paris" },
      },
    ],
  });

  assert.deepEqual(index.getLevel("tr", "b1").words, ["açık", "cevap"]);
  assert.deepEqual(index.getLevel("en", "b1").words, ["open", "answer"]);
  assert.deepEqual(index.getLevel("tr", "b2").words, [
    "Türkiye'nin başkenti",
    "Ankara",
  ]);
  assert.deepEqual(index.getLevel("en", "b2").words, ["Capital of France", "Paris"]);
});

test("prompt/answer and prompt/answers variants are accepted", () => {
  const index = createLevelIndex({
    tr: [
      { id: "p1", prompt: "Türkiye'nin başkenti", answer: "Ankara" },
      { id: "p2", prompt: "bir", answers: ["iki", "üç"] },
    ],
  });

  assert.deepEqual(index.getLevel("tr", "p1").words, [
    "Türkiye'nin başkenti",
    "Ankara",
  ]);
  assert.deepEqual(index.getLevel("tr", "p2").words, ["bir", "iki", "üç"]);
});

test("a language field plus a localized word array is accepted", () => {
  const index = createLevelIndex({
    levels: [
      { id: "t1", language: "tr", tr: ["açık", "cevap"] },
      { id: "e1", lang: "en", en: ["open", "answer"] },
    ],
  });

  assert.deepEqual(index.getLevel("tr", "t1").words, ["açık", "cevap"]);
  assert.deepEqual(index.getLevel("en", "e1").words, ["open", "answer"]);
});

test("a top-level language field is inherited by its levels array", () => {
  const tr = {
    language: "tr",
    categories: [{ id: "kitchen" }],
    levels: [
      { id: "t1", title: "Çay", words: ["ÇAY", "KAŞIK"], hints: ["a", "b"] },
      { id: "t2", title: "Su", words: ["SU", "BARDAK"], hints: ["a", "b"] },
    ],
  };
  const index = createLevelIndex(tr);

  assert.deepEqual(index.ids("tr"), ["t1", "t2"]);
  assert.deepEqual(index.getLevel("tr", "t1").words, ["ÇAY", "KAŞIK"]);
  assert.deepEqual(index.ids("en"), []);
});

test("levels in a combined array can infer language from tr_/en_ ids", () => {
  const index = createLevelIndex({
    levels: [
      { id: "tr_kitchen_tea", words: ["ÇAY", "KAŞIK"] },
      { id: "en_kitchen_ice", words: ["ICE", "CREAM"] },
    ],
  });

  assert.deepEqual(index.ids("tr"), ["tr_kitchen_tea"]);
  assert.deepEqual(index.ids("en"), ["en_kitchen_ice"]);
});

test("pairs are expanded into one level per pair", () => {
  const index = createLevelIndex({
    tr: [
      {
        id: "chain",
        pairs: [
          { prompt: "a", answer: "b" },
          { prompt: "b", answer: "c" },
        ],
      },
    ],
  });

  assert.deepEqual(index.ids("tr"), ["chain-1", "chain-2"]);
  assert.deepEqual(index.getLevel("tr", "chain-1").words, ["a", "b"]);
  assert.deepEqual(index.getLevel("tr", "chain-2").words, ["b", "c"]);
});

test("items containing word objects work and invalid levels are skipped", () => {
  const index = createLevelIndex({
    tr: [
      { id: "words", items: [{ word: "a" }, { word: "b" }, { word: "c" }] },
      { id: "one", words: ["only"] },
      { id: "empty", words: ["a", ""] },
      { id: "words", words: ["duplicate", "id"] },
    ],
  });

  assert.deepEqual(index.ids("tr"), ["words"]);
  assert.deepEqual(index.getLevel("tr", "words").words, ["a", "b", "c"]);
  assert.ok(index.warnings.some((warning) => warning.includes("needs at least two words")));
  assert.ok(index.warnings.some((warning) => warning.includes("empty word")));
  assert.ok(index.warnings.some((warning) => warning.includes("duplicate")));
});

test("arrow-separated chains are accepted", () => {
  const index = createLevelIndex({
    tr: [{ id: "c", chain: "açık → cevap → son" }],
  });
  assert.deepEqual(index.getLevel("tr", "c").words, ["açık", "cevap", "son"]);
});
