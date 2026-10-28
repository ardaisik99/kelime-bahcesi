class_name DeviceLineEdit
extends LineEdit
## Canvas draws the field. An invisible browser input only provides native text/IME.
var display_as_slots := false
var clip_to: Control
var _bridge: JavaScriptObject
var _input_callback: JavaScriptObject
var _submit_callback: JavaScriptObject
var _focus_callback: JavaScriptObject
var _normal_style: StyleBox
var _id := ""
var _last_rect := Rect2()
var _last_clip := Rect2()
var _last_value := ""
var _last_size := Vector2.ZERO
var _last_window := Vector2i.ZERO

func _ready() -> void:
	if display_as_slots:
		custom_minimum_size = Vector2.ZERO
		for state in ["normal", "focus", "read_only"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		for key in ["font_color", "font_uneditable_color", "font_selected_color", "caret_color", "selection_color", "font_placeholder_color"]:
			add_theme_color_override(key, Color.TRANSPARENT)
		placeholder_text = ""
	set_process(false)
	if not OS.has_feature("web"):
		return
	_bridge = JavaScriptBridge.get_interface("KelimeInput")
	if _bridge == null:
		return
	_normal_style = get_theme_stylebox("normal")
	virtual_keyboard_enabled = false
	_id = str(get_instance_id())
	_input_callback = JavaScriptBridge.create_callback(_on_html_input)
	_submit_callback = JavaScriptBridge.create_callback(_on_html_submit)
	_focus_callback = JavaScriptBridge.create_callback(_on_html_focus)
	_bridge.create(_id, _input_callback, _submit_callback, text,
		"Kelime harfleri" if display_as_slots else placeholder_text, max_length, _focus_callback)
	RenderingServer.frame_pre_draw.connect(_sync)
	_sync.call_deferred()

func _sync() -> void:
	if _bridge == null or not is_inside_tree():
		return
	var rect := get_global_rect()
	var viewport := get_viewport_rect().size
	var clipped := rect.intersection(Rect2(Vector2.ZERO, viewport))
	if is_instance_valid(clip_to):
		clipped = clipped.intersection(clip_to.get_global_rect())
	var ancestor := get_parent()
	while ancestor is Control:
		if ancestor.clip_contents:
			clipped = clipped.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	if not is_visible_in_tree() or not clipped.has_area():
		_bridge.hide(_id)
		_last_rect = Rect2()
		return
	if rect != _last_rect or clipped != _last_clip or viewport != _last_size or get_window().size != _last_window:
		_bridge.place(_id, rect.position.x, rect.position.y, rect.size.x, rect.size.y, viewport.x, viewport.y,
			clipped.position.x - rect.position.x, clipped.position.y - rect.position.y,
			rect.end.x - clipped.end.x, rect.end.y - clipped.end.y)
		_last_rect = rect
		_last_clip = clipped
		_last_size = viewport
		_last_window = get_window().size
	if text != _last_value:
		_bridge.value(_id, text)
		_last_value = text

func focus_device() -> void:
	if _bridge != null:
		_bridge.focus(_id)
	else:
		grab_focus()

func _on_html_focus(args: Array) -> void:
	# Calling grab_focus here would focus the canvas and immediately dismiss
	# the browser keyboard. Keep DOM focus and draw the focus state in Godot.
	var active := not args.is_empty() and bool(args[0])
	caret_force_displayed = active
	if not display_as_slots:
		add_theme_stylebox_override("normal", get_theme_stylebox("focus") if active else _normal_style)


func _on_html_input(args: Array) -> void:
	if args.is_empty():
		return
	if editable:
		text = str(args[0])
		caret_column = text.length()
		_last_value = text
		text_changed.emit(text)
	else:
		_bridge.value(_id, text)

func _on_html_submit(_args: Array) -> void:
	if editable:
		text_submitted.emit(text)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)
	if _bridge != null:
		_bridge.remove(_id)
	_input_callback = null
	_submit_callback = null
	_focus_callback = null
	_bridge = null
