extends Control

## Solo level play and relaxed Party mode.
##
## Gameplay state lives in core/game_session.gd. This screen only renders the
## session snapshot and forwards typing / purchase intents. Coins, hints,
## letter reveals and completion rewards are always decided by the core
## (GameSession + SaveStore), never by the view layer.

var app: Node

var _mode := "level"
var _lang := "tr"
var _level: Dictionary = {}
var _category: Dictionary = {}
var _words: Array = []
var _session: Variant = null

# Read-only mirror of the session snapshot. The UI test harness inspects these
# names, and the header/chain rendering reads them instead of duplicating state.
var _current := 0
var _typed := ""
var _revealed := 1
var _hint_text := ""
var _busy := false
var _finished := false
var _victory_open := false

var _box: VBoxContainer
var _scroll: ScrollContainer
var _chain_view: GardenChainView
var _keyboard: GardenKeyboard
var _progress_label: Label
var _progress_bar: ProgressBar
var _title_label: Label
var _feedback: Label
var _hint_button: Button
var _reveal_button: Button
var _victory_layer: Control
var _focus_target: Control
var _feedback_serial := 0
var _first_clear := false
var _reward := 0


## Party mode must never touch real progress or award completion coins. This
## shim reads the real coin balance but refuses spending, reports every level as
## already completed and never persists a completion.
class PartyStore:
	extends RefCounted

	func _real_store() -> Node:
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			return (loop as SceneTree).root.get_node_or_null("SaveStore")
		return null

	func get_coins(lang: String = "") -> int:
		var store := _real_store()
		if store != null and store.has_method("get_coins"):
			return int(store.call("get_coins", lang))
		return 100

	func spend_coins(_lang: String, _amount: int) -> bool:
		return false

	func is_completed(_lang: String, _level_id: String) -> bool:
		return true

	func mark_level_completed(lang: String, _level_id: String, _reward_amount: int = 25) -> Dictionary:
		return {
			"success": true,
			"first_clear": false,
			"coins_awarded": 0,
			"coins": get_coins(lang),
			"already_completed": true,
		}

	func record_purchase(_lang: String, _kind: String) -> void:
		pass


func setup(params: Dictionary = {}) -> void:
	_mode = "party" if str(params.get("mode", "")) == "party" else "level"
	_lang = GardenApi.lang()
	_category = params.get("category", {})
	if _mode == "party":
		var given: Dictionary = params.get("level", {})
		if given.is_empty():
			_level = GardenApi.party_level(_lang)
		else:
			_level = GardenApi.normalize_level(given.get("raw", given), _lang)
	else:
		_level = params.get("level", {})
		if not _level.is_empty() and not _level.has("words"):
			_level = GardenApi.get_level(_lang, _level.get("id", ""))
	_words = _level.get("words", [])
	_reset_round()
	_start_session()
	if _mode == "level" and not _level.is_empty():
		var store := GardenApi.save_store()
		if store != null:
			store.call("set_last_level", _lang, str(_level.get("id", "")))
	_build()


func _reset_round() -> void:
	_current = 0
	_typed = ""
	_revealed = 1
	_hint_text = ""
	_busy = false
	_finished = false
	_victory_open = false
	_first_clear = false
	_reward = 0


# ---------------------------------------------------------------------------
# Session wiring
# ---------------------------------------------------------------------------

func _start_session() -> bool:
	_session = null
	if _level.is_empty() or _words.is_empty():
		return false
	var created: Variant = null
	if _mode == "party":
		created = GardenApi.create_session(PartyStore.new())
	else:
		created = GardenApi.create_session()
	if created == null:
		return false
	_session = created
	var s: Variant = _session
	s.state_changed.connect(_on_state_changed)
	s.word_solved.connect(_on_word_solved)
	s.chain_completed.connect(_on_chain_completed)
	s.answer_rejected.connect(_on_answer_rejected)
	s.submit_blocked.connect(_on_submit_blocked)
	s.hint_bought.connect(_on_hint_bought)
	s.letters_revealed.connect(_on_letters_revealed)
	s.level_won.connect(_on_level_won)
	s.coins_changed.connect(_on_coins_changed)
	if not bool(s.start(_level, _lang)):
		_session = null
		return false
	_sync_from_session()
	return true


func _session_alive() -> bool:
	return _session != null


func _active_index() -> int:
	if _session == null:
		return -1
	var s: Variant = _session
	return int(s.active_word_index())


func _active_locked_count() -> int:
	if _session == null:
		return 0
	var s: Variant = _session
	var index := int(s.active_word_index())
	if index < 0:
		return 0
	var total := 0
	var length := int(s.word_length(index))
	for letter_index in length:
		if bool(s.is_locked(index, letter_index)):
			total += 1
	return total


func _sync_from_session() -> void:
	if _session == null:
		return
	var s: Variant = _session
	var state: Dictionary = s.get_state()
	_current = int(state.get("current_word_index", -1))
	_revealed = _active_locked_count()
	_hint_text = str(s.get_active_hint())
	if bool(state.get("won", false)):
		_finished = true


func _refresh_from_session() -> void:
	_sync_from_session()
	if _chain_view != null and is_instance_valid(_chain_view) and _session != null:
		_chain_view.setup_session(_session, _level, _mode == "party", _mode == "party")
		_chain_view.scroll_to_current(_scroll)
	_update_header()


func _on_state_changed() -> void:
	_refresh_from_session()


func _on_word_solved(_index: int) -> void:
	_busy = true
	if _keyboard != null:
		_keyboard.set_enabled(false)
	_update_header()
	_show_feedback(GardenLoc.t("correct", _lang), GardenTheme.MINT_DEEP)
	GardenApi.play_sound("correct")
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(25)
	var timer := get_tree().create_timer(0.42)
	timer.timeout.connect(_clear_busy)


func _clear_busy() -> void:
	if not is_instance_valid(self):
		return
	_busy = false
	if _finished or _victory_open:
		return
	if _keyboard != null:
		_keyboard.set_enabled(true)
	_update_header()


func _on_chain_completed() -> void:
	_finished = true


func _on_answer_rejected(_answer: String) -> void:
	GardenApi.play_sound("wrong")
	_show_feedback(GardenLoc.t("wrong", _lang), GardenTheme.DANGER)
	if _chain_view != null:
		_chain_view.shake()
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(45)
	var target: Control = _chain_view
	if target != null and is_instance_valid(target):
		var original := target.modulate
		target.modulate = Color(1.0, 0.82, 0.86)
		var tween := target.create_tween()
		tween.tween_property(target, "modulate", original, 0.25)


func _on_submit_blocked(reason: String) -> void:
	if reason == "incomplete":
		_show_feedback(GardenLoc.t("incomplete", _lang), GardenTheme.DANGER)
		if _chain_view != null:
			_chain_view.shake()
		GardenApi.play_sound("wrong")


func _on_hint_bought(_word_index: int, hint: String, _coins: int) -> void:
	_hint_text = hint
	if app != null:
		app.update_coins()
	_show_feedback(GardenLoc.t("hint_prefix", _lang) + " · -10", GardenTheme.YELLOW_DEEP.darkened(0.25))
	GardenApi.play_sound("coin")


func _on_letters_revealed(_count: int, _coins: int) -> void:
	if app != null:
		app.update_coins()
	_revealed = _active_locked_count()
	_show_feedback("+1 " + GardenLoc.t("reveal_btn", _lang) + " · -15", GardenTheme.LAVENDER_DEEP)
	GardenApi.play_sound("coin")


func _on_coins_changed(_coins: int) -> void:
	if app != null:
		app.update_coins()


func _on_level_won(coins_awarded: int, first_clear: bool, _total_coins: int) -> void:
	if _finished and _victory_open:
		return
	_finished = true
	_busy = false
	_first_clear = first_clear
	_reward = coins_awarded
	if _keyboard != null:
		_keyboard.set_enabled(false)
	if app != null:
		app.update_coins()
	if first_clear and app != null:
		app.celebrate(Vector2(size.x * 0.5, size.y * 0.28))
	GardenApi.play_sound("win")
	_show_victory()


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build() -> void:
	GardenWidgets.clear_children(self)
	_victory_layer = null
	_feedback = null
	_progress_label = null
	_progress_bar = null
	_hint_button = null
	_reveal_button = null
	_keyboard = null
	_chain_view = null
	_scroll = null
	if _session == null or _level.is_empty() or _words.is_empty():
		_build_empty()
		return
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 7)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_box)

	_box.add_child(_header())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.custom_minimum_size.y = 120
	_box.add_child(_scroll)
	var chain_margin := MarginContainer.new()
	chain_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chain_margin.add_theme_constant_override("margin_left", 0)
	chain_margin.add_theme_constant_override("margin_right", 0)
	chain_margin.add_theme_constant_override("margin_top", 2)
	chain_margin.add_theme_constant_override("margin_bottom", 4)
	_scroll.add_child(chain_margin)
	_chain_view = GardenChainView.new()
	_chain_view.party_style = _mode == "party"
	_chain_view.card_tapped.connect(func(_index: int) -> void:
		if _mode == "party":
			_next_party_chain())
	chain_margin.add_child(_chain_view)
	_rebuild_chain()

	if _mode == "party":
		var next := GardenWidgets.button(GardenLoc.t("party_next", _lang), "pink", 52)
		next.pressed.connect(_next_party_chain)
		_box.add_child(next)
		_focus_target = next
		return

	_keyboard = GardenKeyboard.new()
	_keyboard.setup(_lang)
	_keyboard.letter_pressed.connect(_on_letter)
	_keyboard.backspace_pressed.connect(_on_backspace)
	_keyboard.submit_pressed.connect(_on_submit)
	_box.add_child(_keyboard)
	_keyboard.set_enabled(not _busy and not _finished)


func _build_empty() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 24, true, 20)
	card.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 40.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(GardenWidgets.title(GardenLoc.t("content_missing", _lang), 20))
	v.add_child(GardenWidgets.caption(GardenLoc.t("content_missing_body", _lang)))
	var back := GardenWidgets.button(GardenLoc.t("back", _lang), "ghost", 44)
	back.pressed.connect(func() -> void:
		if app != null:
			app.force_back())
	v.add_child(back)
	card.add_child(v)


func _header() -> Control:
	var panel := GardenWidgets.panel(GardenTheme.SURFACE, 20, true, 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var cat_label := _category_name()
	var cat_chip := GardenWidgets.chip(GardenApi.upper(cat_label, _lang), GardenTheme.LAVENDER_SOFT, GardenTheme.LAVENDER_DEEP)
	row.add_child(cat_chip)
	if _mode == "party":
		row.add_child(GardenWidgets.chip(GardenLoc.t("party_badge", _lang), GardenTheme.PINK_SOFT, GardenTheme.PINK_DEEP))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_progress_label = GardenWidgets.bold_label("", 13, GardenTheme.MUTED)
	row.add_child(_progress_label)
	v.add_child(row)
	_title_label = GardenWidgets.bold_label(_level_title(), 16, GardenTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	v.add_child(_title_label)
	_progress_bar = GardenWidgets.progress_bar(0, maxi(1, _words.size()), GardenTheme.LAVENDER, 6)
	v.add_child(_progress_bar)
	if _mode == "party":
		v.add_child(GardenWidgets.caption(GardenLoc.t("party_tip", _lang), GardenTheme.MUTED))
	# Party mode is purchase-free: no hints and no letter reveals.
	if _mode != "party":
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		_hint_button = GardenWidgets.small_button("", "yellow", 34)
		_hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hint_button.pressed.connect(_buy_hint)
		actions.add_child(_hint_button)
		_reveal_button = GardenWidgets.small_button("", "ghost", 34)
		_reveal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_reveal_button.pressed.connect(_buy_letter)
		actions.add_child(_reveal_button)
		v.add_child(actions)
	_feedback = GardenWidgets.caption("", GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_feedback.custom_minimum_size.y = 16
	v.add_child(_feedback)
	_update_header()
	return panel


func _update_header() -> void:
	if _progress_label == null:
		return
	var solved := 0
	if _session != null:
		var s: Variant = _session
		solved = int(s.get("solved_word_count"))
	var total := maxi(1, _words.size())
	if _mode == "party":
		solved = total
	_progress_label.text = GardenLoc.f("chain_progress", [solved, total], _lang)
	if _progress_bar != null:
		_progress_bar.max_value = total
		_progress_bar.value = solved
	if _hint_button != null:
		_hint_button.text = GardenLoc.f("hint_cost", [10], _lang)
		_hint_button.disabled = _busy or _finished or _active_index() < 0 or (_hint_text.is_empty() and not bool(_session.can_buy_hint()))
	if _reveal_button != null:
		_reveal_button.text = GardenLoc.f("reveal_cost", [15], _lang)
		_reveal_button.disabled = _busy or _finished or _active_index() < 0 or not bool(_session.can_buy_letter())


func _category_name() -> String:
	if _mode == "party":
		return GardenLoc.t("party_title", _lang)
	if not _category.is_empty():
		var name := GardenLoc.category_name(_category, _lang)
		if not name.is_empty():
			return name
	return GardenLoc.category_name(str(_level.get("category", "")), _lang)


func _level_title() -> String:
	if _mode == "party":
		return GardenLoc.t("party_sub", _lang)
	var cat := _category_name()
	var title := str(_level.get("title", ""))
	if not title.is_empty() and title != cat:
		return "%s · %s" % [cat, title]
	var list := GardenApi.levels(_lang, str(_level.get("category", "")))
	var index := 1
	for i in list.size():
		if str(list[i].get("id", "")) == str(_level.get("id", "")):
			index = i + 1
			break
	return "%s · %s" % [cat, GardenLoc.f("level_n", [index], _lang)]


func _rebuild_chain() -> void:
	if _chain_view == null or _session == null:
		return
	_chain_view.setup_session(_session, _level, _mode == "party", _mode == "party")
	_chain_view.scroll_to_current(_scroll)
	_update_header()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _on_letter(letter: String) -> void:
	if _busy or _finished or _victory_open or _session == null:
		return
	var s: Variant = _session
	s.type_letter(letter)


func _on_backspace() -> void:
	if _busy or _finished or _victory_open or _session == null:
		return
	var s: Variant = _session
	s.backspace()


func _on_submit() -> void:
	if _busy or _finished or _victory_open or _session == null:
		return
	var s: Variant = _session
	s.submit()


func _purchases_allowed() -> bool:
	return _mode != "party" and not _busy and not _finished and not _victory_open and _session != null


func _buy_hint() -> void:
	if not _purchases_allowed():
		return
	var index := _active_index()
	if index < 0 or index >= _words.size():
		return
	var hint := str((_words[index] as Dictionary).get("hint", ""))
	if hint.is_empty():
		if app != null:
			app.toast(GardenLoc.t("no_hint", _lang))
		return
	if not _hint_text.is_empty():
		if app != null:
			app.toast(GardenLoc.t("hint_prefix", _lang) + ": " + _hint_text)
		return
	var s: Variant = _session
	if not bool(s.buy_hint()):
		if app != null:
			app.toast(GardenLoc.t("save_failed", _lang) if GardenApi.coins() >= 10 else GardenLoc.t("not_enough_coins", _lang))


func _buy_letter() -> void:
	if not _purchases_allowed():
		return
	var s: Variant = _session
	if not bool(s.buy_letter()):
		if app != null:
			app.toast(GardenLoc.t("save_failed", _lang) if GardenApi.coins() >= 15 else GardenLoc.t("not_enough_coins", _lang))


# ---------------------------------------------------------------------------
# Victory
# ---------------------------------------------------------------------------

func _show_victory() -> void:
	if _victory_layer != null and is_instance_valid(_victory_layer):
		remove_child(_victory_layer)
		_victory_layer.queue_free()
	_victory_open = true
	_victory_layer = Control.new()
	_victory_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_victory_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.2, 0.40)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_victory_layer.add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dim.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	scroll.add_child(margin)
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 28, true, 20)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	card.add_child(v)

	var mascot := GardenPaint.Mascot.new()
	mascot.custom_minimum_size = Vector2(88, 92)
	mascot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(mascot)
	var headline := GardenLoc.t("party_finished", _lang) if _mode == "party" else GardenLoc.t("victory_title", _lang)
	v.add_child(GardenWidgets.title(headline, 27, GardenTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.label(GardenLoc.t("victory_sub", _lang), 14, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 6)
	chips.add_child(GardenWidgets.chip("%d / %d" % [_words.size(), _words.size()], GardenTheme.LAVENDER_SOFT, GardenTheme.LAVENDER_DEEP))
	if _first_clear:
		var reward_chip := GardenWidgets.chip(GardenLoc.f("first_clear_reward", [_reward], _lang), GardenTheme.YELLOW_SOFT, Color("6a4d10"), GardenPaint.CoinIcon.new())
		chips.add_child(reward_chip)
	elif _mode == "level":
		chips.add_child(GardenWidgets.chip(GardenLoc.t("completed", _lang), GardenTheme.MINT, GardenTheme.MINT_DEEP.darkened(0.3)))
	v.add_child(chips)
	v.add_child(GardenWidgets.divider())
	var links_head := GardenWidgets.bold_label(GardenLoc.t("party_links", _lang) if _mode == "party" else GardenLoc.t("expression_label", _lang), 13, GardenTheme.MUTED)
	v.add_child(links_head)
	var links_box := VBoxContainer.new()
	links_box.add_theme_constant_override("separation", 6)
	var any_link := false
	for i in _words.size():
		var link := str((_words[i] as Dictionary).get("link", ""))
		if link.is_empty():
			continue
		any_link = true
		var row := GardenWidgets.panel(GardenTheme.CARD, 13, false, 10)
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 1)
		rv.add_child(GardenWidgets.bold_label(GardenApi.upper_tr(str((_words[i] as Dictionary).get("word", ""))), 12, GardenTheme.LAVENDER_DEEP))
		rv.add_child(GardenWidgets.label(link, 12, GardenTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		row.add_child(rv)
		links_box.add_child(row)
	if not any_link:
		links_box.add_child(GardenWidgets.caption(GardenLoc.t("expression_none", _lang)))
	v.add_child(links_box)
	if _mode == "level" and not _first_clear:
		var unsaved := _session != null and not str(_session.get("save_error")).is_empty()
		v.add_child(GardenWidgets.caption(GardenLoc.t("save_failed", _lang) if unsaved else GardenLoc.t("already_cleared", _lang), GardenTheme.DANGER if unsaved else GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.vspace(2))

	var next := GardenApi.next_level(_lang, _level.get("id", "")) if _mode == "level" else GardenApi.party_level(_lang, str(_level.get("id", "")))
	var next_button: Button
	if _mode == "party":
		next_button = GardenWidgets.button(GardenLoc.t("party_next", _lang), "primary", 48)
		next_button.pressed.connect(func() -> void:
			_close_victory()
			_next_party_chain())
	elif not next.is_empty():
		next_button = GardenWidgets.button(GardenLoc.t("next_level", _lang), "primary", 48)
		next_button.pressed.connect(func() -> void:
			_close_victory()
			if app != null:
				app.play_level(next, {}, true))
	else:
		next_button = GardenWidgets.button(GardenLoc.t("back_to_map", _lang), "primary", 48)
		next_button.pressed.connect(func() -> void:
			if app != null:
				app.force_back())
	v.add_child(next_button)
	var back := GardenWidgets.button(GardenLoc.t("back_to_map", _lang) if _mode == "level" else GardenLoc.t("home", _lang), "ghost", 44)
	back.pressed.connect(func() -> void:
		if app != null:
			app.force_back())
	if _mode == "level" and not next.is_empty():
		v.add_child(back)
	GardenWidgets.focus(next_button)


func _close_victory() -> void:
	_victory_open = false
	if _victory_layer != null and is_instance_valid(_victory_layer):
		if _victory_layer.get_parent() == self:
			remove_child(_victory_layer)
		_victory_layer.queue_free()
	_victory_layer = null


func _next_party_chain() -> void:
	var avoid := str(_level.get("id", ""))
	var next := GardenApi.party_level(_lang, avoid)
	if next.is_empty() or str(next.get("id", "")) == avoid:
		# Ensure no immediate repeat even when only one chain exists.
		var all := GardenApi.all_levels(_lang)
		next = {}
		for lv in all:
			if str(lv.get("id", "")) != avoid:
				next = lv
				break
		if next.is_empty():
			next = GardenApi.party_level(_lang)
	if next.is_empty():
		return
	_level = next
	_words = _level.get("words", [])
	_reset_round()
	_start_session()
	_build()
	if app != null:
		app.update_coins()


func on_language_changed(code: String) -> void:
	if _mode != "party":
		return
	_lang = "en" if code == "en" else "tr"
	var avoid := str(_level.get("id", ""))
	_level = GardenApi.party_level(_lang, avoid)
	_words = _level.get("words", [])
	_reset_round()
	_start_session()
	_build()


func language_lock_reason() -> String:
	if _mode == "party":
		return ""
	return GardenLoc.t("lang_locked_play", _lang)


func handle_back() -> bool:
	if _victory_open:
		if app != null:
			app.force_back()
		return true
	if _mode == "party":
		if app != null:
			app.force_back()
		return true
	if app != null:
		app.show_confirm(GardenLoc.t("quit_title", _lang), GardenLoc.t("quit_body", _lang),
				GardenLoc.t("quit_confirm", _lang), func() -> void:
					if is_instance_valid(app):
						app.force_back())
	return true


func initial_focus() -> Control:
	return _focus_target


func _show_feedback(text: String, color: Color) -> void:
	if _feedback == null or not is_instance_valid(_feedback):
		return
	_feedback_serial += 1
	var serial := _feedback_serial
	_feedback.text = text
	_feedback.add_theme_color_override("font_color", color)
	_feedback.modulate.a = 1.0
	var timer := get_tree().create_timer(1.25)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self) or not is_instance_valid(_feedback) or serial != _feedback_serial:
			return
		var tween := _feedback.create_tween()
		tween.tween_property(_feedback, "modulate:a", 0.0, 0.25))


func _input(event: InputEvent) -> void:
	# Touch is emulated as mouse input by the project settings. Navigation in the
	# top bar remains outside this screen, while any party-body tap advances.
	if _mode != "party" or not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if click.pressed and click.button_index == MOUSE_BUTTON_LEFT and get_global_rect().has_point(click.position):
		get_viewport().set_input_as_handled()
		_next_party_chain()


func _unhandled_key_input(event: InputEvent) -> void:
	if app != null and bool(app.call("_modal_open")):
		return
	if _mode == "party":
		return
	if _victory_open:
		if event is InputEventKey and event.pressed and not event.echo:
			var vk := event as InputEventKey
			if vk.keycode in [KEY_ENTER, KEY_KP_ENTER]:
				get_viewport().set_input_as_handled()
				var focus := get_viewport().gui_get_focus_owner()
				if focus is Button:
					(focus as Button).pressed.emit()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			_on_submit()
			return
		if key.keycode == KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			_on_backspace()
			return
		var ch := char(key.unicode)
		if ch.is_empty() or key.unicode == 0:
			return
		var up := GardenApi.upper(ch, _lang)
		var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		if _lang == "tr":
			alphabet = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"
		if up.length() == 1 and alphabet.contains(up):
			get_viewport().set_input_as_handled()
			_on_letter(up)
