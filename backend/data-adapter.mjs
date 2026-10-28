/**
 * Tolerant adapter for the project's game content.
 *
 * The preferred shape is:
 *   { "tr": [{ "id": "tr-1", "words": ["open word", "answer", ...] }], "en": [...] }
 *
 * It also accepts `{ levels: [...] }`, per-level `language`/`lang` fields,
 * `{ tr: { levels: [...] }, en: { levels: [...] } }`, bilingual levels with
 * `tr`/`en` word arrays, and common `prompt` + `answer` / `pairs` variants.
 *
 * A level's first word is the "open" word (index 0). The engine only asks for
 * words at index 1..n, so every normalized level needs at least two words.
 */

import { isPlainObject, normalizeLanguage } from "./protocol.mjs";

const LANGUAGE_LIST = Object.freeze(["tr", "en"]);

const WORD_LIST_KEYS = Object.freeze([
  "words",
  "wordList",
  "word_list",
  "chain",
  "wordChain",
  "word_chain",
  "sequence",
  "steps",
  "tokens",
  "items",
  "answers",
]);

const PROMPT_KEYS = Object.freeze([
  "prompt",
  "question",
  "sentence",
  "clue",
  "start",
  "base",
  "word",
  "text",
]);

const ANSWER_KEYS = Object.freeze([
  "answer",
  "solution",
  "target",
]);

const ID_KEYS = Object.freeze([
  "id",
  "level_id",
  "levelId",
  "slug",
  "key",
  "code",
]);

function nfcWhitespace(value) {
  return value.normalize("NFC").replace(/\s+/g, " ").trim();
}

function firstDefined(...values) {
  for (const value of values) {
    if (value !== undefined && value !== null) return value;
  }
  return undefined;
}

function firstNonEmptyString(...values) {
  for (const value of values) {
    if (typeof value === "string") {
      const cleaned = nfcWhitespace(value);
      if (cleaned) return cleaned;
    }
  }
  return null;
}

function tokenFrom(value, language) {
  if (typeof value === "string") {
    const cleaned = nfcWhitespace(value);
    return cleaned || null;
  }
  if (!isPlainObject(value)) return null;

  // Prefer the requested language before generic answer-like fields, so a
  // bilingual token never resolves to the other language.
  for (const key of [language, ...ANSWER_KEYS, ...PROMPT_KEYS]) {
    if (typeof value[key] === "string") {
      const cleaned = nfcWhitespace(value[key]);
      if (cleaned) return cleaned;
    }
  }

  for (const key of LANGUAGE_LIST) {
    if (key !== language && typeof value[key] === "string") {
      const cleaned = nfcWhitespace(value[key]);
      if (cleaned) return cleaned;
    }
  }

  return null;
}

function hasPromptAndAnswer(value) {
  if (!isPlainObject(value)) return false;
  const prompt = firstNonEmptyString(
    value.prompt,
    value.question,
    value.sentence,
    value.clue,
    value.start,
    value.base,
    value.left,
  );
  const answer = firstNonEmptyString(
    value.answer,
    value.solution,
    value.target,
    value.end,
    value.right,
  );
  return Boolean(prompt && answer);
}

function isPairLike(value) {
  if (Array.isArray(value)) {
    return value.length === 2 && value.every((part) => typeof part === "string");
  }
  return hasPromptAndAnswer(value);
}

function pairWords(value, language) {
  if (Array.isArray(value)) {
    return value.map((part) => tokenFrom(part, language));
  }
  if (!isPlainObject(value)) return null;

  const prompt = firstNonEmptyString(
    value.prompt,
    value.question,
    value.sentence,
    value.clue,
    value.start,
    value.base,
    value.left,
    value.a,
  );
  const answer = firstNonEmptyString(
    value.answer,
    value.solution,
    value.target,
    value.end,
    value.right,
    value.b,
  );

  if (prompt && answer) {
    return [tokenFrom(prompt, language), tokenFrom(answer, language)];
  }
  return null;
}

function wordsFromValue(value, language) {
  if (typeof value === "string") {
    if (value.includes("→") || value.includes("->")) {
      return value
        .split(/\s*(?:→|->)\s*/)
        .map((part) => nfcWhitespace(part))
        .filter(Boolean);
    }
    const cleaned = nfcWhitespace(value);
    return cleaned ? [cleaned] : null;
  }

  if (Array.isArray(value)) {
    if (value.length === 0) return null;

    // A list of prompt/answer pairs is treated as a chain: the first prompt is
    // open, followed by every answer.
    if (value.every(isPairLike)) {
      const firstPair = pairWords(value[0], language);
      if (!firstPair) return null;
      const words = [firstPair[0]];
      for (const pair of value) {
        const pairValue = pairWords(pair, language);
        if (!pairValue) return null;
        words.push(pairValue[1]);
      }
      return words.some((word) => !word) ? null : words;
    }

    const words = value.map((item) => tokenFrom(item, language));
    return words;
  }

  if (isPlainObject(value)) {
    const localized = firstDefined(value[language], value[language.toUpperCase()]);
    if (localized !== undefined) return wordsFromValue(localized, language);

    if (isPairLike(value)) return pairWords(value, language);
  }

  return null;
}

function languageValueWords(raw, language) {
  const direct = raw[language];
  if (direct === undefined) return null;

  if (typeof direct === "string" || Array.isArray(direct)) {
    return wordsFromValue(direct, language);
  }

  if (isPlainObject(direct)) {
    const nested = extractWords(direct, language);
    if (nested) return nested;
  }

  return null;
}

function extractWords(raw, language) {
  if (!isPlainObject(raw)) return null;

  // A language bucket can itself be the word sequence, e.g.
  // { id: "1", tr: ["open", "answer"], en: ["open", "answer"] }.
  const fromLanguage = languageValueWords(raw, language);
  if (fromLanguage) return fromLanguage;

  const baseWord = firstNonEmptyString(
    raw.prompt,
    raw.question,
    raw.sentence,
    raw.clue,
    raw.start,
    raw.base,
    raw.word,
    raw.text,
  );

  for (const key of WORD_LIST_KEYS) {
    if (raw[key] === undefined) continue;

    if (key === "answers" && baseWord) {
      const answerWords = wordsFromValue(raw[key], language);
      if (!answerWords) return null;
      return [baseWord, ...answerWords];
    }

    const words = wordsFromValue(raw[key], language);
    if (words) return words;
  }

  const answer = firstNonEmptyString(
    raw.answer,
    raw.solution,
    raw.target,
    raw.end,
    raw.right,
  );
  const pairBase = firstNonEmptyString(raw.left, raw.a) ?? baseWord;
  if (pairBase && answer) {
    return [pairBase, answer];
  }

  return null;
}

function levelId(raw, fallbackId, language, existingCount) {
  const candidate = firstDefined(...ID_KEYS.map((key) => raw[key]), fallbackId);

  if (typeof candidate === "number" && Number.isFinite(candidate)) {
    return candidate;
  }
  if (typeof candidate === "string") {
    const cleaned = candidate.trim();
    if (cleaned && cleaned.length <= 64) return cleaned;
  }
  return `${language}-${existingCount + 1}`;
}

function isWordSequence(value) {
  if (typeof value === "string") return true;
  if (!Array.isArray(value) || value.length === 0) return false;
  return value.every((entry) => {
    if (typeof entry === "string") return true;
    if (!isPlainObject(entry)) return false;
    // An object carrying level metadata is a level, not a single word token.
    if (ID_KEYS.some((key) => entry[key] !== undefined)) return false;
    if (WORD_LIST_KEYS.some((key) => entry[key] !== undefined)) return false;
    if (entry.pairs !== undefined) return false;
    return !hasPromptAndAnswer(entry) && tokenFrom(entry, "tr") !== null;
  });
}

function isPuzzleSource(value) {
  if (isWordSequence(value)) return true;
  if (!isPlainObject(value)) return false;
  return (
    hasPromptAndAnswer(value) ||
    WORD_LIST_KEYS.some((key) => value[key] !== undefined) ||
    (isWordSequence(value.tr) && isWordSequence(value.en))
  );
}

function looksLikeBilingualLevel(raw) {
  return isPuzzleSource(raw.tr) && isPuzzleSource(raw.en);
}

function inferLanguageFromId(raw) {
  for (const key of ID_KEYS) {
    const value = raw[key];
    if (typeof value !== "string") continue;
    const match = /^(tr|en)(?:[_-]|$)/i.exec(value.trim());
    if (match) return match[1].toLowerCase();
  }
  return null;
}

function isLevelLike(raw) {
  if (!isPlainObject(raw)) return false;
  if (looksLikeBilingualLevel(raw)) return true;
  if (WORD_LIST_KEYS.some((key) => raw[key] !== undefined)) return true;
  if (raw.pairs !== undefined) return true;
  if (hasPromptAndAnswer(raw)) return true;
  if (raw.answer !== undefined && (raw.word !== undefined || raw.prompt !== undefined)) {
    return true;
  }
  if (
    normalizeLanguage(raw.language ?? raw.lang ?? raw.locale) &&
    (isPuzzleSource(raw.tr) || isPuzzleSource(raw.en))
  ) {
    return true;
  }
  return false;
}

export function createLevelIndex(source) {
  const byLanguage = { tr: [], en: [] };
  const seen = new Set();
  const warnings = [];

  function addNormalizedLevel(rawWords, rawId, language) {
    if (!rawWords || rawWords.length < 2) {
      warnings.push(`Skipping ${language} level "${String(rawId)}": needs at least two words.`);
      return;
    }
    if (rawWords.some((word) => !word)) {
      warnings.push(`Skipping ${language} level "${String(rawId)}": empty word.`);
      return;
    }

    const key = `${language}:${String(rawId)}`;
    if (seen.has(key)) {
      warnings.push(`Skipping duplicate ${language} level id "${String(rawId)}".`);
      return;
    }
    seen.add(key);

    byLanguage[language].push({
      id: rawId,
      language,
      words: rawWords.slice(),
    });
  }

  function addPuzzle(raw, language, fallbackId) {
    const pairs = Array.isArray(raw.pairs)
      ? raw.pairs
      : Array.isArray(raw.items) && raw.items.length > 0 && raw.items.every(isPairLike)
        ? raw.items
        : null;

    const hasChainSource = WORD_LIST_KEYS.some(
      (key) => key !== "items" && raw[key] !== undefined,
    );

    if (pairs && !hasChainSource) {
      const baseId = levelId(raw, fallbackId, language, byLanguage[language].length);
      pairs.forEach((pair, index) => {
        const words = pairWords(pair, language);
        const pairId = isPlainObject(pair) && pair.id !== undefined
          ? pair.id
          : pairs.length === 1
            ? baseId
            : `${String(baseId)}-${index + 1}`;
        addNormalizedLevel(words, pairId, language);
      });
      return;
    }

    const words = extractWords(raw, language);
    const baseId = levelId(raw, fallbackId, language, byLanguage[language].length);
    addNormalizedLevel(words, baseId, language);
  }

  function addRawLevel(raw, hint, fallbackId) {
    if (!isPlainObject(raw)) return;

    const declared = normalizeLanguage(raw.language ?? raw.lang ?? raw.locale);
    const languages = [];
    if (declared) {
      languages.push(declared);
    } else if (hint) {
      languages.push(hint);
    } else if (looksLikeBilingualLevel(raw)) {
      languages.push("tr", "en");
    } else {
      const inferred = inferLanguageFromId(raw);
      if (inferred) {
        languages.push(inferred);
      } else {
        warnings.push("Skipping a level without a tr/en language.");
        return;
      }
    }

    for (const language of languages) {
      addPuzzle(raw, language, fallbackId);
    }
  }

  function ingest(container, hint, fallbackId) {
    if (container === undefined || container === null) return;

    if (Array.isArray(container)) {
      for (const item of container) ingest(item, hint, undefined);
      return;
    }
    if (!isPlainObject(container)) return;

    if (isLevelLike(container)) {
      addRawLevel(container, hint, fallbackId);
      return;
    }

    if (container.levels !== undefined) {
      const declaredLanguage = normalizeLanguage(
        container.language ?? container.lang ?? container.locale,
      );
      ingest(container.levels, hint ?? declaredLanguage, fallbackId);
      return;
    }
    if (container.levelsByLanguage !== undefined) {
      ingest(container.levelsByLanguage, hint, fallbackId);
      return;
    }
    if (container.data !== undefined) {
      ingest(container.data, hint, fallbackId);
      return;
    }
    if (container.languages !== undefined && isPlainObject(container.languages)) {
      ingest(container.languages, hint, fallbackId);
      return;
    }

    const languageKeys = LANGUAGE_LIST.filter((key) => container[key] !== undefined);
    if (languageKeys.length > 0 && languageKeys.length === Object.keys(container).length) {
      for (const key of languageKeys) ingest(container[key], key, undefined);
      return;
    }

    // Object map keyed by level id, e.g. { "tr-1": { ...level } }.
    for (const [key, value] of Object.entries(container)) {
      if (LANGUAGE_LIST.includes(key)) {
        ingest(value, key, undefined);
      } else {
        ingest(value, hint, key);
      }
    }
  }

  ingest(source, null, undefined);

  function get(language) {
    const normalized = normalizeLanguage(language);
    return normalized ? byLanguage[normalized] : [];
  }

  function getLevel(language, id) {
    const target = String(id);
    return get(language).find((level) => String(level.id) === target) ?? null;
  }

  function ids(language) {
    return get(language).map((level) => level.id);
  }

  return {
    byLanguage,
    warnings,
    counts: {
      tr: byLanguage.tr.length,
      en: byLanguage.en.length,
    },
    get,
    getLevel,
    ids,
  };
}
