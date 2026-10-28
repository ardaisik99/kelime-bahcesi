extends SceneTree

## End-to-end UI smoke test for the real main scene.
##
## Run:
##   Godot_v4.5.2-stable_win64_console.exe --headless --path . \
##       --script tests/test_ui.gd
##
## Optional screenshots (needs a real display, never headless):
##   Godot_v4.5.2-stable_win64_console.exe --path . \
##       --script tests/test_ui.gd -- --screenshots=C:\temp\tamlama-shots
##
## The harness never edits the production save:
##   * SaveStore.set_storage_path() points the autoload at a unique
##     user://test_ui_*.json file;
##   * both language progresses are reset inside that test file;
##   * user://garden_ui.json (UI-only preferences) is snapshotted/restored.
##
## It drives the shipped UI: home cards, category level cards, party mode,
## settings, the topbar TR/EN toggle, the on-screen keyboard, hint/reveal
## buttons and the victory screen. Navigation happens through real
## Button.pressed signals (matching visible labels in both languages), not by
## calling screen internals. Screen state is only *read* for assertions.
##
## Missing scene/dependency/content is a FAILURE (exit 1), never a silent pass.

const TOTAL_BUDGET_MS := 120000
const HOME_TIMEOUT_MS := 15000
const PLAY_TIMEOUT_MS := 8000
const HINT_COST := 10
const REVEAL_COST := 15
const FIRST_CLEAR_REWARD := 25
const START_COINS := 100

const REQUIRED_AUTOLOADS := [
	["SaveStore", "res://core/save_store.gd"],
	["I18n", "res://core/i18n.gd"],
	["Content", "res://core/content.gd"],
	["AudioManager", "res://core/audio_manager.gd"],
	["NetworkClient", "res://core/network_client.gd"],
]

var _deadline_ms := 0
var _failures: Array[String] = []
var _checks := 0
var _main: Node = null
var _store: Node = null
var _content: Node = null
var _i18n: Node = null
var _save_path := ""
var _save_backup_path := ""
var _save_prepared := false
var _ui_prefs_path := "user://garden_ui.json"
var _ui_prefs_backup := ""
var _ui_prefs_existed := false
var _ui_prefs_snapshotted := false
var _screenshot_dir := ""
var _shots_taken: Array[String] = []


func _initialize() -> void:
	# --script does not inherit the normal game window dimensions headlessly.
	root.size = Vector2i(480, 900)
	root.content_scale_size = Vector2i(480, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	_deadline_ms = Time.get_ticks_msec() + TOTAL_BUDGET_MS
	_parse_screenshot_arg()
	call_deferred("_run")


func _run() -> void:
	print("[ui] starting end-to-end UI test")
	if not await _ensure_autoloads():
		_finish()
		return
	_store = root.get_node_or_null("SaveStore")
	_content = root.get_node_or_null("Content")
	_i18n = root.get_node_or_null("I18n")
	if _store == null or _content == null or _i18n == null:
		_fail("required autoloads are unavailable (SaveStore/I18n/Content)")
		_finish()
		return
	await _frames(2)
	if not _content_ready():
		_fail("bilingual Content data did not load: %s" % str(_content_errors()))
		_finish()
		return
	var prepared := await _prepare_isolated_save()
	if not prepared:
		await _cleanup_isolated_save()
		_finish()
		return

	var started := await _load_main_scene()
	if started:
		await _run_journeys()
	await _cleanup_isolated_save()
	_finish()


func _run_journeys() -> void:
	await _test_home()
	if _deadline_expired():
		_fail("test time budget exhausted after the home screen")
		return
	await _test_categories()
	if _deadline_expired():
		_fail("test time budget exhausted after categories")
		return
	await _test_party()
	if _deadline_expired():
		_fail("test time budget exhausted after party mode")
		return
	await _test_settings_and_language()
	if _deadline_expired():
		_fail("test time budget exhausted after settings")
		return
	await _test_full_chain_and_economy()


# ---------------------------------------------------------------------------
# Scene boot
# ---------------------------------------------------------------------------

func _load_main_scene() -> bool:
	var scene_path := str(ProjectSettings.get_setting("application/run/main_scene", "res://scenes/main.tscn"))
	if not ResourceLoader.exists(scene_path):
		_fail("main scene is missing: %s" % scene_path)
		return false
	var packed: Resource = load(scene_path)
	if not (packed is PackedScene):
		_fail("could not load a PackedScene from %s" % scene_path)
		return false
	_main = (packed as PackedScene).instantiate()
	if _main == null:
		_fail("main scene instantiation returned null")
		return false
	root.add_child(_main)
	var booted := await _wait_condition(func() -> bool:
		return _home_visible(), "home screen boot", HOME_TIMEOUT_MS)
	if not booted:
		if _failures.is_empty():
			_fail("home screen did not become visible")
		return false
	await _settle(0.35)
	print("[ui] main scene booted: ", scene_path)
	return true


# ---------------------------------------------------------------------------
# Journey tests
# ---------------------------------------------------------------------------

func _test_home() -> void:
	print("[ui] home")
	_check(root.get_visible_rect().size == Vector2(480, 900), "tests use a real 480 x 900 portrait viewport")
	_check(_has_visible_text([_brand_tr()]), "home shows the brand")
	_check(_find_button(["parti", "party"]) != null, "home exposes the party mode")
	_check(_find_button(["ayarlar", "settings"]) != null, "home exposes settings")
	var continue_button := _find_continue_button()
	_check(continue_button != null, "home exposes the continue/play card")
	var category_ids := _content_category_ids(_lang())
	_check(not category_ids.is_empty(), "Content exposes at least one category")
	_check(_find_category_button(category_ids) != null, "home exposes category cards")
	for id in category_ids:
		var card := _find_category_button([id])
		_check(card != null and card.size.x >= 120.0, "category %s has a readable width" % id)
		if card != null:
			_check(_button_label_texts(card).has(_norm(GardenLoc.category_name(id, _lang()))), "category %s uses its translated display name" % id)
	_check(_coins() == START_COINS, "fresh test save starts with %d coins (got %d)" % [START_COINS, _coins()])
	_check(_has_visible_text([str(START_COINS)]), "topbar shows the coin balance")
	await _shot("home")
	_check_no_horizontal_overflow("home")


func _test_categories() -> void:
	print("[ui] categories")
	if not await _go_home():
		return
	var category_ids := _content_category_ids(_lang())
	var category_button := _find_category_button(category_ids)
	if category_button == null:
		_fail("could not find a category card on home")
		return
	var category_id := _category_id_for_button(category_button, category_ids)
	await _press(category_button, "category card")
	await _settle(0.35)
	_check(_has_visible_text(["kategoriler", "categories"]), "category screen opened")
	var expected_levels := _levels_for_category(_lang(), category_id)
	var level_cards := _level_card_buttons()
	_check(level_cards.size() == expected_levels.size(),
		"category screen lists %d level cards (got %d)" % [expected_levels.size(), level_cards.size()])
	_check(_has_visible_text(["kelime", "word"]), "level cards show word metadata")
	_check_no_horizontal_overflow("category")

	# Enter the first (unlocked) level and come back through the topbar.
	if not level_cards.is_empty() and not expected_levels.is_empty():
		var expected_id := str((expected_levels[0] as Dictionary).get("id", ""))
		await _press(level_cards[0], "first level card")
		var play := await _wait_play_screen(PLAY_TIMEOUT_MS)
		if play == null:
			_fail("level card did not open the play screen")
		else:
			var level: Dictionary = play.get("_level")
			_check(str(level.get("id", "")) == expected_id,
				"level card opened '%s' (got '%s')" % [expected_id, str(level.get("id", ""))])
			await _back_one()
	else:
		_fail("category screen exposes no unlocked level card")
	await _back_one()
	_check(await _home_visible(), "back from categories returns home")


func _test_party() -> void:
	print("[ui] party")
	if not await _go_home():
		return
	var party_button := _find_button(["parti", "party"])
	if party_button == null:
		_fail("could not find the party mode")
		return
	await _press(party_button, "party mode")
	var play := await _wait_play_screen(PLAY_TIMEOUT_MS)
	if play == null:
		_fail("party mode did not open a play screen")
		await _back_one()
		return
	await _settle(0.4)
	var mode := str(play.get("_mode"))
	var words: Array = play.get("_words")
	_check(mode == "party",
		"party route starts the party mode (got '%s'; open_party() must pass {\"mode\":\"party\"})" % mode)
	_check(not words.is_empty(), "party mode has a playable chain (%d words)" % words.size())
	_check(not _has_visible_keyboard(), "party is a reveal-all mode, without a guessing keyboard")
	for entry in words:
		_check(_has_visible_text([str(entry.get("word", ""))]), "party reveals word %s" % entry.get("word", ""))
	var old_id := str((play.get("_level") as Dictionary).get("id", ""))
	var party_coins := _coins()
	await _press(_find_button([GardenLoc.t("party_next", _lang())]), "new party chain")
	_check(str((play.get("_level") as Dictionary).get("id", "")) != old_id, "party avoids an immediate repeat")
	var chain: Node = play.get("_chain_view")
	var next_id := str((play.get("_level") as Dictionary).get("id", ""))
	chain.emit_signal("card_tapped", 0)
	await _frames(3)
	_check(str((play.get("_level") as Dictionary).get("id", "")) != next_id, "tapping a party card advances the chain")
	var before_blank := str((play.get("_level") as Dictionary).get("id", ""))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = play.get_global_rect().get_center()
	play.call("_input", click)
	await _frames(2)
	_check(str((play.get("_level") as Dictionary).get("id", "")) != before_blank, "tapping the party background also advances the chain")
	_check(_coins() == party_coins, "party neither spends nor farms coins")
	_check(_has_visible_text(["parti", "party"]), "party screen shows its title")
	_check(_has_visible_text(["zincir", "chain", "ifade", "expression", "rahat", "relaxed"]),
		"party screen shows expression/relaxed copy")
	await _shot("party")
	_check_no_horizontal_overflow("party")
	await _back_one()
	_check(await _home_visible(), "back from party returns home")


func _test_settings_and_language() -> void:
	print("[ui] settings + language")
	if not await _go_home():
		return
	var settings_button := _find_button(["ayarlar", "settings"])
	if settings_button == null:
		_fail("could not find settings")
		return
	await _press(settings_button, "settings")
	await _settle(0.35)
	_check(_has_visible_text(["ayarlar", "settings"]), "settings screen opened")
	_check(_has_visible_text(["dil", "language"]), "settings screen exposes the language selector")
	await _press(_find_button([GardenLoc.t("licenses", "tr")], true), "licenses")
	var license_texts := 0
	for node in _all_nodes():
		if node is TextEdit and (node as TextEdit).text.length() > 1000:
			license_texts += 1
	_check(license_texts == 2, "Godot and third-party licenses are readable inside the app")
	await _back_one()

	var en_button := _find_topbar_language("EN")
	if en_button == null:
		_fail("could not find the topbar EN language button")
		return
	await _press(en_button, "EN language")
	var switched := await _wait_condition(func() -> bool: return _lang() == "en", "language en", 5000)
	_check(switched, "language toggles to English")
	_check(_has_visible_text(["settings"]), "settings labels are English")
	_check(_has_visible_text(["language"]), "settings language label is English")

	if not await _go_home():
		return
	_check(_lang() == "en", "SaveStore language is English")
	_check(_has_visible_text(["word garden"]), "home brand is English")
	_check(_has_visible_text(["pick up where you left off", "continue", "complete"]),
		"home continue copy is English")
	await _shot("en")
	await _press(_find_continue_button(), "English level")
	var english_play := await _wait_play_screen(PLAY_TIMEOUT_MS)
	if english_play != null:
		_check(_keyboard_letters().length() == 26 and _keyboard_letters().contains("I") and not _keyboard_letters().contains("İ"), "English keyboard has 26 standard letters, not Turkish İ")
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = 105
		english_play.call("_unhandled_key_input", event)
		var english_session: Variant = english_play.get("_session")
		_check(str(english_session.letter_at(1, 1)) == "I", "physical lowercase i becomes I in English")
		await _back_one()
		await _go_home()

	var tr_button := _find_topbar_language("TR")
	if tr_button == null:
		_fail("could not find the topbar TR language button")
		return
	await _press(tr_button, "TR language")
	var switched_back := await _wait_condition(func() -> bool: return _lang() == "tr", "language tr", 5000)
	_check(switched_back, "language toggles back to Turkish")
	_check(_has_visible_text([_brand_tr()]), "home brand is Turkish again")
	await _go_home()


func _test_full_chain_and_economy() -> bool:
	print("[ui] play + full chain")
	if not await _go_home():
		return false
	var play_button := _find_continue_button()
	if play_button == null:
		_fail("could not find the continue/play button")
		return false
	await _press(play_button, "continue/play")
	var play := await _wait_play_screen(PLAY_TIMEOUT_MS)
	if play == null:
		_fail("play screen did not open")
		return false
	await _settle(0.5)

	var words: Array = play.get("_words")
	var level: Dictionary = play.get("_level")
	var level_id := str(level.get("id", ""))
	_check(not level_id.is_empty(), "play session has a level id")
	_check(words.size() >= 2, "level '%s' has a playable chain (%d words)" % [level_id, words.size()])
	_check(_has_visible_keyboard(), "play screen shows the on-screen keyboard")
	var session: Variant = play.get("_session")
	_check(session != null and int(session.current_word_index) == 1, "the first hidden word, not the given word, is active")
	_check(str(session.typed_word(0)) == str(words[0].get("word", "")), "the first word is fully given")
	_check(bool(session.is_locked(1, 0)), "the active word's initial letter is fixed")
	_check(_keyboard_letters() == "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ", "Turkish keyboard includes all 29 letters including I and İ")
	await _submit_keyboard()
	_check(int(session.current_word_index) == 1, "incomplete submit does not advance")
	var wrong := ""
	for i in range(1, int(session.word_length(1))):
		wrong += "Z"
	await _type_word(wrong)
	await _submit_keyboard()
	_check(int(session.current_word_index) == 1 and int(session.wrong_attempts) == 1, "wrong word is rejected without advancing")
	while session.backspace():
		pass
	await _shot("play")
	_check_no_horizontal_overflow("play")

	var coins_start := _coins()
	_check(coins_start == START_COINS, "fresh save starts with %d coins (got %d)" % [START_COINS, coins_start])

	# ---- hint ------------------------------------------------------------
	var hint_button := _find_button(["ipucu", "hint"])
	if hint_button == null:
		_fail("could not find the hint button")
		return false
	await _press(hint_button, "hint")
	await _settle(0.3)
	var coins_after_hint := _coins()
	_check(coins_after_hint == coins_start - HINT_COST,
		"hint costs %d coins (%d -> %d)" % [HINT_COST, coins_start, coins_after_hint])
	var hint_text := str(play.get("_hint_text"))
	_check(not hint_text.is_empty(), "hint is unlocked for the active word")
	_check(_has_visible_text([hint_text]), "the unlocked hint is visible in the chain view")

	# ---- reveal ----------------------------------------------------------
	var reveal_button := _find_button(["harf", "letter", "reveal"])
	if reveal_button == null:
		_fail("could not find the reveal button")
		return false
	await _press(reveal_button, "reveal")
	await _settle(0.3)
	var coins_after_reveal := _coins()
	_check(coins_after_reveal == coins_after_hint - REVEAL_COST,
		"reveal costs %d coins (%d -> %d)" % [REVEAL_COST, coins_after_hint, coins_after_reveal])
	var first_revealed := int(play.get("_revealed"))
	_check(first_revealed == 2, "reveal exposes exactly one extra letter (%d shown)" % first_revealed)
	_check(str(session.get_word_state(2).get("mask", "")).replace("_", "").is_empty(), "a reveal never exposes future words")

	# ---- type the whole chain -------------------------------------------
	for i in range(1, words.size()):
		var active := await _wait_condition(func() -> bool:
			return int(play.get("_current")) == i and not bool(play.get("_busy")),
			"word %d active" % (i + 1), 6000)
		if not active:
			_fail("word %d/%d never became active" % [i + 1, words.size()])
			return false
		var entry: Dictionary = words[i]
		var expected := GardenApi.upper_tr(str(entry.get("word", "")))
		var typed := ""
		for letter_index in range(expected.length()):
			if not bool(session.is_locked(i, letter_index)):
				typed += expected.substr(letter_index, 1)
		if not typed.is_empty():
			if not await _type_word(typed):
				_fail("could not type word %d/%d (%s)" % [i + 1, words.size(), expected])
				return false
		await _submit_keyboard()
		var advanced := await _wait_condition(func() -> bool:
			return bool(play.get("_finished")) or int(play.get("_current")) > i,
			"word %d accepted" % (i + 1), 6000)
		if not advanced:
			_fail("word %d/%d was not accepted by the UI" % [i + 1, words.size()])
			return false
		if i == words.size() - 1:
			await _wait_condition(func() -> bool: return bool(play.get("_finished")),
				"victory screen", 6000)
			await _settle(0.4)
			var coins_end := _coins()
			var expected_end := coins_start - HINT_COST - REVEAL_COST + FIRST_CLEAR_REWARD
			_check(coins_end == expected_end,
				"first clear awards %d coins (%d -> %d)" % [FIRST_CLEAR_REWARD, coins_after_reveal, coins_end])
			_check(bool(_store.call("is_completed", _lang(), level_id)),
				"cleared level is persisted in SaveStore")
			_check(_has_visible_text([
					GardenLoc.t("victory_title", _lang()),
					GardenLoc.f("first_clear_reward", [FIRST_CLEAR_REWARD], _lang()),
					"%d" % FIRST_CLEAR_REWARD,
				]), "victory screen shows the first-clear reward")
			await _shot("play_win")

	_check(bool(play.get("_finished")), "the full chain is won")
	# Replay uses the same real scene/session and cannot duplicate its reward.
	var replay_balance := _coins()
	_main.call("play_level", level, {}, true)
	await _settle(0.3)
	play = _find_play_screen()
	session = play.get("_session")
	for i in range(1, words.size()):
		await _wait_condition(func() -> bool: return not bool(play.get("_busy")), "replay input", 3000)
		await _type_word(str(words[i].get("word", "")).substr(1))
		await _submit_keyboard()
	_check(bool(play.get("_finished")), "a completed level can be replayed")
	_check(_coins() == replay_balance, "replay awards zero extra coins")
	return true


func _keyboard_letters() -> String:
	var keyboard := _find_keyboard()
	if keyboard == null:
		return ""
	var nodes: Array = []
	_walk(keyboard, nodes)
	var letters: Array[String] = []
	for node in nodes:
		if node is Button and (node as Button).text.length() == 1:
			letters.append((node as Button).text)
	return "".join(letters)


# ---------------------------------------------------------------------------
# UI interaction helpers
# ---------------------------------------------------------------------------

func _all_nodes() -> Array:
	var out: Array = []
	if _main != null:
		_walk(_main, out)
	return out


func _walk(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_walk(child, out)


func _visible_nodes() -> Array:
	var out: Array = []
	for node in _all_nodes():
		if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
			continue
		out.append(node)
	return out


func _node_text(node: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	elif node is RichTextLabel:
		parts.append((node as RichTextLabel).get_parsed_text())
	elif node is LineEdit:
		parts.append((node as LineEdit).text)
		parts.append((node as LineEdit).placeholder_text)
	elif node is Button:
		parts.append((node as Button).text)
	elif node is OptionButton:
		parts.append((node as OptionButton).text)
	if "tooltip_text" in node:
		parts.append(str(node.get("tooltip_text")))
	parts.append(str(node.name))
	var text := " ".join(parts).strip_edges()
	return text


func _subtree_text(node: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	_collect_text(node, parts)
	return " ".join(parts)


func _collect_text(node: Node, parts: PackedStringArray) -> void:
	for child in node.get_children():
		if child is Label:
			parts.append((child as Label).text)
		elif child is RichTextLabel:
			parts.append((child as RichTextLabel).get_parsed_text())
		elif child is Button:
			parts.append((child as Button).text)
		elif child is LineEdit:
			parts.append((child as LineEdit).text)
		_collect_text(child, parts)


func _norm(text: String) -> String:
	return text.to_lower().replace("i̇", "i").replace("\n", " ").strip_edges()


func _find_button(needles: Array, exact: bool = false) -> Button:
	var best: Button = null
	var best_score := 999
	for node in _visible_nodes():
		if not (node is Button):
			continue
		var button := node as Button
		if button.disabled:
			continue
		var haystack := _norm(_subtree_text(button) + " " + _node_text(button))
		var own := _norm(button.text + " " + str(button.tooltip_text) + " " + str(button.name))
		for needle_v in needles:
			var needle := _norm(str(needle_v))
			if needle.is_empty():
				continue
			var score := 999
			if _norm(button.text) == needle or own == needle:
				score = 0
			elif _norm(button.text).begins_with(needle) or own.begins_with(needle):
				score = 1
			elif not exact and haystack.contains(needle):
				score = 2
			elif not exact and own.contains(needle):
				score = 3
			if score < best_score:
				best_score = score
				best = button
	return best


func _has_visible_text(needles: Array) -> bool:
	for node in _visible_nodes():
		if not (node is Label or node is RichTextLabel or node is Button):
			continue
		var haystack := _norm(_node_text(node) + " " + (_subtree_text(node) if node is Button else ""))
		for needle_v in needles:
			var needle := _norm(str(needle_v))
			if not needle.is_empty() and haystack.contains(needle):
				return true
	return false


func _find_category_button(category_ids: Array) -> Button:
	# A category card is a button that *labels itself* with the category id or
	# its localized name. Matching the whole subtree is too loose: the
	# "continue" card also mentions the next category ("Kitchen · ...").
	for node in _visible_nodes():
		if not (node is Button) or (node as Button).disabled:
			continue
		var labels := _button_label_texts(node as Button)
		for id_v in category_ids:
			for needle_v in _category_needles(str(id_v)):
				if labels.has(_norm(str(needle_v))):
					return node as Button
	return null


func _button_label_texts(button: Button) -> Array[String]:
	var out: Array[String] = []
	var stack: Array = [button]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			if child is Label:
				out.append(_norm((child as Label).text))
			elif child is Button:
				# Nested buttons own their own labels.
				continue
			stack.append(child)
	return out


func _category_needles(category_id: String) -> Array:
	var needles: Array = [category_id, category_id.replace("_", " ")]
	var localized := GardenLoc.category_name(category_id, "tr")
	if not localized.is_empty() and localized != "category." + category_id:
		needles.append(localized)
	localized = GardenLoc.category_name(category_id, "en")
	if not localized.is_empty() and localized != "category." + category_id:
		needles.append(localized)
	return needles


func _category_id_for_button(button: Button, category_ids: Array) -> String:
	var labels := _button_label_texts(button)
	for id_v in category_ids:
		var id := str(id_v)
		for needle_v in _category_needles(id):
			if labels.has(_norm(str(needle_v))):
				return id
	return str(category_ids[0]) if not category_ids.is_empty() else ""


func _level_card_buttons() -> Array:
	var out: Array = []
	for node in _visible_nodes():
		if not (node is Button) or (node as Button).disabled:
			continue
		# Level cards are the tall (82 px) rows; locked cards do not print the
		# word count, so text matching alone would miss them.
		if (node as Button).custom_minimum_size.y >= 80.0:
			out.append(node)
	return out


func _find_continue_button() -> Button:
	var needles := [
		GardenLoc.t("home_continue", "tr"),
		GardenLoc.t("home_continue", "en"),
		GardenLoc.t("all_done_title", "tr"),
		GardenLoc.t("all_done_title", "en"),
		"kaldığın yerden", "pick up where", "bahçen tamamlandı", "garden is complete",
	]
	for node in _visible_nodes():
		if not (node is Button) or (node as Button).disabled:
			continue
		var haystack := _norm(_subtree_text(node) + " " + _node_text(node))
		for needle_v in needles:
			var needle := _norm(str(needle_v))
			if not needle.is_empty() and haystack.contains(needle):
				return node as Button
	return null


func _find_keyboard() -> Node:
	for node in _visible_nodes():
		if node.has_signal("letter_pressed") and node.has_signal("backspace_pressed") \
			and node.has_signal("submit_pressed"):
			return node
	return null


func _has_visible_keyboard() -> bool:
	return _find_keyboard() != null


func _find_keyboard_key(letter: String) -> Button:
	var keyboard := _find_keyboard()
	if keyboard == null:
		return null
	var out: Array = []
	_walk(keyboard, out)
	for node in out:
		if node is Button and not (node as Button).disabled and (node as Button).text == letter:
			return node as Button
	for node in out:
		if node is Button and not (node as Button).disabled \
			and _norm((node as Button).text) == _norm(letter):
			return node as Button
	for node in out:
		if node is Button and not (node as Button).disabled \
			and _norm(str((node as Button).tooltip_text)) == _norm(letter):
			return node as Button
	return null


func _find_keyboard_action(labels: Array) -> Button:
	var keyboard := _find_keyboard()
	if keyboard == null:
		return null
	var out: Array = []
	_walk(keyboard, out)
	for node in out:
		if not (node is Button) or (node as Button).disabled:
			continue
		var text := _norm((node as Button).text)
		for label_v in labels:
			if text == _norm(str(label_v)):
				return node as Button
	for node in out:
		if not (node is Button) or (node as Button).disabled:
			continue
		var text := _norm((node as Button).text)
		for label_v in labels:
			var label := _norm(str(label_v))
			if not label.is_empty() and text.contains(label):
				return node as Button
	return null


func _type_word(text: String) -> bool:
	var keyboard := _find_keyboard()
	if keyboard == null:
		_fail("on-screen keyboard is unavailable")
		return false
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var key := _find_keyboard_key(ch)
		if key == null:
			_fail("keyboard has no key for '%s'" % ch)
			return false
		key.emit_signal("pressed")
		await _frames(1)
	await _settle(0.05)
	return true


func _submit_keyboard() -> void:
	var submit := _find_keyboard_action([
		GardenLoc.t("submit", "tr"),
		GardenLoc.t("submit", "en"),
		"tamam", "enter", "gönder", "submit", "kontrol", "check",
	])
	if submit != null:
		submit.emit_signal("pressed")
		await _settle(0.2)
		return
	var keyboard := _find_keyboard()
	if keyboard != null:
		keyboard.emit_signal("submit_pressed")
		await _settle(0.2)
		return
	_fail("could not find the keyboard submit button")


func _find_topbar_language(code: String) -> Button:
	for node in _visible_nodes():
		if not (node is Button) or (node as Button).disabled:
			continue
		var button := node as Button
		if _norm(button.text) != _norm(code):
			continue
		if button.get_global_rect().position.y < 140.0:
			return button
	return null


func _find_play_screen() -> Control:
	for node in _all_nodes():
		if not (node is Control):
			continue
		if "_words" in node and "_current" in node and "_revealed" in node and "_finished" in node:
			return node as Control
	return null


func _wait_play_screen(timeout_ms: int) -> Control:
	var local_deadline := mini(_deadline_ms, Time.get_ticks_msec() + timeout_ms)
	while Time.get_ticks_msec() < local_deadline:
		var found := _find_play_screen()
		if found != null:
			return found
		await _frames(1)
	var late := _find_play_screen()
	if late == null:
		print("[ui] timeout waiting for play screen")
	return late


func _press(button: Button, what: String) -> void:
	if button == null:
		_fail("cannot press null button (%s)" % what)
		return
	if button.disabled:
		_fail("button is disabled (%s)" % what)
		return
	button.emit_signal("pressed")
	await _settle(0.16)


func _back_one() -> void:
	var back := _find_button(["←"])
	if back == null:
		for node in _visible_nodes():
			if node is Button and _norm(str(node.name)).contains("back"):
				back = node as Button
				break
	if back == null:
		return
	await _press(back, "back")
	await _settle(0.2)
	if _modal_open():
		# Scope the search to the modal layer: the play screen also has a
		# "Tamam" submit key that must not be mistaken for the confirm button.
		var leave := _find_button_under(_modal_layer(), [
			GardenLoc.t("quit_confirm", "tr"),
			GardenLoc.t("quit_confirm", "en"),
			GardenLoc.t("online_leave", "tr"),
			GardenLoc.t("online_leave", "en"),
			"ayrıl", "leave",
		])
		if leave != null:
			await _press(leave, "leave confirmation")
			await _settle(0.2)


func _go_home() -> bool:
	if await _home_visible():
		return true
	for attempt in range(5):
		await _back_one()
		if await _home_visible():
			return true
	var home := _find_button(["ana sayfa", "home", "menüye dön", "back to menu"])
	if home != null:
		await _press(home, "home")
		await _settle(0.2)
		return await _home_visible()
	_fail("could not return to the home screen")
	return false


func _home_visible() -> bool:
	return _has_visible_text([_brand_tr()]) \
		and _find_button(["parti", "party"]) != null \
		and _find_button(["ayarlar", "settings"]) != null


func _modal_open() -> bool:
	if _main != null and _main.has_method("_modal_open"):
		return bool(_main.call("_modal_open"))
	return false


func _modal_layer() -> Node:
	if _main != null:
		var layer: Variant = _main.get("_modal_layer")
		if layer is Node:
			return layer as Node
	return null


func _find_button_under(root_node: Node, needles: Array) -> Button:
	if root_node == null:
		return null
	var nodes: Array = []
	_walk(root_node, nodes)
	var best: Button = null
	var best_score := 999
	for node in nodes:
		if not (node is Button) or (node as Button).disabled:
			continue
		var button := node as Button
		if not button.is_visible_in_tree():
			continue
		var text := _norm(button.text)
		for needle_v in needles:
			var needle := _norm(str(needle_v))
			if needle.is_empty():
				continue
			var score := 999
			if text == needle:
				score = 0
			elif text.begins_with(needle):
				score = 1
			if score < best_score:
				best_score = score
				best = button
	return best


# ---------------------------------------------------------------------------
# Language / content / save adapters
# ---------------------------------------------------------------------------

func _brand_tr() -> String:
	return GardenLoc.t("brand", "tr")


func _lang() -> String:
	if _store != null and _store.has_method("get_language"):
		return str(_store.call("get_language"))
	if _i18n != null and _i18n.has_method("get_language"):
		return str(_i18n.call("get_language"))
	return "tr"


func _content_ready() -> bool:
	if _content == null:
		return false
	if _content.has_method("is_loaded"):
		return bool(_content.call("is_loaded", "tr")) and bool(_content.call("is_loaded", "en"))
	var levels: Variant = _content.call("get_levels", "tr") if _content.has_method("get_levels") else []
	return levels is Array and not (levels as Array).is_empty()


func _content_errors() -> Array:
	if _content != null and _content.has_method("errors"):
		return _content.call("errors")
	return []


func _content_category_ids(lang: String) -> Array:
	if _content == null:
		return []
	if _content.has_method("categories"):
		var categories: Variant = _content.call("categories", lang)
		var out: Array = []
		if categories is Array:
			for category_v in categories:
				if category_v is Dictionary:
					out.append(str((category_v as Dictionary).get("id", "")))
		return out
	return []


func _levels_for_category(lang: String, category_id: String) -> Array:
	if _content == null or not _content.has_method("get_levels"):
		return []
	var levels: Variant = _content.call("get_levels", lang, category_id)
	return levels if levels is Array else []


func _coins() -> int:
	if _store == null or not _store.has_method("get_coins"):
		return -1
	return int(_store.call("get_coins", _lang()))


func _prepare_isolated_save() -> bool:
	if _store == null or not _store.has_method("set_storage_path"):
		_fail("SaveStore has no set_storage_path(); refusing to touch the production save")
		return false
	_ui_prefs_snapshotted = true
	_ui_prefs_existed = FileAccess.file_exists(_ui_prefs_path)
	if _ui_prefs_existed:
		var f := FileAccess.open(_ui_prefs_path, FileAccess.READ)
		if f != null:
			_ui_prefs_backup = f.get_as_text()
			f.close()
	# A stale test file or pref must not leak between runs.
	var unique := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_save_path = "user://test_ui_%s.json" % unique
	_save_backup_path = _save_path + ".bak"
	_remove_user_file(_ui_prefs_path)
	_remove_user_file(_save_path)
	_remove_user_file(_save_backup_path)
	_store.call("set_storage_path", _save_path, _save_backup_path)
	_save_prepared = true
	_store.call("reset_progress", "tr")
	_store.call("reset_progress", "en")
	_store.call("set_language", "tr")
	if _i18n != null and _i18n.has_method("set_language"):
		_i18n.call("set_language", "tr", false)
	# GardenApi caches its UI-only prefs statically.
	GardenApi._prefs = {}
	GardenApi._prefs_loaded = false
	await _frames(2)
	if _lang() != "tr":
		_fail("could not reset language to Turkish for the UI run")
		return false
	if _coins() != START_COINS:
		_fail("fresh test save does not start with %d coins (got %d)" % [START_COINS, _coins()])
		return false
	print("[ui] isolated save: ", _save_path)
	return true


func _cleanup_isolated_save() -> void:
	if _store != null and _save_prepared:
		if _store.has_method("use_default_path"):
			_store.call("use_default_path")
		_remove_user_file(_save_path)
		_remove_user_file(_save_backup_path)
		_save_prepared = false
	if _ui_prefs_snapshotted:
		if _ui_prefs_existed:
			var f := FileAccess.open(_ui_prefs_path, FileAccess.WRITE)
			if f != null:
				f.store_string(_ui_prefs_backup)
				f.close()
		else:
			_remove_user_file(_ui_prefs_path)
		_ui_prefs_snapshotted = false


func _remove_user_file(path: String) -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------------------
# Assertions / screenshots / lifecycle
# ---------------------------------------------------------------------------

func _check_no_horizontal_overflow(label: String) -> void:
	var viewport_size: Vector2 = root.get_visible_rect().size
	if viewport_size.x <= 0.0:
		_fail("[%s] viewport width is zero" % label)
		return
	var bad: Array[String] = []
	for node in _all_nodes():
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		if not (node is Button or node is LineEdit or node is OptionButton):
			continue
		var control := node as Control
		if control.size.x <= 0.0:
			continue
		var rect := control.get_global_rect()
		if rect.position.x < -1.0 or rect.end.x > viewport_size.x + 1.0:
			bad.append("%s x=%.1f..%.1f" % [str(control.get_path()), rect.position.x, rect.end.x])
	_check(bad.is_empty(), "[%s] interactive controls fit the %.0f px viewport%s" % [
		label, viewport_size.x, "" if bad.is_empty() else ": " + ", ".join(bad)])


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[ui] PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[ui] FAIL: " + message)
	print("[ui] FAIL: ", message)


func _parse_screenshot_arg() -> void:
	for arg_v in OS.get_cmdline_user_args():
		var arg := str(arg_v)
		if arg.begins_with("--screenshots="):
			_screenshot_dir = arg.substr("--screenshots=".length()).strip_edges()


func _shot(name: String) -> void:
	if _screenshot_dir.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		print("[ui] screenshot '%s' skipped (headless)" % name)
		return
	await _frames(3)
	var absolute_dir := _screenshot_dir
	if not absolute_dir.is_absolute_path():
		absolute_dir = ProjectSettings.globalize_path("res://" + absolute_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % name)
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("screenshot '%s' produced an empty image" % name)
		return
	var err := image.save_png(path)
	if err != OK:
		_fail("screenshot '%s' could not be saved (%d): %s" % [name, err, path])
	else:
		_shots_taken.append(path)
		print("[ui] screenshot: ", path)


func _finish() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	if _failures.is_empty():
		print("[ui] RESULT: PASS (%d checks)" % _checks)
		if not _shots_taken.is_empty():
			print("[ui] screenshots: ", ", ".join(_shots_taken))
		call_deferred("_quit_cleanly", 0)
	else:
		print("[ui] RESULT: FAIL (%d checks, %d failures)" % [_checks, _failures.size()])
		for failure: String in _failures:
			print("[ui]   - ", failure)
		call_deferred("_quit_cleanly", 1)


func _quit_cleanly(code: int) -> void:
	var audio := root.get_node_or_null("AudioManager")
	if audio != null:
		audio.call("stop_all")
	await _frames(3)
	await create_timer(0.1).timeout
	quit(code)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _settle(seconds: float) -> void:
	await create_timer(seconds).timeout


func _deadline_expired() -> bool:
	return Time.get_ticks_msec() >= _deadline_ms


func _wait_condition(predicate: Callable, label: String, timeout_ms: int = 3000) -> bool:
	var local_deadline := mini(_deadline_ms, Time.get_ticks_msec() + timeout_ms)
	while Time.get_ticks_msec() < local_deadline:
		if bool(predicate.call()):
			return true
		await _frames(1)
	if bool(predicate.call()):
		return true
	print("[ui] timeout waiting for ", label)
	return false


func _ensure_autoloads() -> bool:
	var ok := true
	for entry_v in REQUIRED_AUTOLOADS:
		var entry: Array = entry_v
		var autoload_name := str(entry[0])
		var path := str(entry[1])
		if root.has_node(autoload_name):
			continue
		if not ResourceLoader.exists(path):
			_fail("missing required script %s (%s)" % [path, autoload_name])
			ok = false
			continue
		var script: Script = load(path)
		if script == null:
			_fail("could not load %s" % path)
			ok = false
			continue
		var node := Node.new()
		node.name = autoload_name
		node.set_script(script)
		root.add_child(node)
		print("[ui] registered missing autoload %s" % autoload_name)
	await _frames(3)
	return ok
