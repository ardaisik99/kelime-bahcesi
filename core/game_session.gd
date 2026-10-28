class_name GameSession
extends RefCounted
## UI-independent gameplay state for one word-chain level.
##
## USER RULES (fixed, not negotiable):
##   * Word 0 is SOLVED and fully locked when the level starts.
##   * Only the NEXT word is active. Its first letter is pre-revealed and
##     locked; the player fills the remaining letters of that single word.
##   * "Submit" validates the ACTIVE word only. A correct word is revealed and
##     locked in full, then the next word becomes active with its first letter
##     pre-revealed. A wrong or incomplete submit changes nothing.
##   * Words after the active one stay hidden (underscores) and expose only
##     metadata (length, state).
##   * The level is won only after the FINAL word is verified. There is no
##     blind full-chain fill and `chain_completed` is emitted at that victory.
##   * Backspace/clear only touch typed letters of the active word; solved
##     words and fixed letters (pre-revealed / bought) can never be erased.
##
## Construct directly:  var session := GameSession.new()
## Optional injection:  var session := GameSession.new(save_store, content)
## Both injection arguments may be null; /root/SaveStore and /root/Content are
## resolved lazily when available. The class also works in-memory without them.
##
## Public API:
##   start(level: Variant, lang: String = "") -> bool
##       level may be a Dictionary from Content.get_level(), a
##       presentation-normalized dictionary (words as Dictionaries with a
##       "word" key and an optional "raw" original), or a level id String.
##   start_level(level_id: String, lang: String) -> bool
##   type_letter(letter: String) -> bool
##   type_unicode(unicode: int) -> bool
##   handle_key_event(event: InputEvent) -> bool  (physical keyboard helper)
##   backspace() -> bool
##   clear_input() -> void
##   submit() -> bool          (validates the active word, advances on success)
##   buy_hint() -> bool        (10 coins, active word, once per word)
##   buy_letter() -> bool      (15 coins, reveals + locks ONE random still
##                              hidden NON-INITIAL letter of the active word;
##                              no charge when nothing can be revealed)
##   get_word_state(index: int) -> Dictionary
##   get_state() -> Dictionary
##
## Read-only properties:
##   words, hints, links, language, level_id, coins, won, first_clear,
##   coins_awarded, wrong_attempts, save_error,
##   current (active word root), current_mask, mask, current_word_index,
##   chain_complete, solved_word_count.
##
## Semantics:
##   won                  all words verified (independent of persistence)
##   is_chain_completed() true when won; the `chain_completed` signal fires once
##                        at victory (never on an unverified full mask)
##   first_clear / coins_awarded  reflect the SaveStore result; when the save
##                        fails they stay false/0 and save_error is set
##
## Signals:
##   state_changed
##   letter_typed(word_index, letter_index, letter)
##   letter_removed(word_index, letter_index)
##   word_filled(word_index)          active word fully typed (not yet verified)
##   word_solved(word_index)          word verified and locked
##   chain_completed                  all words verified (victory)
##   answer_rejected(answer)          wrong active-word submit
##   submit_blocked(reason)           "incomplete" | "not_started"
##   hint_bought(word_index, hint, coins)
##   letters_revealed(count, coins)
##   coins_changed(coins)
##   level_won(coins_awarded, first_clear, total_coins)

signal state_changed
signal letter_typed(word_index: int, letter_index: int, letter: String)
signal letter_removed(word_index: int, letter_index: int)
signal word_filled(word_index: int)
signal word_solved(word_index: int)
signal chain_completed
signal answer_rejected(answer: String)
signal submit_blocked(reason: String)
signal hint_bought(word_index: int, hint: String, coins: int)
signal letters_revealed(count: int, coins: int)
signal coins_changed(coins: int)
signal level_won(coins_awarded: int, first_clear: bool, total_coins: int)

const HINT_COST: int = 10
const REVEAL_COST: int = 15
const COMPLETION_REWARD: int = 25
const DEFAULT_COINS: int = 100
const EN_ALPHABET: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const TR_ALPHABET: String = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"

var language: String = "tr"
var level: Dictionary = {}
var level_id: String = ""
var words: Array[String] = []
var hints: Array[String] = []
var links: Array[String] = []
var coins: int = DEFAULT_COINS
var won: bool = false
var first_clear: bool = false
var coins_awarded: int = 0
var wrong_attempts: int = 0
var started: bool = false
var save_error: String = ""

var _save_store: Variant = null
var _content: Variant = null
var _chars: Array[String] = []
var _locked: Array[bool] = []
var _solved: Array[bool] = []
var _word_starts: Array[int] = []
var _hints_shown: Array[bool] = []
var _cursor: int = 0
var _current: int = -1
var _local_completed: Dictionary = {}
var _local_coins: int = DEFAULT_COINS

var current: String:
	get:
		if _current < 0 or _current >= words.size():
			return ""
		return words[_current]

var current_word: String:
	get:
		return current

var current_word_index: int:
	get:
		return active_word_index()

var current_mask: String:
	get:
		if _current < 0 or _current >= words.size():
			return ""
		return _mask_word(_current)

var mask: String:
	get:
		return " ".join(get_mask_words())

var chain_complete: bool:
	get:
		return is_chain_completed()

var solved_word_count: int:
	get:
		return solved_words()


func _init(save_store_ref: Variant = null, content_ref: Variant = null) -> void:
	_save_store = save_store_ref
	_content = content_ref


func _resolve_autoload(node_name: String) -> Variant:
	var loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = loop as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)


func _store() -> Variant:
	if _save_store != null:
		return _save_store
	return _resolve_autoload("SaveStore")


func _content_service() -> Variant:
	if _content != null:
		return _content
	return _resolve_autoload("Content")


func _i18n() -> Variant:
	return _resolve_autoload("I18n")


func _normalize_lang(value: String) -> String:
	var clean: String = value.strip_edges().to_lower()
	if clean.begins_with("tr"):
		return "tr"
	if clean.begins_with("en"):
		return "en"
	return ""


func _alphabet() -> String:
	return TR_ALPHABET if language == "tr" else EN_ALPHABET


func _upper_letter(ch: String) -> String:
	var i18n: Variant = _i18n()
	if i18n != null and i18n.has_method("upper_letter"):
		return str(i18n.call("upper_letter", ch, language))
	if language == "tr":
		if ch == "i" or ch == "î":
			return "İ"
		if ch == "ı":
			return "I"
	return ch.to_upper()


# ---------------------------------------------------------------------------
# Level input normalisation
# ---------------------------------------------------------------------------

## Accepts a plain content level dictionary (words: Array[String]) or a
## presentation-normalized dictionary (words: Array[Dictionary] with a "word"
## key and an optional "raw" copy of the original level).
func _coerce_level(level_data: Dictionary) -> Dictionary:
	var raw: Variant = level_data.get("raw", null)
	if raw is Dictionary:
		var raw_dict: Dictionary = raw
		var raw_words: Variant = raw_dict.get("words", null)
		if raw_words is Array and not (raw_words as Array).is_empty():
			var merged: Dictionary = raw_dict.duplicate(true)
			for key: String in ["id", "category", "title"]:
				if str(merged.get(key, "")).is_empty() and level_data.has(key):
					merged[key] = level_data[key]
			return merged
	return level_data


func _word_text(value: Variant) -> String:
	if value is String or value is StringName:
		return str(value).strip_edges()
	if value is Dictionary:
		var dict: Dictionary = value
		for key: String in ["word", "answer", "text", "kelime"]:
			if dict.has(key):
				var text: String = _word_text(dict[key])
				if not text.is_empty():
					return text
	return ""


func _entry_field(value: Variant, keys: Array) -> String:
	if not (value is Dictionary):
		return ""
	var dict: Dictionary = value
	for key: Variant in keys:
		if dict.has(key):
			var text: String = _word_text(dict[key])
			if not text.is_empty():
				return text
	return ""


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func start(level_data: Variant, lang: String = "") -> bool:
	var resolved: Dictionary = {}
	if level_data is Dictionary:
		resolved = _coerce_level((level_data as Dictionary).duplicate(true))
	elif level_data is String:
		var content: Variant = _content_service()
		if content == null or not content.has_method("get_level"):
			return false
		var chosen_lang: String = _normalize_lang(lang)
		if chosen_lang.is_empty():
			chosen_lang = _normalize_lang(language)
		if chosen_lang.is_empty():
			chosen_lang = "tr"
		resolved = content.call("get_level", chosen_lang, str(level_data))
	else:
		return false
	if resolved.is_empty():
		return false

	var raw_words: Variant = resolved.get("words", null)
	if not (raw_words is Array) or (raw_words as Array).is_empty():
		return false
	var chosen: String = _normalize_lang(lang)
	if chosen.is_empty():
		chosen = _normalize_lang(str(resolved.get("language", "")))
	if chosen.is_empty():
		chosen = "tr"

	language = chosen
	level = resolved
	level_id = str(resolved.get("id", ""))
	words.clear()
	var entry_hints: Array[String] = []
	var entry_links: Array[String] = []
	for word_value: Variant in raw_words:
		var word_text: String = _word_text(word_value)
		if word_text.is_empty():
			continue
		words.append(word_text)
		entry_hints.append(_entry_field(word_value, ["hint", "clue", "ipucu"]))
		entry_links.append(_entry_field(word_value, ["link", "expression", "example", "ifade"]))
	if words.is_empty():
		return false
	hints.clear()
	var raw_hints: Variant = resolved.get("hints", null)
	if raw_hints is Array:
		for hint_value: Variant in raw_hints:
			hints.append(str(hint_value))
	while hints.size() < words.size():
		var fallback_hint: String = entry_hints[hints.size()] if hints.size() < entry_hints.size() else ""
		hints.append(fallback_hint)
	links.clear()
	var raw_links: Variant = resolved.get("links", null)
	if raw_links is Array:
		for link_value: Variant in raw_links:
			links.append(str(link_value))
	while links.size() < words.size() - 1:
		var fallback_link: String = entry_links[links.size()] if links.size() < entry_links.size() else ""
		links.append(fallback_link)

	_chars.clear()
	_locked.clear()
	_solved.clear()
	_word_starts.clear()
	_hints_shown.clear()
	for word_index: int in range(words.size()):
		_word_starts.append(_chars.size())
		_hints_shown.append(false)
		_solved.append(false)
		for _letter_index: int in range(words[word_index].length()):
			_chars.append("")
			_locked.append(false)

	_cursor = 0
	_current = -1
	won = false
	started = true
	coins_awarded = 0
	wrong_attempts = 0
	first_clear = true
	save_error = ""

	# Word 0 is the given expression: fully revealed and locked.
	_lock_word(0)
	if words.size() > 1:
		# Only the next word is active, with its first letter pre-revealed.
		_activate_word(1)
	else:
		_current = -1
		_cursor = _chars.size()

	var store: Variant = _store()
	if store != null:
		if store.has_method("get_coins"):
			coins = int(store.call("get_coins", language))
		if store.has_method("is_completed") and not level_id.is_empty():
			first_clear = not bool(store.call("is_completed", language, level_id))
	else:
		coins = _local_coins
		first_clear = not _local_completed.has(_level_key())

	state_changed.emit()
	return true


func start_level(id: String, lang: String) -> bool:
	return start(id, lang)


func _level_key() -> String:
	return language + ":" + level_id


# ---------------------------------------------------------------------------
# Word helpers
# ---------------------------------------------------------------------------

func active_word_index() -> int:
	if not started or won or _current < 0 or _current >= words.size():
		return -1
	return _current


func word_start(index: int) -> int:
	if index < 0 or index >= _word_starts.size():
		return -1
	return _word_starts[index]


func word_length(index: int) -> int:
	if index < 0 or index >= words.size():
		return 0
	return words[index].length()


func flat_index(word_index: int, letter_index: int) -> int:
	if word_index < 0 or word_index >= words.size():
		return -1
	if letter_index < 0 or letter_index >= words[word_index].length():
		return -1
	return _word_starts[word_index] + letter_index


func letter_at(word_index: int, letter_index: int) -> String:
	var flat: int = flat_index(word_index, letter_index)
	if flat < 0:
		return ""
	return _chars[flat]


func is_locked(word_index: int, letter_index: int) -> bool:
	var flat: int = flat_index(word_index, letter_index)
	if flat < 0:
		return false
	return _locked[flat]


func is_word_solved(word_index: int) -> bool:
	if word_index < 0 or word_index >= _solved.size():
		return false
	return _solved[word_index]


func solved_words() -> int:
	var count: int = 0
	for word_index: int in range(_solved.size()):
		if _solved[word_index]:
			count += 1
	return count


func is_word_complete(word_index: int) -> bool:
	if word_index < 0 or word_index >= words.size():
		return false
	var start: int = _word_starts[word_index]
	var length: int = words[word_index].length()
	for i: int in range(start, start + length):
		if _chars[i].is_empty():
			return false
	return true


func is_chain_completed() -> bool:
	# Every word is locked only after verification, so this equals victory.
	if not started or words.is_empty():
		return false
	return won


func can_submit() -> bool:
	return started and not won and _current >= 0 and is_word_complete(_current)


func typed_word(index: int) -> String:
	if index < 0 or index >= words.size():
		return ""
	var start: int = _word_starts[index]
	var out: String = ""
	for i: int in range(words[index].length()):
		out += _chars[start + i]
	return out


## The active word's current letters (what submit() will validate).
func typed_answer() -> String:
	return typed_word(_current)


## Whole-chain snapshot of typed/solved letters (view helpers, not answers).
func typed_chain() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for word_index: int in range(words.size()):
		parts.append(typed_word(word_index))
	return " ".join(parts)


func _mask_word(index: int) -> String:
	if index < 0 or index >= words.size():
		return ""
	var out: String = ""
	var start: int = _word_starts[index]
	for i: int in range(words[index].length()):
		var ch: String = _chars[start + i]
		out += ch if not ch.is_empty() else "_"
	return out


func get_mask_words() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for word_index: int in range(words.size()):
		out.append(_mask_word(word_index))
	return out


# ---------------------------------------------------------------------------
# Internal state transitions
# ---------------------------------------------------------------------------

func _lock_word(index: int) -> void:
	if index < 0 or index >= words.size():
		return
	var start: int = _word_starts[index]
	var word: String = words[index]
	for i: int in range(word.length()):
		_chars[start + i] = word.substr(i, 1)
		_locked[start + i] = true
	_solved[index] = true


## Reveals and locks the first letter, makes `index` the active word and puts
## the cursor on its first writable slot.
func _activate_word(index: int) -> void:
	if index < 0 or index >= words.size():
		_current = -1
		_cursor = _chars.size()
		return
	_current = index
	var start: int = _word_starts[index]
	if words[index].length() > 0:
		_chars[start] = words[index].substr(0, 1)
		_locked[start] = true
	_cursor = _first_writable_in_word(index, start)


func _first_writable_in_word(index: int, from_flat: int) -> int:
	var start: int = _word_starts[index]
	var end: int = start + words[index].length()
	var index_flat: int = maxi(from_flat, start)
	while index_flat < end and _locked[index_flat]:
		index_flat += 1
	return index_flat if index_flat < end else end


func _skip_locked_cursor() -> void:
	if _current < 0:
		return
	var end: int = _word_starts[_current] + words[_current].length()
	while _cursor < end and _locked[_cursor]:
		_cursor += 1


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func type_letter(letter: String) -> bool:
	if not started or won or _current < 0:
		return false
	if letter.length() != 1:
		return false
	var normalized: String = _upper_letter(letter)
	if normalized.length() != 1 or not _alphabet().contains(normalized):
		return false
	var start: int = _word_starts[_current]
	var end: int = start + words[_current].length()
	var index: int = maxi(_cursor, start)
	while index < end and _locked[index]:
		index += 1
	if index >= end:
		return false
	_chars[index] = normalized
	_cursor = index + 1
	_skip_locked_cursor()
	letter_typed.emit(_current, index - start, normalized)
	if is_word_complete(_current):
		word_filled.emit(_current)
	state_changed.emit()
	return true


func type_unicode(unicode: int) -> bool:
	if unicode <= 0:
		return false
	return type_letter(String.chr(unicode))


func handle_key_event(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.keycode == KEY_BACKSPACE:
		return backspace()
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		return submit()
	if key.unicode > 0:
		return type_unicode(key.unicode)
	return false


func backspace() -> bool:
	if not started or won or _current < 0:
		return false
	var start: int = _word_starts[_current]
	var index: int = mini(_cursor - 1, start + words[_current].length() - 1)
	while index >= start:
		if not _locked[index] and not _chars[index].is_empty():
			_chars[index] = ""
			_cursor = index
			letter_removed.emit(_current, index - start)
			state_changed.emit()
			return true
		index -= 1
	return false


func clear_input() -> void:
	if not started or won or _current < 0:
		return
	var start: int = _word_starts[_current]
	var end: int = start + words[_current].length()
	for i: int in range(start, end):
		if not _locked[i]:
			_chars[i] = ""
	_cursor = _first_writable_in_word(_current, start)
	state_changed.emit()


# ---------------------------------------------------------------------------
# Purchases
# ---------------------------------------------------------------------------

func can_buy_hint() -> bool:
	if not started or won or _current < 0:
		return false
	if _hints_shown[_current] or is_word_complete(_current):
		return false
	return coins >= HINT_COST


func buy_hint() -> bool:
	if not can_buy_hint():
		return false
	var word_index: int = _current
	if not _spend_coins(HINT_COST):
		return false
	_hints_shown[word_index] = true
	var text: String = hints[word_index] if word_index < hints.size() else ""
	_record_purchase("hint")
	hint_bought.emit(word_index, text, coins)
	state_changed.emit()
	return true


func can_buy_letter() -> bool:
	if not started or won or _current < 0:
		return false
	if coins < REVEAL_COST:
		return false
	return not _reveal_targets().is_empty()


## Still-hidden, non-initial letter positions of the ACTIVE word.
func _reveal_targets() -> Array[int]:
	var targets: Array[int] = []
	if _current < 0:
		return targets
	var start: int = _word_starts[_current]
	var length: int = words[_current].length()
	for offset: int in range(1, length):
		var flat: int = start + offset
		if _locked[flat]:
			continue
		if _chars[flat].is_empty():
			targets.append(flat)
	return targets


func buy_letter() -> bool:
	if not started or won or _current < 0:
		return false
	var targets: Array[int] = _reveal_targets()
	if targets.is_empty() or coins < REVEAL_COST:
		return false
	if not _spend_coins(REVEAL_COST):
		return false
	var pick: int = targets[randi() % targets.size()]
	var start: int = _word_starts[_current]
	_chars[pick] = words[_current].substr(pick - start, 1)
	_locked[pick] = true
	_skip_locked_cursor()
	_record_purchase("reveal")
	letters_revealed.emit(1, REVEAL_COST)
	state_changed.emit()
	return true


func _spend_coins(amount: int) -> bool:
	if amount < 0:
		return false
	var store: Variant = _store()
	if store != null and store.has_method("spend_coins"):
		var ok: bool = bool(store.call("spend_coins", language, amount))
		if ok:
			coins = maxi(0, coins - amount)
			coins_changed.emit(coins)
		return ok
	if _local_coins < amount:
		return false
	_local_coins -= amount
	coins = _local_coins
	coins_changed.emit(coins)
	return true


func _record_purchase(kind: String) -> void:
	var store: Variant = _store()
	if store != null and store.has_method("record_purchase"):
		store.call("record_purchase", language, kind)


func hint_for(word_index: int) -> String:
	if word_index < 0 or word_index >= _hints_shown.size():
		return ""
	if not _hints_shown[word_index]:
		return ""
	return hints[word_index] if word_index < hints.size() else ""


func get_active_hint() -> String:
	return hint_for(_current)


# ---------------------------------------------------------------------------
# Submit / victory
# ---------------------------------------------------------------------------

func submit() -> bool:
	if not started:
		submit_blocked.emit("not_started")
		return false
	if won:
		return false
	if _current < 0:
		# Defensive: a one-word level is already solved at start.
		if solved_words() == words.size():
			return _win()
		return false
	if not is_word_complete(_current):
		submit_blocked.emit("incomplete")
		return false
	if typed_word(_current) != words[_current]:
		wrong_attempts += 1
		answer_rejected.emit(typed_word(_current))
		state_changed.emit()
		return false

	_lock_word(_current)
	word_solved.emit(_current)
	if _current + 1 < words.size():
		_activate_word(_current + 1)
		state_changed.emit()
		return true
	_current = -1
	_cursor = _chars.size()
	return _win()


func _win() -> bool:
	if won:
		return false
	won = true
	coins_awarded = 0
	first_clear = false
	save_error = ""

	var store: Variant = _store()
	if store != null and store.has_method("mark_level_completed"):
		var result_value: Variant = store.call("mark_level_completed", language, level_id, COMPLETION_REWARD)
		if result_value is Dictionary:
			var result: Dictionary = result_value
			var saved: bool = bool(result.get("success", true))
			if not saved:
				save_error = str(result.get("error", "save_failed"))
				coins = int(result.get("coins", coins))
			else:
				first_clear = bool(result.get("first_clear", false))
				coins_awarded = int(result.get("coins_awarded", 0))
				coins = int(result.get("coins", coins))
				if first_clear:
					coins_changed.emit(coins)
	else:
		if _local_completed.has(_level_key()):
			first_clear = false
			coins_awarded = 0
		else:
			_local_completed[_level_key()] = true
			first_clear = true
			coins_awarded = COMPLETION_REWARD
			_local_coins = clampi(_local_coins + COMPLETION_REWARD, 0, 999999999)
			coins = _local_coins
			coins_changed.emit(coins)
	chain_completed.emit()
	level_won.emit(coins_awarded, first_clear, coins)
	state_changed.emit()
	return true


# ---------------------------------------------------------------------------
# Snapshots
# ---------------------------------------------------------------------------

func _word_state_name(index: int) -> String:
	if index < 0 or index >= words.size():
		return "none"
	if _solved[index]:
		return "solved"
	if index == _current:
		return "active"
	return "future"


func get_word_state(word_index: int) -> Dictionary:
	if word_index < 0 or word_index >= words.size():
		return {}
	var state_name: String = _word_state_name(word_index)
	var start: int = _word_starts[word_index]
	return {
		"index": word_index,
		"word": words[word_index],
		"length": words[word_index].length(),
		"typed": typed_word(word_index),
		"mask": _mask_word(word_index),
		"state": state_name,
		"solved": _solved[word_index],
		"active": state_name == "active",
		"future": state_name == "future",
		"complete": is_word_complete(word_index),
		"correct": _word_is_correct(word_index),
		"hint": hint_for(word_index),
		"hint_shown": _hints_shown[word_index],
		"first_revealed": _locked[start] if not words[word_index].is_empty() else false,
		"active_word": word_index == active_word_index(),
	}


func _word_is_correct(word_index: int) -> bool:
	if word_index < 0 or word_index >= words.size():
		return false
	if _solved[word_index]:
		return true
	var word: String = words[word_index]
	for i: int in range(word.length()):
		if _chars[_word_starts[word_index] + i] != word.substr(i, 1):
			return false
	return true


func get_state() -> Dictionary:
	var mask_words: Array[String] = []
	for item: String in get_mask_words():
		mask_words.append(item)
	var word_states: Array[Dictionary] = []
	for word_index: int in range(words.size()):
		word_states.append(get_word_state(word_index))
	return {
		"started": started,
		"language": language,
		"level_id": level_id,
		"words": words.duplicate(),
		"hints": hints.duplicate(),
		"links": links.duplicate(),
		"mask": mask,
		"mask_words": mask_words,
		"current": current,
		"current_word_index": active_word_index(),
		"current_letter_index": _cursor - _word_starts[_current] if _current >= 0 else -1,
		"chain_completed": is_chain_completed(),
		"won": won,
		"first_clear": first_clear,
		"coins": coins,
		"coins_awarded": coins_awarded,
		"wrong_attempts": wrong_attempts,
		"solved_count": solved_words(),
		"save_error": save_error,
		"words_state": word_states,
	}
