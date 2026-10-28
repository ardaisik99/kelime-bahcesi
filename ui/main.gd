extends Control

## Application shell: procedural pastel background, safe-area layout, fixed top
## bar, screen routing, toasts, confirm dialogs and the confetti canvas.
## Screen content lives in ui/screens/*.gd and is intentionally decoupled from
## the core autoloads through GardenApi.

const HomeScreenScript = preload("res://ui/screens/home.gd")
const CategoryScreenScript = preload("res://ui/screens/category.gd")
const PlayScreenScript = preload("res://ui/screens/play.gd")
const OnlineScreenScript = preload("res://ui/screens/online.gd")
const SettingsScreenScript = preload("res://ui/screens/settings.gd")

var _safe: MarginContainer
var _root_box: VBoxContainer
var _topbar: PanelContainer
var _content: Control
var _screen: Control
var _back_button: Button
var _brand_main: Label
var _brand_sub: Label
var _coin_label: Label
var _lang_holder: Control
var _overlay: Control
var _modal_layer: Control
var _toast: PanelContainer
var _toast_label: Label
var _toast_serial := 0
var _confetti: GardenPaint.Confetti
var _route: Dictionary = {"name": "home", "params": {}}
var _history: Array = []


func _ready() -> void:
	theme = GardenTheme.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	goto_home()
	_update_topbar_texts()


func _build() -> void:
	var background := GardenPaint.Background.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_safe = MarginContainer.new()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_safe)

	_root_box = VBoxContainer.new()
	_root_box.add_theme_constant_override("separation", 4)
	_root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_safe.add_child(_root_box)

	_topbar = GardenWidgets.panel(Color(1, 1, 1, 0.66), 20, false, 8)
	_topbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_topbar)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 7)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topbar.add_child(bar)

	_back_button = Button.new()
	_back_button.text = "←"
	_back_button.tooltip_text = GardenLoc.t("back", GardenApi.lang())
	_back_button.custom_minimum_size = Vector2(34, 34)
	_back_button.focus_mode = Control.FOCUS_ALL
	_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back_button.add_theme_font_override("font", GardenTheme.bold_font())
	_back_button.add_theme_font_size_override("font_size", 20)
	_back_button.add_theme_color_override("font_color", GardenTheme.INK)
	_back_button.add_theme_color_override("font_hover_color", GardenTheme.INK)
	_back_button.add_theme_color_override("font_pressed_color", GardenTheme.LAVENDER_DEEP)
	var back_normal := GardenTheme.panel_style(GardenTheme.CARD, 12, false)
	back_normal.content_margin_left = 0
	back_normal.content_margin_right = 0
	back_normal.content_margin_top = 0
	back_normal.content_margin_bottom = 0
	_back_button.add_theme_stylebox_override("normal", back_normal)
	_back_button.add_theme_stylebox_override("hover", GardenTheme.panel_style(GardenTheme.LAVENDER_SOFT, 12, false))
	_back_button.add_theme_stylebox_override("pressed", GardenTheme.panel_style(GardenTheme.PINK_SOFT, 12, false))
	_back_button.add_theme_stylebox_override("focus", GardenTheme.panel_style(Color.TRANSPARENT, 12, false, GardenTheme.LAVENDER_DEEP, 2))
	_back_button.pressed.connect(_on_back_pressed)
	bar.add_child(_back_button)

	var brand_icon := GardenPaint.FlowerMark.new()
	brand_icon.custom_minimum_size = Vector2(32, 34)
	bar.add_child(brand_icon)

	var brand_box := VBoxContainer.new()
	brand_box.add_theme_constant_override("separation", 0)
	brand_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_brand_main = GardenWidgets.bold_label("Kelime Bahçesi", 14, GardenTheme.INK)
	_brand_main.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_brand_sub = GardenWidgets.label("Word Garden", 9, GardenTheme.MUTED)
	_brand_sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	brand_box.add_child(_brand_main)
	brand_box.add_child(_brand_sub)
	bar.add_child(brand_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	var coin_chip := GardenWidgets.panel(GardenTheme.YELLOW_SOFT, 13, false, 8)
	coin_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 5)
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var coin_icon := GardenPaint.CoinIcon.new()
	coin_icon.custom_minimum_size = Vector2(19, 19)
	coin_row.add_child(coin_icon)
	_coin_label = GardenWidgets.bold_label(str(GardenApi.coins()), 13, Color("6a4d10"))
	coin_row.add_child(_coin_label)
	coin_chip.add_child(coin_row)
	bar.add_child(coin_chip)

	_lang_holder = Control.new()
	_lang_holder.custom_minimum_size = Vector2(88, 34)
	_lang_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_lang_holder)
	_rebuild_language_toggle()

	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_box.add_child(_content)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_modal_layer)

	_toast = GardenWidgets.panel(Color("3d3550f2"), 15, true, 12)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_left = 32
	_toast.offset_right = -32
	_toast.offset_bottom = -18
	_toast.offset_top = -76
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast_label = GardenWidgets.bold_label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(_toast_label)
	_overlay.add_child(_toast)

	_confetti = GardenPaint.Confetti.new()
	add_child(_confetti)
	_confetti.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _update_safe_area() -> void:
	if _safe == null:
		return
	var vp := get_viewport_rect().size
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var scale := Vector2(1, 1)
	if win.x > 0 and win.y > 0:
		scale = Vector2(vp.x / float(win.x), vp.y / float(win.y))
	var top := 0.0
	var bottom := 0.0
	var left := 0.0
	var right := 0.0
	if win.x > 0 and win.y > 0:
		top = maxf(0.0, float(safe.position.y)) * scale.y
		bottom = maxf(0.0, float(win.y - safe.position.y - safe.size.y)) * scale.y
		left = maxf(0.0, float(safe.position.x)) * scale.x
		right = maxf(0.0, float(win.x - safe.position.x - safe.size.x)) * scale.x
	top = clampf(top, 0.0, 64.0)
	bottom = clampf(bottom, 0.0, 48.0)
	left = clampf(left, 0.0, 48.0)
	right = clampf(right, 0.0, 48.0)
	_safe.add_theme_constant_override("margin_left", int(maxf(16.0, left + 10.0)))
	_safe.add_theme_constant_override("margin_right", int(maxf(16.0, right + 10.0)))
	_safe.add_theme_constant_override("margin_top", int(maxf(12.0, top + 8.0)))
	_safe.add_theme_constant_override("margin_bottom", int(maxf(14.0, bottom + 8.0)))


func _rebuild_language_toggle() -> void:
	if _lang_holder == null:
		return
	GardenWidgets.clear_children(_lang_holder)
	var seg := GardenWidgets.segmented([
		{"value": "tr", "label": "TR"},
		{"value": "en", "label": "EN"}
	], GardenApi.lang(), _on_language_selected, 32.0)
	seg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lang_holder.add_child(seg)


func _update_topbar_texts() -> void:
	var lang := GardenApi.lang()
	if _brand_main != null:
		_brand_main.text = GardenLoc.t("brand", lang)
		_brand_sub.text = GardenLoc.t("brand_sub", lang)
	if _back_button != null:
		_back_button.tooltip_text = GardenLoc.t("back", lang)
	if _coin_label != null:
		_coin_label.text = str(GardenApi.coins())
	if _screen != null and _screen.has_method("on_topbar_language"):
		_screen.call("on_topbar_language", lang)


func update_coins() -> void:
	if _coin_label != null:
		_coin_label.text = str(GardenApi.coins())


func _on_language_selected(code: String) -> void:
	if code == GardenApi.lang():
		return
	var reason := ""
	if _screen != null and _screen.has_method("language_lock_reason"):
		reason = str(_screen.call("language_lock_reason"))
	if not reason.is_empty():
		toast(reason)
		_rebuild_language_toggle()
		return
	GardenApi.set_lang(code)
	_update_topbar_texts()
	_rebuild_language_toggle()
	if _screen != null and _screen.has_method("on_language_changed"):
		_screen.call("on_language_changed", code)
	elif _screen != null and _screen.has_method("on_language_changed_no_args"):
		_screen.call("on_language_changed_no_args")
	else:
		reload_current()
	GardenApi.play_sound("click")


# ---------------------------------------------------------------------------
# Routing
# ---------------------------------------------------------------------------

func _make_screen(route_name: String) -> Control:
	match route_name:
		"home":
			return HomeScreenScript.new()
		"category":
			return CategoryScreenScript.new()
		"play", "party":
			return PlayScreenScript.new()
		"online":
			return OnlineScreenScript.new()
		"settings":
			return SettingsScreenScript.new()
		_:
			return HomeScreenScript.new()


func _show(route_name: String, params: Dictionary, push_history: bool) -> void:
	if push_history and not _route.is_empty():
		_history.append({"name": _route.get("name", "home"), "params": (_route.get("params", {}) as Dictionary).duplicate(true)})
	if _history.size() > 24:
		_history.pop_front()
	_route = {"name": route_name, "params": params.duplicate(true)}
	_instantiate_route()
	_update_back_button()
	_update_topbar_texts()
	_rebuild_language_toggle()


func _instantiate_route() -> void:
	if _screen != null and is_instance_valid(_screen):
		_content.remove_child(_screen)
		_screen.queue_free()
	_screen = null
	var new_screen := _make_screen(str(_route.get("name", "home")))
	_screen = new_screen
	new_screen.set("app", self)
	new_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(new_screen)
	if new_screen.has_method("setup"):
		new_screen.call("setup", _route.get("params", {}))
	if new_screen.has_method("initial_focus"):
		var focus_target: Variant = new_screen.call("initial_focus")
		if focus_target is Control:
			GardenWidgets.focus(focus_target)
	if not GardenApi.reduced_motion():
		new_screen.modulate.a = 0.0
		var tween := new_screen.create_tween()
		tween.tween_property(new_screen, "modulate:a", 1.0, 0.18)


func show_screen(route_name: String, params: Dictionary = {}) -> void:
	_show(route_name, params, true)


func replace_screen(route_name: String, params: Dictionary = {}) -> void:
	_show(route_name, params, false)


func reload_current() -> void:
	_instantiate_route()
	_update_topbar_texts()


func back() -> void:
	if _modal_open():
		close_modal()
		return
	if _screen != null and _screen.has_method("handle_back"):
		var handled: Variant = _screen.call("handle_back")
		if typeof(handled) == TYPE_BOOL and bool(handled):
			return
	force_back()


func force_back() -> void:
	if _history.is_empty():
		goto_home()
		return
	var previous: Dictionary = _history.pop_back()
	_route = previous
	_instantiate_route()
	_update_back_button()
	_update_topbar_texts()
	_rebuild_language_toggle()


func goto_home() -> void:
	_history.clear()
	_route = {"name": "home", "params": {}}
	_instantiate_route()
	_update_back_button()
	_update_topbar_texts()
	_rebuild_language_toggle()


func open_category(category: Dictionary) -> void:
	show_screen("category", {"category": category})


func play_level(level: Dictionary, category: Dictionary = {}, replace: bool = false) -> void:
	var params := {"level": level, "category": category}
	if replace:
		replace_screen("play", params)
	else:
		show_screen("play", params)


func open_party() -> void:
	show_screen("party", {"mode": "party"})


func open_online() -> void:
	show_screen("online", {})


func open_settings() -> void:
	show_screen("settings", {})


func set_language(code: String) -> void:
	_on_language_selected(code)


func _on_back_pressed() -> void:
	GardenApi.play_sound("click")
	back()


func _update_back_button() -> void:
	if _back_button == null:
		return
	_back_button.visible = str(_route.get("name", "home")) != "home"


# ---------------------------------------------------------------------------
# Feedback
# ---------------------------------------------------------------------------

func toast(message: String, duration: float = 2.4) -> void:
	if _toast == null:
		return
	_toast_serial += 1
	var serial := _toast_serial
	_toast_label.text = message
	_toast.visible = true
	_toast.modulate.a = 0.0
	var tween := _toast.create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.14)
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if serial != _toast_serial or not is_instance_valid(_toast):
			return
		var out := _toast.create_tween()
		out.tween_property(_toast, "modulate:a", 0.0, 0.2)
		out.tween_callback(func() -> void:
			if is_instance_valid(_toast):
				_toast.visible = false))


func celebrate(origin: Vector2 = Vector2(-1, -1)) -> void:
	if _confetti != null and not GardenApi.reduced_motion():
		_confetti.start(100, origin)


func _modal_open() -> bool:
	return _modal_layer != null and _modal_layer.get_child_count() > 0


func show_confirm(title_text: String, body: String, confirm_text: String,
		on_confirm: Callable, cancel_text: String = "") -> void:
	close_modal()
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.08, 0.2, 0.48)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var card := GardenWidgets.panel(GardenTheme.SURFACE, 26, true, 22)
	card.custom_minimum_size = Vector2(minf(340.0, get_viewport_rect().size.x - 44.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(GardenWidgets.title(title_text, 21))
	v.add_child(GardenWidgets.label(body, 15, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	v.add_child(GardenWidgets.vspace(2))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var cancel := GardenWidgets.button(cancel_text if not cancel_text.is_empty() else GardenLoc.t("cancel", GardenApi.lang()), "ghost", 46)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close_modal)
	actions.add_child(cancel)
	var confirm := GardenWidgets.button(confirm_text, "primary", 46)
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.pressed.connect(func() -> void:
		close_modal()
		if on_confirm.is_valid():
			on_confirm.call())
	actions.add_child(confirm)
	v.add_child(actions)
	GardenWidgets.focus(confirm)


func close_modal() -> void:
	if _modal_layer == null:
		return
	for child in _modal_layer.get_children():
		_modal_layer.remove_child(child)
		child.queue_free()


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			back()
