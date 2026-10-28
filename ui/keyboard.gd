class_name GardenKeyboard
extends VBoxContainer

signal letter_pressed(letter: String)
signal backspace_pressed
signal submit_pressed

const TR_ROWS := [
	["A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H"],
	["I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P"],
	["R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"]
]
const EN_ROWS := [
	["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
	["A", "S", "D", "F", "G", "H", "J", "K", "L"],
	["Z", "X", "C", "V", "B", "N", "M"]
]

var language := "tr"
var enabled := true
var _rows_box: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 5)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 5)
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_rows_box)


func setup(lang: String) -> void:
	language = "en" if lang == "en" else "tr"
	_rebuild()


func set_enabled(value: bool) -> void:
	enabled = value
	for row in _rows_box.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Button:
					(child as Button).disabled = not enabled


func _rebuild() -> void:
	GardenWidgets.clear_children(_rows_box)
	var rows: Array = EN_ROWS if language == "en" else TR_ROWS
	for row_letters_v in rows:
		var row_letters: Array = row_letters_v
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for letter_v in row_letters:
			var letter := str(letter_v)
			var b := _make_key(letter, 40.0, 16)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = letter
			b.pressed.connect(_on_letter.bind(letter))
			row.add_child(b)
		_rows_box.add_child(row)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := _make_key("⌫  " + GardenLoc.t("backspace", GardenApi.lang()), 42.0, 14)
	back.custom_minimum_size.x = 92
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.tooltip_text = GardenLoc.t("backspace", GardenApi.lang())
	back.pressed.connect(_on_backspace)
	actions.add_child(back)
	var submit := _make_key(GardenLoc.t("submit", GardenApi.lang()), 42.0, 15)
	submit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submit.add_theme_stylebox_override("normal", GardenTheme.button_style(GardenTheme.LAVENDER, 13, false))
	submit.add_theme_stylebox_override("hover", GardenTheme.button_style(GardenTheme.LAVENDER.lightened(0.07), 13, false))
	submit.add_theme_stylebox_override("pressed", GardenTheme.button_style(GardenTheme.LAVENDER_DEEP, 13, false))
	submit.add_theme_color_override("font_color", Color("2f2650"))
	submit.add_theme_color_override("font_pressed_color", Color.WHITE)
	submit.pressed.connect(_on_submit)
	actions.add_child(submit)
	_rows_box.add_child(actions)
	set_enabled(enabled)


func _make_key(text: String, height: float, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	# Enter must submit the word, not press the last clicked letter again.
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", GardenTheme.bold_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", GardenTheme.INK)
	b.add_theme_color_override("font_hover_color", GardenTheme.INK)
	b.add_theme_color_override("font_pressed_color", GardenTheme.INK)
	b.add_theme_color_override("font_disabled_color", GardenTheme.LOCKED_INK)
	var normal := GardenTheme.panel_style(GardenTheme.CARD, 12, true)
	normal.content_margin_left = 2
	normal.content_margin_right = 2
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	var hover := GardenTheme.panel_style(GardenTheme.LAVENDER_SOFT, 12, false)
	hover.content_margin_left = 2
	hover.content_margin_right = 2
	hover.content_margin_top = 2
	hover.content_margin_bottom = 2
	var pressed := GardenTheme.panel_style(GardenTheme.PINK_SOFT, 12, false)
	pressed.content_margin_left = 2
	pressed.content_margin_right = 2
	pressed.content_margin_top = 2
	pressed.content_margin_bottom = 2
	var disabled := GardenTheme.panel_style(GardenTheme.LOCKED, 12, false)
	disabled.content_margin_left = 2
	disabled.content_margin_right = 2
	disabled.content_margin_top = 2
	disabled.content_margin_bottom = 2
	var focus := GardenTheme.panel_style(Color.TRANSPARENT, 12, false, GardenTheme.LAVENDER_DEEP, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus)
	return b


func _on_letter(letter: String) -> void:
	if not enabled:
		return
	GardenApi.play_sound("key")
	letter_pressed.emit(letter)


func _on_backspace() -> void:
	if not enabled:
		return
	GardenApi.play_sound("key")
	backspace_pressed.emit()


func _on_submit() -> void:
	if not enabled:
		return
	GardenApi.play_sound("key")
	submit_pressed.emit()
