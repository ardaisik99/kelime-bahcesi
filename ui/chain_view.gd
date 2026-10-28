class_name GardenChainView
extends VBoxContainer

## Word-chain renderer.
##
## Two sources are supported:
##   * a live core/game_session.gd snapshot (solo + party), rendered per letter
##     from the authoritative masks/locks;
##   * the legacy prefix mode (online) where the server owns progress and the
##     view only knows "revealed prefix" + typed suffix.

signal card_tapped(index: int)

var level: Dictionary = {}
var current_index := 0
var typed := ""
var revealed := 1
var hint_text := ""
var show_links := false
var party_style := false
var session: Variant = null

var _input_row: HBoxContainer
var _current_card: PanelContainer
var _words: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func setup(level_data: Dictionary, current: int, current_typed: String = "",
		current_revealed: int = 1, current_hint: String = "", links: bool = false) -> void:
	session = null
	level = level_data
	current_index = current
	typed = current_typed
	revealed = maxi(1, current_revealed)
	hint_text = current_hint
	show_links = links
	_words = level.get("words", [])
	rebuild()


## Session-driven mode: masks, locked letters and hints come from the core.
func setup_session(session_ref: Variant, level_data: Dictionary, links: bool = false,
		party: bool = false) -> void:
	var same_word: bool = session == session_ref and session_ref != null and current_index == int(session_ref.active_word_index()) and not _words.is_empty()
	var same_hint: bool = hint_text == str(session_ref.get_active_hint()) if session_ref != null else false
	session = session_ref
	level = level_data
	_words = level_data.get("words", [])
	show_links = links
	party_style = party
	if session != null:
		current_index = int(session.active_word_index())
		hint_text = str(session.get_active_hint())
		typed = ""
		revealed = 0
	if same_word and same_hint and not party:
		_fill_session_boxes(current_index)
		return
	rebuild()


func rebuild() -> void:
	GardenWidgets.clear_children(self)
	_input_row = null
	_current_card = null
	if _words.is_empty():
		var empty := GardenWidgets.panel(GardenTheme.CARD, 20, true, 20)
		empty.add_child(GardenWidgets.label(GardenLoc.t("loading", GardenApi.lang()), 15, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
		add_child(empty)
		return
	if session != null:
		_rebuild_from_session()
		return
	for i in _words.size():
		if i < current_index:
			add_child(_solved_card(i))
		elif i == current_index:
			_current_card = _current_card_node(i)
			add_child(_current_card)
		else:
			add_child(_future_card(i))


func _rebuild_from_session() -> void:
	var total := _words.size()
	var active := int(session.active_word_index())
	current_index = active
	for i in total:
		if party_style or bool(session.is_word_solved(i)):
			add_child(_solved_card(i))
		elif i == active:
			_current_card = _active_card_session(i)
			add_child(_current_card)
		else:
			add_child(_future_card(i))


func current_word() -> String:
	if session != null:
		return str(session.current)
	if current_index < 0 or current_index >= _words.size():
		return ""
	return str(_words[current_index].get("word", ""))


func current_hint() -> String:
	if current_index < 0 or current_index >= _words.size():
		return ""
	return str(_words[current_index].get("hint", ""))


func current_link() -> String:
	if current_index < 0 or current_index >= _words.size():
		return ""
	return str(_words[current_index].get("link", ""))


func update_input(new_typed: String, new_revealed: int) -> void:
	typed = new_typed
	revealed = maxi(1, new_revealed)
	if session != null:
		rebuild()
		return
	_refresh_boxes()


func update_from_session() -> void:
	if session == null:
		return
	hint_text = str(session.get_active_hint())
	rebuild()


func shake() -> void:
	GardenWidgets.shake(_input_row if _input_row != null else _current_card)


func scroll_to_current(scroll: ScrollContainer) -> void:
	if scroll == null or _current_card == null:
		return
	# Keep the preceding word visible: it is the clue for the active word.
	var target: Control = _current_card
	if current_index > 0 and current_index - 1 < get_child_count():
		target = get_child(current_index - 1) as Control
	var target_ref: WeakRef = weakref(target)
	var scroll_ref: WeakRef = weakref(scroll)
	var tree: SceneTree = get_tree()
	var cb := func() -> void:
		# Container sorting must finish before measuring its visible area.
		await tree.process_frame
		var previous: Control = target_ref.get_ref()
		var container: ScrollContainer = scroll_ref.get_ref()
		if container != null and previous != null and previous.is_inside_tree():
			container.ensure_control_visible(previous)
	cb.call_deferred()


# ---------------------------------------------------------------------------
# Cards
# ---------------------------------------------------------------------------

func _solved_card(index: int) -> PanelContainer:
	var word := str(_words[index].get("word", ""))
	var link := str(_words[index].get("link", ""))
	var p := GardenWidgets.panel(GardenTheme.LAVENDER_SOFT, 20, false, 14, GardenTheme.MINT, 1)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var check := GardenPaint.CheckIcon.new()
	check.custom_minimum_size = Vector2(22, 22)
	row.add_child(check)
	var l := GardenWidgets.bold_label(GardenApi.upper(word), 20, GardenTheme.MINT_DEEP.darkened(0.25), HORIZONTAL_ALIGNMENT_LEFT, true)
	l.name = "SolvedWord"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if party_style:
		var idx := GardenWidgets.caption(str(index + 1), GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(idx)
	v.add_child(row)
	if show_links and not link.is_empty():
		var example := GardenWidgets.label(link, 13, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
		example.add_theme_font_override("font", GardenTheme.bold_font())
		v.add_child(example)
	p.add_child(v)
	p.gui_input.connect(_on_card_input.bind(index))
	_ignore_children(p)
	return p


func _current_card_node(index: int) -> PanelContainer:
	var word := str(_words[index].get("word", ""))
	var p := GardenWidgets.panel(GardenTheme.CARD, 22, true, 16, GardenTheme.LAVENDER, 2)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_card_head(index))
	v.add_child(GardenWidgets.bold_label(GardenLoc.t("solve_word", GardenApi.lang()), 15, GardenTheme.MUTED))
	_input_row = HBoxContainer.new()
	_input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_input_row.add_theme_constant_override("separation", 4)
	_input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_row.custom_minimum_size.y = 46
	v.add_child(_input_row)
	_fill_prefix_boxes(word)
	var bubble := _hint_bubble()
	if bubble != null:
		v.add_child(bubble)
	p.add_child(v)
	p.gui_input.connect(_on_card_input.bind(index))
	_ignore_children(p)
	return p


func _active_card_session(index: int) -> PanelContainer:
	var p := GardenWidgets.panel(GardenTheme.CARD, 22, true, 16, GardenTheme.LAVENDER, 2)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_card_head(index))
	v.add_child(GardenWidgets.bold_label(GardenLoc.t("solve_word", GardenApi.lang()), 15, GardenTheme.MUTED))
	_input_row = HBoxContainer.new()
	_input_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_input_row.add_theme_constant_override("separation", 4)
	_input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_row.custom_minimum_size.y = 46
	v.add_child(_input_row)
	_fill_session_boxes(index)
	var bubble := _hint_bubble()
	if bubble != null:
		v.add_child(bubble)
	p.add_child(v)
	p.gui_input.connect(_on_card_input.bind(index))
	_ignore_children(p)
	return p


func _card_head(index: int) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var chip := GardenWidgets.chip("%d / %d" % [index + 1, _words.size()], GardenTheme.LAVENDER_SOFT, GardenTheme.LAVENDER_DEEP)
	head.add_child(chip)
	if party_style:
		head.add_child(GardenWidgets.chip(GardenLoc.t("party_badge", GardenApi.lang()), GardenTheme.PINK_SOFT, GardenTheme.PINK_DEEP))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if not hint_text.is_empty():
		var hint_chip := GardenWidgets.chip(GardenLoc.t("hint_prefix", GardenApi.lang()), GardenTheme.YELLOW_SOFT, GardenTheme.LAVENDER_DEEP)
		head.add_child(hint_chip)
	return head


func _hint_bubble() -> Control:
	if hint_text.is_empty():
		return null
	var bubble := GardenWidgets.panel(GardenTheme.YELLOW_SOFT, 14, false, 11)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	var bulb := GardenPaint.icon(7, 22)
	# Static atlas icon.
	h.add_child(bulb)
	var hint_l := GardenWidgets.label(hint_text, 14, GardenTheme.LAVENDER_DEEP, HORIZONTAL_ALIGNMENT_LEFT, true)
	hint_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(hint_l)
	bubble.add_child(h)
	return bubble


func _future_card(index: int) -> PanelContainer:
	var p := GardenWidgets.panel(Color("f1edf7"), 20, false, 14, GardenTheme.LINE, 1)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	var lock := GardenPaint.LockIcon.new()
	lock.custom_minimum_size = Vector2(21, 21)
	row.add_child(lock)
	var title := GardenWidgets.bold_label("%s %d" % [GardenLoc.t("chain_title", GardenApi.lang()), index + 1], 15, GardenTheme.LOCKED_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var dots := GardenWidgets.label("• • •", 15, GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(dots)
	p.add_child(row)
	p.gui_input.connect(_on_card_input.bind(index))
	_ignore_children(p)
	return p


# ---------------------------------------------------------------------------
# Letter boxes
# ---------------------------------------------------------------------------

func _cell_style(filled: bool, locked: bool, cursor: bool) -> Dictionary:
	var bg := GardenTheme.CARD
	var fg := GardenTheme.INK
	var border := GardenTheme.LINE
	var border_w := 1
	if locked:
		bg = GardenTheme.YELLOW_SOFT
		fg = GardenTheme.LAVENDER_DEEP
		border = GardenTheme.YELLOW
	elif filled:
		bg = GardenTheme.LAVENDER_SOFT
		border = GardenTheme.LAVENDER
	elif cursor:
		bg = Color("fbf8ff")
		border = GardenTheme.LAVENDER_DEEP
		border_w = 2
	return {"bg": bg, "fg": fg, "border": border, "border_w": border_w}


func _add_cell(letter: String, width: float, height: float, font_size: int,
		locked: bool, filled: bool, cursor: bool) -> void:
	if _input_row == null:
		return
	var colors := _cell_style(filled, locked, cursor)
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(width, height)
	var sb := GardenTheme.panel_style(colors["bg"], 9, false, colors["border"], int(colors["border_w"]))
	sb.content_margin_left = 1
	sb.content_margin_right = 1
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	cell.add_theme_stylebox_override("panel", sb)
	var l := GardenWidgets.bold_label(letter, font_size, colors["fg"], HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_child(l)
	_input_row.add_child(cell)


func _box_metrics(count: int) -> Dictionary:
	# Account for the safe-area margins and the active card's padding on phones.
	var viewport_width: float = get_viewport_rect().size.x
	var available := minf(392.0, maxf(180.0, viewport_width - 86.0))
	var gap := 4.0
	var box_w := clampf((available - gap * float(maxi(0, count - 1))) / float(maxi(1, count)), 19.0, 40.0)
	return {
		"width": box_w,
		"height": box_w + 9.0,
		"font": int(clampf(box_w * 0.52, 13.0, 21.0)),
	}


func _fill_prefix_boxes(word: String) -> void:
	if _input_row == null:
		return
	GardenWidgets.clear_children(_input_row)
	var letters := GardenApi.upper_tr(word)
	var count := letters.length()
	if count == 0:
		return
	var metrics := _box_metrics(count)
	revealed = clampi(revealed, 0, count)
	var typed_here := typed.substr(0, maxi(0, count - revealed))
	for i in count:
		var is_revealed := i < revealed
		var typed_index := i - revealed
		var is_typed := typed_index >= 0 and typed_index < typed_here.length()
		var is_cursor := i == revealed + typed_here.length()
		var letter := letters.substr(i, 1) if is_revealed else (typed_here.substr(typed_index, 1) if is_typed else "")
		_add_cell(letter, metrics["width"], metrics["height"], metrics["font"], is_revealed, is_typed, is_cursor)


func _fill_session_boxes(index: int) -> void:
	if _input_row == null or session == null:
		return
	var count := int(session.word_length(index))
	if count <= 0:
		return
	var metrics := _box_metrics(count)
	var cursor_letter := int(session.current_letter_index())
	for i in count:
		var locked := bool(session.is_locked(index, i))
		var letter := str(session.letter_at(index, i))
		var filled := not letter.is_empty()
		var is_cursor := i == cursor_letter and not filled
		var shown := letter if filled else ""
		if i < _input_row.get_child_count():
			var cell := _input_row.get_child(i) as PanelContainer
			var text_label := cell.get_child(0) as Label
			text_label.text = shown
			var state_key := str(locked) + str(filled) + str(is_cursor)
			if str(cell.get_meta("state", "")) != state_key:
				var colors := _cell_style(filled and not locked, locked, is_cursor)
				var sb := GardenTheme.panel_style(colors.bg, 9, false, colors.border, colors.border_w)
				sb.content_margin_left = 1
				sb.content_margin_right = 1
				sb.content_margin_top = 1
				sb.content_margin_bottom = 1
				cell.add_theme_stylebox_override("panel", sb)
				text_label.add_theme_color_override("font_color", colors.fg)
				cell.set_meta("state", state_key)
		else:
			_add_cell(shown, metrics["width"], metrics["height"], metrics["font"], locked, filled and not locked, is_cursor)



func _refresh_boxes() -> void:
	if _input_row == null:
		return
	if session != null:
		_fill_session_boxes(int(session.active_word_index()))
	else:
		_fill_prefix_boxes(current_word())


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			card_tapped.emit(index)


func _ignore_children(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_children(child)


func morph_word(index: int, answer: String, root: String) -> void:
	if index < 0 or index >= get_child_count():
		return
	var label_node := get_child(index).find_child("SolvedWord", true, false) as Label
	if label_node == null:
		return
	label_node.text = GardenApi.upper(answer)
	if GardenApi.reduced_motion() or GardenApi.upper(answer) == GardenApi.upper(root):
		label_node.text = GardenApi.upper(root)
		return
	var tween := label_node.create_tween()
	tween.tween_interval(0.26)
	tween.tween_property(label_node, "modulate:a", 0.0, 0.13).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: label_node.text = GardenApi.upper(root))
	tween.tween_property(label_node, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	await tween.finished
