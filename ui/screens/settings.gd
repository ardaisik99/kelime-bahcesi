extends Control

## Settings: sound, reduced motion, language and a short about section.

var app: Node
var _focus_target: Control
var _license_layer: Control = null


func setup(_params: Dictionary = {}) -> void:
	_build()


func _build() -> void:
	GardenWidgets.clear_children(self)
	_focus_target = null
	_license_layer = null
	var lang := GardenApi.lang()
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
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var header := GardenWidgets.panel(GardenTheme.LAVENDER_SOFT, 24, true, 18)
	var hv := HBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	var flower := GardenPaint.ChainIcon.new()
	flower.custom_minimum_size = Vector2(50, 54)
	hv.add_child(flower)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 1)
	titles.add_child(GardenWidgets.title(GardenLoc.t("settings_title", lang), 25))
	titles.add_child(GardenWidgets.label(GardenLoc.t("settings_sub", lang), 13, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	hv.add_child(titles)
	header.add_child(hv)
	content.add_child(header)

	content.add_child(_setting_card(
		GardenLoc.t("sound_effects", lang),
		GardenLoc.t("sound_desc", lang),
		"sound",
		GardenApi.sound_enabled(),
		lang))
	content.add_child(_setting_card(
		GardenLoc.t("reduced_motion", lang),
		GardenLoc.t("reduced_motion_desc", lang),
		"motion",
		GardenApi.reduced_motion(),
		lang))
	content.add_child(_language_card(lang))
	var profile := GardenWidgets.button(("Oyuncu: " if lang == "tr" else "Player: ") + GardenApi.player_name(), "ghost", 48)
	profile.pressed.connect(func() -> void: app.show_screen("profile", {"first_run": false}))
	content.add_child(profile)


	var about := GardenWidgets.panel(GardenTheme.SURFACE, 22, true, 16)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 7)
	var mini := GardenPaint.ChainIcon.new()
	mini.custom_minimum_size = Vector2(26, 28)
	arow.add_child(mini)
	arow.add_child(GardenWidgets.bold_label(GardenLoc.t("about_title", lang), 16, GardenTheme.INK))
	av.add_child(arow)
	av.add_child(GardenWidgets.label(GardenLoc.t("about_body", lang), 13, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	av.add_child(GardenWidgets.divider())
	av.add_child(GardenWidgets.caption(GardenLoc.t("progress_note", lang), GardenTheme.LOCKED_INK))
	av.add_child(GardenWidgets.caption("%s · %s · v%s" % [GardenLoc.t("brand", lang), GardenLoc.t("brand_sub", lang), str(ProjectSettings.get_setting("application/config/version", "0.1.0"))], GardenTheme.LOCKED_INK, HORIZONTAL_ALIGNMENT_CENTER))
	about.add_child(av)
	content.add_child(about)
	content.add_child(_licenses_card(lang))


func _licenses_card(lang: String) -> Control:
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 20, true, 15)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(GardenWidgets.bold_label(GardenLoc.t("licenses_title", lang), 15, GardenTheme.INK))
	v.add_child(GardenWidgets.caption(GardenLoc.t("licenses_body", lang)))
	var open := GardenWidgets.button(GardenLoc.t("licenses", lang), "ghost", 42)
	open.pressed.connect(func() -> void:
		_show_licenses(lang))
	v.add_child(open)
	card.add_child(v)
	return card


func _read_license(path: String, lang: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return GardenLoc.t("licenses_missing", lang)
	return text


func _license_text_edit(text: String) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = text
	edit.editable = false
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.custom_minimum_size = Vector2(0, 210)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 11)
	edit.add_theme_color_override("font_readonly_color", GardenTheme.INK)
	edit.add_theme_stylebox_override("read_only", GardenTheme._input_style(GardenTheme.CARD))
	return edit


func _show_licenses(lang: String) -> void:
	if _license_layer != null and is_instance_valid(_license_layer):
		remove_child(_license_layer)
		_license_layer.queue_free()
	_license_layer = Control.new()
	_license_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_license_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.2, 0.48)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_license_layer.add_child(dim)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dim.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 24, true, 16)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	card.add_child(v)
	v.add_child(GardenWidgets.title(GardenLoc.t("licenses_title", lang), 20))
	v.add_child(GardenWidgets.caption(GardenLoc.t("licenses_body", lang)))
	v.add_child(GardenWidgets.divider())
	v.add_child(GardenWidgets.bold_label(GardenLoc.t("licenses_engine", lang), 14, GardenTheme.LAVENDER_DEEP))
	v.add_child(_license_text_edit(_read_license("res://assets/legal/GODOT_LICENSE.txt", lang)))
	v.add_child(GardenWidgets.bold_label(GardenLoc.t("licenses_copyright", lang), 14, GardenTheme.LAVENDER_DEEP))
	v.add_child(_license_text_edit(_read_license("res://assets/legal/GODOT_COPYRIGHT.txt", lang)))
	v.add_child(GardenWidgets.bold_label("Nunito Sans · SIL Open Font License 1.1", 14, GardenTheme.LAVENDER_DEEP))
	v.add_child(_license_text_edit(_read_license("res://assets/fonts/OFL.txt", lang)))
	var close := GardenWidgets.button(GardenLoc.t("close", lang), "primary", 44)
	close.pressed.connect(_close_licenses)
	v.add_child(close)
	GardenWidgets.focus(close)


func _close_licenses() -> void:
	if _license_layer != null and is_instance_valid(_license_layer):
		if _license_layer.get_parent() == self:
			remove_child(_license_layer)
		_license_layer.queue_free()
	_license_layer = null


func handle_back() -> bool:
	if _license_layer != null:
		_close_licenses()
		return true
	return false


func on_language_changed_no_args() -> void:
	_close_licenses()
	_build()


func _setting_card(title: String, desc: String, key: String, value: bool, lang: String) -> Control:
	var card := GardenWidgets.panel(GardenTheme.CARD, 20, true, 15)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	var t := GardenWidgets.bold_label(title, 15, GardenTheme.INK)
	texts.add_child(t)
	var d := GardenWidgets.caption(desc, GardenTheme.MUTED)
	texts.add_child(d)
	row.add_child(texts)
	var state := "on" if value else "off"
	var seg := GardenWidgets.segmented([
		{"value": "on", "label": GardenLoc.t("on", lang)},
		{"value": "off", "label": GardenLoc.t("off", lang)}
	], state, func(selected: String) -> void:
		_toggle(key, selected == "on"), 32.0)
	seg.custom_minimum_size.x = 96
	row.add_child(seg)
	v.add_child(row)
	card.add_child(v)
	if _focus_target == null:
		_focus_target = seg
	return card


func _language_card(lang: String) -> Control:
	var card := GardenWidgets.panel(GardenTheme.CARD, 20, true, 15)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 1)
	texts.add_child(GardenWidgets.bold_label(GardenLoc.t("language", lang), 15, GardenTheme.INK))
	texts.add_child(GardenWidgets.caption(GardenLoc.t("language_desc", lang), GardenTheme.MUTED))
	row.add_child(texts)
	var seg := GardenWidgets.segmented([
		{"value": "tr", "label": "TR"},
		{"value": "en", "label": "EN"}
	], lang, func(selected: String) -> void:
		if is_instance_valid(app) and app.has_method("set_language"):
			app.call("set_language", selected), 32.0)
	seg.custom_minimum_size.x = 86
	row.add_child(seg)
	v.add_child(row)
	card.add_child(v)
	return card


func _toggle(key: String, value: bool) -> void:
	if key == "sound":
		GardenApi.set_sound_enabled(value)
		if value:
			GardenApi.play_sound("click")
	else:
		GardenApi.set_reduced_motion(value)
	_build()
	GardenWidgets.focus(_focus_target)


func initial_focus() -> Control:
	return _focus_target
