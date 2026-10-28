extends SceneTree
## Core tests: SaveStore, I18n, Content, GameSession.
## Run:
##   godot --headless --path . --script tests/test_core.gd
##
## The test switches SaveStore to a temporary user:// path before mutating
## anything, so the player's real save.json is never overwritten.

var _checks: int = 0
var _failures: Array[String] = []
var _save_path: String = ""
var _backup_path: String = ""
var _store: Node = null
var _i18n: Node = null
var _content: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_save_path = "user://test_core_%d.json" % Time.get_ticks_usec()
	_backup_path = _save_path + ".bak"
	await _ensure_core()
	if _store == null or _i18n == null or _content == null:
		_fail("core autoloads could not be created")
		_finish()
		return

	_test_i18n()
	_test_content()
	await _test_save_store()
	_test_session()
	_test_persistence_reload()
	_test_recovery()
	_test_save_failures()
	_cleanup()
	_finish()


func _ensure_core() -> void:
	_store = root.get_node_or_null("SaveStore")
	if _store == null:
		_store = Node.new()
		_store.name = "SaveStore"
		_store.set_script(load("res://core/save_store.gd"))
		_store.set("save_path", _save_path)
		_store.set("backup_path", _backup_path)
		root.add_child(_store)
		print("[core] registered missing SaveStore autoload")
	else:
		_store.call("set_storage_path", _save_path, _backup_path)

	_i18n = root.get_node_or_null("I18n")
	if _i18n == null:
		_i18n = Node.new()
		_i18n.name = "I18n"
		_i18n.set_script(load("res://core/i18n.gd"))
		root.add_child(_i18n)
		print("[core] registered missing I18n autoload")

	_content = root.get_node_or_null("Content")
	if _content == null:
		_content = Node.new()
		_content.name = "Content"
		_content.set_script(load("res://core/content.gd"))
		root.add_child(_content)
		print("[core] registered missing Content autoload")

	await _frames(2)
	# A previous autoload may have loaded the real save before the temp switch.
	_store.call("set_storage_path", _save_path, _backup_path)
	await _frames(1)


func _test_i18n() -> void:
	_i18n.call("set_language", "tr", false)
	_check(str(_i18n.call("normalize", "istanbul ışık", "tr")) == "İSTANBUL IŞIK", "Turkish uppercase normalizes i/ı correctly")
	_check(str(_i18n.call("lower", "İSTANBUL IŞIK", "tr")) == "istanbul ışık", "Turkish lowercase normalizes İ/I correctly")
	_check(str(_i18n.call("normalize", "istanbul", "en")) == "ISTANBUL", "English uppercase is locale-neutral")
	_check(str(_i18n.call("upper_letter", "i", "tr")) == "İ", "Turkish dotted i upper")
	_check(str(_i18n.call("upper_letter", "ı", "tr")) == "I", "Turkish dotless ı upper")
	_check(str(_i18n.call("alphabet", "tr")).contains("Ş"), "Turkish alphabet contains Ş")

	var tr_ui: Dictionary = _i18n.call("ui_dictionary", "tr")
	var en_ui: Dictionary = _i18n.call("ui_dictionary", "en")
	_check(tr_ui.size() > 80 and en_ui.size() > 80, "UI dictionaries are populated")
	var missing: Array[String] = []
	for key: String in tr_ui.keys():
		if not en_ui.has(key):
			missing.append(key)
		elif str(en_ui[key]).strip_edges().is_empty():
			missing.append(key)
	_check(missing.is_empty(), "tr/en UI dictionaries have matching keys (%s)" % [str(missing)])
	_i18n.call("set_language", "tr", false)
	_check(str(_i18n.call("t", "common.coin_count", {"coins": 7})) == "7 altın", "t() formats placeholders")
	_check(str(_i18n.call("t", "category.kitchen")) == "Mutfak", "category translation")
	_i18n.call("set_language", "en", false)
	_check(str(_i18n.call("t", "category.kitchen")) == "Kitchen", "language switch changes t()")
	_i18n.call("set_language", "tr", false)


func _test_content() -> void:
	var errors: Variant = _content.call("errors")
	_check(errors is Array and (errors as Array).is_empty(), "Content loads without validation errors: %s" % [str(errors)])
	var all_ids: Dictionary = {}
	for lang: String in ["tr", "en"]:
		var levels: Array = _content.call("get_levels", lang)
		_check(levels.size() == 18, "%s has 18 levels" % lang)
		var categories: Array = _content.call("categories", lang)
		_check(categories.size() == 3, "%s has 3 categories" % lang)
		var seen_chains: Dictionary = {}
		for category: String in ["kitchen", "nature", "daily"]:
			_check(int(_content.call("category_count", lang, category)) == 6, "%s/%s has 6 levels" % [lang, category])
		for level_value: Variant in levels:
			var level: Dictionary = level_value
			var id: String = str(level.get("id", ""))
			_check(not id.is_empty() and not all_ids.has(id), "%s level id is unique (%s)" % [lang, id])
			all_ids[id] = true
			var words: Array = level.get("words", [])
			var hints: Array = level.get("hints", [])
			var links: Array = level.get("links", [])
			_check(words.size() >= 4 and words.size() <= 5, "%s has 4-5 words" % id)
			_check(hints.size() == words.size(), "%s has one hint per word" % id)
			_check(links.size() == words.size() - 1, "%s has one link between each pair" % id)
			var chain_parts: PackedStringArray = PackedStringArray()
			for word_value: Variant in words:
				var word: String = str(word_value)
				_check(word == str(_i18n.call("normalize", word, lang)), "%s word is uppercase (%s)" % [id, word])
				chain_parts.append(word)
			var chain_key: String = "|".join(chain_parts)
			_check(not seen_chains.has(chain_key), "%s chain is not repeated" % id)
			seen_chains[chain_key] = true
			for link_index: int in range(links.size()):
				var link: String = str(links[link_index])
				var root: String = str(words[link_index])
				var lowered: String = str(_i18n.call("lower", root, lang))
				_check(str(_i18n.call("lower", link, lang)).begins_with(lowered), "%s link '%s' starts with '%s'" % [id, link, lowered])

	var tea: Dictionary = _content.call("get_level", "tr", "tr_kitchen_tea_time")
	_check(tea.get("words", []) == ["ÇAY", "KAŞIK", "OYUN", "HAVA"], "required ÇAY KAŞIK OYUN HAVA chain exists")
	_check(tea.get("links", []) == ["çay kaşığı", "kaşık oyunu", "oyun havası"], "Turkish chain link suffixes are correct")
	var iced: Dictionary = _content.call("get_level", "en", "en_kitchen_ice_cream_soda")
	_check(iced.get("links", []) == ["ice cream", "cream soda", "soda pop"], "English open compounds are natural")

	var copy: Dictionary = _content.call("get_level", "tr", "tr_kitchen_tea_time")
	var copy_words: Array = copy.get("words", [])
	if not copy_words.is_empty():
		copy_words[0] = "BOZUK"
	var again: Dictionary = _content.call("get_level", "tr", "tr_kitchen_tea_time")
	_check(again.get("words", [])[0] == "ÇAY", "get_level returns a defensive copy")

	var avoided: int = 0
	for i: int in range(40):
		var picked: Dictionary = _content.call("random_level", "tr", "kitchen", "tr_kitchen_tea_time")
		if str(picked.get("id", "")) == "tr_kitchen_tea_time":
			avoided += 1
	_check(avoided == 0, "random_level avoids the immediate repeat id")
	var recent: Array = ["tr_kitchen_tea_time"]
	var picked2: Dictionary = _content.call("random_level_avoiding", "tr", "kitchen", recent, 1)
	_check(str(picked2.get("id", "")) != "tr_kitchen_tea_time", "random_level_avoiding avoids recent id")


func _test_save_store() -> void:
	_store.call("reset_progress", "tr")
	_store.call("reset_progress", "en")
	_check(int(_store.call("get_coins", "tr")) == 100, "tr starts with 100 coins")
	_check(int(_store.call("get_coins", "en")) == 100, "en starts with 100 coins")
	_check(bool(_store.call("spend_coins", "tr", 1000)) == false, "cannot overspend")
	_check(int(_store.call("get_coins", "tr")) == 100, "failed spend does not charge")
	_check(bool(_store.call("spend_coins", "tr", 10)), "hint-sized spend succeeds")
	_check(int(_store.call("get_coins", "tr")) == 90, "spend deducts exactly once")
	_store.call("add_coins", "tr", 10)
	_check(int(_store.call("get_coins", "tr")) == 100, "add_coins credits")

	var first: Dictionary = _store.call("mark_level_completed", "tr", "tr_kitchen_tea_time")
	_check(bool(first.get("first_clear", false)), "first completion is first clear")
	_check(int(first.get("coins_awarded", 0)) == 25, "first completion awards 25")
	var second: Dictionary = _store.call("mark_level_completed", "tr", "tr_kitchen_tea_time")
	_check(not bool(second.get("first_clear", true)), "replay is not first clear")
	_check(int(second.get("coins_awarded", -1)) == 0, "replay awards no coins")
	_check(int(_store.call("get_coins", "tr")) == 125, "coins after first clear are 125")
	_check(int(_store.call("get_coins", "en")) == 100, "English wallet is separate")
	_check(not bool(_store.call("is_completed", "en", "tr_kitchen_tea_time")), "completion is per language")

	_store.call("set_setting", "sound", false)
	_store.call("set_setting", "language", "en")
	_store.call("save_game")
	_check(FileAccess.file_exists(_save_path), "save file exists after save_game")
	_check(not FileAccess.file_exists(_save_path + ".tmp"), "atomic save leaves no .tmp file")
	_check(FileAccess.file_exists(_backup_path), "backup file exists after save_game")

	_store.call("set_storage_path", _save_path, _backup_path)
	_check(int(_store.call("get_coins", "tr")) == 125, "coins survive reload")
	_check(bool(_store.call("is_completed", "tr", "tr_kitchen_tea_time")), "completion survives reload")
	_check(str(_store.call("get_setting", "language", "")) == "en", "language setting survives reload")
	_check(not bool(_store.call("is_sound_enabled")), "sound setting survives reload")
	_store.call("set_setting", "language", "tr")
	_store.call("set_setting", "sound", true)
	_store.call("reset_progress", "tr")
	_store.call("reset_progress", "en")


func _test_session() -> void:
	_store.call("reset_progress", "tr")
	var level: Dictionary = _content.call("get_level", "tr", "tr_kitchen_tea_time")
	var session: GameSession = GameSession.new(_store, _content)
	_check(session.start(level, "tr"), "session starts from a Content level")
	_check(session.words == ["ÇAY", "KAŞIK", "OYUN", "HAVA"], "session copies words")
	_check(int(session.current_word_index) == 1, "gameplay starts on word 1 (word 0 is given)")
	_check(session.current == "KAŞIK", "current is the active word")
	_check(session.current_mask == "K____", "active word shows only its first letter")
	_check(session.mask == "ÇAY K____ ____ ____", "solved word is visible, future words stay hidden")
	_check(session.is_word_solved(0), "word 0 is solved at start")
	_check(session.solved_word_count == 1, "exactly one word is solved at start")
	for i: int in range(session.word_length(0)):
		_check(session.letter_at(0, i) == session.words[0].substr(i, 1), "word 0 letter %d is revealed at start" % i)
		_check(session.is_locked(0, i), "word 0 letter %d is locked at start" % i)
	_check(session.is_locked(1, 0) and session.letter_at(1, 0) == "K", "active first letter is pre-revealed and locked")
	for i: int in range(1, session.word_length(1)):
		_check(session.letter_at(1, i) == "" and not session.is_locked(1, i), "active word letter %d starts empty and editable" % i)
	for w: int in [2, 3]:
		var state: Dictionary = session.get_word_state(w)
		_check(str(state.get("state", "")) == "future", "word %d snapshot is future" % w)
		_check(str(state.get("mask", "")) == "_".repeat(session.word_length(w)), "future word %d mask is fully hidden" % w)
		_check(not bool(state.get("first_revealed", true)), "future word %d first letter is hidden" % w)
	_check(str(session.get_word_state(0).get("state", "")) == "solved", "word 0 snapshot is solved")
	_check(str(session.get_word_state(1).get("state", "")) == "active", "word 1 snapshot is active")
	_check(session.coins == 100, "session reads coins from SaveStore")
	_check(not session.can_submit(), "an empty active word cannot be submitted")
	_check(not session.is_chain_completed(), "victory is not reported at start")
	_check(not session.won, "session is not won at start")

	# Typing is confined to the active word.
	_check(session.type_letter("a"), "typing accepts lowercase Turkish input")
	_check(session.letter_at(1, 1) == "A", "typed letter lands in the active word")
	_check(session.letter_at(0, 1) == "A", "solved word content is unchanged by typing")
	session.clear_input()
	_check(session.current_mask == "K____", "clear_input keeps the fixed first letter")
	_check(session.letter_at(0, 0) == "Ç", "clear_input never clears the solved word")
	_type_active_word(session)
	_check(session.current_mask == "KAŞIK", "active word can be filled")
	_check(not session.type_letter("A"), "typing stops at the end of the active word")
	for i: int in range(session.word_length(2)):
		_check(session.letter_at(2, i) == "", "typing never leaks into future word 2 (%d)" % i)

	# Backspace only touches active typed letters.
	_check(session.backspace(), "backspace removes the last typed letter")
	_check(session.current_mask == "KAŞI_", "backspace updates the active mask")
	for _i: int in range(3):
		session.backspace()
	_check(session.current_mask == "K____", "backspace clears all typed letters")
	_check(not session.backspace(), "backspace cannot erase the fixed first letter")
	_check(session.letter_at(1, 0) == "K", "fixed first letter survives backspace")
	_check(session.letter_at(0, 1) == "A", "backspace never reaches the solved word")

	# Incomplete and wrong submits change nothing.
	var blocked: Array = []
	var rejected: Array = []
	session.submit_blocked.connect(func(reason: String) -> void: blocked.append(reason))
	session.answer_rejected.connect(func(answer: String) -> void: rejected.append(answer))
	_check(not session.submit(), "incomplete active word cannot be submitted")
	_check(blocked == ["incomplete"], "incomplete submit reports its reason")
	_check(int(session.current_word_index) == 1, "incomplete submit does not advance")
	_check(session.is_word_solved(0), "incomplete submit keeps the solved word")

	_type_active_word(session, true)
	_check(not session.submit(), "wrong active word is rejected")
	_check(session.wrong_attempts == 1, "wrong submit increments attempts")
	_check(rejected.size() == 1 and str(rejected[0]) == session.typed_word(1), "rejected answer is the typed word")
	_check(int(session.current_word_index) == 1, "wrong submit does not advance")
	_check(not session.is_word_solved(1), "wrong submit does not lock the word")
	_check(session.letter_at(0, 0) == "Ç", "wrong submit does not alter the solved word")

	# Correct submit locks the word and activates the next one.
	session.backspace()
	_check(session.type_letter("K"), "correct letter can be typed after the rejection")
	var solved_events: Array = []
	session.word_solved.connect(func(index: int) -> void: solved_events.append(index))
	_check(session.submit(), "correct active word submits")
	_check(solved_events == [1], "word_solved reports the verified word")
	_check(session.is_word_solved(1), "verified word is solved")
	for i: int in range(session.word_length(1)):
		_check(session.is_locked(1, i), "verified word letter %d is locked" % i)
	_check(int(session.current_word_index) == 2, "next word becomes active after a correct submit")
	_check(session.current == "OYUN", "current advances to word 2")
	_check(session.current_mask == "O___", "next active word shows only its first letter")
	_check(session.mask == "ÇAY KAŞIK O___ ____", "solved cards stay visible after advancing")
	_check(not session.backspace(), "backspace cannot cross into the previous solved word")
	_check(session.current_mask == "O___", "previous solved word and new first letter are intact")

	session.type_letter("Y")
	session.clear_input()
	_check(session.current_mask == "O___", "clear_input only clears the new active word")

	# Victory requires every word to be verified.
	var completions: Array = []
	var wins: Array = []
	session.chain_completed.connect(func() -> void: completions.append(true))
	session.level_won.connect(func(awarded: int, first: bool, total: int) -> void: wins.append([awarded, first, total]))
	_type_active_word(session)
	_check(session.can_submit(), "fully typed active word can be submitted")
	_check(completions.is_empty(), "typing a full mask does not complete the chain")
	_check(session.submit(), "word 2 submits")
	_check(int(session.current_word_index) == 3, "word 3 becomes active")
	_check(session.current_mask == "H___", "last word shows its first letter only")
	_type_active_word(session)
	_check(completions.is_empty(), "full final mask before submit does not complete the chain")
	_check(session.submit(), "final word submits")
	_check(session.won, "session is won after the final verification")
	_check(session.is_chain_completed(), "is_chain_completed is true at victory")
	_check(session.chain_complete, "chain_complete mirrors victory")
	_check(completions.size() == 1, "chain_completed fires exactly once, at victory")
	_check(session.first_clear, "first clear is true")
	_check(session.coins_awarded == 25, "session awards 25 on first clear")
	_check(session.save_error.is_empty(), "saved victory has no save_error")
	_check(session.coins == 125, "session coins are 100 + 25")
	_check(wins.size() == 1 and int(wins[0][0]) == 25, "level_won reports the reward")
	_check(int(_store.call("get_coins", "tr")) == 125, "session persisted coins")
	_check(session.mask == "ÇAY KAŞIK OYUN HAVA", "all cards are revealed at victory")
	_check(int(session.current_word_index) == -1, "no word is active after victory")
	_check(session.current == "", "no current word after victory")

	# Replay must not farm coins.
	var replay: GameSession = GameSession.new(_store, _content)
	_check(replay.start(level, "tr"), "replay starts")
	_check(int(replay.current_word_index) == 1, "replay starts on word 1")
	_check(not replay.first_clear, "replay knows the level was completed")
	_check(_solve_all(replay), "replay can be solved word by word")
	_check(not replay.first_clear, "replay is not first clear")
	_check(replay.coins_awarded == 0, "replay awards zero")
	_check(replay.coins == 125, "replay does not change coins")

	# Hint: active word only, once per word, 10 coins.
	_store.call("reset_progress", "tr")
	var hint_level: Dictionary = _content.call("get_level", "tr", "tr_kitchen_lemon_water")
	var hint_session: GameSession = GameSession.new(_store, _content)
	_check(hint_session.start(hint_level, "tr"), "hint session starts")
	var hint_events: Array = []
	hint_session.hint_bought.connect(func(index: int, text: String, coins: int) -> void: hint_events.append([index, text, coins]))
	_check(hint_session.buy_hint(), "hint purchase succeeds")
	_check(hint_session.coins == 90, "hint costs 10 coins")
	_check(hint_session.get_active_hint() == str(hint_level["hints"][1]), "hint text is the active word's hint")
	_check(hint_events.size() == 1 and int(hint_events[0][0]) == 1, "hint_bought reports the active word")
	_check(not hint_session.buy_hint(), "second hint for the same word is inapplicable")
	_check(hint_session.coins == 90, "inapplicable hint does not charge")

	# Reveal: one random still-hidden non-initial letter of the active word.
	var before_reveal: int = hint_session.coins
	var revealed: Array = []
	hint_session.letters_revealed.connect(func(count: int, coins: int) -> void: revealed.append([count, coins]))
	_check(hint_session.buy_letter(), "reveal succeeds on the active word")
	_check(hint_session.coins == before_reveal - 15, "reveal costs 15 coins")
	_check(hint_session.letter_at(1, 1) == "U" and hint_session.is_locked(1, 1), "reveal fills and locks a non-initial letter")
	_check(hint_session.letter_at(1, 0) == "S", "reveal leaves the initial letter alone")
	_check(revealed.size() == 1 and int(revealed[0][0]) == 1, "letters_revealed reports one letter")
	_check(hint_session.letter_at(0, 0) == "L", "reveal never touches the solved word")
	_check(not hint_session.backspace(), "backspace cannot erase a bought letter")
	_check(hint_session.current_mask == "SU", "bought letters stay locked")
	_check(not hint_session.buy_letter(), "reveal is inapplicable when the active word is full")
	_check(hint_session.coins == before_reveal - 15, "inapplicable reveal does not charge")

	# Reveal picks among several hidden letters, one at a time, never the initial.
	_store.call("reset_progress", "tr")
	var reveal_session: GameSession = GameSession.new(_store, _content)
	_check(reveal_session.start(level, "tr"), "reveal session starts")
	var reveal_count: int = 0
	while reveal_session.buy_letter():
		reveal_count += 1
		var locked_offsets: int = 0
		for offset: int in range(reveal_session.word_length(1)):
			if reveal_session.is_locked(1, offset):
				locked_offsets += 1
		_check(locked_offsets == 1 + reveal_count, "each reveal locks exactly one additional letter")
		for i: int in range(reveal_session.word_length(2)):
			_check(reveal_session.letter_at(2, i) == "", "reveal never exposes future word 2")
	_check(reveal_count == 4, "every hidden non-initial letter can be revealed once")
	_check(reveal_session.coins == 100 - 15 * 4, "reveals are charged one by one")
	_check(reveal_session.current_mask == "KAŞIK", "revealing all hidden letters fills the active word")
	_check(not reveal_session.buy_letter(), "reveal is inapplicable after exhausting the active word")
	_check(reveal_session.coins == 100 - 15 * 4, "exhausted reveal does not charge")

	# Atomic failure when broke.
	_store.call("reset_progress", "tr")
	_store.call("spend_coins", "tr", 95)
	var poor_level: Dictionary = _content.call("get_level", "tr", "tr_daily_book_cover")
	var poor: GameSession = GameSession.new(_store, _content)
	_check(poor.start(poor_level, "tr"), "broke session starts")
	_check(poor.coins == 5, "broke session sees 5 coins")
	_check(not poor.buy_hint(), "hint fails when broke")
	_check(not poor.buy_letter(), "reveal fails when broke")
	_check(poor.coins == 5, "failed purchases do not charge")

	# Presentation-normalized level shape (GardenApi.normalize_level output).
	var normalized: Dictionary = {
		"id": "tr_kitchen_tea_time",
		"category": "kitchen",
		"words": [],
		"raw": level,
	}
	for word_value: Variant in level["words"]:
		(normalized["words"] as Array).append({"word": word_value, "hint": "", "link": ""})
	var normalized_session: GameSession = GameSession.new(_store, _content)
	_check(normalized_session.start(normalized, "tr"), "session starts from a presentation-normalized level")
	_check(normalized_session.words == level["words"], "normalized level keeps the original words")
	_check(normalized_session.hints == level["hints"], "normalized level keeps the original hints")
	_check(normalized_session.links == level["links"], "normalized level keeps the original links")
	_check(normalized_session.current_mask == "K____", "normalized level starts on the active word")

	# Normalized entries without a raw copy still supply per-entry hints.
	var entry_only: Dictionary = {
		"id": "tr_entry_only",
		"words": [
			{"word": "KİTAP", "hint": "Ciltli sayfalar bütünü"},
			{"word": "KAPAK", "hint": "Kitabın ön yüzü"},
		],
	}
	var entry_session: GameSession = GameSession.new(_store, _content)
	_check(entry_session.start(entry_only, "tr"), "session starts from normalized entries only")
	_check(entry_session.words == ["KİTAP", "KAPAK"], "entry-only words are extracted")
	_check(entry_session.hints == ["Ciltli sayfalar bütünü", "Kitabın ön yüzü"], "entry-only hints are extracted")
	_check(entry_session.links.size() == 1, "entry-only levels still expose one link slot per pair")
	_check(entry_session.is_word_solved(0) and entry_session.current_mask == "K____", "entry-only level uses the per-word start state")
	_store.call("reset_progress", "tr")


func _type_active_word(session: GameSession, spoil_last: bool = false) -> bool:
	var index: int = session.current_word_index
	if index < 0:
		return false
	var word: String = session.words[index]
	for letter_index: int in range(word.length()):
		if session.is_locked(index, letter_index):
			continue
		var letter: String = word.substr(letter_index, 1)
		if spoil_last and letter_index == word.length() - 1:
			letter = _different_letter(letter)
		if not session.type_letter(letter):
			return false
	return true


func _solve_all(session: GameSession) -> bool:
	var guard: int = 0
	while not session.won and session.current_word_index >= 0 and guard < 64:
		guard += 1
		if not _type_active_word(session):
			return false
		if not session.submit():
			return false
	return session.won


func _different_letter(expected: String) -> String:
	for i: int in range(GameSession.TR_ALPHABET.length()):
		var candidate: String = GameSession.TR_ALPHABET.substr(i, 1)
		if candidate != expected:
			return candidate
	return "A"


func _test_persistence_reload() -> void:
	_store.call("set_storage_path", _save_path, _backup_path)
	_store.call("reset_progress", "tr")
	_store.call("mark_level_completed", "tr", "tr_kitchen_tea_time")
	_store.call("set_storage_path", _save_path, _backup_path)
	_check(bool(_store.call("is_completed", "tr", "tr_kitchen_tea_time")), "session win is persisted")
	_check(int(_store.call("get_coins", "tr")) == 125, "persisted completion keeps its reward")
	_store.call("reset_progress", "tr")


func _test_recovery() -> void:
	var recovery_dir: String = "user://test_core_recovery_%d" % Time.get_ticks_usec()
	var recovery_path: String = recovery_dir + "/save.json"
	var recovery_backup: String = recovery_path + ".bak"
	_store.call("set_storage_path", recovery_path, recovery_backup)
	_store.call("reset_progress", "tr")
	_store.call("add_coins", "tr", 50)
	_store.call("save_game")
	_store.call("reset_progress", "tr")
	_check(int(_store.call("get_coins", "tr")) == 100, "recovery fixture at 100")

	# Corrupt main + good backup: recover, keep the good backup on disk.
	_write_text(recovery_path, "{ not valid json")
	_store.call("set_storage_path", recovery_path, recovery_backup)
	_check(int(_store.call("get_coins", "tr")) == 150, "corrupt main recovers from backup")
	_check(str(_store.get("last_error")) == "backup_recovered", "backup recovery is reported")
	_check(FileAccess.file_exists(recovery_backup), "recovery keeps the good backup file")
	_check(FileAccess.file_exists(recovery_path), "recovery writes a new main file")

	# Missing main + good backup: recover without destroying the only copy.
	_delete(recovery_path)
	_store.call("set_storage_path", recovery_path, recovery_backup)
	_check(int(_store.call("get_coins", "tr")) == 150, "missing main recovers from backup")
	_check(FileAccess.file_exists(recovery_backup), "missing main keeps the backup until a new write commits")
	_check(FileAccess.file_exists(recovery_path), "missing main is recreated")

	# Corrupt main + corrupt backup: defaults, but never delete the .bak file.
	_write_text(recovery_path, "broken")
	_write_text(recovery_backup, "also broken")
	_store.call("set_storage_path", recovery_path, recovery_backup)
	_check(int(_store.call("get_coins", "tr")) == 100, "corrupt save+backup resets to defaults")
	_check(str(_store.get("last_error")) == "reset_after_corruption", "corrupt reset is reported")
	_check(FileAccess.file_exists(recovery_backup), "corrupt pair keeps the backup file for inspection")

	_delete(recovery_path)
	_delete(recovery_backup)
	_delete(recovery_path + ".tmp")
	_delete(recovery_path + ".corrupt")
	_delete(recovery_backup + ".tmp")
	_delete_dir(recovery_dir)


func _test_save_failures() -> void:
	# A file used as a parent directory makes every write fail on any platform.
	var blocker: String = "user://test_core_block_%d" % Time.get_ticks_usec()
	_write_text(blocker, "not a directory")
	var bad_main: String = blocker + "/save.json"
	var bad_backup: String = blocker + "/save.json.bak"
	_store.call("set_storage_path", bad_main, bad_backup)
	_check(int(_store.call("get_coins", "tr")) == 100, "unwritable path falls back to defaults")

	_check(not bool(_store.call("spend_coins", "tr", 10)), "spend fails when the save cannot be written")
	_check(int(_store.call("get_coins", "tr")) == 100, "failed spend keeps the in-memory balance")
	_check(not str(_store.get("last_error")).is_empty(), "failed spend sets last_error")

	var result: Dictionary = _store.call("mark_level_completed", "tr", "tr_kitchen_tea_time")
	_check(not bool(result.get("success", true)), "completion reports failure when the save fails")
	_check(int(result.get("coins_awarded", -1)) == 0, "failed completion awards nothing")
	_check(str(result.get("error", "")) == "save_failed", "failed completion reports save_failed")
	_check(not bool(_store.call("is_completed", "tr", "tr_kitchen_tea_time")), "failed completion is not recorded in memory")
	_check(int(_store.call("get_coins", "tr")) == 100, "failed completion leaves the balance")
	_check(not FileAccess.file_exists(bad_main), "no main file is created in an unwritable path")

	# The session must not announce a reward that could not be persisted.
	var level: Dictionary = _content.call("get_level", "tr", "tr_kitchen_tea_time")
	var session: GameSession = GameSession.new(_store, _content)
	_check(session.start(level, "tr"), "session starts on an unwritable save path")
	_check(not session.buy_hint(), "purchase fails when coins cannot be saved")
	_check(session.coins == 100, "failed purchase does not change session coins")
	_check(_solve_all(session), "player can still finish the puzzle")
	_check(session.won, "session reports the puzzle as solved")
	_check(not session.first_clear, "unsaved completion is not reported as first clear")
	_check(session.coins_awarded == 0, "unsaved completion awards no coins")
	_check(session.save_error == "save_failed", "unsaved completion sets save_error")
	_check(session.coins == 100, "unsaved completion leaves session coins")
	_check(int(_store.call("get_coins", "tr")) == 100, "store balance unchanged after an unsaved win")

	_delete(blocker)
	_store.call("set_storage_path", _save_path, _backup_path)


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _delete_dir(path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs_path):
		DirAccess.remove_absolute(abs_path)


func _cleanup() -> void:
	_delete(_save_path)
	_delete(_backup_path)
	_delete(_save_path + ".tmp")
	_delete(_save_path + ".corrupt")
	_delete(_backup_path + ".tmp")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[core] PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[core] FAIL: " + message)
	print("[core] FAIL: ", message)


func _frames(count: int) -> void:
	for i: int in range(count):
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("[core] RESULT: PASS (%d checks)" % _checks)
		quit(0)
	else:
		print("[core] RESULT: FAIL (%d checks, %d failures)" % [_checks, _failures.size()])
		for failure: String in _failures:
			print("[core]   - ", failure)
		quit(1)
