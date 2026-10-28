# Tamlama multiplayer backend

Authoritative WebSocket backend for the bilingual (Turkish/English) chain game.
It runs locally on Node or on Cloudflare Workers with one SQLite-backed Durable
Object room hub.

The same room engine is used in both places:

| File | Purpose |
| --- | --- |
| `room-engine.mjs` | Shared authoritative rooms, scoring, timers tick, validation |
| `protocol.mjs` | Wire limits, normalization, parsing, room codes, rate limiter |
| `data-adapter.mjs` | Tolerant loader for the split `data/levels_*.json` content |
| `local-server.mjs` | Local Node HTTP + `ws` gateway, `/health`, `/ws` and `/` |
| `worker.mjs` | Cloudflare Worker gateway + `RoomHub` Durable Object |
| `wrangler.jsonc` | Worker config, SQLite DO binding/migration |
| `test/` | `node:test` engine, adapter, protocol and real gateway tests |

## Run locally

Requirements: Node.js 20+ (tested with Node 24), `npm install` network access on
first setup.

```sh
cd backend
npm install
npm start
```

Defaults:

- WebSocket: `ws://127.0.0.1:8787` (bare root alias; `/ws` is canonical)
- Health: `http://127.0.0.1:8787/health`
- Content: `../data/levels_tr.json` + `../data/levels_en.json` (merged by default;
  a combined `../data/levels.json` is used if it already exists)

Environment overrides:

```sh
PORT=9000 HOST=0.0.0.0 LEVELS_FILE=C:\path\to\levels.json npm start
```

`HOST` defaults to `127.0.0.1`. Use `0.0.0.0` only when LAN access is intended.
`LEVELS_FILE` is resolved relative to the current working directory. By default
the local gateway tries `../data/levels.json`; when it is absent (the normal
repository state) it merges `../data/levels_tr.json` + `../data/levels_en.json`.
An explicit missing `LEVELS_FILE` fails with an explicit error and is never
silently replaced by the split pair.

The health response is JSON, for example:

```json
{
  "ok": true,
  "service": "tamlama-room-hub-local",
  "rooms": 0,
  "connections": 0,
  "levels": { "tr": 10, "en": 10 },
  "server_time": 1760000000000
}
```

## Client protocol

The fixed client connects **once** to the root URL and keeps that socket for the
whole session. There is no per-room URL:

- `ws://127.0.0.1:8787` (compatible default used by `core/network_client.gd`)
- `wss://<worker>.workers.dev` (bare root alias)

The canonical path `/ws` is still supported on both gateways:

- `ws://127.0.0.1:8787/ws`
- `wss://<worker>.workers.dev/ws`

Both paths terminate at the same room hub. Query strings such as
`?code=ABC123` are deliberately ignored; clients must send `create`/`join`
messages on the same connection. This keeps the local and Worker gateways
identical.

All messages are UTF-8 JSON objects. Server-sent events are authoritative.

### On connect

The server immediately sends:

```json
{ "type": "welcome", "player_id": "uuid" }
{ "type": "pong", "server_time": 1760000000000 }
```

Use the initial `pong.server_time` to estimate clock offset before interpreting
`starts_at` / `ends_at` (both are Unix epoch milliseconds).

### Client messages

Create a waiting room:

```json
{ "type": "create", "language": "tr", "name": "Ada" }
```

Join by code (case-insensitive):

```json
{ "type": "join", "code": "ABC234", "name": "Bora" }
```

Submit an answer:

```json
{
  "type": "answer",
  "answer": "cevap",
  "level_index": 0,
  "word_index": 1
}
```

Emote (one of `hello`, `nice`, `wow`, `gg`):

```json
{ "type": "emote", "id": "hello" }
```

Ping / leave:

```json
{ "type": "ping" }
{ "type": "leave" }
```

`leave` removes the player from the room but leaves the WebSocket open, so the
same connection can `create` or `join` again. After a match finishes the room is
deleted automatically and the player can immediately create/join again.

### Server messages

Waiting room snapshot:

```json
{
  "type": "room",
  "code": "ABC234",
  "language": "tr",
  "players": [{ "id": "p1", "name": "Ada", "score": 0, "connected": true }],
  "status": "waiting"
}
```

When the second player joins, both receive a `room` snapshot and then a `start`:

```json
{
  "type": "start",
  "starts_at": 1760000003000,
  "ends_at": 1760000093000,
  "levels": ["tr-3", "tr-7", "tr-1"],
  "players": [
    { "id": "p1", "name": "Ada", "score": 0, "connected": true },
    { "id": "p2", "name": "Bora", "score": 0, "connected": true }
  ]
}
```

`starts_at` is 3 seconds after the join and `ends_at` is exactly 90 seconds after
`starts_at`. No answers are accepted before `starts_at` or at/after `ends_at`.

Answer response:

```json
{
  "type": "answer_result",
  "correct": true,
  "level_index": 0,
  "word_index": 2,
  "score": 100,
  "finished": false
}
```

- `level_index` / `word_index` are the **next expected coordinates after a
  correct answer**.
- After a wrong answer, stale coordinate, or out-of-order coordinate, they are
  the **current expected coordinates** and no score is added.
- After the final answer both indices are `-1` and `finished` is `true`. This is
  the client's done flag.
- Answers are accepted only at the server's exact expected coordinates, so
  gameplay is monotonic and cannot skip words.
- Scores are never read from the client. Every accepted word is worth 100
  points.

Score snapshot (sent after each accepted word):

```json
{
  "type": "score",
  "players": [
    { "id": "p1", "name": "Ada", "score": 200, "connected": true },
    { "id": "p2", "name": "Bora", "score": 100, "connected": true }
  ]
}
```

Emote broadcast (including the sender):

```json
{ "type": "emote", "player_id": "p1", "id": "hello" }
```

Match finish:

```json
{
  "type": "finish",
  "players": [
    { "id": "p1", "name": "Ada", "score": 500, "connected": true },
    { "id": "p2", "name": "Bora", "score": 300, "connected": false }
  ],
  "reason": "opponent_disconnected"
}
```

Finish reasons:

| Reason | Meaning |
| --- | --- |
| `completed` | Both players finished all words |
| `timeout` | 90-second play window ended |
| `waiting_timeout` | Waiting room expired after 15 minutes |
| `opponent_disconnected` | The other socket closed |
| `opponent_left` | The other player sent `leave` |

Pong / errors:

```json
{ "type": "pong", "server_time": 1760000000000 }
{ "type": "error", "code": "not_started", "message": "The countdown has not finished yet." }
```

Selected error codes include `invalid_name`, `invalid_language`,
`already_in_room`, `room_not_found`, `room_unavailable`, `room_full`, `no_room`,
`not_started`, `game_over`, `already_finished`, `invalid_answer`,
`invalid_coordinates`, `invalid_emote`, `rate_limited`, `server_busy`,
`content_unavailable`, `message_too_large`, `invalid_json`, `unknown_type`.

### First word is open

A level's word array is an ordered sequence. Index `0` is the open/given word
and is never submitted. Expected progress starts at `(0, 1)` and advances to
`(0, 2)`, ... then `(1, 1)`, ... for the three selected levels. The client already
has the level data and level IDs; the server stores the validating answers.

Any level with fewer than two words is ignored by the adapter. A room language
needs at least three usable levels or `create` returns `content_unavailable`.

### Limits and disconnect behavior

Defaults in `protocol.mjs`:

- Raw JSON message: 4096 bytes
- Name: 1-24 printable characters after whitespace/control cleanup
- Answer: 120 characters
- Per-connection token bucket: 30 messages burst, 10/second refill
- Emote cooldown: 1.5 seconds per player
- Idle WebSocket: closed after 90 seconds without any client message
- 2 players per room, 3 levels per match
- 200 rooms per hub, 500 WebSocket connections per hub
- 15 minute waiting room, 3 second countdown, 90 second match

The official client pings every 15 seconds, so normal waiting rooms and matches
stay open. The idle timer exists so sockets that never join, ping, or send
anything cannot occupy connection slots forever. A closed idle socket is treated
like any other disconnect (waiting rooms are deleted, active opponents get
`finish`).

If a player disconnects during a match, the opponent receives
`finish` with `opponent_disconnected`. A waiting room is simply deleted. There is
**no reconnect recovery**: a reconnecting client is a new player, and the old
match is cancelled. This is acceptable for the casual prototype.

No hints or coins exist in multiplayer. Do not send them; the server will not
score or accept them.

## Content / data adapter

Preferred shape (also the most predictable for the client):

```json
{
  "tr": [
    { "id": "tr-1", "words": ["açık", "cevap", "son"] },
    { "id": "tr-2", "words": ["başka", "cevap"] }
  ],
  "en": [
    { "id": "en-1", "words": ["open", "answer", "end"] },
    { "id": "en-2", "words": ["other", "answer"] }
  ]
}
```

Rules:

- `id` is preserved (`string` or number) and is what `start.levels` contains.
  The client must be able to look up the same IDs in its copy of the content.
  If an ID is missing, the adapter generates `<lang>-<n>`; keep explicit IDs in
  the real data so both sides agree.
- `words` must have at least two non-empty entries. Index 0 is open.
- At least three usable levels per language are required to create a room.
- Both client and server must use the same content/IDs. The server does not send
  full level text over the wire.

`data-adapter.mjs` is intentionally tolerant while the content shape settles. It
also accepts:

- `{ "levels": [{ "id": "...", "language": "tr", "words": [...] }] }`
- `{ "tr": { "levels": [...] }, "en": { ... } }`
- bilingual levels such as `{ "id": "1", "tr": ["a", "b"], "en": ["a", "b"] }`
- `prompt`/`question`/`sentence` + `answer`, or `prompt` + `answers`
- `pairs` (expanded to one level per pair)
- `items` / `tokens` containing strings or objects with `word`/`answer`/`text`
- arrow chains such as `"açık → cevap → son"`
- id-keyed maps and common language aliases (`lang`, `locale`, `tr-TR`, `en-US`)
- combined level arrays without a language field when IDs start `tr_`/`en_`

The normalized internal shape is `{ tr: [{ id, language, words }], en: [...] }`.
Adapter warnings (missing language, duplicate IDs, too few words) are logged by
the local server. The Worker has no startup logging for these; validate content
with `npm test`/local start before deploying.

Local default source: `../data/levels_tr.json` + `../data/levels_en.json`,
merged by the local gateway. If a combined file is present at
`../data/levels.json`, it is read instead; an explicit `LEVELS_FILE` always wins.

Worker bundle source: `worker.mjs` statically imports
`../data/levels_tr.json` and `../data/levels_en.json` and passes
`{ tr, en }` to the shared adapter/engine. No combined `data/levels.json` is
needed to build or deploy. Content is bundled at deploy time, so redeploy after
changing either language file.

The live files use a top-level `language` plus a `levels` array, which the
adapter accepts directly. Each file is ingested under its own language bucket,
so IDs stay as authored (`tr_...` / `en_...`) and are shared with the client.

## Test

```sh
cd backend
npm test
```

`node --test` runs 39 tests covering room create/join, countdown rejection,
server-authoritative scores/forged scores, wrong/stale/out-of-order answers,
Turkish `İ/i` and `I/ı` normalization, English case folding, both-players
completion, timeout, exact `ends_at` rejection, waiting-room and active-room
disconnect cleanup, explicit leave, room code uniqueness/capacity, names,
emotes/rate limiting, pings, join errors, adapter variants, protocol bounds,
real local WebSocket integration over both `/ws` and `/`, and a live-content
gateway test that reads the actual `data/levels_tr.json` + `data/levels_en.json`
(18 levels each at the time of writing) instead of fixtures.

## Cloudflare deployment

The Worker exposes:

- `GET /health` → JSON hub status (proxied to the Durable Object)
- `GET /ws` with `Upgrade: websocket` → canonical WebSocket gateway
- `GET /` with `Upgrade: websocket` → bare-root compatibility alias
- Plain `GET /` is a 404 and is never treated as health or a page

Deploy from `backend/`:

```sh
cd backend
npm install
npx wrangler login
npm run deploy
```

`wrangler login` is an interactive local OAuth flow. No secrets, API tokens, or
account IDs are committed in this repository.

After deploy, Wrangler prints the `workers.dev` URL. Use:

- `https://<worker>.workers.dev/health`
- `wss://<worker>.workers.dev` (bare root, matches the client default shape)
- `wss://<worker>.workers.dev/ws` (canonical path)

You can verify the bundle without an account or login:

```sh
npx wrangler deploy --dry-run --outdir dist
```

### Plan and quota caveat — read before deploying

This project **does not assume or enable a paid plan**. Cloudflare Workers,
Durable Objects, SQLite-backed Durable Objects, WebSocket duration, request/CPU
allowances, and free-plan availability can change and differ by account. Check
the current Cloudflare dashboard/pricing for your account.

If SQLite-backed Durable Objects are not included in your plan, `wrangler
deploy` may fail or the Worker may not run; there is no paid service
automatically added by this repository. Do not deploy assuming unlimited free
usage.

`wrangler.jsonc` defines:

- binding `ROOM_HUB` → class `RoomHub`
- migration `v1` with `new_sqlite_classes: ["RoomHub"]`
- `compatibility_date: "2026-09-01"`
- `observability.enabled: false` to avoid optional Workers Logs retention; the
  app itself does not log message payloads or IP addresses

Changing the Durable Object class name requires a new migration. The engine
does not persist room state to SQLite; the SQLite migration is present because
the class is configured as a SQLite-backed Durable Object.

### Scaling and durability limitations

- **One global hub.** `env.ROOM_HUB.idFromName("global")` sends every connection
  to one Durable Object. This is simple and acceptable for a small casual
  prototype, but it is not horizontally scalable: one isolate/hub holds all
  rooms and up to 500 connections, and all players share its limits.
- **No persistence.** Rooms, scores, progress, and sockets are in memory. A
  Durable Object restart/eviction cancels matches. No reconnect or state
  recovery is promised.
- **Non-hibernating sockets.** `server.accept()` is used, not
  `state.acceptWebSocket()`. Match deadlines are checked by short `setTimeout`
  chunks (capped at 30 seconds). This keeps the prototype simple but makes no
  uptime, latency, or cost guarantee. Use Durable Object alarms/hibernation for
  a production design.
- **Idle sockets are bounded.** Each session has a 90-second inactivity timer
  refreshed by any client message. The official client pings every 15 seconds;
  dead or unjoined sockets are closed instead of holding a connection slot
  forever. The 15-minute waiting-room deadline and 90-second match deadline are
  separate engine rules.
- **Timers are not durable.** If the DO sleeps, clients should treat the match
  as cancelled. Reconnect creates a new player.
- **Health is not a readiness guarantee.** It reports the current hub instance's
  room/connection counts.

If the game grows, shard rooms across Durable Objects by a room key and add
durable match storage/reconnect tokens. That is intentionally out of scope here.

## Security notes

This is a casual prototype, not an authenticated competitive service:

- No accounts, tokens, TLS termination, or per-IP limits are implemented. The
  Worker provides TLS at Cloudflare; local `ws://` is plaintext. Cloudflare's
  edge still processes connection metadata (including IPs) as part of normal
  request handling even with `observability.enabled: false`; this app does not
  persist or log message payloads itself.
- Rate limits are per WebSocket connection. A reconnecting client gets a new
  bucket.
- Names are bounded and control characters are stripped, but not profanity
  filtered.
- The server validates answers and scores; clients cannot submit scores.
