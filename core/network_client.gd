extends Node
## Real WebSocket multiplayer client with JSON polling.
##
## Autoload name: NetworkClient (res://core/network_client.gd)
## URL: res://config/network.json {"url":"wss://host/ws"} when present,
## otherwise ws://127.0.0.1:8787/ws (canonical local endpoint). The local
## backend also accepts the legacy root path for older configs, so
## ws://127.0.0.1:8787 keeps working. No secrets or paid APIs are used.
##
## Public API:
##   connect_to_server(ws_url: String = "") -> bool
##   disconnect_from_server(send_leave: bool = true) -> void
##   create_room(language: String = "tr", player_name: String = "Player") -> bool
##   join_room(code: String, player_name: String = "Player") -> bool
##   send_answer(answer: String, level_index: int, word_index: int) -> bool
##   send_emote(emote_id: String) -> bool
##   ping() -> bool
##   leave_room() -> bool
##   is_open() -> bool, get_status() -> String, get_latency_ms() -> int
##   ingest_message(raw_json: String) -> bool   (tests / replay)
##   set_url(ws_url: String) -> void, resolve_url() -> String
##
## Signals:
##   connected()
##   disconnected(reason: String)
##   connection_failed(message: String)
##   message_received(data: Dictionary)          generic, every valid packet
##   welcome(player_id: String)
##   room_updated(code, language, players, status)
##   game_started(starts_at, ends_at, levels, players)
##   answer_result(correct, level_index, word_index, score, finished)
##   score_updated(players)
##   emote_received(player_id, id)
##   game_finished(players, reason)
##   pong(server_time)
##   error_received(code, message)
##   network_error(message)

signal connected
signal disconnected(reason: String)
signal connection_failed(message: String)
signal message_received(data: Dictionary)
signal welcome(player_id: String)
signal room_updated(code: String, language: String, players: Array, status: String)
signal game_started(starts_at: int, ends_at: int, levels: Array, players: Array)
signal answer_result(correct: bool, level_index: int, word_index: int, score: int, finished: bool)
signal score_updated(players: Array)
signal emote_received(player_id: String, id: String)
signal game_finished(players: Array, reason: String)
signal pong(server_time: int)
signal error_received(code: String, message: String)
signal network_error(message: String)

const DEFAULT_URL: String = "ws://127.0.0.1:8787/ws"
const CONFIG_PATH: String = "res://config/network.json"
const CONNECT_TIMEOUT_MS: int = 8000
const PING_INTERVAL_MS: int = 15000
const PONG_TIMEOUT_MS: int = 45000
const EMOTES: Array = ["hello", "nice", "wow", "gg"]

var url: String = DEFAULT_URL
var player_id: String = ""
var room_code: String = ""
var room_language: String = "tr"
var room_status: String = ""
var players: Array = []
var status: String = "idle"
var last_error: String = ""
var latency_ms: int = -1

var _ws: WebSocketPeer = null
var _was_open: bool = false
var _connect_started_ms: int = 0
var _last_ping_ms: int = 0
var _last_pong_ms: int = 0
var _ping_outstanding: bool = false
var _disconnect_emitted: bool = false
var _server_anchor_ms: int = 0
var _server_anchor_ticks: int = 0


func _ready() -> void:
	url = resolve_url()
	set_process(false)


func set_url(ws_url: String) -> void:
	var clean: String = ws_url.strip_edges()
	if clean.is_empty():
		clean = DEFAULT_URL
	url = clean


func resolve_url() -> String:
	if not FileAccess.file_exists(CONFIG_PATH):
		return DEFAULT_URL
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return DEFAULT_URL
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return DEFAULT_URL
	var data: Dictionary = json.data
	var candidate: Variant = data.get("url", data.get("server_url", DEFAULT_URL))
	var clean: String = str(candidate).strip_edges()
	if clean.begins_with("ws://") or clean.begins_with("wss://"):
		return clean
	return DEFAULT_URL


func is_open() -> bool:
	return _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func get_status() -> String:
	return status


func get_latency_ms() -> int:
	return latency_ms


func server_now_msec() -> int:
	if _server_anchor_ms > 0:
		return _server_anchor_ms + Time.get_ticks_msec() - _server_anchor_ticks
	return int(Time.get_unix_time_from_system() * 1000.0)


func connect_to_server(ws_url: String = "") -> bool:
	set_process(true)
	if not ws_url.strip_edges().is_empty():
		set_url(ws_url)
	elif url.strip_edges().is_empty():
		url = resolve_url()
	last_error = ""
	player_id = ""
	room_code = ""
	room_status = ""
	players = []
	_disconnect_emitted = false
	if _ws != null:
		_ws.close(1000, "reconnect")
		_ws = null
	_ws = WebSocketPeer.new()
	var err: Error = _ws.connect_to_url(url)
	if err != OK:
		last_error = "connect_error_%d" % err
		status = "closed"
		_ws = null
		connection_failed.emit(last_error)
		network_error.emit(last_error)
		return false
	status = "connecting"
	_was_open = false
	_connect_started_ms = Time.get_ticks_msec()
	_last_ping_ms = _connect_started_ms
	_last_pong_ms = _connect_started_ms
	_ping_outstanding = false
	_server_anchor_ms = 0
	return true


func disconnect_from_server(send_leave: bool = true) -> void:
	set_process(false)
	if _ws == null:
		status = "closed"
		return
	if send_leave and is_open():
		leave_room()
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN or _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		_ws.close(1000, "client_disconnect")
	status = "closing"


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state: int = _ws.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING:
		if Time.get_ticks_msec() - _connect_started_ms > CONNECT_TIMEOUT_MS:
			last_error = "timeout"
			connection_failed.emit("timeout")
			network_error.emit("timeout")
			_ws.close(1000, "timeout")
			_ws = null
			status = "closed"
		return
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			status = "open"
			_last_ping_ms = Time.get_ticks_msec()
			_last_pong_ms = _last_ping_ms
			_ping_outstanding = false
			connected.emit()
		_read_packets()
		var now: int = Time.get_ticks_msec()
		if now - _last_ping_ms >= PING_INTERVAL_MS:
			_last_ping_ms = now
			if ping():
				_ping_outstanding = true
		if _ping_outstanding and now - _last_pong_ms > PONG_TIMEOUT_MS:
			last_error = "timeout"
			_ping_outstanding = false
			_ws.close(1000, "pong_timeout")
			status = "closing"
		return
	if state == WebSocketPeer.STATE_CLOSING:
		status = "closing"
		return
	if state == WebSocketPeer.STATE_CLOSED:
		_handle_closed()


func _handle_closed() -> void:
	var reason: String = ""
	var code: int = 0
	if _ws != null:
		code = _ws.get_close_code()
		reason = _ws.get_close_reason()
		if reason.is_empty() and code != 0:
			reason = "close_%d" % code
	_ws = null
	status = "closed"
	_ping_outstanding = false
	var was_open: bool = _was_open
	_was_open = false
	if not _disconnect_emitted:
		_disconnect_emitted = true
		if was_open:
			disconnected.emit(reason if not reason.is_empty() else "closed")
		elif not reason.is_empty() and last_error.is_empty():
			last_error = reason
			connection_failed.emit(reason)
			network_error.emit(reason)


func _read_packets() -> void:
	if _ws == null:
		return
	while _ws.get_available_packet_count() > 0:
		var packet: PackedByteArray = _ws.get_packet()
		ingest_message(packet.get_string_from_utf8())


func ingest_message(raw_json: String) -> bool:
	if raw_json.strip_edges().is_empty():
		return false
	var json: JSON = JSON.new()
	if json.parse(raw_json) != OK:
		last_error = "invalid_json"
		network_error.emit("invalid_json")
		return false
	if not (json.data is Dictionary):
		last_error = "invalid_message"
		network_error.emit("invalid_message")
		return false
	var data: Dictionary = json.data
	var type: String = str(data.get("type", ""))
	if type.is_empty():
		last_error = "missing_type"
		network_error.emit("missing_type")
		return false
	message_received.emit(data)
	match type:
		"welcome":
			player_id = str(data.get("player_id", ""))
			welcome.emit(player_id)
		"room":
			room_code = str(data.get("code", ""))
			room_language = str(data.get("language", "tr"))
			var room_players: Variant = data.get("players", [])
			players = (room_players as Array).duplicate(true) if room_players is Array else []
			room_status = str(data.get("status", "waiting"))
			room_updated.emit(room_code, room_language, players, room_status)
		"start":
			var raw_levels: Variant = data.get("levels", [])
			var raw_start_players: Variant = data.get("players", [])
			var starts_at: int = int(data.get("starts_at", 0))
			var ends_at: int = int(data.get("ends_at", 0))
			var levels: Array = (raw_levels as Array).duplicate(true) if raw_levels is Array else []
			if raw_start_players is Array:
				players = (raw_start_players as Array).duplicate(true)
			room_status = "playing"
			game_started.emit(starts_at, ends_at, levels, players)
		"answer_result":
			answer_result.emit(
				bool(data.get("correct", false)),
				int(data.get("level_index", 0)),
				int(data.get("word_index", 0)),
				int(data.get("score", 0)),
				bool(data.get("finished", false))
			)
		"score":
			var raw_score_players: Variant = data.get("players", [])
			if raw_score_players is Array:
				players = (raw_score_players as Array).duplicate(true)
			score_updated.emit(players)
		"emote":
			emote_received.emit(str(data.get("player_id", "")), str(data.get("id", "")))
		"finish":
			var raw_finish_players: Variant = data.get("players", [])
			if raw_finish_players is Array:
				players = (raw_finish_players as Array).duplicate(true)
			room_status = "finished"
			game_finished.emit(players, str(data.get("reason", "")))
		"error":
			var code: String = str(data.get("code", "error"))
			var message: String = str(data.get("message", ""))
			last_error = code
			error_received.emit(code, message)
		"pong":
			var server_time: int = int(data.get("server_time", 0))
			last_error = ""
			if _ping_outstanding:
				latency_ms = maxi(0, Time.get_ticks_msec() - _last_ping_ms)
			if server_time > 0:
				_server_anchor_ms = server_time + (int(float(maxi(0, latency_ms)) / 2.0) if _ping_outstanding else 0)
				_server_anchor_ticks = Time.get_ticks_msec()
			_ping_outstanding = false
			_last_pong_ms = Time.get_ticks_msec()
			pong.emit(server_time)
		_:
			pass
	return true


func _send(data: Dictionary) -> bool:
	if not is_open():
		last_error = "not_connected"
		network_error.emit("not_connected")
		return false
	var text: String = JSON.stringify(data)
	var err: Error = _ws.send_text(text)
	if err != OK:
		last_error = "send_error_%d" % err
		network_error.emit(last_error)
		return false
	return true


func create_room(language: String = "tr", player_name: String = "Player") -> bool:
	var clean_lang: String = "en" if language.to_lower().begins_with("en") else "tr"
	var clean_name: String = player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "Player"
	return _send({"type": "create", "language": clean_lang, "name": clean_name})


func join_room(code: String, player_name: String = "Player") -> bool:
	var clean_code: String = code.strip_edges().to_upper()
	var clean_name: String = player_name.strip_edges()
	if clean_code.is_empty():
		last_error = "invalid_code"
		return false
	if clean_name.is_empty():
		clean_name = "Player"
	return _send({"type": "join", "code": clean_code, "name": clean_name})


func send_answer(answer: String, level_index: int, word_index: int) -> bool:
	return _send({
		"type": "answer",
		"answer": answer,
		"level_index": maxi(0, level_index),
		"word_index": maxi(0, word_index),
	})


func send_emote(emote_id: String) -> bool:
	if not EMOTES.has(emote_id):
		last_error = "invalid_emote"
		return false
	return _send({"type": "emote", "id": emote_id})


func ping() -> bool:
	return _send({"type": "ping"})


func leave_room() -> bool:
	return _send({"type": "leave"})
