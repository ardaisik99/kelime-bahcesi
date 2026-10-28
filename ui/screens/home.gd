extends Control

## Home: brand hero, continue card, category garden grid, party/online modes,
## settings access and a compact how-to-play tutorial.

var app: Node

var _scroll: ScrollContainer
var _next_level: Dictionary = {}
var _focus_target: Control


func setup(_params: Dictionary = {}) -> void:
	_build()


func _build() -> void:
	GardenWidgets.clear_children(self)
	_focus_target = null
	var lang := GardenApi.lang()
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 18)
	_scroll.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 13)
	margin.add_child(content)

	content.add_child(_hero(lang))
	content.add_child(_continue_section(lang))
	content.add_child(_categories_section(lang))
	content.add_child(_modes_section(lang))
	content.add_child(_tutorial(lang))
	content.add_child(_settings_row(lang))
	var footer := GardenWidgets.caption("%s · %s" % [GardenLoc.t("brand", lang), GardenLoc.t("brand_sub", lang)],
			GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(footer)


func _hero(lang: String) -> Control:
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 8)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	var greeting := GardenWidgets.caption(GardenLoc.t("brand_sub", lang).to_upper(), GardenTheme.PINK_DEEP)
	text_box.add_child(greeting)
	var title := GardenWidgets.title(GardenLoc.t("brand", lang), 28)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_box.add_child(title)
	var tagline := GardenWidgets.label(GardenLoc.t("tagline", lang), 14, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	text_box.add_child(tagline)
	hero.add_child(text_box)
	var mascot := GardenPaint.Mascot.new()
	mascot.custom_minimum_size = Vector2(96, 100)
	hero.add_child(mascot)
	return hero


func _continue_section(lang: String) -> Control:
	var next := GardenApi.next_unfinished(lang)
	_next_level = next
	var all_levels := GardenApi.all_levels(lang)
	var total := all_levels.size()
	var done := 0
	for lv in all_levels:
		if GardenApi.is_completed(lang, lv.get("id", "")):
			done += 1
	var all_done := total > 0 and done >= total
	if next.is_empty():
		var empty := GardenWidgets.panel(GardenTheme.SURFACE, 24, true, 18)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.add_child(GardenWidgets.bold_label(GardenLoc.t("content_missing", lang), 16, GardenTheme.DANGER))
		v.add_child(GardenWidgets.caption(GardenLoc.t("content_missing_body", lang)))
		var retry := GardenWidgets.button(GardenLoc.t("retry", lang), "ghost", 42)
		retry.pressed.connect(_build)
		v.add_child(retry)
		empty.add_child(v)
		return empty

	var card_button := Button.new()
	card_button.custom_minimum_size = Vector2(0, 104)
	card_button.focus_mode = Control.FOCUS_ALL
	card_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card_button.add_theme_stylebox_override("normal", GardenTheme.panel_style(GardenTheme.LAVENDER_SOFT, 24, true))
	card_button.add_theme_stylebox_override("hover", GardenTheme.panel_style(GardenTheme.LAVENDER_SOFT.lightened(0.04), 24, true))
	card_button.add_theme_stylebox_override("pressed", GardenTheme.panel_style(GardenTheme.LAVENDER_SOFT.darkened(0.05), 24, false))
	card_button.add_theme_stylebox_override("focus", GardenTheme.panel_style(Color.TRANSPARENT, 24, false, GardenTheme.LAVENDER_DEEP, 2))
	card_button.add_theme_stylebox_override("disabled", GardenTheme.panel_style(GardenTheme.LOCKED, 24, false))
	card_button.pressed.connect(func() -> void:
		GardenApi.play_sound("click")
		if app != null:
			app.play_level(next, _category_for(next, lang)))
	add_child_to(card_button, _continue_content(card_button, next, lang, all_done, done, total))
	if _focus_target == null:
		_focus_target = card_button
	return card_button


func add_child_to(parent: Control, child: Control) -> void:
	parent.add_child(child)
	if child is Control:
		(child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		(child as Control).offset_left = 17
		(child as Control).offset_right = -17
		(child as Control).offset_top = 13
		(child as Control).offset_bottom = -13
		_ignore_mouse(child)


func _continue_content(_owner: Button, next: Dictionary, lang: String, all_done: bool, done: int, total: int) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	if all_done:
		v.add_child(GardenWidgets.bold_label(GardenLoc.t("all_done_title", lang), 18, GardenTheme.LAVENDER_DEEP))
		v.add_child(GardenWidgets.label(GardenLoc.t("all_done_body", lang), 12, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	else:
		v.add_child(GardenWidgets.caption(GardenLoc.t("home_continue", lang), GardenTheme.LAVENDER_DEEP))
		var level_title := _level_title(next, lang)
		v.add_child(GardenWidgets.bold_label(level_title, 18, GardenTheme.INK))
		v.add_child(GardenWidgets.label(GardenLoc.f("category_done", [done, total], lang), 12, GardenTheme.MUTED))
	row.add_child(v)
	var action := VBoxContainer.new()
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	var play := Button.new()
	play.text = "▶" if not all_done else "✿"
	play.custom_minimum_size = Vector2(52, 52)
	play.focus_mode = Control.FOCUS_NONE
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.add_theme_font_size_override("font_size", 20)
	play.add_theme_font_override("font", GardenTheme.bold_font())
	play.add_theme_color_override("font_color", GardenTheme.WHITE)
	play.add_theme_stylebox_override("normal", GardenTheme.panel_style(GardenTheme.LAVENDER_DEEP, 26, true))
	play.add_theme_stylebox_override("hover", GardenTheme.panel_style(GardenTheme.LAVENDER_DEEP, 26, true))
	play.add_theme_stylebox_override("pressed", GardenTheme.panel_style(GardenTheme.LAVENDER_DEEP, 26, true))
	play.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	action.add_child(play)
	row.add_child(action)
	return row


func _categories_section(lang: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	var categories := GardenApi.categories(lang)
	var head := HBoxContainer.new()
	var heading := GardenWidgets.section_heading(GardenLoc.t("home_categories", lang))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	if not categories.is_empty():
		head.add_child(GardenWidgets.caption(GardenLoc.f("home_category_count", [categories.size()], lang), GardenTheme.MUTED))
	box.add_child(head)
	if categories.is_empty():
		var empty := GardenWidgets.panel(GardenTheme.SURFACE, 20, true, 16)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.add_child(GardenWidgets.caption(GardenLoc.t("content_missing_body", lang)))
		var retry := GardenWidgets.small_button(GardenLoc.t("retry", lang), "ghost")
		retry.pressed.connect(_build)
		v.add_child(retry)
		empty.add_child(v)
		box.add_child(empty)
		return box
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 9)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for category in categories:
		grid.add_child(_category_card(category, lang))
	box.add_child(grid)
	return box


func _category_card(category: Dictionary, lang: String) -> Button:
	var dark := _category_deep(str(category.get("color", "lavender")))
	var soft := _category_soft(str(category.get("color", "lavender")))
	var card := Button.new()
	card.custom_minimum_size = Vector2(120, 112)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", GardenTheme.panel_style(soft, 21, true))
	card.add_theme_stylebox_override("hover", GardenTheme.panel_style(soft.lightened(0.035), 21, true))
	card.add_theme_stylebox_override("pressed", GardenTheme.panel_style(soft.darkened(0.05), 21, false))
	card.add_theme_stylebox_override("focus", GardenTheme.panel_style(Color.TRANSPARENT, 21, false, dark, 2))
	card.pressed.connect(func() -> void:
		GardenApi.play_sound("click")
		if app != null:
			app.open_category(category))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 13
	inner.offset_right = -13
	inner.offset_top = 11
	inner.offset_bottom = -11
	_ignore_mouse(inner)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	var flower := GardenPaint.FlowerMark.new()
	flower.petal_color = dark
	flower.center_color = GardenTheme.YELLOW
	flower.custom_minimum_size = Vector2(28, 30)
	top.add_child(flower)
	var name_label := GardenWidgets.bold_label(GardenLoc.category_name(category, lang), 15, GardenTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.max_lines_visible = 2
	top.add_child(name_label)
	inner.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)
	var progress := GardenApi.category_progress(lang, str(category.get("id", "")))
	var count := int(progress.get("total", 0))
	var done := int(progress.get("done", 0))
	var meta := GardenLoc.f("category_done", [done, count], lang)
	inner.add_child(GardenWidgets.caption(meta, GardenTheme.MUTED))
	inner.add_child(GardenWidgets.progress_bar(done, count, dark, 6))
	return card


func _modes_section(lang: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	box.add_child(GardenWidgets.section_heading(GardenLoc.t("home_modes", lang)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_mode_card(GardenLoc.t("home_party", lang), GardenLoc.t("home_party_desc", lang),
			GardenTheme.PINK_SOFT, GardenTheme.PINK_DEEP, "party", true))
	row.add_child(_mode_card(GardenLoc.t("home_online", lang), GardenLoc.t("home_online_desc", lang),
			GardenTheme.YELLOW_SOFT, GardenTheme.YELLOW_DEEP.darkened(0.2), "online", false))
	box.add_child(row)
	return box


func _mode_card(title: String, subtitle: String, soft: Color, dark: Color, route: String, party: bool) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 108)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", GardenTheme.panel_style(soft, 21, true))
	card.add_theme_stylebox_override("hover", GardenTheme.panel_style(soft.lightened(0.04), 21, true))
	card.add_theme_stylebox_override("pressed", GardenTheme.panel_style(soft.darkened(0.05), 21, false))
	card.add_theme_stylebox_override("focus", GardenTheme.panel_style(Color.TRANSPARENT, 21, false, dark, 2))
	card.pressed.connect(func() -> void:
		GardenApi.play_sound("click")
		if app == null:
			return
		if route == "party":
			app.open_party()
		else:
			app.open_online())
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	card.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 13
	inner.offset_right = -13
	inner.offset_top = 12
	inner.offset_bottom = -12
	_ignore_mouse(inner)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 5)
	var mark := GardenPaint.FlowerMark.new()
	mark.petal_color = dark
	mark.center_color = GardenTheme.CARD
	mark.custom_minimum_size = Vector2(25, 28)
	top.add_child(mark)
	var t := GardenWidgets.bold_label(title, 16, dark)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	inner.add_child(top)
	inner.add_child(GardenWidgets.label(subtitle, 11, GardenTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)
	inner.add_child(GardenWidgets.caption("→", dark, HORIZONTAL_ALIGNMENT_RIGHT))
	return card


func _tutorial(lang: String) -> Control:
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 22, true, 16)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	var head := HBoxContainer.new()
	var title := GardenWidgets.bold_label(GardenLoc.t("home_how", lang), 16, GardenTheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var flower := GardenPaint.FlowerMark.new()
	flower.custom_minimum_size = Vector2(24, 26)
	head.add_child(flower)
	v.add_child(head)
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		var step := GardenWidgets.bold_label(str(i + 1), 12, GardenTheme.LAVENDER_DEEP, HORIZONTAL_ALIGNMENT_CENTER)
		step.custom_minimum_size = Vector2(22, 22)
		step.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var step_panel := GardenWidgets.panel(GardenTheme.LAVENDER_SOFT, 11, false, 0)
		step_panel.custom_minimum_size = Vector2(22, 22)
		step_panel.add_child(step)
		row.add_child(step_panel)
		var body := GardenWidgets.label(GardenLoc.t("how_%d" % (i + 1), lang), 12, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(body)
		v.add_child(row)
	var example := GardenWidgets.chip(GardenLoc.t("how_example", lang), GardenTheme.YELLOW_SOFT, Color("6a4d10"))
	example.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(example)
	card.add_child(v)
	return card


func _settings_row(lang: String) -> Control:
	var sound := GardenLoc.t("on", lang) if GardenApi.sound_enabled() else GardenLoc.t("off", lang)
	var b := GardenWidgets.button("%s  ·  %s: %s" % [GardenLoc.t("settings", lang), GardenLoc.t("sound", lang), sound], "ghost", 44)
	b.pressed.connect(func() -> void:
		if app != null:
			app.open_settings())
	return b


func _level_title(level: Dictionary, lang: String) -> String:
	var category := str(level.get("category", ""))
	var category_name := GardenLoc.category_name(category, lang)
	var list := GardenApi.levels(lang, category)
	var index := 0
	for i in list.size():
		if str(list[i].get("id", "")) == str(level.get("id", "")):
			index = i + 1
			break
	if index == 0:
		index = 1
	var title := str(level.get("title", ""))
	if not title.is_empty() and title != category_name:
		return "%s · %s" % [category_name, title]
	return "%s · %s" % [category_name, GardenLoc.f("level_n", [index], lang)]


func _category_for(level: Dictionary, lang: String) -> Dictionary:
	var category_id := str(level.get("category", ""))
	for cat in GardenApi.categories(lang):
		if str(cat.get("id", "")) == category_id:
			return cat
	return {"id": category_id, "name": GardenLoc.category_name(category_id, lang), "color": "lavender"}


func _category_soft(color_name: String) -> Color:
	match color_name:
		"pink":
			return GardenTheme.PINK_SOFT
		"yellow":
			return GardenTheme.YELLOW_SOFT
		"mint":
			return Color("e8f8ef")
		_:
			return GardenTheme.LAVENDER_SOFT


func _category_deep(color_name: String) -> Color:
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
