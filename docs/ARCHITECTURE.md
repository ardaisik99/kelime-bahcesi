# WordGarden — Core Architecture

Bilingual (Turkish/English) word-chain puzzle for mobile portrait (480×900).
In-game brand: **Kelime Bahçesi** (`project.godot` → `config/name`); the code and
docs use **WordGarden** for the project.

This document describes the **core layer** (`core/`, `data/`, `tests/`) and the
exact contracts the UI, scene and backend agents can rely on.

Ownership: core files are `project.godot`, `.gitignore`, `icon.svg`,
`core/**`, `data/**`, `docs/ARCHITECTURE.md`, `docs/PLAN.md`,
`tests/test_core.gd`, `tests/test_content.gd`. UI (`ui/**`, `scenes/**`),
backend (`backend/**`) and the other `docs/*` files belong to other agents.

---

## 1. Layer overview

```
scenes/main.tscn           (UI agent)
   │  user input / drawing only
   ▼
ui/**                      (UI agent)  →  GardenApi adapter
   │
   ▼
GameSession                (core, RefCounted)   one instance per level
   │
   ├── Content   (autoload)  res://data/levels_{tr,en}.json
   ├── SaveStore (autoload)  user://save.json + save.json.bak
   ├── I18n      (autoload)  tr/en UI strings, Turkish casing
   ├── AudioManager (autoload) runtime-generated SFX
   └── NetworkClient (autoload) optional online 1v1 over WebSocket
```

Rules that keep the layers honest:

* `GameSession` never touches `Node` UI, `Control`, or the scene tree. It is a
  `RefCounted` and is unit-tested without a scene.
* `Content` returns **deep copies**; mutating a returned level never changes
  the loaded data.
* `SaveStore` is the only writer of `user://save.json`; coins, completion and
  settings are persisted there, never in UI code.
* Solo play is fully offline. `NetworkClient` is optional and only used by the
  online 1v1 mode.
* Presentation state (animations, selected tab, reduced motion) belongs to the
  UI and lives in `user://garden_ui.json` via `GardenApi`.

## 2. Gameplay rules (fixed product requirements)

These rules are the user's specification; the core implements them literally.

1. A level is a chain of 4–5 words. Adjacent words form a real compound or
   expression (`ÇAY KAŞIĞI`, `KAŞIK OYUNU`, `OYUN HAVASI`).
2. **Word 0 is given.** At `start()` it is revealed and locked in full — the
   player never types it.
3. **Only the next word is active.** Its first letter is pre-revealed and
   locked; the remaining letters are empty and editable.
4. **Submission is per word.** "Submit" validates the *active* word only.
   * incomplete → `submit_blocked("incomplete")`, nothing changes;
   * wrong → `answer_rejected`, `wrong_attempts += 1`, nothing changes;
   * correct → the word is revealed and locked in full (`word_solved`), and the
     next word becomes active with its first letter pre-revealed.
5. **Future words stay hidden.** They show underscores and only metadata
   (length, state). Their first letters are not pre-revealed.
6. **Victory only after the final word is verified.** There is no blind
   full-chain fill. `chain_completed` fires exactly once, at victory;
   `is_chain_completed()` / `chain_complete` are true only then.
7. **Backspace/clear are confined to the active word.** Solved words and fixed
   letters (pre-revealed or bought) can never be erased.
8. **Hints** cost 10 coins, apply to the active word and are available once per
   word. **Reveal** costs 15 coins and reveals + locks **one random still-hidden
   non-initial letter of the active word**. Neither charges when inapplicable
   (already shown/solved/full/insufficient coins).
9. **Rewards:** 25 coins on the first clear of a level per language; replays
   award nothing. Coins are per language; each language starts at 100.
10. A reward is only announced when it was written to disk; see §6.

## 3. Autoloads and boot order

Defined in `project.godot`:

| Order | Name | Script |
|------:|------|--------|
| 1 | `SaveStore` | `res://core/save_store.gd` |
| 2 | `I18n` | `res://core/i18n.gd` |
| 3 | `Content` | `res://core/content.gd` |
| 4 | `AudioManager` | `res://core/audio_manager.gd` |
| 5 | `NetworkClient` | `res://core/network_client.gd` |

Order matters: `I18n._ready()` reads the saved language from `SaveStore`, and
`AudioManager._ready()` reads the saved sound flag and subscribes to
`SaveStore.settings_changed`. `GameSession` resolves `SaveStore`/`Content`/`I18n`
lazily through the `SceneTree` root, so it also works when autoloads are absent
(pure in-memory mode, used by tests).

## 4. Content data schema

`data/levels_tr.json` / `data/levels_en.json`:

```json
{
  "language": "tr",
  "version": 1,
  "categories": [
    { "id": "kitchen", "name_key": "category.kitchen" },
    { "id": "nature",  "name_key": "category.nature" },
    { "id": "daily",   "name_key": "category.daily" }
  ],
  "levels": [
    {
      "id": "tr_kitchen_tea_time",
      "category": "kitchen",
      "title": "Çay keyfi",
      "words": ["ÇAY", "KAŞIK", "OYUN", "HAVA"],
      "hints": ["…", "…", "…", "…"],
      "links": ["çay kaşığı", "kaşık oyunu", "oyun havası"]
    }
  ]
}
```

Validation at load time (`Content.errors()` lists violations; a level failing
validation is dropped, the rest still load):

* `id` non-empty, unique per language, `[a-z0-9_]` only;
* `category` in `kitchen`, `nature`, `daily`;
* 4–5 words, each a single alphabetic token in the language alphabet,
  uppercase after `I18n.normalize`;
* `hints.size() == words.size()`, every hint non-empty;
* `links.size() == words.size() - 1`, link *i* starts with the lowercase root
  of word *i*;
* no duplicate chain (same ordered word list) within a language.

`Content.get_levels()` enriches each returned level with `language` and a
1-based `order` inside its category. 18 chains per language (6 per category).

## 5. Save format

`user://save.json` (default), with `user://save.json.bak` as the previous good
copy. Plain, human-readable JSON:

```json
{
  "version": 1,
  "settings": { "language": "tr", "sound": true, "music": false, "vibration": true },
  "progress": {
    "tr": {
      "coins": 100,
      "completed": { "tr_kitchen_tea_time": true },
      "hints_used": 0, "reveals_used": 0, "total_wins": 1, "last_level": "tr_kitchen_tea_time"
    },
    "en": { "coins": 100, "completed": {}, "hints_used": 0, "reveals_used": 0, "total_wins": 0, "last_level": "" }
  },
  "meta": { "created_at": 0, "updated_at": 0 }
}
```

Durability guarantees:

* **Atomic write:** JSON goes to `save.json.tmp`, is flushed, then renamed over
  `save.json`. A failed write never leaves a half-written main file.
* **Backup rotation is conservative.** `.bak` is replaced only when a readable
  main file exists *and* the new backup copy is complete. If the main file is
  missing or corrupt, the existing `.bak` is left untouched until a new main
  has been committed — the only good copy is never deleted to make room.
* **Recovery:** corrupt main → moved to `.corrupt`, `.bak` is loaded; missing
  main → `.bak` is loaded. Both unreadable → defaults restored, `.bak` kept for
  inspection. `SaveStore.last_error` reports `"backup_recovered"`,
  `"reset_after_corruption"` or `""`.
* **Rollback on write failure:** `add_coins`, `spend_coins` and
  `mark_level_completed` restore the previous in-memory state when the save
  fails. `spend_coins` returns `false`; `mark_level_completed` returns
  `success = false`, `coins_awarded = 0`. Nothing is announced that is not on
  disk.
* Values are sanitized on load (coins clamped to `0..999_999_999`, counters to
  `>= 0`, language to `tr`/`en`).

## 6. API reference

### 6.1 `SaveStore` (`core/save_store.gd`, autoload `SaveStore`)

Settings / data

| Member | Notes |
|---|---|
| `language` (property), `get_language()`, `set_language(lang)` | persists; normalizes to `tr`/`en` |
| `get_setting(key, fallback)`, `set_setting(key, value, persist = true)` | `language`, `sound`, `music`, `vibration` |
| `is_sound_enabled()`, `set_sound_enabled(on)` | read by `AudioManager` |
| `get_data()` | deep copy of the whole save |
| `load_game() -> bool`, `save_game() -> bool`, `save()`, `persist()` | `save()`/`persist()` alias `save_game()` |
| `set_storage_path(main, backup = "")`, `use_default_path()` | tests / migrations |
| `last_error` (variable, not a method) | last load/save problem |

Coins (per language)

| Member | Notes |
|---|---|
| `get_coins(lang = "")` | empty `lang` = current interface language |
| `can_afford(lang, amount)` | non-mutating |
| `add_coins(lang, amount)` / `add_coins(amount)` | returns the new balance; on write failure returns the unchanged balance |
| `spend_coins(lang, amount)` / `spend_coins(amount)` | **atomic**: `false` and unchanged when the balance is too low **or the save fails** |

Progress

| Member | Notes |
|---|---|
| `is_completed(lang, level_id) -> bool` | |
| `mark_level_completed(lang, level_id, reward = 25) -> Dictionary` | the only place the reward is granted |
| `complete_level(lang, level_id)` | alias; adds `first`/`reward` keys for `GardenApi` |
| `mark_completed(...)`, `set_level_completed(...)` | aliases |
| `completed_ids(lang) -> PackedStringArray`, `completed_count(lang)` | |
| `get_progress(lang) -> Dictionary` | deep copy |
| `set_last_level(lang, level_id)`, `record_purchase(lang, "hint"\|"reveal")` | statistics |
| `reset_progress(lang)` | back to 100 coins, empty completion map |

`mark_level_completed()` results:

```gdscript
# first clear, saved
{ "success": true,  "first_clear": true,  "coins_awarded": 25, "coins": 125, "already_completed": false }
# replay, saved
{ "success": true,  "first_clear": false, "coins_awarded": 0,  "coins": 125, "already_completed": true  }
# disk write failed — everything rolled back
{ "success": false, "first_clear": false, "coins_awarded": 0,  "coins": 100, "already_completed": false, "error": "save_failed" }
```

`coins_awarded` is the actual delta (a wallet at the cap reports 0). Replays
never farm coins: the completion map is checked before awarding.

Signals: `coins_changed(lang, coins)`, `level_completed(lang, level_id, first_clear)`,
`settings_changed(key, value)`, `save_failed(message)`, `save_succeeded`,
`progress_reset(lang)`.

### 6.2 `I18n` (`core/i18n.gd`, autoload `I18n`)

| Member | Notes |
|---|---|
| `t(key, args = {}) -> String` | `{name}` placeholders; falls back to the key |
| `has_key(key)`, `ui_dictionary(lang = "")` | dictionary copy for bulk UI work |
| `language` (property), `get_language()`, `set_language(lang, persist = true)` | setting persists through `SaveStore` |
| `upper_letter(ch, lang)`, `lower_letter(ch, lang)` | Turkish `i → İ`, `ı → I`, `İ → i`, `I → ı` |
| `upper(text, lang)`, `lower(text, lang)`, `normalize(text, lang)` | `normalize` = Turkish-aware uppercase + trim |
| `alphabet(lang)` | `ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ` / `A–Z` |
| `is_alphabet_letter(ch, lang)` | |
| `category_name(id)`, `emote_name(id)` | localized display names |

Key namespaces (both languages have identical key sets — enforced by tests):
`app.*`, `nav.*`, `home.*`, `common.*`, `level.*`, `game.*`, `result.*`,
`category.*`, `settings.*`, `party.*`, `error.*`, `emote.*`, `toast.*`.

Signal: `language_changed(language)`.

### 6.3 `Content` (`core/content.gd`, autoload `Content`)

| Member | Notes |
|---|---|
| `get_levels(lang, category = "") -> Array[Dictionary]` | deep copies, enriched with `language`/`order` |
| `get_level(lang, level_id) -> Dictionary` | `{}` when unknown |
| `has_level(lang, level_id)`, `count(lang, category = "")` | |
| `categories(lang) -> Array[Dictionary]` | `{id, name_key, icon, order, count}` |
| `category_ids(lang)`, `category_count(lang, category)` | |
| `level_ids(lang)`, `languages()`, `has_language(lang)` | |
| `random_level(lang, category = "", avoid_id = "")` | never the avoided id when >1 candidate |
| `party_chain(lang = "", avoid = "")` | alias used by `GardenApi.party_level` |
| `random_level_avoiding(lang, category, recent_ids, max_recent = 1)` | no immediate repeat |
| `alphabet(lang)`, `normalize(text, lang)`, `word_count(level)` | |
| `category_display_name(lang, id)`, `errors()`, `is_loaded(lang = "")`, `reload()` | |

Signal: `content_loaded`.

### 6.4 `GameSession` (`core/game_session.gd`, `class_name GameSession`)

`GameSession.new()` resolves autoloads lazily; `GameSession.new(save_store,
content)` injects them. Both may be `null` for a fully in-memory session.

Lifecycle / play

| Member | Behaviour |
|---|---|
| `start(level, lang = "") -> bool` | accepts a `Content` level dictionary, a presentation-normalized dictionary (`words` as dictionaries with a `word` key, optional `raw`), or a level id `String`. Word 0 is solved; word 1 becomes active with its first letter locked |
| `start_level(id, lang)` | alias of `start(id, lang)` |
| `type_letter(ch)`, `type_unicode(code)`, `handle_key_event(event)` | writes only into free slots of the active word; returns `false` when the word is full |
| `backspace() -> bool` | removes the last *typed* letter of the active word only |
| `clear_input()` | clears typed letters of the active word; keeps fixed letters |
| `submit() -> bool` | validates the active word (see §2), advances or wins |
| `can_submit() -> bool` | active word fully typed and the level is not won |
| `is_chain_completed() -> bool` | alias of `won`: true only at victory |
| `buy_hint() -> bool` | 10 coins, active word, once per word |
| `buy_letter() -> bool` | 15 coins, one random hidden non-initial letter of the active word |
| `can_buy_hint()`, `can_buy_letter()` | side-effect-free affordance checks |
| `get_word_state(i)`, `get_state()` | render snapshots |
| `typed_word(i)`, `typed_answer()` | typed letters; `typed_answer()` is the **active word** (what submit validates) |
| `typed_chain()`, `get_mask_words()`, `letter_at(w, l)`, `is_locked(w, l)` | view helpers |
| `is_word_solved(w)`, `word_start(i)`, `word_length(i)`, `flat_index(w, l)` | view helpers |

Read-only state: `words`, `hints`, `links`, `language`, `level_id`, `level`,
`coins`, `won`, `first_clear`, `coins_awarded`, `wrong_attempts`, `save_error`,
`current`, `current_word_index`, `current_mask`, `mask`, `chain_complete`,
`solved_word_count`.

`current_word_index` starts at `1`; it is `-1` before a level starts and after
victory. `current`/`current_mask` are empty in those states.

Snapshot keys per word (`get_word_state`): `index`, `word`, `length`, `typed`,
`mask`, `state` (`"solved" | "active" | "future"`), `solved`, `active`,
`future`, `complete`, `correct`, `hint`, `hint_shown`, `first_revealed`,
`active_word`. Masks: solved word = full word, active = fixed letters + typed
letters + `_`, future = all `_`. `get_state()` adds `solved_count`,
`save_error`, `chain_completed` (== won) and `words_state`.

Views must render `mask` and `state`; `word` is the solution root and must not
be drawn for active/future cards.

Signals

```gdscript
state_changed
letter_typed(word_index, letter_index, letter)
letter_removed(word_index, letter_index)
word_filled(word_index)        # active word fully typed, not yet verified
word_solved(word_index)        # word verified and locked
chain_completed                # exactly once, at victory
answer_rejected(answer)        # wrong active-word submit
submit_blocked(reason)         # "incomplete" | "not_started"
hint_bought(word_index, hint, coins)
letters_revealed(count, coins) # count is 1 for the current reveal rule
coins_changed(coins)
level_won(coins_awarded, first_clear, total_coins)
```

Constants: `HINT_COST = 10`, `REVEAL_COST = 15`, `COMPLETION_REWARD = 25`,
`DEFAULT_COINS = 100`, `TR_ALPHABET`, `EN_ALPHABET`.

Persistence failure: if `SaveStore.mark_level_completed()` returns
`success = false`, the session still reports `won`, but `first_clear = false`,
`coins_awarded = 0` and `save_error = "save_failed"`.

### 6.5 `AudioManager` (`core/audio_manager.gd`, autoload `AudioManager`)

Sounds are generated at runtime (`AudioStreamWAV`, 22050 Hz sine/chime); the
repo ships no audio assets. A pool of 8 `AudioStreamPlayer`s allows overlap.

| Member | Notes |
|---|---|
| `play(name)` / `play_sfx(name)` | unknown names warn and are ignored |
| `play_tap()`, `play_backspace()`, `play_hint()`, `play_reveal()`, `play_correct()`, `play_wrong()`, `play_coin()`, `play_win()`, `play_emote()` | typed wrappers |
| `enabled` (property), `set_enabled(on)`, `is_enabled()` | persisted to `SaveStore` |
| `muted` (property) | inverse of `enabled` |
| `stop_all()` | |

Sound names: `tap`, `key`, `click` (tap aliases), `backspace`, `hint`, `reveal`,
`correct`, `wrong`, `coin`, `win`, `emote`.

### 6.6 `NetworkClient` (`core/network_client.gd`, autoload `NetworkClient`)

Optional **online 1v1** mode over a real `WebSocketPeer` polled in `_process()`.
No third-party dependencies. URL resolution:

1. `res://config/network.json` → `{"url": "wss://host/ws"}` (optional file;
   template: `res://config/network.example.json`),
2. otherwise `ws://127.0.0.1:8787/ws` — the canonical local endpoint of
   `backend/local-server.mjs`. The backend also accepts the legacy root path
   (`ws://127.0.0.1:8787`), so older configs keep working.

Only `ws://` and `wss://` are accepted. Timeouts: connect 8 s, ping every 15 s,
pong timeout 45 s (socket closed, `disconnected` fires).

Client → server (compact JSON):

```json
{"type":"create","language":"tr","name":"Ada"}
{"type":"join","code":"ABCD","name":"Ada"}
{"type":"answer","answer":"KAŞIK","level_index":0,"word_index":1}
{"type":"emote","id":"hello"}
{"type":"ping"}
{"type":"leave"}
```

Server → client: `welcome`, `room`, `start`, `answer_result`, `score`, `emote`,
`finish`, `error`, `pong`. Each is parsed into a typed signal; the raw
dictionary is also emitted through `message_received`. Unknown types are
ignored, malformed JSON reports `network_error("invalid_json")`.

| Member | Notes |
|---|---|
| `connect_to_server(url = "")`, `disconnect_from_server(send_leave = true)` | |
| `set_url(url)`, `resolve_url()`, `is_open()`, `get_status()`, `get_latency_ms()` | |
| `server_now_msec()` | Server epoch time anchored to monotonic ticks; used for countdown and match timer, independent of device clock |
| `create_room(language, player_name)`, `join_room(code, player_name)` | legacy 1v1 names; code uppercased client-side |
| `send_answer(answer, level_index, word_index)`, `send_emote(id)` | emotes: `hello`, `nice`, `wow`, `gg` |
| `ping()`, `leave_room()`, `ingest_message(raw_json)` | `ingest_message` is public for tests/replay |
| `status` | `idle` → `connecting` → `open` → `closing` → `closed` |
| `last_error`, `latency_ms`, `player_id`, `room_code`, `room_language`, `room_status`, `players` | |

Signals: `connected`, `disconnected(reason)`, `connection_failed(message)`,
`message_received(data)`, `welcome(player_id)`,
`room_updated(code, language, players, status)`,
`game_started(starts_at, ends_at, levels, players)`,
`answer_result(correct, level_index, word_index, score, finished)`,
`score_updated(players)`, `emote_received(player_id, id)`,
`game_finished(players, reason)`, `pong(server_time)`,
`error_received(code, message)`, `network_error(message)`.

Online 1v1 keeps its own score on the server; the client sends per-word answers
and never awards coins from a match.

## 7. UI integration

```gdscript
# ui/screens/play.gd (UI agent)
var session: GameSession

func _start_level(level: Dictionary) -> void:
    session = GameSession.new()                     # autoloads resolved lazily
    session.state_changed.connect(_refresh)
    session.word_solved.connect(_on_word_solved)    # lock/animate the card
    session.level_won.connect(_on_won)
    session.start(level, GardenApi.lang())

func _on_letter(ch: String) -> void:
    session.type_letter(ch)

func _on_backspace() -> void:
    session.backspace()

func _on_submit() -> void:
    session.submit()            # per-word: rejected/incomplete leaves state intact

func _on_hint() -> void:
    if session.buy_hint():
        _show_hint(session.get_active_hint())

func _on_reveal() -> void:
    session.buy_letter()        # reveals one letter of the active word

func _refresh() -> void:
    var state: Dictionary = session.get_state()
    # state.current_word_index, state.words_state (solved/active/future),
    # state.mask_words, state.coins, state.chain_completed …
    _submit_button.disabled = not session.can_submit()
```

Coins displayed anywhere must come from `SaveStore.get_coins(lang)` or
`session.coins`; never credit the 25-coin reward in UI code.
`GardenApi.complete_level()` already delegates to `SaveStore.complete_level()`.

## 8. Tests

Run with the pinned Godot 4.5.2 binary:

```powershell
$godot = "C:\Users\ArdHP\AppData\Local\Temp\opencode\godot-4.5.2\Godot_v4.5.2-stable_win64_console.exe"
& $godot --headless --path . --script tests/test_core.gd
& $godot --headless --path . --script tests/test_content.gd
```

* `tests/test_core.gd` switches `SaveStore` to a unique
  `user://test_core_<ticks>.json` before mutating anything (the player's real
  save is never touched) and creates missing autoloads because `--script` does
  not instantiate project autoloads. It asserts the gameplay rules explicitly:
  word 0 solved/locked, active word 1 with a locked first letter, hidden future
  words, typed letters confined to the active word, backspace/clear limits,
  incomplete/wrong submit immutability, per-word advance, victory only after
  the final word, reveal = one random non-initial letter, hint per word, coin
  economy, replay without farming, and save-failure behaviour (rollback, no
  announced reward) using an unwritable path.
* `tests/test_content.gd` checks the 36 chains: word count, casing, alphabet,
  hint/link counts, link prefixes, category balance, duplicates and required
  chains.
* Expected warnings: `SaveStore: recovered progress from backup.` and
  `save and backup were unreadable; defaults restored.` — produced by the
  recovery fixtures.
* `tests/test_network.gd` and `tests/test_ui.gd` belong to other agents.

## 9. Project settings

* Portrait 480×900, `canvas_items` stretch, `expand` aspect,
  `gl_compatibility` renderer (low-end Android + web export).
* `config/name = "Kelime Bahçesi"`; pastel clear colour matching the UI
  background (`#f6f0ff`).
* `.gitignore` ignores generated files (`.godot/`), signing material
  (`export_credentials.cfg`, `*.keystore`, `*.jks`, `*.p12`, `*.pfx`, `*.pem`,
  `*.key`, `*.mobileprovision`) and builds (`builds/`, `build/`, `dist/`,
  `*.apk`, `*.aab`, `*.ipa`, `*.pck`, `*.zip`). **`export_presets.cfg` is
  tracked** because the presets are safe to share and reproducible builds depend
  on them; the presets export into `builds/`.
