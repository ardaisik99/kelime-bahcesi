extends Control
## Mobile menu: one primary action, compact modes, progress and categories.
var app: Node
var _focus_target: Control
var _next_level: Dictionary = {}

func setup(_params: Dictionary = {}) -> void:
	_build()

func _build() -> void:
	GardenWidgets.clear_children(self)
	var tr := GardenApi.lang() == "tr"
	var lang := GardenApi.lang()
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	content.add_child(GardenWidgets.vspace(6))
	var greeting := HBoxContainer.new()
	greeting.add_theme_constant_override("separation", 12)
	var initial := GardenWidgets.panel(GardenTheme.LAVENDER_SOFT, 16, false, 0)
	initial.custom_minimum_size = Vector2(48, 48)
	initial.add_child(GardenWidgets.bold_label(GardenApi.upper(GardenApi.player_name().left(1)), 22, GardenTheme.LAVENDER_DEEP, HORIZONTAL_ALIGNMENT_CENTER))
	greeting.add_child(initial)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	names.add_child(GardenWidgets.label("TEKRAR HOŞ GELDİN" if tr else "WELCOME BACK", 11, GardenTheme.MUTED))
	names.add_child(GardenWidgets.bold_label(GardenApi.player_name() if not GardenApi.player_name().is_empty() else ("Oyuncu" if tr else "Player"), 21))
	greeting.add_child(names)
	var settings := GardenWidgets.small_button("", "ghost", 44)
	settings.icon = GardenPaint.texture(9)
	settings.expand_icon = true
	settings.add_theme_constant_override("icon_max_width", 24)
	settings.custom_minimum_size.x = 44
	for state in ["normal", "hover", "pressed"]:
		var sb := GardenTheme.button_style(GardenTheme.LAVENDER_SOFT, 15, false)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		settings.add_theme_stylebox_override(state, sb)
	settings.tooltip_text = GardenLoc.t("settings", lang)
	settings.pressed.connect(func() -> void: app.open_settings())
	greeting.add_child(settings)
	content.add_child(greeting)

	content.add_child(GardenWidgets.title("Bağlantıyı bul.\nZinciri tamamla." if tr else "Find the link.\nComplete the chain.", 34))
	content.add_child(GardenWidgets.label("Biraz düşün, bir kelimeyle devam et." if tr else "Take a moment. Find the next word.", 15, GardenTheme.MUTED))
	_next_level = GardenApi.next_unfinished(lang)
	var all := GardenApi.all_levels(lang)
	var done := 0
	for lv in all:
		if GardenApi.is_completed(lang, lv.get("id", "")):
			done += 1

	var hero := GardenWidgets.panel(GardenTheme.LAVENDER, 24, false, 22)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 12)
	hero.add_child(hv)
	var head := HBoxContainer.new()
	var eyebrow := GardenWidgets.bold_label("KELİME YOLCULUĞUN" if tr else "YOUR WORD JOURNEY", 11, Color("e7dcff"))
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(eyebrow)
	head.add_child(GardenWidgets.bold_label("%02d / %02d" % [done, all.size()], 13, Color.WHITE))
	hv.add_child(head)
	var title := GardenLoc.t("all_done_title", lang) if done == all.size() else (("Bölüm %02d" if tr else "Chapter %02d") % (all.find(_next_level) + 1))
	hv.add_child(GardenWidgets.bold_label(title, 27, Color.WHITE))
	hv.add_child(GardenWidgets.label("Kolaydan zora, her adımda yeni bir zincir." if tr else "From easy to challenging, one link at a time.", 13, Color("e7dcff"), HORIZONTAL_ALIGNMENT_LEFT, true))
	var journey_progress := GardenWidgets.progress_bar(done, all.size(), Color("e9deff"), 5)
	var track := GardenTheme.panel_style(Color("9366e5"), 3, false)
	track.content_margin_left = 0
	track.content_margin_right = 0
	track.content_margin_top = 0
	track.content_margin_bottom = 0
	journey_progress.add_theme_stylebox_override("background", track)
	hv.add_child(journey_progress)
	var play := GardenWidgets.button("Oyna" if tr else "Play", "white", 52)
	play.icon = GardenPaint.texture(1)
	play.expand_icon = true
	play.add_theme_constant_override("icon_max_width", 24)
	play.pressed.connect(_play)
	hv.add_child(play)
	_focus_target = play
	content.add_child(hero)

	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 12)
	modes.add_child(_mode("Parti" if tr else "Party", "Birlikte düşünün" if tr else "Think together", 2, func() -> void: app.open_party()))
	modes.add_child(_mode("Online", "Yakında" if tr else "Coming soon", 3, func() -> void: app.open_online()))
	content.add_child(modes)

	var section := HBoxContainer.new()
	var section_title := GardenWidgets.bold_label("Kategorileri keşfet" if tr else "Explore categories", 19)
	section_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(section_title)
	section.add_child(GardenWidgets.label("03", 13, GardenTheme.MUTED))
	content.add_child(section)
	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation", 10)
	for cat in GardenApi.categories(lang):
		var progress := GardenApi.category_progress(lang, str(cat.get("id", "")))
		var b := GardenWidgets.button("", "white", 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 10
		inner.offset_right = -10
		inner.offset_top = 14
		inner.offset_bottom = -14
		inner.add_theme_constant_override("separation", 8)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		inner.add_child(GardenWidgets.bold_label(GardenLoc.category_name(cat, lang), 15, GardenTheme.INK, HORIZONTAL_ALIGNMENT_CENTER))
		inner.add_child(GardenWidgets.label("%d / %d" % [progress.done, progress.total], 12, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		inner.add_child(GardenWidgets.progress_bar(progress.done, progress.total, GardenTheme.LAVENDER, 4))
		_ignore_mouse(inner)
		b.pressed.connect(func() -> void: app.open_category(cat))
		cats.add_child(b)
	content.add_child(cats)

	var learn := GardenWidgets.button("Nasıl oynanır?     Başlangıç rehberi" if tr else "How to play?     A hands-on guide", "ghost", 54)
	learn.add_theme_font_size_override("font_size", 14)
	learn.icon = GardenPaint.texture(7)
	learn.expand_icon = true
	learn.add_theme_constant_override("icon_max_width", 25)
	learn.pressed.connect(func() -> void: app.start_tutorial())
	content.add_child(learn)
	content.add_child(GardenWidgets.label("Düşünmek için zamanın var." if tr else "Take your time. Make the connection.", 12, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, true))
	content.add_child(GardenWidgets.vspace(8))

func _mode(title: String, subtitle: String, index: int, action: Callable) -> Button:
	var b := GardenWidgets.button("", "white", 102)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	var inner := HBoxContainer.new()
	b.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 16
	inner.offset_right = -12
	inner.offset_top = 16
	inner.offset_bottom = -16
	inner.add_theme_constant_override("separation", 10)
	inner.add_child(GardenPaint.icon(index, 30))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(GardenWidgets.bold_label(title, 19))
	v.add_child(GardenWidgets.label(subtitle, 12, GardenTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))
	inner.add_child(v)
	_ignore_mouse(inner)
	return b

func _play() -> void:
	if not bool(GardenApi.get_pref("tutorial_v2_" + GardenApi.lang(), false)):
		app.start_tutorial()
	elif not _next_level.is_empty():
		app.play_level(_next_level)

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func initial_focus() -> Control:
	return _focus_target
