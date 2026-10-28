class_name DeviceLineEdit
extends LineEdit
## Native LineEdit on mobile/desktop; a real HTML input over the same rect on web.
## This avoids Godot 4.5's experimental contenteditable IME losing composed text.
var _bridge: JavaScriptObject
var _input_callback: JavaScriptObject
var _submit_callback: JavaScriptObject
var _id := ""
var _last_rect := Rect2()
var _last_value := ""
var _last_size := Vector2.ZERO
var _last_window := Vector2i.ZERO
var _elapsed := 0.0

func _ready() -> void:
	set_process(false)
	if not OS.has_feature("web"):
		return
	_bridge = JavaScriptBridge.get_interface("KelimeInput")
	if _bridge == null:
		return
	virtual_keyboard_enabled = false
	_id = str(get_instance_id())
	_input_callback = JavaScriptBridge.create_callback(_on_html_input)
	_submit_callback = JavaScriptBridge.create_callback(_on_html_submit)
	_bridge.create(_id, _input_callback, _submit_callback, text, placeholder_text, max_length)
	set_process(true)
	_sync.call_deferred()

func _process(delta: float) -> void:
	# Only an active web text field polls; DOM styles change only when geometry changes.
	_elapsed += delta
	if _elapsed >= 0.06:
		_elapsed = 0.0
		_sync()

func _sync() -> void:
	if _bridge == null or not is_inside_tree():
		return
	var rect := get_global_rect()
	var viewport := get_viewport_rect().size
	if not is_visible_in_tree():
		_bridge.hide(_id)
		_last_rect = Rect2()
		return
	if rect != _last_rect or viewport != _last_size or get_window().size != _last_window:
		_bridge.place(_id, rect.position.x, rect.position.y, rect.size.x, rect.size.y, viewport.x, viewport.y)
		_last_rect = rect
		_last_size = viewport
		_last_window = get_window().size
	if text != _last_value:
		_bridge.value(_id, text)
		_last_value = text

func _on_html_input(args: Array) -> void:
	if args.is_empty():
		return
	if editable:
		text = str(args[0])
		_last_value = text
		text_changed.emit(text)
	else:
		_bridge.value(_id, text)

func _on_html_submit(_args: Array) -> void:
	if editable:
		text_submitted.emit(text)

func _exit_tree() -> void:
	if _bridge != null:
		_bridge.remove(_id)
	_input_callback = null
	_submit_callback = null
	_bridge = null
