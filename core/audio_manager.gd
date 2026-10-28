extends Node
## Runtime-generated UI sounds (no audio assets required).
##
## Autoload name: AudioManager (res://core/audio_manager.gd)
## Sounds are mono 16-bit AudioStreamWAV sine/chime tones built on first use.
##
## Public API:
##   play(name: String) -> void
##   play_tap(), play_backspace(), play_hint(), play_reveal(),
##   play_correct(), play_wrong(), play_coin(), play_win(), play_emote()
##   set_enabled(on: bool) -> void   (persists "sound" in SaveStore)
##   is_enabled() -> bool
##   muted property (inverse of enabled)

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 8
const NAMES: Array = [
	"tap", "key", "click", "backspace", "hint", "reveal", "correct", "wrong", "coin", "win", "emote",
]

var _enabled: bool = true

var enabled: bool:
	get:
		return _enabled
	set(value):
		set_enabled(value)
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0

var muted: bool:
	get:
		return not _enabled
	set(value):
		set_enabled(not value)


func _ready() -> void:
	for i: int in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = "Master"
		add_child(player)
		_players.append(player)

	var store: Node = get_node_or_null("/root/SaveStore")
	if store != null:
		if store.has_method("is_sound_enabled"):
			_enabled = bool(store.call("is_sound_enabled"))
		if store.has_signal("settings_changed"):
			store.settings_changed.connect(_on_setting_changed)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "sound":
		_enabled = bool(value)


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		stop_all()
	var store: Node = get_node_or_null("/root/SaveStore")
	if store != null and store.has_method("set_sound_enabled"):
		store.call("set_sound_enabled", on)


func is_enabled() -> bool:
	return _enabled


func stop_all() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()


func _tone_notes(notes: Array) -> AudioStreamWAV:
	var duration: float = 0.05
	for note_value: Variant in notes:
		if not (note_value is Dictionary):
			continue
		var note: Dictionary = note_value
		var note_end: float = float(note.get("start", 0.0)) + float(note.get("duration", 0.1))
		duration = maxf(duration, note_end)
	var sample_count: int = maxi(1, int(ceil(duration * float(SAMPLE_RATE))))
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	data.fill(0)
	for sample_index: int in range(sample_count):
		var t: float = float(sample_index) / float(SAMPLE_RATE)
		var mixed: float = 0.0
		for note_value: Variant in notes:
			if not (note_value is Dictionary):
				continue
			var note: Dictionary = note_value
			var start: float = float(note.get("start", 0.0))
			var note_duration: float = maxf(0.01, float(note.get("duration", 0.1)))
			if t < start or t > start + note_duration:
				continue
			var local_t: float = t - start
			var freq: float = float(note.get("freq", 440.0))
			var amp: float = clampf(float(note.get("amp", 0.25)), 0.0, 1.0)
			var attack: float = minf(0.006, note_duration * 0.25)
			var envelope: float = 1.0
			if local_t < attack:
				envelope = local_t / maxf(0.0001, attack)
			else:
				envelope = pow(1.0 - (local_t - attack) / maxf(0.0001, note_duration - attack), 2.0)
			var wave: float = sin(TAU * freq * local_t)
			wave += 0.28 * sin(TAU * freq * 2.0 * local_t)
			wave += 0.10 * sin(TAU * freq * 3.0 * local_t)
			mixed += wave * amp * envelope / 1.38
		mixed = clampf(mixed, -1.0, 1.0)
		var value: int = int(round(mixed * 32767.0))
		data.encode_s16(sample_index * 2, value)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _build_streams() -> void:
	if not _streams.is_empty():
		return
	_streams["tap"] = _tone_notes([
		{"freq": 660.0, "start": 0.0, "duration": 0.05, "amp": 0.16},
	])
	_streams["key"] = _streams["tap"]
	_streams["click"] = _streams["tap"]
	_streams["backspace"] = _tone_notes([
		{"freq": 330.0, "start": 0.0, "duration": 0.05, "amp": 0.14},
	])
	_streams["hint"] = _tone_notes([
		{"freq": 880.0, "start": 0.0, "duration": 0.12, "amp": 0.18},
		{"freq": 1108.73, "start": 0.06, "duration": 0.14, "amp": 0.16},
	])
	_streams["reveal"] = _tone_notes([
		{"freq": 587.33, "start": 0.0, "duration": 0.10, "amp": 0.17},
		{"freq": 880.0, "start": 0.07, "duration": 0.14, "amp": 0.16},
	])
	_streams["correct"] = _tone_notes([
		{"freq": 523.25, "start": 0.0, "duration": 0.12, "amp": 0.18},
		{"freq": 659.25, "start": 0.08, "duration": 0.14, "amp": 0.18},
		{"freq": 783.99, "start": 0.16, "duration": 0.20, "amp": 0.18},
	])
	_streams["wrong"] = _tone_notes([
		{"freq": 233.08, "start": 0.0, "duration": 0.14, "amp": 0.16},
		{"freq": 174.61, "start": 0.11, "duration": 0.18, "amp": 0.14},
	])
	_streams["coin"] = _tone_notes([
		{"freq": 1046.5, "start": 0.0, "duration": 0.07, "amp": 0.15},
		{"freq": 1318.51, "start": 0.06, "duration": 0.12, "amp": 0.14},
	])
	_streams["win"] = _tone_notes([
		{"freq": 523.25, "start": 0.0, "duration": 0.14, "amp": 0.18},
		{"freq": 659.25, "start": 0.10, "duration": 0.16, "amp": 0.18},
		{"freq": 783.99, "start": 0.20, "duration": 0.18, "amp": 0.18},
		{"freq": 1046.5, "start": 0.30, "duration": 0.32, "amp": 0.18},
	])
	_streams["emote"] = _tone_notes([
		{"freq": 740.0, "start": 0.0, "duration": 0.08, "amp": 0.16},
		{"freq": 987.77, "start": 0.07, "duration": 0.12, "amp": 0.14},
	])


func _get_player() -> AudioStreamPlayer:
	if _players.is_empty():
		return null
	for i: int in range(_players.size()):
		var index: int = (_next_player + i) % _players.size()
		if not _players[index].playing:
			_next_player = (index + 1) % _players.size()
			return _players[index]
	var fallback: AudioStreamPlayer = _players[_next_player % _players.size()]
	_next_player = (_next_player + 1) % _players.size()
	fallback.stop()
	return fallback


func play(sound_name: String) -> void:
	if not _enabled:
		return
	if not NAMES.has(sound_name):
		push_warning("AudioManager: unknown sound '%s'" % sound_name)
		return
	_build_streams()
	var stream: AudioStreamWAV = _streams.get(sound_name) as AudioStreamWAV
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = -6.0
	player.play()


func play_tap() -> void:
	play("tap")


## Adapter-friendly alias used by GardenApi.play_sound().
func play_sfx(sound_name: String) -> void:
	play(sound_name)


func play_backspace() -> void:
	play("backspace")


func play_hint() -> void:
	play("hint")


func play_reveal() -> void:
	play("reveal")


func play_correct() -> void:
	play("correct")


func play_wrong() -> void:
	play("wrong")


func play_coin() -> void:
	play("coin")


func play_win() -> void:
	play("win")


func play_emote() -> void:
	play("emote")
