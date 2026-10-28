extends SceneTree

## Real-WebSocket protocol smoke test for the local Tamlama server.
##
## Run (server must already be listening):
##   Godot_v4.5.2-stable_win64_console.exe --headless --path . \
##       --script tests/test_network.gd
##
## Optional:
##   -- --url=ws://127.0.0.1:8787
##
## The harness deliberately talks to the server with two independent
## WebSocketPeer instances. That keeps the wire protocol test independent of
## whatever convenience API core/network_client.gd exposes, so a bug in the
## client wrapper cannot hide a bug in the server (or vice versa).
##
## It never leaves the process hanging: every wait is bounded and the whole
## run has a hard deadline well below the 60 s CI timeout. Any failure or
## timeout exits with status 1.

const DEFAULT_URL := "ws://127.0.0.1:8787/ws"
const TOTAL_BUDGET_MS := 55000
const CONNECT_TIMEOUT_MS := 8000
const DEFAULT_WAIT_MS := 6000

const AUTOLOADS := [
	["SaveStore", "res://core/save_store.gd"],
	["I18n", "res://core/i18n.gd"],
	["Content", "res://core/content.gd"],
]

var _deadline_ms := 0
var _failures: Array[String] = []
var _checks := 0
var _network_peer_a: Dictionary = {}
var _network_peer_b: Dictionary = {}


func _initialize() -> void:
	_deadline_ms = Time.get_ticks_msec() + TOTAL_BUDGET_MS
	call_deferred("_run")


func _run() -> void:
	print("[network] starting protocol test")
	var url := _url_from_args()
	print("[network] server: ", url)

	if not await _ensure_autoloads():
		_finish()
		return

	var content := root.get_node_or_null("Content")
	if content == null:
		_fail("Content autoload is unavailable")
		_finish()
		return
	await _frames(2)
	if content.has_method("is_loaded") and not bool(content.call("is_loaded", "tr")):
		var errors: Variant = content.call("errors") if content.has_method("errors") else []
		_fail("Turkish Content data did not load: %s" % [str(errors)])
		_finish()
		return

	var a := await _connect_peer(url, "A")
	if a.is_empty():
		_finish()
		return
	var b := await _connect_peer(url, "B")
	if b.is_empty():
		_close_peer(a)
		_finish()
		return
	_network_peer_a = a
	_network_peer_b = b

	# ---- create room -----------------------------------------------------
	_send(a, {"type": "create", "language": "tr", "name": "Harness A"})
	var welcome_a := await _wait_event(a, func(m: Dictionary) -> bool:
		return str(m.get("type", "")) == "welcome", "A welcome")
	if welcome_a.is_empty():
		_close_all()
		_finish()
		return
	print("[network] A welcome: ", JSON.stringify(welcome_a))

	var player_a := str(welcome_a.get("player_id", welcome_a.get("id", "")))
	_check(not player_a.is_empty(), "welcome A has a player_id")
	if player_a.is_empty():
		_close_all()
		_finish()
		return

	# The current server answers create with a room snapshot (code/language/
	# players) rather than embedding the room in welcome. Accept both shapes.
	var room_a := await _wait_event(a, func(m: Dictionary) -> bool:
		var t := str(m.get("type", ""))
		return not _room_code(m).is_empty() or t in ["room", "created"], "A room snapshot")
	if room_a.is_empty():
		_close_all()
		_finish()
		return
	print("[network] A room: ", JSON.stringify(room_a))
	var code := _room_code(room_a)
	_check(not code.is_empty(), "create returns a room code")
	if code.is_empty():
		_close_all()
		_finish()
		return

	# ---- join room -------------------------------------------------------
	_send(b, {"type": "join", "code": code, "name": "Harness B"})
	var welcome_b := await _wait_event(b, func(m: Dictionary) -> bool:
		return str(m.get("type", "")) == "welcome", "B welcome")
	if welcome_b.is_empty():
		_close_all()
		_finish()
		return
	var player_b := str(welcome_b.get("player_id", welcome_b.get("id", "")))
	_check(not player_b.is_empty(), "welcome B has a player_id")
	_check(player_a != player_b, "the two players have distinct ids")
	if player_b.is_empty():
		_close_all()
		_finish()
		return

	var joined := await _wait_event(b, func(m: Dictionary) -> bool:
		return _room_code(m) == code, "B room snapshot")
	if joined.is_empty():
		_close_all()
		_finish()
		return
	print("[network] B room: ", JSON.stringify(joined))
	_check(_room_code(joined) == code, "both players are in the same room (%s)" % code)
	_check(_players_count(joined) == 2, "join room snapshot lists two players")

	# ---- start broadcast -------------------------------------------------
	var start_a := await _wait_event(a, func(m: Dictionary) -> bool:
		return str(m.get("type", "")) == "start", "A start", 9000)
	if start_a.is_empty():
		_close_all()
		_finish()
		return
	var start_b := await _wait_event(b, func(m: Dictionary) -> bool:
		return str(m.get("type", "")) == "start", "B start", 9000)
	if start_b.is_empty():
		_close_all()
		_finish()
		return
	print("[network] start A: ", JSON.stringify(start_a))

	var ids_a := _level_ids(start_a)
	var ids_b := _level_ids(start_b)
	_check(ids_a.size() > 0, "start carries at least one level id")
	_check(ids_a == ids_b, "both players receive identical level ids (%s)" % [str(ids_a)])
	_check(_has_number(start_a, "starts_at") and _has_number(start_a, "ends_at"),
		"start carries numeric starts_at/ends_at")
	var starts_at_ms := _timestamp_ms(start_a.get("starts_at", 0))
	var ends_at_ms := _timestamp_ms(start_a.get("ends_at", 0))
	_check(ends_at_ms > starts_at_ms,
		"match window ends after it starts (%d -> %d)" % [starts_at_ms, ends_at_ms])
	var server_now_ms := int(Time.get_unix_time_from_system() * 1000.0)
	_check(starts_at_ms > server_now_ms,
		"start arrived before starts_at (countdown visible: %d ms)" % (starts_at_ms - server_now_ms))

	# ---- early answer must be rejected ----------------------------------
	print("[network] sending deliberately early/wrong answer")
	# The first word of each server level is open, so word_index 1 is the first
	# coordinate the server would accept once the countdown has elapsed.
	_send(a, {"type": "answer", "level_index": 0, "word_index": 1, "answer": "__early_wrong__"})
	var early_result := await _wait_event(a, func(m: Dictionary) -> bool:
		var t := str(m.get("type", ""))
		return t == "error" or (t == "answer_result" and not bool(m.get("correct", false))),
		"early answer rejection", 5000)
	if early_result.is_empty():
		_close_all()
		_finish()
		return
	print("[network] early rejection: ", JSON.stringify(early_result))
	_check(str(early_result.get("type", "")) == "error"
		or not bool(early_result.get("correct", false)),
		"early/wrong answer is rejected")

	# ---- wait for the countdown, then answer correctly ------------------
	var wait_ms := starts_at_ms - int(Time.get_unix_time_from_system() * 1000.0)
	if wait_ms > 0:
		await _sleep(minf(float(wait_ms) / 1000.0 + 0.2, 8.0))
	else:
		await _sleep(0.2)

	var first_level_id := str(ids_a[0])
	var answer := _answer_for_level(first_level_id, 1)
	_check(not answer.is_empty(), "found word 1 for level '%s' in Content" % first_level_id)
	if answer.is_empty():
		_close_all()
		_finish()
		return
	print("[network] submitting correct answer for level %s word 1: %s" % [first_level_id, answer])
	_send(a, {"type": "answer", "level_index": 0, "word_index": 1, "answer": answer})

	var correct := await _wait_event(a, func(m: Dictionary) -> bool:
		return str(m.get("type", "")) == "answer_result" and bool(m.get("correct", false)),
		"correct answer result", 8000)
	if correct.is_empty():
		_close_all()
		_finish()
		return
	print("[network] correct result: ", JSON.stringify(correct))
	_check(bool(correct.get("correct", false)), "server accepts the correct word")
	_check(int(correct.get("score", 0)) >= 100, "correct answer awards at least 100 points")

	# The opponent must see the updated score in the server's score broadcast.
	var seen_score := await _wait_event(b, func(m: Dictionary) -> bool:
		if str(m.get("type", "")) not in ["score", "players"]:
			return false
		return _score_for(m, player_a) > 0,
		"opponent sees A's score", 8000)
	if seen_score.is_empty():
		_close_all()
		_finish()
		return
	print("[network] opponent score update: ", JSON.stringify(seen_score))
	_check(_score_for(seen_score, player_a) > 0,
		"opponent sees player A's first score (%d)" % _score_for(seen_score, player_a))

	# ---- emote -----------------------------------------------------------
	_send(b, {"type": "emote", "id": "hello"})
	var emote := await _wait_event(a, func(m: Dictionary) -> bool:
		if str(m.get("type", "")) != "emote":
			return false
		return str(m.get("player_id", "")) == player_b,
		"emote delivery", 5000)
	if emote.is_empty():
		_close_all()
		_finish()
		return
	print("[network] emote: ", JSON.stringify(emote))
	var emote_id := str(emote.get("id", emote.get("emote_id", emote.get("emote", ""))))
	_check(emote_id == "hello", "opponent receives emote id 'hello' (got '%s')" % emote_id)
	_check(str(emote.get("player_id", "")) == player_b, "emote carries player B's id")

	# ---- explicit leave, opponent gets finish ----------------------------
	_send(a, {"type": "leave"})
	var finish := await _wait_event(b, func(m: Dictionary) -> bool:
		return str(m.get("type", "")) == "finish", "finish after leave", 7000)
	if finish.is_empty():
		_close_all()
		_finish()
		return
	print("[network] finish after leave: ", JSON.stringify(finish))
	var reason := str(finish.get("reason", ""))
	_check(reason in ["opponent_left", "left", "forfeit", "completed"] or not reason.is_empty(),
		"finish carries a leave reason (got '%s')" % reason)
	var finish_players: Variant = finish.get("players", [])
	_check(finish_players is Array, "finish carries a players array")
	if finish_players is Array:
		var left_connected := true
		for entry: Variant in finish_players:
			if entry is Dictionary and _player_id(entry) == player_a:
				left_connected = bool((entry as Dictionary).get("connected", true))
		_check(not left_connected, "finish marks the player who left as disconnected")

	_close_all()
	_finish()


# ---------------------------------------------------------------------------
# WebSocket plumbing
# ---------------------------------------------------------------------------

func _connect_peer(url: String, label: String) -> Dictionary:
	var ws := WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 16
	ws.outbound_buffer_size = 1 << 16
	ws.max_queued_packets = 256
	var err := ws.connect_to_url(url)
	if err != OK:
		_fail("%s could not start WebSocket connection to %s (error %d)" % [label, url, err])
		return {}
	var local_deadline := mini(_deadline_ms, Time.get_ticks_msec() + CONNECT_TIMEOUT_MS)
	while Time.get_ticks_msec() < local_deadline:
		ws.poll()
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			print("[network] %s connected" % label)
			return {"label": label, "ws": ws, "events": []}
		if state == WebSocketPeer.STATE_CLOSED:
			_fail("%s connection closed during handshake: %d %s" % [
				label, ws.get_close_code(), ws.get_close_reason()])
			return {}
		await _sleep(0.02)
	_fail("%s timed out connecting to %s (is the local server running?)" % [label, url])
	return {}


func _send(peer: Dictionary, message: Dictionary) -> void:
	if peer.is_empty():
		return
	var ws: WebSocketPeer = peer["ws"]
	var text := JSON.stringify(message)
	var err := ws.send_text(text)
	if err != OK:
		_fail("%s send failed (error %d): %s" % [str(peer.get("label", "?")), err, text])
		return
	print("[network] -> %s %s" % [str(peer.get("label", "?")), text])


func _pump(peer: Dictionary) -> void:
	if peer.is_empty():
		return
	var ws: WebSocketPeer = peer["ws"]
	ws.poll()
	while ws.get_available_packet_count() > 0:
		var packet := ws.get_packet()
		var text := packet.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if not (parsed is Dictionary):
			_fail("%s received non-object JSON: %s" % [str(peer.get("label", "?")), text])
			continue
		var message: Dictionary = parsed
		print("[network] <- %s %s" % [str(peer.get("label", "?")), text])
		var events: Array = peer["events"]
		events.append(message)
		peer["events"] = events


func _wait_event(peer: Dictionary, predicate: Callable, label: String,
		timeout_ms: int = DEFAULT_WAIT_MS) -> Dictionary:
	var local_deadline := mini(_deadline_ms, Time.get_ticks_msec() + timeout_ms)
	while Time.get_ticks_msec() < local_deadline:
		_pump(peer)
		var events: Array = peer.get("events", [])
		for i in range(events.size()):
			var message: Variant = events[i]
			if message is Dictionary and bool(predicate.call(message)):
				events.remove_at(i)
				peer["events"] = events
				return message
		var ws: WebSocketPeer = peer["ws"]
		if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_fail("%s socket closed while waiting for %s (%d %s)" % [
				str(peer.get("label", "?")), label, ws.get_close_code(), ws.get_close_reason()])
			return {}
		await _sleep(0.02)
	_fail("timed out after %d ms waiting for %s" % [timeout_ms, label])
	return {}


func _close_peer(peer: Dictionary) -> void:
	if peer.is_empty():
		return
	var ws: WebSocketPeer = peer["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.close(1000, "test complete")
		for i in range(10):
			ws.poll()


func _close_all() -> void:
	_close_peer(_network_peer_a)
	_close_peer(_network_peer_b)


# ---------------------------------------------------------------------------
# Content helpers
# ---------------------------------------------------------------------------

func _ensure_autoloads() -> bool:
	var ok := true
	for entry: Array in AUTOLOADS:
		var autoload_name := str(entry[0])
		var path := str(entry[1])
		if root.has_node(autoload_name):
			continue
		if not ResourceLoader.exists(path):
			_fail("missing required script %s (%s)" % [path, autoload_name])
			ok = false
			continue
		var script: Script = load(path)
		if script == null:
			_fail("could not load %s" % path)
			ok = false
			continue
		var node := Node.new()
		node.name = autoload_name
		node.set_script(script)
		root.add_child(node)
		print("[network] registered missing autoload %s" % autoload_name)
	await _frames(2)
	return ok


func _answer_for_level(level_id: String, word_index: int) -> String:
	var content := root.get_node_or_null("Content")
	if content == null:
		return ""
	var level: Variant = content.call("get_level", "tr", level_id)
	if not (level is Dictionary):
		# Be defensive: servers may use a numeric id while Content uses strings.
		for candidate: Variant in content.call("get_levels", "tr"):
			if candidate is Dictionary and str(candidate.get("id", "")) == level_id:
				level = candidate
				break
	if not (level is Dictionary):
		return ""
	var words: Variant = (level as Dictionary).get("words", [])
	if not (words is Array) or word_index < 0 or word_index >= (words as Array).size():
		return ""
	return str((words as Array)[word_index]).strip_edges()


# ---------------------------------------------------------------------------
# Message helpers
# ---------------------------------------------------------------------------

func _room_code(message: Dictionary) -> String:
	for key in ["code", "room_code"]:
		var value := str(message.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	var room: Variant = message.get("room", null)
	if room is String:
		return str(room)
	if room is Dictionary:
		return str((room as Dictionary).get("code", "")).strip_edges()
	return ""


func _level_ids(message: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = message.get("levels", [])
	if not (raw is Array):
		return out
	for entry: Variant in raw:
		if entry is String:
			out.append(entry)
		elif entry is Dictionary:
			var id := str((entry as Dictionary).get("id", (entry as Dictionary).get("level_id", "")))
			out.append(id)
		else:
			out.append(str(entry))
	return out


func _has_number(message: Dictionary, key: String) -> bool:
	var raw: Variant = message.get(key, null)
	if typeof(raw) in [TYPE_INT, TYPE_FLOAT]:
		return true
	if raw is String and (raw as String).is_valid_float():
		return true
	return false


func _timestamp_ms(value: Variant) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		var number := float(value)
		return int(number * 1000.0) if number < 100000000000.0 else int(number)
	var text := str(value)
	if text.is_valid_float():
		var number := text.to_float()
		return int(number * 1000.0) if number < 100000000000.0 else int(number)
	return 0


func _players_count(message: Dictionary) -> int:
	var players: Variant = message.get("players", [])
	return (players as Array).size() if players is Array else 0


func _player_id(player: Dictionary) -> String:
	return str(player.get("player_id", player.get("id", "")))


func _score_for(message: Dictionary, player_id: String) -> int:
	var players: Variant = message.get("players", [])
	if not (players is Array):
		return -1
	for entry: Variant in players:
		if not (entry is Dictionary):
			continue
		if _player_id(entry) == player_id:
			return int((entry as Dictionary).get("score", 0))
	return -1


func _url_from_args() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--url="):
			var value := arg.substr("--url=".length()).strip_edges()
			if not value.is_empty():
				return value
	return DEFAULT_URL


# ---------------------------------------------------------------------------
# Assertions / lifecycle
# ---------------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("[network] PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error("[network] FAIL: " + message)
	print("[network] FAIL: ", message)


func _finish() -> void:
	if _failures.is_empty():
		print("[network] RESULT: PASS (%d checks)" % _checks)
		quit(0)
	else:
		print("[network] RESULT: FAIL (%d checks, %d failures)" % [_checks, _failures.size()])
		for failure: String in _failures:
			print("[network]   - ", failure)
		quit(1)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _sleep(seconds: float) -> void:
	await create_timer(seconds).timeout
