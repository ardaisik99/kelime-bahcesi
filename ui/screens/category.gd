extends Control

## Category level picker. Levels unlock strictly in order, per language.

var app: Node

var _category: Dictionary = {}
var _focus_target: Control


func setup(params: Dictionary = {}) -> void:
	_category = params.get("category", {})
	_build()


func _build() -> void:
	GardenWidgets.clear_children(self)
	var lang := GardenApi.lang()
	var category_id := str(_category.get("id", ""))
	# Re-read the category so language changes update its display name/colour.
	for cat in GardenApi.categories(lang):
		if str(cat.get("id", "")) == category_id:
			_category = cat
			break
	if _category.is_empty():
		_category = {"id": category_id, "name": GardenLoc.category_name(category_id, lang), "color": "lavender"}

	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
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

	content.add_child(_header(lang, category_id))
	var levels := GardenApi.levels(lang, category_id)
	var completed: Array = []
	for lv in levels:
		completed.append(GardenApi.is_completed(lang, lv.get("id", "")))
	var done := 0
	for c in completed:
		if c:
			done += 1
	if levels.is_empty():
		content.add_child(_empty_state(lang))
	else:
		for i in levels.size():
			var unlocked := bool(completed[i]) or i == 0 or bool(completed[i - 1])
			content.add_child(_level_card(levels[i], i, bool(completed[i]), unlocked, lang))
		var note := GardenWidgets.caption(GardenLoc.t("language_levels_note", lang), GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_CENTER)
		content.add_child(note)
		if done == levels.size() and not levels.is_empty():
			content.add_child(GardenWidgets.caption(GardenLoc.t("all_done_body", lang), GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))


func _header(lang: String, category_id: String) -> Control:
	var color_name := str(_category.get("color", "lavender"))
	var dark := _deep(color_name)
	var soft := _soft(color_name)
	var card := GardenWidgets.panel(soft, 24, true, 18)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var flower := GardenPaint.ChainIcon.new()
	flower.petal_color = dark
	flower.center_color = GardenTheme.CARD
	flower.custom_minimum_size = Vector2(46, 50)
	top.add_child(flower)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	names.add_child(GardenWidgets.caption(GardenLoc.t("home_categories", lang).to_upper(), dark))
	var title := GardenWidgets.title(GardenLoc.category_name(_category, lang), 23)
	names.add_child(title)
	top.add_child(names)
	v.add_child(top)
	var progress := GardenApi.category_progress(lang, category_id)
	var done := int(progress.get("done", 0))
	var total := int(progress.get("total", 0))
	v.add_child(GardenWidgets.label(GardenLoc.f("category_done", [done, total], lang)
			+ "  ·  " + GardenLoc.f("category_levels_count", [total], lang), 12, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(GardenWidgets.progress_bar(done, total, dark, 8))
	v.add_child(GardenWidgets.caption(GardenLoc.t("categories_sub", lang), GardenTheme.MUTED))
	card.add_child(v)
	return card


func _level_card(level: Dictionary, index: int, completed: bool, unlocked: bool, lang: String) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 82)
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var base := GardenTheme.CARD
	if completed:
		base = GardenTheme.LAVENDER_SOFT
	elif not unlocked:
		base = Color("f3f0f7")
	card.add_theme_stylebox_override("normal", GardenTheme.panel_style(base, 20, not completed, GardenTheme.LINE if not completed else GardenTheme.MINT, 1))
	card.add_theme_stylebox_override("hover", GardenTheme.panel_style(base.lightened(0.02), 20, true, GardenTheme.LAVENDER, 1))
	card.add_theme_stylebox_override("pressed", GardenTheme.panel_style(base.darkened(0.04), 20, false))
	card.add_theme_stylebox_override("focus", GardenTheme.panel_style(Color.TRANSPARENT, 20, false, GardenTheme.LAVENDER_DEEP, 2))
	card.tooltip_text = GardenLoc.t("locked_prev", lang) if not unlocked else ""
	card.pressed.connect(func() -> void:
		if not unlocked:
			if app != null:
				app.toast(GardenLoc.t("locked_prev", lang))
			return
		GardenApi.play_sound("click")
		if app != null:
			app.play_level(level, _category))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 10
	row.offset_bottom = -10
	_ignore_mouse(row)

	var number := GardenWidgets.bold_label(str(index + 1), 17, GardenTheme.WHITE if unlocked else GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_CENTER)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.custom_minimum_size = Vector2(38, 38)
	var circle := GardenWidgets.panel(GardenTheme.LAVENDER_DEEP if unlocked else GardenTheme.LOCKED, 19, false, 0)
	circle.custom_minimum_size = Vector2(40, 40)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.add_child(number)
	row.add_child(circle)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	var level_title := str(level.get("title", ""))
	var category_name := GardenLoc.category_name(_category, lang)
	if level_title.is_empty() or level_title == category_name:
		level_title = GardenLoc.f("level_n", [index + 1], lang)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	var title := GardenWidgets.bold_label(level_title, 16, GardenTheme.INK if unlocked else GardenTheme.LOCKED_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if completed:
		var check := GardenPaint.CheckIcon.new()
		check.custom_minimum_size = Vector2(19, 19)
		head.add_child(check)
	v.add_child(head)

	var words: Array = level.get("words", [])
	if not unlocked:
		var l := HBoxContainer.new()
		l.add_theme_constant_override("separation", 5)
		var lock := GardenPaint.LockIcon.new()
		lock.custom_minimum_size = Vector2(15, 15)
		l.add_child(lock)
		l.add_child(GardenWidgets.caption(GardenLoc.t("locked", lang), GardenTheme.LOCKED_INK))
		v.add_child(l)
	else:
		var difficulty := int(level.get("difficulty", 1))
		var names := ["", "Kolay", "Orta", "Zor"] if lang == "tr" else ["", "Easy", "Medium", "Hard"]
		var detail := str(names[clampi(difficulty, 1, 3)]) + "  ·  " + GardenLoc.f("word_count", [words.size()], lang)
		if not words.is_empty():
			detail += "  ·  " + GardenApi.upper_tr(str(words[0].get("word", "")))
		v.add_child(GardenWidgets.caption(detail, GardenTheme.MUTED))
	row.add_child(v)

	if unlocked:
		var arrow := GardenPaint.icon(10, 22)
		arrow.flip_h = true
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(arrow)
	else:
		var lock2 := GardenPaint.LockIcon.new()
		lock2.custom_minimum_size = Vector2(20, 20)
		lock2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock2)
	if _focus_target == null and unlocked:
		_focus_target = card
	return card


func _empty_state(lang: String) -> Control:
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 20, true, 16)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(GardenWidgets.bold_label(GardenLoc.t("content_missing", lang), 15, GardenTheme.DANGER))
	v.add_child(GardenWidgets.caption(GardenLoc.t("content_missing_body", lang)))
	var retry := GardenWidgets.small_button(GardenLoc.t("retry", lang), "ghost")
	retry.pressed.connect(_build)
	v.add_child(retry)
	card.add_child(v)
	return card


func _soft(color_name: String) -> Color:
	match color_name:
		"pink":
			return GardenTheme.PINK_SOFT
		"yellow":
			return GardenTheme.YELLOW_SOFT
		"mint":
			return GardenTheme.LAVENDER_SOFT
		_:
			return GardenTheme.LAVENDER_SOFT


func _deep(color_name: String) -> Color:
	match color_name:
		"pink":
			return GardenTheme.PINK_DEEP
		"yellow":
			return GardenTheme.YELLOW_DEEP.darkened(0.2)
		"mint":
			return GardenTheme.MINT_DEEP
		_:
			return GardenTheme.LAVENDER_DEEP


func _ignore_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(child)


func initial_focus() -> Control:
	return _focus_target
