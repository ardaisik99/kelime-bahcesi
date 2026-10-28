extends Control

## Online mode: real WebSocket play through the core NetworkClient autoload.
##
## Flow: lobby -> room -> server-driven 3-2-1 countdown -> shared 3 chains ->
## finish screen. Progress coordinates are owned by the server: word 0 of every
## chain is given, so the first answerable slot is word index 1 and every
## `answer_result` carries the NEXT expected coordinates (-1 once finished).
## The room language is locked while a room/match exists; hints are disabled.

const POINTS_PER_WORD := 100
const CONFIG_PATH := "res://config/network.json"
const EMOTES := ["hello", "nice", "wow", "gg"]

var app: Node

var _net: Node = null
var _ui_root: Control
var _state := "lobby"
var _lang := "tr"

var _connected := false
var _connecting := true
var _joining := false
var _player_id := ""
var _players: Array = []
var _room_code := ""
var _room_lang := "tr"
var _room_status := "waiting"

var _name_edit: LineEdit
var _code_edit: LineEdit
var _create_button: Button
var _join_button: Button
var _retry_button: Button
var _status_chip: PanelContainer
var _status_label: Label
var _offline_card: Control
var _join_note: Label

var _levels: Array = []
var _level_index := 0
var _word_index := 1
var _typed := ""
var _revealed := 1
var _score_self := 0
var _score_opp := 0
var _starts_at := 0
var _ends_at := 0
var _match_started := false
var _time_up := false
var _answer_pending := false
var _awaiting_finish := false
var _finish_open := false
var _answer_serial := 0

var _scroll: ScrollContainer
var _chain_view: GardenChainView
var _keyboard: GardenKeyboard
var _round_strip: HBoxContainer
var _round_label: Label
var _score_self_label: Label
var _score_opp_label: Label
var _self_name_label: Label
var _opp_name_label: Label
var _self_bar: ProgressBar
var _opp_bar: ProgressBar
var _timer_label: Label
var _match_feedback: Label
var _match_feedback_serial := 0
var _countdown_layer: Control
var _countdown_label: Label
var _finish_layer: Control
var _focus_target: Control
var _joining_serial := 0


func setup(_params: Dictionary = {}) -> void:
	_lang = GardenApi.lang()
	_room_lang = _lang
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_root)
	_net = GardenApi.network()
	_build_lobby()
	set_process(true)
	if _net == null:
		_connecting = false
		_set_connection_ui()
		return
	_wire_network()
	if _net.has_method("is_open") and bool(_net.call("is_open")):
		_on_connected()
	else:
		_connecting = true
		_set_connection_ui()
		if not bool(_net.call("connect_to_server")):
			_connecting = false
			_set_connection_ui()


# ---------------------------------------------------------------------------
# Network wiring
# ---------------------------------------------------------------------------

func _wire_network() -> void:
	if _net == null:
		return
	if not _net.connected.is_connected(_on_connected):
		_net.connected.connect(_on_connected)
	if not _net.disconnected.is_connected(_on_disconnected):
		_net.disconnected.connect(_on_disconnected)
	if not _net.connection_failed.is_connected(_on_connection_failed):
		_net.connection_failed.connect(_on_connection_failed)
	if not _net.welcome.is_connected(_on_welcome):
		_net.welcome.connect(_on_welcome)
	if not _net.room_updated.is_connected(_on_room_updated):
		_net.room_updated.connect(_on_room_updated)
	if not _net.game_started.is_connected(_on_game_started):
		_net.game_started.connect(_on_game_started)
	if not _net.answer_result.is_connected(_on_answer_result):
		_net.answer_result.connect(_on_answer_result)
	if not _net.score_updated.is_connected(_on_score_updated):
		_net.score_updated.connect(_on_score_updated)
	if not _net.emote_received.is_connected(_on_emote_received):
		_net.emote_received.connect(_on_emote_received)
	if not _net.game_finished.is_connected(_on_game_finished):
		_net.game_finished.connect(_on_game_finished)
	if not _net.error_received.is_connected(_on_error_received):
		_net.error_received.connect(_on_error_received)
	if not _net.network_error.is_connected(_on_network_error):
		_net.network_error.connect(_on_network_error)


func _exit_tree() -> void:
	_state = "leaving"
	if is_instance_valid(_net):
		_net.call("disconnect_from_server", true)


func _on_connected() -> void:
	_connected = true
	_connecting = false
	_player_from_net()
	_set_connection_ui()
	_update_create_label()


func _on_disconnected(reason: String) -> void:
	_connected = false
	_connecting = false
	if _state == "leaving":
		return
	if _state in ["countdown", "match", "room"] and not _finish_open:
		_show_connection_lost(reason)
	elif _state != "finish":
		_set_connection_ui()
		var msg := GardenLoc.t("err_offline", _lang)
		if reason == "timeout":
			msg = GardenLoc.t("err_timeout", _lang)
		if app != null:
			app.toast(msg)


func _on_connection_failed(message: String) -> void:
	_connected = false
	_connecting = false
	_set_connection_ui()
	if app != null:
		app.toast(GardenLoc.status_label(message, _lang))


func _on_network_error(message: String) -> void:
	if message == "not_connected" and app != null:
		app.toast(GardenLoc.t("err_not_connected", _lang))


func _on_welcome(player_id: String) -> void:
	_player_id = player_id
	if _player_id.is_empty():
		_player_from_net()


func _player_from_net() -> void:
	if _net == null:
		return
	var value: Variant = _net.get("player_id")
	if typeof(value) == TYPE_STRING and not str(value).is_empty():
		_player_id = str(value)


# ---------------------------------------------------------------------------
# Lobby
# ---------------------------------------------------------------------------

func _clear_ui() -> void:
	if _ui_root != null and is_instance_valid(_ui_root):
		if _ui_root.get_parent() == self:
			remove_child(_ui_root)
		_ui_root.queue_free()
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_root)
	_name_edit = null
	_code_edit = null
	_create_button = null
	_join_button = null
	_retry_button = null
	_status_chip = null
	_status_label = null
	_offline_card = null
	_join_note = null
	_scroll = null
	_chain_view = null
	_keyboard = null
	_round_strip = null
	_round_label = null
	_score_self_label = null
	_score_opp_label = null
	_self_name_label = null
	_opp_name_label = null
	_self_bar = null
	_opp_bar = null
	_timer_label = null
	_match_feedback = null
	_countdown_layer = null
	_countdown_label = null
	_finish_layer = null
	_finish_open = false


func _build_lobby() -> void:
	_state = "lobby"
	_clear_ui()
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ui_root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 11)
	margin.add_child(content)

	var header := GardenWidgets.panel(GardenTheme.YELLOW_SOFT, 24, true, 18)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 5)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 7)
	hrow.add_child(GardenWidgets.chip(GardenLoc.t("online_title", _lang).to_upper(), GardenTheme.CARD, GardenTheme.YELLOW_DEEP.darkened(0.25)))
	var hspacer := Control.new()
	hspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(hspacer)
	_status_chip = GardenWidgets.panel(GardenTheme.LAVENDER_SOFT, 12, false, 8)
	_status_label = GardenWidgets.bold_label("", 11, GardenTheme.LAVENDER_DEEP)
	_status_chip.add_child(_status_label)
	hrow.add_child(_status_chip)
	hv.add_child(hrow)
	hv.add_child(GardenWidgets.title(GardenLoc.t("online_title", _lang), 27))
	hv.add_child(GardenWidgets.label(GardenLoc.t("online_sub", _lang), 13, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	hv.add_child(GardenWidgets.caption(GardenLoc.t("online_no_login", _lang), GardenTheme.LOCKED_INK))
	header.add_child(hv)
	content.add_child(header)

	var name_card := GardenWidgets.panel(GardenTheme.SURFACE, 22, true, 16)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 6)
	nv.add_child(GardenWidgets.bold_label(GardenLoc.t("online_name", _lang), 14, GardenTheme.INK))
	_name_edit = GardenWidgets.line_edit(GardenLoc.t("online_name_ph", _lang), GardenApi.player_name(), 18)
	_name_edit.text_changed.connect(func(text: String) -> void:
		GardenApi.set_player_name(text)
		if _create_button != null and not _joining:
			_create_button.disabled = not _connected)
	nv.add_child(_name_edit)
	_create_button = GardenWidgets.button("", "primary", 50)
	_create_button.pressed.connect(_create_room)
	nv.add_child(_create_button)
	var or_row := HBoxContainer.new()
	or_row.add_theme_constant_override("separation", 8)
	var line_a := GardenWidgets.divider()
	line_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	or_row.add_child(line_a)
	or_row.add_child(GardenWidgets.caption(GardenLoc.t("or", _lang), GardenTheme.LOCKED_INK))
	var line_b := GardenWidgets.divider()
	line_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	or_row.add_child(line_b)
	nv.add_child(or_row)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 7)
	_code_edit = GardenWidgets.line_edit(GardenLoc.t("online_code_ph", _lang), "", 8)
	_code_edit.size_flags_stretch_ratio = 1.0
	_code_edit.text_changed.connect(func(text: String) -> void:
		var upper := text.to_upper()
		if upper != text:
			_code_edit.text = upper
			_code_edit.caret_column = upper.length())
	join_row.add_child(_code_edit)
	_join_button = GardenWidgets.button(GardenLoc.t("online_join", _lang), "pink", 44)
	_join_button.custom_minimum_size.x = 150
	_join_button.pressed.connect(_join_room)
	join_row.add_child(_join_button)
	nv.add_child(join_row)
	_join_note = GardenWidgets.caption("", GardenTheme.MUTED)
	nv.add_child(_join_note)
	name_card.add_child(nv)
	content.add_child(name_card)

	_offline_card = GardenWidgets.panel(GardenTheme.PINK_SOFT, 20, true, 15)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 6)
	ov.add_child(GardenWidgets.bold_label(GardenLoc.t("online_offline_title", _lang), 15, GardenTheme.PINK_DEEP.darkened(0.25)))
	ov.add_child(GardenWidgets.label(GardenLoc.t("online_offline_body", _lang), 12, GardenTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	_retry_button = GardenWidgets.small_button(GardenLoc.t("online_retry", _lang), "ghost", 38)
	_retry_button.pressed.connect(_retry_connection)
	ov.add_child(_retry_button)
	_offline_card.add_child(ov)
	content.add_child(_offline_card)
	if _net == null:
		_offline_card.visible = true
		content.add_child(GardenWidgets.caption(GardenLoc.t("online_no_client", _lang), GardenTheme.DANGER))

	content.add_child(_config_card())
	content.add_child(GardenWidgets.caption(GardenLoc.t("online_copy_hint", _lang), GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_CENTER))
	_set_connection_ui()
	_update_create_label()
	_focus_target = _name_edit if GardenApi.player_name().is_empty() else _create_button


func _update_create_label() -> void:
	if _create_button == null:
		return
	var lang_name := GardenLoc.t("turkish", _lang) if _lang == "tr" else GardenLoc.t("english", _lang)
	_create_button.text = "%s  ·  %s" % [GardenLoc.t("online_create", _lang), lang_name]
	if _joining:
		_create_button.text = GardenLoc.t("loading", _lang)


func _config_card() -> Control:
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 18, true, 14)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(GardenWidgets.bold_label(GardenLoc.t("online_config_title", _lang), 13, GardenTheme.INK))
	v.add_child(GardenWidgets.label(GardenLoc.t("online_config_body", _lang), 11, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	var url := ""
	if _net != null:
		var value: Variant = _net.get("url")
		if typeof(value) == TYPE_STRING:
			url = str(value)
	if url.is_empty():
		url = "ws://127.0.0.1:8787"
	var path_label := GardenWidgets.caption(url, GardenTheme.LAVENDER_DEEP)
	path_label.add_theme_font_override("font", GardenTheme.bold_font())
	v.add_child(path_label)
	var file_label := GardenWidgets.caption(CONFIG_PATH, GardenTheme.LOCKED_INK)
	v.add_child(file_label)
	card.add_child(v)
	return card


func _set_connection_ui() -> void:
	if _status_label == null:
		return
	var bg := GardenTheme.YELLOW_SOFT
	var fg := GardenTheme.LAVENDER_DEEP
	var text := GardenLoc.t("online_connecting", _lang)
	if _connected:
		bg = GardenTheme.MINT
		fg = GardenTheme.MINT_DEEP.darkened(0.25)
		text = GardenLoc.t("online_connected", _lang)
	elif not _connecting:
		bg = GardenTheme.PINK_SOFT
		fg = GardenTheme.PINK_DEEP.darkened(0.2)
		text = GardenLoc.t("online_disconnected", _lang)
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", fg)
	if _status_chip != null:
		_status_chip.add_theme_stylebox_override("panel", GardenTheme.panel_style(bg, 12, false))
	if _offline_card != null:
		_offline_card.visible = not _connected and not _connecting
	if _create_button != null:
		_create_button.disabled = not _connected or _joining
	if _join_button != null:
		_join_button.disabled = not _connected or _joining
	if _join_note != null:
		if not _connected and not _connecting:
			_join_note.text = GardenLoc.t("online_offline_title", _lang)
			_join_note.add_theme_color_override("font_color", GardenTheme.DANGER)
		else:
			_join_note.text = ""
	if _retry_button != null:
		_retry_button.disabled = _connecting or _net == null


func _create_room() -> void:
	if not _connected or _net == null:
		if app != null:
			app.toast(GardenLoc.t("err_offline", _lang))
		return
	var name := _name_edit.text.strip_edges() if _name_edit != null else GardenApi.player_name()
	if name.is_empty():
		if app != null:
			app.toast(GardenLoc.t("online_need_name", _lang))
		if _name_edit != null:
			_name_edit.grab_focus()
		return
	GardenApi.set_player_name(name)
	_joining = true
	_set_connection_ui()
	_update_create_label()
	if _join_note != null:
		_join_note.text = GardenLoc.t("online_connecting_hint", _lang)
		_join_note.add_theme_color_override("font_color", GardenTheme.MUTED)
	if not bool(_net.call("create_room", _lang, name)):
		_joining = false
		_update_create_label()
		_set_connection_ui()
		return
	_arm_join_timeout()


func _join_room() -> void:
	if not _connected or _net == null:
		if app != null:
			app.toast(GardenLoc.t("err_offline", _lang))
		return
	var name := _name_edit.text.strip_edges() if _name_edit != null else GardenApi.player_name()
	if name.is_empty():
		if app != null:
			app.toast(GardenLoc.t("online_need_name", _lang))
		return
	var code := _code_edit.text.strip_edges() if _code_edit != null else ""
	if code.is_empty():
		if app != null:
			app.toast(GardenLoc.t("online_need_code", _lang))
		_code_edit.grab_focus()
		return
	GardenApi.set_player_name(name)
	_joining = true
	_set_connection_ui()
	if _join_note != null:
		_join_note.text = GardenLoc.t("online_connecting_hint", _lang)
		_join_note.add_theme_color_override("font_color", GardenTheme.MUTED)
	if not bool(_net.call("join_room", code, name)):
		_joining = false
		_update_create_label()
		_set_connection_ui()
		return
	_arm_join_timeout()


func _arm_join_timeout() -> void:
	_joining_serial += 1
	var serial := _joining_serial
	var timer := get_tree().create_timer(10.0)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self) or serial != _joining_serial or not _joining:
			return
		_joining = false
		_update_create_label()
		_set_connection_ui()
		if _join_note != null:
			_join_note.text = GardenLoc.t("err_timeout", _lang)
			_join_note.add_theme_color_override("font_color", GardenTheme.DANGER)
		if app != null:
			app.toast(GardenLoc.t("err_timeout", _lang)))


func _retry_connection() -> void:
	if _net == null:
		return
	_connecting = true
	_connected = false
	_set_connection_ui()
	_net.call("connect_to_server")


# ---------------------------------------------------------------------------
# Room
# ---------------------------------------------------------------------------

func _build_room() -> void:
	_state = "room"
	_clear_ui()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(center)
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 26, true, 20)
	card.custom_minimum_size = Vector2(minf(360.0, get_viewport_rect().size.x - 40.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(GardenWidgets.chip(GardenLoc.t("online_room", _lang).to_upper(), GardenTheme.YELLOW_SOFT, GardenTheme.LAVENDER_DEEP))
	v.add_child(GardenWidgets.caption(GardenLoc.t("online_room_code", _lang), GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var code := GardenWidgets.title(_display_code(), 38, GardenTheme.LAVENDER_DEEP, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(code)
	var lang_name := GardenLoc.t("turkish", _lang) if _room_lang == "tr" else GardenLoc.t("english", _lang)
	v.add_child(GardenWidgets.caption("%s: %s" % [GardenLoc.t("online_room_lang", _lang), lang_name], GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.divider())
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for p_v in _players:
		var p: Dictionary = p_v
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := GardenWidgets.bold_label("+", 15, GardenTheme.PINK_DEEP)
		row.add_child(dot)
		var pname := str(p.get("name", GardenLoc.t("online_opponent", _lang)))
		var name_label := GardenWidgets.bold_label(pname if not pname.is_empty() else GardenLoc.t("online_opponent", _lang), 15, GardenTheme.INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if str(p.get("id", "")) == _player_id:
			row.add_child(GardenWidgets.chip(GardenLoc.t("online_you", _lang), GardenTheme.LAVENDER_SOFT, GardenTheme.LAVENDER_DEEP))
		else:
			row.add_child(GardenWidgets.chip(GardenLoc.t("online_ready", _lang), GardenTheme.MINT, GardenTheme.MINT_DEEP.darkened(0.2)))
		list.add_child(row)
	if _players.size() < 2:
		list.add_child(GardenWidgets.caption(GardenLoc.t("online_waiting", _lang), GardenTheme.MUTED))
	else:
		list.add_child(GardenWidgets.caption(GardenLoc.t("online_wait_start", _lang), GardenTheme.MUTED))
	v.add_child(list)
	v.add_child(GardenWidgets.divider())
	v.add_child(GardenWidgets.caption(GardenLoc.t("online_copy_hint", _lang), GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.caption(GardenLoc.t("online_lang_locked_room", _lang), GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var leave := GardenWidgets.button(GardenLoc.t("online_leave", _lang), "ghost", 44)
	leave.pressed.connect(_confirm_leave)
	v.add_child(leave)
	_focus_target = leave


func _display_code() -> String:
	var code := _room_code.strip_edges()
	if code.is_empty():
		return "····"
	if code.is_valid_int() and code.length() < 4:
		return code.pad_zeros(4)
	return code


# ---------------------------------------------------------------------------
# Match start / countdown
# ---------------------------------------------------------------------------

func _on_game_started(starts_at: int, ends_at: int, levels: Array, players: Array) -> void:
	_joining = false
	_player_from_net()
	_players = _normalise_players(players)
	_infer_self_id()
	_resolve_levels(levels)
	if _levels.is_empty():
		_state = "match"
		_build_match_error()
		return
	_starts_at = _epoch_ms(starts_at)
	_ends_at = _epoch_ms(ends_at)
	_room_lang = str(_net.get("room_language")) if _net != null else _room_lang
	if not _room_lang in ["tr", "en"]:
		_room_lang = _lang
	_lang = _room_lang
	_level_index = 0
	# Word 0 of every chain is given by the server.
	_word_index = 1
	_typed = ""
	_revealed = 1
	_answer_pending = false
	_awaiting_finish = false
	_time_up = false
	_finish_open = false
	_score_self = 0
	_score_opp = 0
	_update_scores_from_players()
	_match_started = _starts_at <= 0 or _server_now() >= _starts_at
	_state = "match" if _match_started else "countdown"
	_build_match()


func _resolve_levels(raw: Variant) -> void:
	_levels = []
	if raw is Dictionary and (raw as Dictionary).has("levels"):
		raw = (raw as Dictionary)["levels"]
	if not (raw is Array):
		return
	for item in raw:
		if item is Dictionary:
			var d: Dictionary = item
			if d.has("words"):
				_levels.append(GardenApi.normalize_level(d, _room_lang))
			else:
				var lv := GardenApi.get_level(_room_lang, d.get("id", ""))
				if not lv.is_empty():
					_levels.append(lv)
		else:
			var lv2 := GardenApi.get_level(_room_lang, item)
			if not lv2.is_empty():
				_levels.append(lv2)


func _build_match() -> void:
	_clear_ui()
	_state = "match" if _match_started else "countdown"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_bottom", 2)
	_ui_root.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	box.add_child(_match_header())
	_round_strip = HBoxContainer.new()
	_round_strip.add_theme_constant_override("separation", 5)
	_round_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_round_strip)
	_rebuild_round_strip()

	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = 100
	box.add_child(_scroll)
	var chain_margin := MarginContainer.new()
	chain_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chain_margin.add_theme_constant_override("margin_top", 2)
	chain_margin.add_theme_constant_override("margin_bottom", 3)
	_scroll.add_child(chain_margin)
	_chain_view = GardenChainView.new()
	chain_margin.add_child(_chain_view)
	_rebuild_chain()

	var emote_row := HBoxContainer.new()
	emote_row.add_theme_constant_override("separation", 4)
	emote_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in EMOTES:
		var b := GardenWidgets.small_button(GardenLoc.t("emote_" + str(id), _room_lang), "ghost", 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_send_emote.bind(str(id)))
		emote_row.add_child(b)
	box.add_child(emote_row)

	_keyboard = GardenKeyboard.new()
	_keyboard.setup(_room_lang)
	_keyboard.letter_pressed.connect(_on_letter)
	_keyboard.backspace_pressed.connect(_on_backspace)
	_keyboard.submit_pressed.connect(_on_submit)
	box.add_child(_keyboard)
	_keyboard.set_enabled(_match_started and not _time_up and not _awaiting_finish)

	if not _match_started:
		_build_countdown_overlay()
	_update_countdown()
	_update_timer()


func _build_countdown_overlay() -> void:
	_countdown_layer = Control.new()
	_countdown_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(_countdown_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.10, 0.22, 0.34)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_countdown_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := GardenWidgets.panel(GardenTheme.SURFACE, 30, true, 26)
	panel.custom_minimum_size = Vector2(minf(300.0, get_viewport_rect().size.x - 48.0), 0)
	center.add_child(panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	cv.add_child(GardenWidgets.caption(GardenLoc.t("online_countdown", _room_lang), GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	_countdown_label = GardenWidgets.title("3", 64, GardenTheme.LAVENDER_DEEP, HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(_countdown_label)
	cv.add_child(GardenWidgets.caption(GardenLoc.t("online_go", _room_lang) + "!", GardenTheme.PINK_DEEP, HORIZONTAL_ALIGNMENT_CENTER))
	panel.add_child(cv)


func _build_match_error() -> void:
	_clear_ui()
	_state = "match"
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(center)
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 24, true, 20)
	card.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 42.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.add_child(GardenWidgets.title(GardenLoc.t("content_missing", _room_lang), 19))
	v.add_child(GardenWidgets.caption(GardenLoc.t("content_missing_body", _room_lang)))
	var home := GardenWidgets.button(GardenLoc.t("online_return", _room_lang), "ghost", 44)
	home.pressed.connect(_leave_home)
	v.add_child(home)
	card.add_child(v)


func _match_header() -> Control:
	var panel := GardenWidgets.panel(GardenTheme.SURFACE, 18, true, 11)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 7)
	_timer_label = GardenWidgets.title("0:00", 21, GardenTheme.INK)
	top.add_child(_timer_label)
	var tcap := GardenWidgets.caption(GardenLoc.t("online_remaining", _room_lang), GardenTheme.MUTED)
	tcap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(tcap)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var round_chip := GardenWidgets.panel(GardenTheme.LAVENDER_SOFT, 14, false, 10)
	var round_row := HBoxContainer.new()
	round_row.add_theme_constant_override("separation", 4)
	round_chip.add_child(round_row)
	_round_label = GardenWidgets.bold_label("", 13, GardenTheme.LAVENDER_DEEP)
	round_row.add_child(_round_label)
	top.add_child(round_chip)
	var leave := GardenWidgets.text_button(GardenLoc.t("online_leave", _room_lang), GardenTheme.PINK_DEEP)
	leave.add_theme_font_size_override("font_size", 12)
	leave.pressed.connect(_confirm_leave)
	top.add_child(leave)
	v.add_child(top)

	var scores := HBoxContainer.new()
	scores.add_theme_constant_override("separation", 6)
	var self_card := GardenWidgets.panel(GardenTheme.LAVENDER_SOFT, 14, false, 9)
	self_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 1)
	_self_name_label = GardenWidgets.caption(GardenLoc.t("online_you", _room_lang), GardenTheme.LAVENDER_DEEP)
	sv.add_child(_self_name_label)
	_score_self_label = GardenWidgets.title("0", 24, GardenTheme.LAVENDER_DEEP)
	sv.add_child(_score_self_label)
	_self_bar = GardenWidgets.progress_bar(0, 1, GardenTheme.LAVENDER_DEEP, 5)
	sv.add_child(_self_bar)
	self_card.add_child(sv)
	scores.add_child(self_card)
	var opp_card := GardenWidgets.panel(GardenTheme.PINK_SOFT, 14, false, 9)
	opp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 1)
	_opp_name_label = GardenWidgets.caption(GardenLoc.t("online_opponent", _room_lang), GardenTheme.PINK_DEEP)
	ov.add_child(_opp_name_label)
	_score_opp_label = GardenWidgets.title("0", 24, GardenTheme.PINK_DEEP.darkened(0.15))
	ov.add_child(_score_opp_label)
	_opp_bar = GardenWidgets.progress_bar(0, 1, GardenTheme.PINK_DEEP, 5)
	ov.add_child(_opp_bar)
	opp_card.add_child(ov)
	scores.add_child(opp_card)
	v.add_child(scores)
	_match_feedback = GardenWidgets.caption("", GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_match_feedback.custom_minimum_size.y = 14
	v.add_child(_match_feedback)
	_update_match_header()
	return panel


func _rebuild_round_strip() -> void:
	if _round_strip == null:
		return
	GardenWidgets.clear_children(_round_strip)
	var count := maxi(3, _levels.size())
	for i in count:
		var completed := i < _level_index
		var current := i == _level_index
		var bg := GardenTheme.LOCKED
		var fg := GardenTheme.LOCKED_INK
		if completed:
			bg = GardenTheme.MINT
			fg = GardenTheme.MINT_DEEP.darkened(0.25)
		elif current:
			bg = GardenTheme.LAVENDER_SOFT
			fg = GardenTheme.LAVENDER_DEEP
		var label := str(i + 1)
		var chip: PanelContainer
		if completed:
			chip = GardenWidgets.chip(label, bg, fg, GardenPaint.CheckIcon.new())
		else:
			chip = GardenWidgets.chip(label, bg, fg)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_round_strip.add_child(chip)


func _rebuild_chain() -> void:
	if _chain_view == null:
		return
	var lv := _current_level()
	if lv.is_empty():
		return
	_chain_view.setup(lv, _word_index, _typed, _revealed, "", false)
	_chain_view.scroll_to_current(_scroll)
	_update_match_header()


func _current_level() -> Dictionary:
	if _level_index < 0 or _level_index >= _levels.size():
		return {}
	return _levels[_level_index]


func _current_word() -> String:
	var lv := _current_level()
	if lv.is_empty():
		return ""
	var words: Array = lv.get("words", [])
	if _word_index < 0 or _word_index >= words.size():
		return ""
	return str((words[_word_index] as Dictionary).get("word", ""))


func _total_words() -> int:
	var total := 0
	for lv in _levels:
		total += maxi(0, (lv.get("words", []) as Array).size() - 1)
	return total


func _update_match_header() -> void:
	if _score_self_label == null:
		return
	var self_p := _find_self()
	var opp_p := _find_opponent()
	_score_self_label.text = str(_score_self)
	_score_opp_label.text = str(_score_opp)
	if not self_p.is_empty():
		var sn := str(self_p.get("name", ""))
		_self_name_label.text = GardenLoc.t("online_you", _room_lang) + ((" · " + sn) if not sn.is_empty() else "")
	if not opp_p.is_empty():
		var on := str(opp_p.get("name", ""))
		_opp_name_label.text = GardenLoc.t("online_opponent", _room_lang) + ((" · " + on) if not on.is_empty() else "")
	var total := maxi(POINTS_PER_WORD, _total_words() * POINTS_PER_WORD)
	_self_bar.max_value = total
	_self_bar.value = clampi(_score_self, 0, total)
	_opp_bar.max_value = total
	_opp_bar.value = clampi(_score_opp, 0, total)
	if _round_label != null:
		_round_label.text = GardenLoc.f("online_round", [mini(_level_index + 1, maxi(1, _levels.size())), maxi(1, _levels.size())], _room_lang)


func _update_timer() -> void:
	if _timer_label == null:
		return
	if not _match_started:
		_timer_label.text = "0:03"
		if _countdown_label != null:
			_update_countdown()
		return
	var remaining := 0.0
	if _ends_at > 0:
		remaining = maxf(0.0, float(_ends_at - _server_now()) / 1000.0)
	var secs := int(ceil(remaining))
	_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	if _ends_at > 0 and remaining <= 0.0 and not _time_up and not _finish_open:
		_time_up = true
		if _keyboard != null:
			_keyboard.set_enabled(false)
		_show_match_feedback(GardenLoc.t("online_time_up", _room_lang), GardenTheme.DANGER, 6.0)


func _update_countdown() -> void:
	if _countdown_layer == null or _countdown_label == null:
		return
	var remaining := float(_starts_at - _server_now()) / 1000.0
	var secs := int(ceil(remaining))
	if secs <= 0:
		_countdown_label.text = GardenLoc.t("online_go", _room_lang)
	elif secs > 3:
		_countdown_label.text = "3"
	else:
		_countdown_label.text = str(secs)


func _start_match_now() -> void:
	if _match_started:
		return
	_match_started = true
	_state = "match"
	if _countdown_layer != null:
		_countdown_layer.visible = false
	if _keyboard != null:
		_keyboard.set_enabled(not _time_up and not _awaiting_finish)
	_update_timer()


func _process(_delta: float) -> void:
	if _state == "leaving":
		return
	if _state in ["countdown", "match"]:
		if not _match_started:
			if _starts_at > 0 and _server_now() >= _starts_at:
				_start_match_now()
			else:
				_update_countdown()
		if _match_started:
			_update_timer()


# ---------------------------------------------------------------------------
# Answers / emotes
# ---------------------------------------------------------------------------

func _on_letter(letter: String) -> void:
	if not _can_type():
		return
	var expected := GardenApi.upper(_current_word(), _room_lang)
	if _revealed + _typed.length() >= expected.length():
		return
	_typed += letter
	if _chain_view != null:
		_chain_view.update_input(_typed, _revealed)


func _on_backspace() -> void:
	if not _can_type():
		return
	if _typed.is_empty():
		return
	_typed = _typed.substr(0, _typed.length() - 1)
	if _chain_view != null:
		_chain_view.update_input(_typed, _revealed)


func _can_type() -> bool:
	return _state in ["countdown", "match"] and _match_started and not _time_up \
		and not _answer_pending and not _awaiting_finish and not _finish_open


func _on_submit() -> void:
	if not _can_type():
		return
	var expected := GardenApi.upper(_current_word(), _room_lang)
	if expected.is_empty():
		return
	if _revealed + _typed.length() < expected.length():
		_show_match_feedback(GardenLoc.t("incomplete", _room_lang), GardenTheme.DANGER)
		if _chain_view != null:
			_chain_view.shake()
		return
	var built := expected.substr(0, _revealed) + _typed
	if _net == null:
		return
	_answer_pending = true
	_answer_serial += 1
	var serial := _answer_serial
	if _keyboard != null:
		_keyboard.set_enabled(false)
	if not bool(_net.call("send_answer", built, _level_index, _word_index)):
		_answer_pending = false
		if _keyboard != null:
			_keyboard.set_enabled(_can_type())
		return
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if serial != _answer_serial or not is_instance_valid(self):
			return
		if _answer_pending:
			_answer_pending = false
			if _keyboard != null:
				_keyboard.set_enabled(_can_type())
			_show_match_feedback(GardenLoc.t("err_timeout", _room_lang), GardenTheme.DANGER)
			if app != null:
				app.toast(GardenLoc.t("err_timeout", _room_lang)))


func _send_emote(id: String) -> void:
	if _state not in ["match", "countdown"] or _finish_open or _net == null:
		return
	_net.call("send_emote", id)


func _show_match_feedback(text: String, color: Color, hold: float = 1.3) -> void:
	if _match_feedback == null or not is_instance_valid(_match_feedback):
		return
	_match_feedback_serial += 1
	var serial := _match_feedback_serial
	_match_feedback.text = text
	_match_feedback.add_theme_color_override("font_color", color)
	_match_feedback.modulate.a = 1.0
	var timer := get_tree().create_timer(hold)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self) or not is_instance_valid(_match_feedback) or serial != _match_feedback_serial:
			return
		var tween := _match_feedback.create_tween()
		tween.tween_property(_match_feedback, "modulate:a", 0.0, 0.25))


# ---------------------------------------------------------------------------
# Network events
# ---------------------------------------------------------------------------

func _on_room_updated(code: String, language: String, players: Array, status: String) -> void:
	_joining = false
	_joining_serial += 1
	_room_code = code
	if language in ["tr", "en"]:
		_room_lang = language
		_lang = language
		if GardenApi.lang() != language:
			GardenApi.set_lang(language)
			if app != null:
				app.call("_update_topbar_texts")
				app.call("_rebuild_language_toggle")
	_room_status = status
	_players = _normalise_players(players)
	_infer_self_id()
	_update_scores_from_players()
	if _state in ["countdown", "match", "finish"]:
		_update_match_header()
		return
	_state = "room"
	_build_room()


func _on_answer_result(correct: bool, level_index: int, word_index: int, score: int, finished: bool) -> void:
	if _state != "match" and _state != "countdown":
		return
	_answer_serial += 1
	_answer_pending = false
	_score_self = score
	_update_match_header()
	if not correct:
		_typed = ""
		if _chain_view != null:
			_chain_view.update_input(_typed, _revealed)
			_chain_view.shake()
		_show_match_feedback(GardenLoc.t("wrong", _room_lang), GardenTheme.DANGER)
		GardenApi.play_sound("wrong")
		if _keyboard != null:
			_keyboard.set_enabled(_can_type())
		return
	GardenApi.play_sound("correct")
	_show_match_feedback(GardenLoc.t("correct", _room_lang), GardenTheme.MINT_DEEP)
	_typed = ""
	_revealed = 1
	if finished or level_index < 0 or word_index < 0:
		_awaiting_finish = true
		_word_index = (_current_level().get("words", []) as Array).size()
		_rebuild_chain()
		if _keyboard != null:
			_keyboard.set_enabled(false)
		_show_match_feedback(GardenLoc.t("online_wait_finish", _room_lang), GardenTheme.LAVENDER_DEEP, 8.0)
		return
	_level_index = level_index
	_word_index = word_index
	if _level_index >= _levels.size():
		return
	_rebuild_round_strip()
	_rebuild_chain()
	if _keyboard != null:
		_keyboard.set_enabled(_can_type())


func _on_score_updated(players: Array) -> void:
	_players = _normalise_players(players)
	_update_scores_from_players()
	_update_match_header()


func _on_emote_received(player_id: String, id: String) -> void:
	if id.is_empty():
		return
	var pname := GardenLoc.t("online_opponent", _room_lang)
	for p_v in _players:
		var p: Dictionary = p_v
		if str(p.get("id", "")) == player_id:
			pname = str(p.get("name", pname))
			break
	var text := GardenLoc.t("emote_" + id, _room_lang)
	if app != null:
		app.toast("%s: %s" % [pname, text], 1.8)


func _on_game_finished(players: Array, reason: String) -> void:
	if not players.is_empty():
		_players = _normalise_players(players)
	_update_scores_from_players()
	_state = "finish"
	if _keyboard != null:
		_keyboard.set_enabled(false)
	_show_finish(reason)


func _on_error_received(code: String, message: String) -> void:
	_joining = false
	_joining_serial += 1
	_answer_pending = false
	var msg := GardenLoc.status_label(code, _lang)
	# Never display untranslated server diagnostics as player-facing UI.
	if app != null:
		app.toast(msg)
	_update_create_label()
	if _keyboard != null:
		_keyboard.set_enabled(_can_type())
	if _state == "lobby":
		_set_connection_ui()
		if _join_note != null:
			_join_note.text = msg
			_join_note.add_theme_color_override("font_color", GardenTheme.DANGER)


func _normalise_players(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				out.append(_player_dict(item, ""))
			elif item is String:
				out.append({"id": str(item), "name": str(item), "score": 0, "connected": true})
	elif raw is Dictionary:
		var d: Dictionary = raw
		if d.has("id") or d.has("name"):
			out.append(_player_dict(d, ""))
		else:
			for key in d.keys():
				var val: Variant = d[key]
				if val is Dictionary:
					out.append(_player_dict(val, str(key)))
				elif typeof(val) in [TYPE_INT, TYPE_FLOAT]:
					out.append({"id": str(key), "name": str(key), "score": int(val), "connected": true})
	return out


func _player_dict(d: Dictionary, fallback_id: String) -> Dictionary:
	return {
		"id": str(d.get("id", d.get("player_id", fallback_id))),
		"name": str(d.get("name", d.get("nickname", ""))),
		"score": int(d.get("score", d.get("points", 0))),
		"connected": bool(d.get("connected", true)),
	}


func _find_self() -> Dictionary:
	for p_v in _players:
		var p: Dictionary = p_v
		if str(p.get("id", "")) == _player_id:
			return p
	return {}


func _find_opponent() -> Dictionary:
	for p_v in _players:
		var p: Dictionary = p_v
		if str(p.get("id", "")) != _player_id:
			return p
	return {}


func _infer_self_id() -> void:
	_player_from_net()
	if not _player_id.is_empty():
		return
	if _players.size() == 1:
		_player_id = str((_players[0] as Dictionary).get("id", ""))
		return
	var my_name := GardenApi.player_name().strip_edges().to_lower()
	if not my_name.is_empty():
		for p_v in _players:
			var p: Dictionary = p_v
			if str(p.get("name", "")).strip_edges().to_lower() == my_name:
				_player_id = str(p.get("id", ""))
				return
	if not _players.is_empty():
		_player_id = str((_players[0] as Dictionary).get("id", ""))


func _update_scores_from_players() -> void:
	var self_p := _find_self()
	var opp_p := _find_opponent()
	if not self_p.is_empty():
		_score_self = int(self_p.get("score", _score_self))
	if not opp_p.is_empty():
		_score_opp = int(opp_p.get("score", _score_opp))


# ---------------------------------------------------------------------------
# Finish / connection lost
# ---------------------------------------------------------------------------

func _show_finish(reason: String) -> void:
	if _finish_layer != null and is_instance_valid(_finish_layer):
		if _finish_layer.get_parent() == _ui_root:
			_ui_root.remove_child(_finish_layer)
		_finish_layer.queue_free()
	_finish_open = true
	_finish_layer = Control.new()
	_finish_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(_finish_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.2, 0.44)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_finish_layer.add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	var flower := GardenPaint.ChainIcon.new()
	flower.custom_minimum_size = Vector2(74, 78)
	flower.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(flower)

	var my := _score_self
	var their := _score_opp
	var opponent_gone := reason.contains("opponent_left") or reason.contains("opponent_disconnected") or reason.contains("left")
	var winner_text := ""
	if opponent_gone:
		winner_text = GardenLoc.t("online_you_win", _room_lang)
	elif my > their:
		winner_text = GardenLoc.t("online_you_win", _room_lang)
	elif my < their:
		winner_text = GardenLoc.t("online_you_lose", _room_lang)
	else:
		winner_text = GardenLoc.t("online_draw", _room_lang)
	if opponent_gone:
		v.add_child(GardenWidgets.caption(GardenLoc.t("online_opponent_left", _room_lang), GardenTheme.PINK_DEEP, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.title(winner_text, 26, GardenTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.caption(GardenLoc.t("online_final", _room_lang), GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.divider())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	for p_v in _players:
		var p: Dictionary = p_v
		var is_self := str(p.get("id", "")) == _player_id
		var row := GardenWidgets.panel(GardenTheme.LAVENDER_SOFT if is_self else GardenTheme.PINK_SOFT, 13, false, 10)
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 7)
		var nm := str(p.get("name", ""))
		if nm.is_empty():
			nm = GardenLoc.t("online_you", _room_lang) if is_self else GardenLoc.t("online_opponent", _room_lang)
		var nl := GardenWidgets.bold_label(nm, 14, GardenTheme.INK)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(nl)
		rh.add_child(GardenWidgets.title(str(int(p.get("score", 0))), 20, GardenTheme.LAVENDER_DEEP if is_self else GardenTheme.PINK_DEEP))
		row.add_child(rh)
		rows.add_child(row)
	if _players.is_empty():
		rows.add_child(GardenWidgets.label("%d — %d" % [_score_self, _score_opp], 14, GardenTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(rows)
	v.add_child(GardenWidgets.caption(GardenLoc.t("online_sub", _room_lang), GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var home := GardenWidgets.button(GardenLoc.t("online_return", _room_lang), "primary", 48)
	home.pressed.connect(func() -> void:
		if is_instance_valid(app):
			app.goto_home())
	v.add_child(home)
	GardenWidgets.focus(home)


func _show_connection_lost(reason: String) -> void:
	if _finish_open:
		return
	_state = "disconnected"
	if _keyboard != null:
		_keyboard.set_enabled(false)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.2, 0.48)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 26, true, 20)
	card.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 44.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	v.add_child(GardenWidgets.title(GardenLoc.t("online_disconnected", _room_lang), 22))
	v.add_child(GardenWidgets.label(GardenLoc.t("err_offline", _room_lang), 14, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	if reason == "timeout":
		v.add_child(GardenWidgets.caption(GardenLoc.t("err_timeout", _room_lang)))
	v.add_child(GardenWidgets.caption(GardenLoc.t("online_offline_body", _room_lang), GardenTheme.MUTED))
	var retry := GardenWidgets.button(GardenLoc.t("online_retry", _room_lang), "primary", 44)
	retry.pressed.connect(func() -> void:
		if is_instance_valid(layer):
			layer.get_parent().remove_child(layer)
			layer.queue_free()
		_state = "lobby"
		_connecting = true
		_connected = false
		_build_lobby()
		if _net != null:
			_net.call("connect_to_server"))
	v.add_child(retry)
	var home := GardenWidgets.button(GardenLoc.t("online_return", _room_lang), "ghost", 42)
	home.pressed.connect(func() -> void:
		if is_instance_valid(layer):
			layer.get_parent().remove_child(layer)
			layer.queue_free()
		if is_instance_valid(app):
			app.goto_home())
	v.add_child(home)
	card.add_child(v)
	GardenWidgets.focus(retry)


# ---------------------------------------------------------------------------
# Navigation / language
# ---------------------------------------------------------------------------

func _confirm_leave() -> void:
	if app == null:
		return
	if _state == "room":
		app.show_confirm(GardenLoc.t("online_leave_confirm", _room_lang), "",
				GardenLoc.t("online_leave", _room_lang), _leave_home)
	else:
		app.show_confirm(GardenLoc.t("online_leave_confirm", _room_lang), GardenLoc.t("online_leave_match", _room_lang),
				GardenLoc.t("online_leave", _room_lang), _leave_home)


func _leave_home() -> void:
	_state = "leaving"
	if _keyboard != null:
		_keyboard.set_enabled(false)
	if _net != null and _net.has_method("is_open") and bool(_net.call("is_open")):
		_net.call("leave_room")
	var tree := get_tree()
	var timer := tree.create_timer(0.16)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(app):
			app.force_back())


func handle_back() -> bool:
	match _state:
		"lobby", "leaving", "disconnected":
			return false
		"room", "countdown", "match":
			_confirm_leave()
			return true
		"finish":
			_leave_home()
			return true
	return false


func on_language_changed(code: String) -> void:
	_lang = "en" if code == "en" else "tr"
	if _state == "lobby":
		_build_lobby()


func language_lock_reason() -> String:
	if _state in ["room", "countdown", "match", "finish"]:
		return GardenLoc.t("online_lang_locked_room", _room_lang)
	return ""


func initial_focus() -> Control:
	return _focus_target


# ---------------------------------------------------------------------------
# Time helpers
# ---------------------------------------------------------------------------

func _epoch_ms(value: Variant) -> int:
	var n := 0
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		n = int(value)
	elif typeof(value) == TYPE_STRING and str(value).is_valid_int():
		n = int(value)
	if n > 0 and n < 100000000000:
		n *= 1000
	return n


func _server_now() -> int:
	if _net != null and _net.has_method("server_now_msec"):
		return int(_net.call("server_now_msec"))
	return int(Time.get_unix_time_from_system() * 1000.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if app != null and app.has_method("_modal_open") and bool(app.call("_modal_open")):
		return
	if not _can_type():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
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
		var up := GardenApi.upper(ch, _room_lang)
		var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		if _room_lang == "tr":
			alphabet = "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"
		if up.length() == 1 and alphabet.contains(up):
			get_viewport().set_input_as_handled()
			_on_letter(up)
