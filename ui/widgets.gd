class_name GardenWidgets
extends RefCounted

## Small reusable builders so every screen keeps the same soft, rounded look.

static func clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func make_label(text: String, font_size: int = 17, color: Color = GardenTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false,
		expand: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func label(text: String, font_size: int = 17, color: Color = GardenTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false,
		expand: bool = false) -> Label:
	return make_label(text, font_size, color, align, wrap, expand)


static func bold_label(text: String, font_size: int = 17, color: Color = GardenTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var l := make_label(text, font_size, color, align, wrap)
	l.add_theme_font_override("font", GardenTheme.bold_font())
	return l


static func title(text: String, font_size: int = 27, color: Color = GardenTheme.INK,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := bold_label(text, font_size, color, align, true)
	l.add_theme_constant_override("line_spacing", 2)
	return l


static func caption(text: String, color: Color = GardenTheme.MUTED, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return make_label(text, 14, color, align, true)


static func vspace(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hspace(width: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func panel(bg: Color = GardenTheme.CARD, radius: int = 24, shadow: bool = true,
		padding: int = 16, border: Color = Color.TRANSPARENT, border_width: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := GardenTheme.panel_style(bg, radius, shadow, border, border_width)
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = padding
	sb.content_margin_bottom = padding
	p.add_theme_stylebox_override("panel", sb)
	return p


static func card(bg: Color = GardenTheme.CARD, radius: int = 24, padding: int = 16) -> PanelContainer:
	return panel(bg, radius, true, padding)


static func button(text: String, kind: String = "primary", height: float = 52.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var base := GardenTheme.kind_color(kind)
	var ink := GardenTheme.kind_ink(kind)
	var normal := GardenTheme.button_style(base, 18, kind != "ghost")
	var hover := GardenTheme.button_style(base.lightened(0.06), 18, kind != "ghost")
	var pressed := GardenTheme.button_style(base.darkened(0.14), 18, false)
	var disabled := GardenTheme.button_style(GardenTheme.LOCKED, 18, false)
	var focus := GardenTheme.panel_style(Color.TRANSPARENT, 18, false, GardenTheme.LAVENDER_DEEP, 2)
	focus.content_margin_left = 4
	focus.content_margin_right = 4
	focus.content_margin_top = 4
	focus.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_font_override("font", GardenTheme.bold_font())
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_focus_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", GardenTheme.WHITE if kind in ["primary", "pink", "danger"] else ink)
	b.add_theme_color_override("font_disabled_color", GardenTheme.LOCKED_INK)
	b.pressed.connect(func() -> void: GardenApi.play_sound("click"))
	return b


static func small_button(text: String, kind: String = "ghost", height: float = 38.0) -> Button:
	var b := button(text, kind, height)
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size.x = 0
	return b


static func text_button(text: String, color: Color = GardenTheme.LAVENDER_DEEP) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", GardenTheme.bold_font())
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.darkened(0.15))
	b.add_theme_color_override("font_pressed_color", color.darkened(0.25))
	b.add_theme_color_override("font_focus_color", color)
	b.pressed.connect(func() -> void: GardenApi.play_sound("click"))
	return b


static func chip(text: String, bg: Color = GardenTheme.LAVENDER_SOFT,
		fg: Color = GardenTheme.LAVENDER_DEEP, icon: Control = null) -> PanelContainer:
	var p := panel(bg, 14, false, 10)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon != null:
		row.add_child(icon)
	var l := bold_label(text, 13, fg)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	p.add_child(row)
	return p


static func coin_chip(amount: int) -> PanelContainer:
	return chip(str(amount), GardenTheme.YELLOW_SOFT, GardenTheme.LAVENDER_DEEP, GardenPaint.CoinIcon.new())


static func progress_bar(value: float, maximum: float, color: Color = GardenTheme.LAVENDER,
		height: float = 8.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, maximum)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := GardenTheme.panel_style(GardenTheme.LINE, int(height * 0.5), false)
	bg.content_margin_left = 0
	bg.content_margin_right = 0
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fill := GardenTheme.panel_style(color, int(height * 0.5), false)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


static func line_edit(placeholder: String, text: String = "", max_length: int = 32) -> LineEdit:
	var e := DeviceLineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.max_length = max_length
	e.custom_minimum_size = Vector2(0, 48)
	e.add_theme_font_size_override("font_size", 17)
	e.add_theme_color_override("font_color", GardenTheme.INK)
	e.add_theme_color_override("caret_color", GardenTheme.LAVENDER_DEEP)
	e.add_theme_stylebox_override("normal", GardenTheme._input_style(GardenTheme.CARD))
	e.add_theme_stylebox_override("focus", GardenTheme._input_style(GardenTheme.CARD, GardenTheme.LAVENDER, 2))
	e.add_theme_stylebox_override("read_only", GardenTheme._input_style(GardenTheme.LOCKED, Color.TRANSPARENT))
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return e


static func divider(color: Color = GardenTheme.LINE) -> Control:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func section_heading(text: String) -> Label:
	var l := title(text, 19)
	l.add_theme_color_override("font_color", GardenTheme.INK)
	return l


static func focus(control: Control) -> void:
	if control == null:
		return
	var target: Control = control
	if target.focus_mode == Control.FOCUS_NONE:
		target = _first_focusable(target)
	if target == null or target.focus_mode == Control.FOCUS_NONE:
		return
	var target_ref: WeakRef = weakref(target)
	var callable := func() -> void:
		var current: Control = target_ref.get_ref()
		if current != null and current.is_inside_tree() and current.is_visible_in_tree():
			current.grab_focus()
	callable.call_deferred()


static func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree():
				return control
			var nested := _first_focusable(control)
			if nested != null:
				return nested
	return null


static func label_for_word(text: String, size: int = 17, color: Color = GardenTheme.INK) -> Label:
	var l := bold_label(GardenApi.upper_tr(text), size, color)
	return l


static func segmented(options: Array, selected: String, on_select: Callable,
		height: float = 34.0) -> PanelContainer:
	var wrap := panel(GardenTheme.LAVENDER_SOFT, 14, false, 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for option_v in options:
		var option: Dictionary = option_v
		var value := str(option.get("value", ""))
		var b := Button.new()
		b.text = str(option.get("label", value))
		b.custom_minimum_size = Vector2(0, height)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", GardenTheme.bold_font())
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", GardenTheme.MUTED)
		b.add_theme_color_override("font_pressed_color", GardenTheme.INK)
		b.add_theme_color_override("font_hover_color", GardenTheme.INK)
		var selected_style := GardenTheme.button_style(GardenTheme.CARD, 11, true)
		selected_style.content_margin_top = 4
		selected_style.content_margin_bottom = 4
		var empty := StyleBoxEmpty.new()
		if value == selected:
			b.add_theme_stylebox_override("normal", selected_style)
			b.add_theme_stylebox_override("hover", selected_style)
			b.add_theme_color_override("font_color", GardenTheme.INK)
		else:
			b.add_theme_stylebox_override("normal", empty)
			b.add_theme_stylebox_override("hover", empty)
			b.add_theme_stylebox_override("pressed", empty)
		b.pressed.connect(func() -> void:
			GardenApi.play_sound("click")
			on_select.call(value))
		row.add_child(b)
	wrap.add_child(row)
	return wrap


static func toast_style(bg: Color) -> StyleBoxFlat:
	return GardenTheme.panel_style(bg, 16, true)


static func shake(control: Control) -> void:
	if control == null or not is_instance_valid(control) or GardenApi.reduced_motion():
		return
	var original := control.position
	var tween := control.create_tween()
	tween.tween_property(control, "position", original + Vector2(-9, 0), 0.045)
	tween.tween_property(control, "position", original + Vector2(8, 0), 0.05)
	tween.tween_property(control, "position", original + Vector2(-6, 0), 0.05)
	tween.tween_property(control, "position", original + Vector2(4, 0), 0.05)
	tween.tween_property(control, "position", original, 0.055)
