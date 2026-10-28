extends Control
## Local profile. No account, network request or tracking.
var app: Node
var _first_run := true
var _name: LineEdit
var _error: Label
var _selected := "tr"

func setup(params: Dictionary = {}) -> void:
	_first_run = bool(params.get("first_run", true))
	_selected = GardenApi.lang()
	_build()

func _build() -> void:
	GardenWidgets.clear_children(self)
	var tr := _selected == "tr"
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	scroll.add_child(v)
	v.add_child(GardenWidgets.vspace(35))
	var mark := GardenPaint.brand(80)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(mark)
	v.add_child(GardenWidgets.title("Kelime Zinciri", 33, GardenTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(GardenWidgets.label("Her kelime yeni bir başlangıç." if tr else "Every word is a new beginning.", 16, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(GardenWidgets.vspace(20))
	var card := GardenWidgets.panel(GardenTheme.CARD, 24, false, 24)
	v.add_child(card)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 14)
	card.add_child(form)
	form.add_child(GardenWidgets.title("Seni nasıl tanıyalım?" if tr else "What should we call you?", 25))
	form.add_child(GardenWidgets.label("Oyuncu adını ve oyun dilini seç. İkisini de daha sonra değiştirebilirsin." if tr else "Choose a player name and a language. You can change both later.", 15, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	form.add_child(GardenWidgets.bold_label("OYUNCU ADI" if tr else "PLAYER NAME", 12, GardenTheme.MUTED))
	_name = GardenWidgets.line_edit("Adın" if tr else "Your name", GardenApi.player_name(), 18)
	_name.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_name.emoji_menu_enabled = false
	form.add_child(_name)
	form.add_child(GardenWidgets.bold_label("KONUŞTUĞUN DİL" if tr else "YOUR LANGUAGE", 12, GardenTheme.MUTED))
	form.add_child(GardenWidgets.segmented([{"value": "tr", "label": "Türkçe"}, {"value": "en", "label": "English"}], _selected, _select_language, 48))
	_error = GardenWidgets.label("", 13, GardenTheme.DANGER, HORIZONTAL_ALIGNMENT_LEFT, true)
	form.add_child(_error)
	var start := GardenWidgets.button("Hadi başlayalım" if tr else "Let's begin", "primary", 54)
	start.pressed.connect(_save)
	_name.text_submitted.connect(func(_text: String) -> void: _save())
	form.add_child(start)
	v.add_child(GardenWidgets.label("Profilin ve ilerlemen bu cihazda saklanır." if tr else "Your profile and progress stay on this device.", 13, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	if not _first_run:
		var cancel := GardenWidgets.button("Vazgeç" if tr else "Cancel", "ghost", 46)
		cancel.pressed.connect(func() -> void: app.force_back())
		v.add_child(cancel)

func _select_language(code: String) -> void:
	var draft := _name.text
	_selected = code
	_build()
	_name.text = draft

func _save() -> void:
	var clean := _name.text.strip_edges()
	if clean.length() < 2:
		_error.text = "En az 2 harfli bir ad yaz." if _selected == "tr" else "Use at least 2 letters."
		return
	for ch in clean:
		if ch.unicode_at(0) > 0xFFFF or ch.unicode_at(0) < 32:
			_error.text = "Harf, rakam ve boşluk kullan." if _selected == "tr" else "Use letters, numbers and spaces."
			return
	GardenApi.set_player_name(clean)
	GardenApi.set_lang(_selected)
	_name.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	if _first_run and not bool(GardenApi.get_pref("tutorial_v2_" + _selected, false)):
		app.start_tutorial()
	else:
		app.goto_home()

func handle_back() -> bool:
	return _first_run
