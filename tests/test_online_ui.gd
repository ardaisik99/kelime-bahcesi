extends "res://tests/test_ui.gd"
## Actual game screen + NetworkClient against a separate real WebSocket opponent.
## Start backend/local-server.mjs, then run with -- --url=ws://127.0.0.1:8787/ws.

var _peer: WebSocketPeer
var _events: Array[Dictionary] = []
var _online: Control
var _url := "ws://127.0.0.1:8787/ws"
var _received_emote := false


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--url="):
			_url = argument.substr(6)
	if not await _ensure_autoloads():
		_finish()
		return
	_store = root.get_node("SaveStore")
	_content = root.get_node("Content")
	_i18n = root.get_node("I18n")
	if not await _prepare_isolated_save():
		_finish()
		return
	if await _load_main_scene():
		var network := root.get_node("NetworkClient")
		network.call("ingest_message", JSON.stringify({"type": "pong", "server_time": int(Time.get_unix_time_from_system() * 1000.0) + 3600000}))
		_check(int(network.call("server_now_msec")) > int(Time.get_unix_time_from_system() * 1000.0) + 3599000, "match clock follows server time, not the device clock")
		await _match("tr", true)
		await _match("en", false)
	if _peer != null:
		_peer.close()
	if is_instance_valid(_main):
		_main.call("goto_home")
		await _frames(4)
	await _cleanup_isolated_save()
	_finish()


func _match(language: String, ui_hosts: bool) -> void:
	print("[online-ui] ", language, " host=", ui_hosts)
	var network := root.get_node("NetworkClient")
	network.call("set_url", _url)
	# The joining client deliberately starts in the OTHER language.
	GardenApi.set_lang(language if ui_hosts else "tr")
	_main.call("goto_home")
	await _frames(3)
	var entry := _find_button([GardenLoc.t("home_online", GardenApi.lang())])
	await _press(entry, "online mode")
	_online = _main.get("_screen")
	if _online == null or not ("_net" in _online):
		_fail("the real online screen could not be instantiated")
		return
	if not await _wait_condition(func() -> bool: return bool(_online.get("_connected")), "game NetworkClient connection", 8000):
		_fail("game NetworkClient did not connect to " + _url)
		return
	_check(true, "online screen connects with the production NetworkClient")
	_check_no_horizontal_overflow("online lobby")
	var name_field: LineEdit = _online.get("_name_edit")
	name_field.text = "Garden UI"
	_peer = WebSocketPeer.new()
	_events.clear()
	_peer.connect_to_url(_url)
	if not await _wait_peer_open():
		_fail("opponent could not connect")
		return
	var code := ""
	if ui_hosts:
		await _press(_online.get("_create_button"), "create room")
		if not await _wait_condition(func() -> bool: return not str(_online.get("_room_code")).is_empty(), "UI room code", 5000):
			_fail("UI did not create a room")
			return
		code = str(_online.get("_room_code"))
		_send_peer({"type": "join", "code": code, "name": "Garden Peer"})
	else:
		_send_peer({"type": "create", "language": language, "name": "Garden Peer"})
		var room := await _peer_event("room")
		code = str(room.get("code", ""))
		var code_field: LineEdit = _online.get("_code_edit")
		code_field.text = code
		await _press(_online.get("_join_button"), "join room")
	_check(code.length() == 6, "room code contains six characters")
	var start := await _peer_event("start")
	if start.is_empty():
		_fail("opponent did not receive start")
		return
	if not await _wait_condition(func() -> bool: return str(_online.get("_state")) in ["countdown", "match"], "UI countdown", 4000):
		_fail("online screen did not enter countdown")
		return
	_check(GardenApi.lang() == language, "joining synchronises the UI and keyboard to the room language")
	_check(not bool(_online.get("_match_started")), "3-2-1 countdown appears before input is enabled")
	await _shot("online_" + language + "_countdown")
	if not await _wait_condition(func() -> bool: return bool(_online.get("_match_started")), "simultaneous start", 5000):
		_fail("countdown never completed")
		return
	_check(_keyboard_letters().length() == (29 if language == "tr" else 26), "room uses the matching alphabet")
	_check_no_horizontal_overflow("online match")
	await _shot("online_" + language + "_match")
	var levels: Array = start.get("levels", [])
	_check((_online.get("_levels") as Array).size() == 3, "game resolves the same three server-selected chains")
	var first: Dictionary = _content.call("get_level", language, str(levels[0]))
	_send_peer({"type": "answer", "answer": first.words[1], "level_index": 0, "word_index": 1})
	if not await _wait_condition(func() -> bool: return int(_online.get("_score_opp")) == 100, "live opponent score", 5000):
		_fail("game did not display the opponent score")
		return
	_check(true, "opponent's score is updated live in the actual game")
	_received_emote = false
	var emote_handler := func(_id: String, emote: String) -> void: _received_emote = emote == "hello"
	network.connect("emote_received", emote_handler)
	_send_peer({"type": "emote", "id": "hello"})
	await _wait_condition(func() -> bool: return _received_emote, "incoming emote", 4000)
	_check(_received_emote, "game receives the opponent's canned message")
	network.disconnect("emote_received", emote_handler)
	# A wrong typed letter must be displayed as typed, never as the secret answer.
	var wrong := "Z".repeat(str(first.words[1]).length() - 1)
	await _type_word(wrong)
	var view: Control = _online.get("_chain_view")
	var row: HBoxContainer = view.get("_input_row")
	_check((row.get_child(1).get_child(0) as Label).text == "Z", "online boxes display the player's actual input")
	await _submit_keyboard()
	_check(int(_online.get("_word_index")) == 1 and int(_online.get("_score_self")) == 0, "server rejects the wrong word without awarding points")
	# Solve all three chains through the real on-screen keys.
	var guard := 0
	while not bool(_online.get("_awaiting_finish")) and guard < 20:
		guard += 1
		var li := int(_online.get("_level_index"))
		var wi := int(_online.get("_word_index"))
		var word := str(_online.call("_current_word"))
		if not await _type_word(word.substr(1)):
			break
		await _submit_keyboard()
		if not await _wait_condition(func() -> bool:
			return not bool(_online.get("_answer_pending")) and (bool(_online.get("_awaiting_finish")) or int(_online.get("_level_index")) != li or int(_online.get("_word_index")) != wi), "server accepts UI word", 4000):
			_fail("UI could not advance after a correct answer")
			return
	_check(bool(_online.get("_awaiting_finish")), "player finishes all three chains using the game keyboard")
	var expected_score := 0
	for li in levels.size():
		var level: Dictionary = _content.call("get_level", language, str(levels[li]))
		for wi in range(1, level.words.size()):
			expected_score += 100
			if li == 0 and wi == 1:
				continue
			_send_peer({"type": "answer", "answer": level.words[wi], "level_index": li, "word_index": wi})
			await _settle(0.16)
	_check(await _wait_condition(func() -> bool: return str(_online.get("_state")) == "finish", "server finish", 5000), "server completion opens the result screen")
	_check(int(_online.get("_score_self")) == expected_score and int(_online.get("_score_opp")) == expected_score, "final scores match the server-validated words")
	_check(_coins() == 100, "online scores never alter the offline wallet")
	await _shot("online_" + language + "_finish")
	_peer.close(1000, "test done")
	_main.call("goto_home")
	await _settle(0.3)
	_check(not bool(network.call("is_open")), "leaving the online screen closes its socket")


func _send_peer(message: Dictionary) -> void:
	_peer.send_text(JSON.stringify(message))


func _pump_peer() -> void:
	if _peer == null:
		return
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var data: Variant = JSON.parse_string(_peer.get_packet().get_string_from_utf8())
		if data is Dictionary:
			_events.append(data)


func _wait_peer_open() -> bool:
	var end := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < end:
		_pump_peer()
		if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			return true
		await process_frame
	return false


func _peer_event(type: String) -> Dictionary:
	var end := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < end:
		_pump_peer()
		for event in _events:
			if str(event.get("type", "")) == type:
				_events.erase(event)
				return event
		await process_frame
	return {}
