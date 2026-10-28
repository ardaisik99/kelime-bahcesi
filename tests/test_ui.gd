extends SceneTree
## End-to-end profile, tutorial, native keyboard, economy, bilingual and layout checks.
## Real saves are never edited. Preferences are snapshotted and restored.
var _main: Control
var _checks := 0
var _failures := 0
var _shots := ""
var _prefs_backup := ""
var _prefs_existed := false
var _prefs_memory: Dictionary
var _save_path := ""
var _original_save_path := ""
var _original_backup := ""

func _initialize() -> void:
	root.size = Vector2i(480, 900)
	root.content_scale_size = Vector2i(480, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			_shots = arg.substr(14)
	create_timer(90).timeout.connect(func() -> void:
		print("[ui] FAIL: watchdog timeout")
		await _cleanup()
		quit(1))
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		print("[ui] FAIL: " + message)

func _frames(count: int = 4) -> void:
	for i in count:
		await process_frame

func _settle(seconds: float = 0.8) -> void:
	await create_timer(seconds).timeout
	await _frames()

func _run() -> void:
	await _frames()
	var store := root.get_node("SaveStore")
	_original_save_path = store.save_path
	_original_backup = store.backup_path
	_save_path = "user://test_ui_v2_%d.json" % Time.get_ticks_usec()
	store.set_storage_path(_save_path)
	_prefs_existed = FileAccess.file_exists(GardenApi.UI_PREFS_PATH)
	if _prefs_existed:
		_prefs_backup = FileAccess.get_file_as_string(GardenApi.UI_PREFS_PATH)
	_prefs_memory = GardenApi.prefs().duplicate(true)
	GardenApi._prefs = {"language": "tr", "reduced_motion": false}
	GardenApi.set_sound_enabled(false)
	GardenApi.set_lang("tr")
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)
	await _settle(0.25)
	_check(_main._route.name == "profile", "first run asks for a local profile")
	var profile: Control = _main._screen
	profile._save()
	_check(not profile._error.text.is_empty(), "profile rejects an empty name")
	profile._name.text = "Deniz"
	profile._select_language("en")
	_check(profile._name.text == "Deniz", "language change preserves draft name")
	profile._select_language("tr")
	await _shot("profile")
	profile._save()
	await _settle(0.25)
	_check(GardenApi.player_name() == "Deniz", "local name saved")
	_check(_main._screen._tutorial, "profile leads into interactive tutorial")
	var play: Control = _main._screen
	_check(play._keyboard == null, "no custom keyboard in game")
	_check(play._answer_input.virtual_keyboard_enabled, "native device keyboard enabled")
	_check(play._session.current == "BARDAĞI", "tutorial asks for inflected word")
	_check(play._session.word_length(1) == 7, "inflected answer mask length")
	await _shot("tutorial")
	var before_nodes: int = play._chain_view.get_child(0).get_instance_id()
	_enter(play, "bardak")
	play._submit_button.pressed.emit()
	await _frames()
	_check(play._session.active_word_index() == 1, "bare root does not advance")
	_enter(play, "bardağı")
	_check(play._chain_view.get_child(0).get_instance_id() == before_nodes, "typing preserves existing cards")
	play._submit_button.pressed.emit()
	await _frames()
	await _shot("morph")
	_check(play._busy, "input is guarded during root morph")
	await _settle()
	_check(play._session.active_word_index() == 2, "correct inflection advances one word")
	_check(play._chain_view.get_child(1).find_child("SolvedWord", true, false).text == "BARDAK", "inflected answer morphs into root")
	_enter(play, "altlığı")
	play._submit_button.pressed.emit()
	await _settle()
	_check(play._chain_view.get_child(2).find_child("SolvedWord", true, false).text == "ALTLIK", "second inflection morphs into root")
	_enter(play, "kenarı")
	play._submit_button.pressed.emit()
	await _settle()
	_check(play._victory_open, "tutorial ends after verified final word")
	_check(bool(GardenApi.get_pref("tutorial_v2_tr", false)), "tutorial completion persists")
	_check(GardenApi.coins() == 100, "tutorial leaves real coins untouched")
	_check(not store.is_completed("tr", "tutorial_v2"), "tutorial leaves real progress untouched")
	await _shot("tutorial_complete")
	_main.goto_home()
	await _settle(0.25)
	_check(_button("Oyna") != null, "primary play action exists")
	_check(_button("Parti") != null, "party action exists")
	_check(_button("Online") != null, "online placeholder exists")
	await _layout("home")
	await _shot("home")
	_button("Online").pressed.emit()
	await _frames()
	_check(_main._modal_open(), "online shows coming-soon dialog")
	_check(not root.get_node("NetworkClient").is_processing(), "offline menu never polls network")
	_main.close_modal()
	_button("Parti").pressed.emit()
	await _settle(0.25)
	play = _main._screen
	_check(play._mode == "party", "party route retained")
	_check(play._answer_input == null, "party has no text input")
	var party_id: String = play._level.id
	play._next_party_chain()
	await _frames()
	_check(play._level.id != party_id, "party avoids immediate repeats")
	_check(GardenApi.coins() == 100, "party does not award coins")
	await _shot("party")
	_main.goto_home()
	_main.open_category(GardenApi.categories("tr")[0])
	await _settle(0.25)
	await _layout("category")
	await _shot("category")
	_main.goto_home()
	_button("Oyna").pressed.emit()
	await _settle(0.25)
	play = _main._screen
	_check(not play._tutorial, "completed tutorial is not repeated")
	_check(play._session.current == "SUYU", "first easy level uses noun compound")
	var level_id: String = play._level.id
	var active := play._session.active_word_index() as int
	_enter(play, "s")
	play._submit_button.pressed.emit()
	await _frames()
	_check(play._session.active_word_index() == active, "incomplete input does not advance")
	play._hint_button.pressed.emit()
	await _frames()
	_check(GardenApi.coins() == 90, "hint costs 10")
	_check(not play._hint_text.is_empty(), "hint appears")
	play._reveal_button.pressed.emit()
	await _frames()
	_check(GardenApi.coins() == 75, "letter costs 15")
	await _layout("play")
	await _shot("play")
	await _solve(play)
	_check(play._victory_open, "real level completes")
	_check(GardenApi.coins() == 100, "first clear awards 25")
	_check(store.is_completed("tr", level_id), "level completion persisted")
	await _shot("victory")
	_main.play_level(GardenApi.get_level("tr", level_id), {}, true)
	await _frames()
	play = _main._screen
	GardenApi.set_reduced_motion(true)
	await _solve(play)
	_check(GardenApi.coins() == 100, "replay gives no duplicate reward")
	_check(play._victory_open, "reduced-motion mode still completes")
	_main.goto_home()
	_main.set_language("en")
	await _settle(0.25)
	_check(GardenApi.coins() == 100, "independent English balance")
	await _shot("home_en")
	_button("Play").pressed.emit()
	await _frames()
	play = _main._screen
	_check(play._tutorial, "new language gets its own tutorial")
	_check(play._session.current == "CREAM", "English compound unchanged")
	await _solve(play)
	_check(bool(GardenApi.get_pref("tutorial_v2_en", false)), "English tutorial completion saved")
	_main.goto_home()
	_main.open_settings()
	await _settle(0.25)
	await _shot("settings")
	var settings: Control = _main._screen
	settings._show_licenses("en")
	await _frames()
	_check(settings._license_layer != null, "licenses remain available")
	settings._close_licenses()
	_main.show_screen("profile", {"first_run": false})
	await _frames()
	profile = _main._screen
	profile._name.text = "Ada"
	profile._save()
	await _frames()
	_check(GardenApi.player_name() == "Ada", "profile editable later")
	_check(_main._route.name == "home", "profile edit returns to menu")
	_main.set_language("tr")
	# Phone-width layouts at 360 and 320 logical pixels.
	for width in [360, 320]:
		root.content_scale_size = Vector2i(width, 800)
		root.size = Vector2i(width, 800)
		await _settle(0.2)
		await _layout("home_" + str(width))
		await _shot("home_" + str(width))
		_main.play_level(GardenApi.all_levels("tr")[17], {}, true)
		await _settle(0.2)
		await _layout("long_word_" + str(width))
		await _shot("play_" + str(width))
		_main.goto_home()
	root.content_scale_size = Vector2i(360, 450)
	root.size = Vector2i(360, 450)
	_main.play_level(GardenApi.all_levels("tr")[0], {}, true)
	await _settle(0.2)
	play = _main._screen
	_check(play._answer_input.get_global_rect().end.y <= 450, "input stays above keyboard-sized viewport")
	await _layout("keyboard_height")
	await _shot("keyboard_height")
	await _cleanup()
	print("[ui] RESULT: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL", _checks])
	quit(0 if _failures == 0 else 1)

func _enter(play: Control, text: String) -> void:
	play._answer_input.text = text
	play._answer_input.text_changed.emit(text)

func _solve(play: Control) -> void:
	for i in range(6):
		if play._finished:
			return
		_enter(play, str(play._session.current))
		play._submit_button.pressed.emit()
		await _settle(0.72)
	_check(play._finished, "bounded solve loop finishes")

func _button(text: String) -> Button:
	for node in _nodes(_main):
		if node is Button and node.is_visible_in_tree() and node.text == text:
			return node
		if node is Button and node.is_visible_in_tree():
			for child in _nodes(node):
				if child is Label and child.text == text:
					return node
	return null

func _nodes(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_nodes(child))
	return out

func _layout(label: String) -> void:
	await _frames(5)
	var width := root.get_visible_rect().size.x
	for node in _nodes(_main):
		if not node is Control or not node.is_visible_in_tree() or node is ScrollBar:
			continue
		var rect: Rect2 = node.get_global_rect()
		if rect.size.x > 2:
			_check(rect.position.x >= -2 and rect.end.x <= width + 2, "no horizontal overflow: " + label + "/" + str(node.name))

func _shot(name: String) -> void:
	if _shots.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(5)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_shots)
	var img := root.get_texture().get_image()
	_check(img.save_png(_shots.path_join(name + ".png")) == OK, "screenshot saved " + name)

func _cleanup() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
	await _frames()
	root.get_node("AudioManager").stop_all()
	var store := root.get_node("SaveStore")
	store.set_storage_path(_original_save_path, _original_backup)
	for path in [_save_path, _save_path + ".bak", _save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _prefs_existed:
		var file := FileAccess.open(GardenApi.UI_PREFS_PATH, FileAccess.WRITE)
		file.store_string(_prefs_backup)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GardenApi.UI_PREFS_PATH))
	GardenApi._prefs = _prefs_memory
	await _frames()
