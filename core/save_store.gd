extends Node
## Safe JSON persistence, per-language progress and settings.
##
## Autoload name: SaveStore (res://core/save_store.gd)
## Storage: user://save.json plus user://save.json.bak (atomic temp + backup).
## Coins are kept separately for each language; a fresh language starts at 100.
##
## Public API:
##   set_storage_path(main: String, backup: String = "") -> void  (tests/custom paths)
##   load_game() -> bool, save_game() -> bool
##   get_setting(key: String, fallback: Variant = null) -> Variant
##   set_setting(key: String, value: Variant, persist: bool = true) -> void
##   get_language() -> String, set_language(lang: String) -> void
##   is_sound_enabled() -> bool, set_sound_enabled(on: bool) -> void
##   get_coins(lang: String) -> int
##   add_coins(lang: String, amount: int) -> int
##   spend_coins(lang: String, amount: int) -> bool
##   can_afford(lang: String, amount: int) -> bool
##   is_completed(lang: String, level_id: String) -> bool
##   mark_level_completed(lang: String, level_id: String, reward: int = 25) -> Dictionary
##   completed_ids(lang: String) -> PackedStringArray
##   completed_count(lang: String) -> int
##   get_progress(lang: String) -> Dictionary
##   set_last_level(lang: String, level_id: String) -> void
##   record_purchase(lang: String, kind: String) -> void  ("hint" or "reveal")
##   reset_progress(lang: String) -> void
##   get_data() -> Dictionary
## Signals: coins_changed(lang, coins), level_completed(lang, level_id, first_clear),
##          settings_changed(key, value), save_failed(message),
##          save_succeeded, progress_reset(lang)

signal coins_changed(lang: String, coins: int)
signal level_completed(lang: String, level_id: String, first_clear: bool)
signal settings_changed(key: String, value: Variant)
signal save_failed(message: String)
signal save_succeeded
signal progress_reset(lang: String)

const SAVE_VERSION: int = 1
const DEFAULT_PATH: String = "user://save.json"
const DEFAULT_BACKUP_PATH: String = "user://save.json.bak"
const DEFAULT_COINS: int = 100
const COMPLETION_REWARD: int = 25
const HINT_COST: int = 10
const REVEAL_COST: int = 15
const LANGUAGES: Array = ["tr", "en"]
const MAX_COINS: int = 999999999

var save_path: String = DEFAULT_PATH
var backup_path: String = DEFAULT_BACKUP_PATH
var last_error: String = ""

var language: String:
	get:
		return get_language()
	set(value):
		set_language(value)

var _data: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	load_game()


func _default_progress() -> Dictionary:
	return {
		"coins": DEFAULT_COINS,
		"completed": {},
		"hints_used": 0,
		"reveals_used": 0,
		"total_wins": 0,
		"last_level": "",
	}


func _default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"settings": {
			"language": "tr",
			"sound": true,
			"music": false,
			"vibration": true,
		},
		"progress": {
			"tr": _default_progress(),
			"en": _default_progress(),
		},
		"meta": {
			"created_at": int(Time.get_unix_time_from_system()),
			"updated_at": int(Time.get_unix_time_from_system()),
		},
	}


func _normalize_lang(lang: String) -> String:
	var clean: String = lang.strip_edges().to_lower()
	if clean.begins_with("tr"):
		return "tr"
	if clean.begins_with("en"):
		return "en"
	return "tr"


func set_storage_path(main: String, backup: String = "") -> void:
	save_path = main if not main.is_empty() else DEFAULT_PATH
	backup_path = backup if not backup.is_empty() else save_path + ".bak"
	load_game()


func use_default_path() -> void:
	set_storage_path(DEFAULT_PATH, DEFAULT_BACKUP_PATH)


func _absolute(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _ensure_parent_dir(path: String) -> void:
	var abs_path: String = _absolute(path)
	var dir: String = abs_path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


func _validated(raw: Variant) -> Dictionary:
	var result: Dictionary = _default_data()
	if not (raw is Dictionary):
		return result
	var raw_dict: Dictionary = raw
	if raw_dict.has("version"):
		result["version"] = int(raw_dict.get("version", SAVE_VERSION))

	var raw_settings: Variant = raw_dict.get("settings", null)
	if raw_settings is Dictionary:
		var settings: Dictionary = raw_settings
		var lang: String = _normalize_lang(str(settings.get("language", "tr")))
		result["settings"]["language"] = lang
		result["settings"]["sound"] = bool(settings.get("sound", true))
		result["settings"]["music"] = bool(settings.get("music", false))
		result["settings"]["vibration"] = bool(settings.get("vibration", true))

	var raw_progress: Variant = raw_dict.get("progress", null)
	if raw_progress is Dictionary:
		var progress: Dictionary = raw_progress
		for lang: String in LANGUAGES:
			var raw_lang: Variant = progress.get(lang, null)
			if not (raw_lang is Dictionary):
				continue
			var data: Dictionary = raw_lang
			var target: Dictionary = result["progress"][lang]
			target["coins"] = clampi(int(data.get("coins", DEFAULT_COINS)), 0, MAX_COINS)
			target["hints_used"] = maxi(0, int(data.get("hints_used", 0)))
			target["reveals_used"] = maxi(0, int(data.get("reveals_used", 0)))
			target["total_wins"] = maxi(0, int(data.get("total_wins", 0)))
			target["last_level"] = str(data.get("last_level", ""))
			var completed: Dictionary = {}
			var raw_completed: Variant = data.get("completed", null)
			if raw_completed is Dictionary:
				for level_id: Variant in raw_completed.keys():
					if bool(raw_completed[level_id]):
						completed[str(level_id)] = true
			target["completed"] = completed

	var raw_meta: Variant = raw_dict.get("meta", null)
	if raw_meta is Dictionary:
		var meta: Dictionary = raw_meta
		result["meta"]["created_at"] = int(meta.get("created_at", result["meta"]["created_at"]))
		result["meta"]["updated_at"] = int(meta.get("updated_at", result["meta"]["updated_at"]))
	return result


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "open_failed: " + str(FileAccess.get_open_error())
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		last_error = "json_error_%d: %s" % [err, json.get_error_message()]
		return {}
	if not (json.data is Dictionary):
		last_error = "json_root_not_object"
		return {}
	return _validated(json.data)


func _move_aside_corrupt() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var corrupt_path: String = save_path + ".corrupt"
	var corrupt_abs: String = _absolute(corrupt_path)
	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(corrupt_abs)
	DirAccess.rename_absolute(_absolute(save_path), corrupt_abs)


func load_game() -> bool:
	last_error = ""
	_data = _default_data()
	_loaded = false

	var main_data: Dictionary = _read_file(save_path)
	if not main_data.is_empty():
		_data = main_data
		_loaded = true
		return true

	var had_corrupt_main: bool = FileAccess.file_exists(save_path) and _read_file(save_path).is_empty()
	if had_corrupt_main:
		_move_aside_corrupt()

	var backup_data: Dictionary = _read_file(backup_path)
	if not backup_data.is_empty():
		_data = backup_data
		_loaded = true
		save_game()
		last_error = "backup_recovered"
		push_warning("SaveStore: recovered progress from backup.")
		return true

	_data = _default_data()
	_loaded = true
	if had_corrupt_main:
		save_game()
		last_error = "reset_after_corruption"
		push_warning("SaveStore: save and backup were unreadable; defaults restored.")
	elif not FileAccess.file_exists(save_path):
		last_error = ""
	return false


func _write_json(path: String, text: String) -> bool:
	_ensure_parent_dir(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "write_open_failed: " + str(FileAccess.get_open_error())
		return false
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		last_error = "write_failed: " + str(write_error)
		return false
	return true


func save_game() -> bool:
	var settings: Dictionary = _data.get("settings", {})
	var lang: String = _normalize_lang(str(settings.get("language", "tr")))
	settings["language"] = lang
	_data["settings"] = settings
	var meta: Dictionary = _data.get("meta", {})
	meta["updated_at"] = int(Time.get_unix_time_from_system())
	_data["meta"] = meta
	_data["version"] = SAVE_VERSION

	var text: String = JSON.stringify(_data, "\t")
	var tmp_path: String = save_path + ".tmp"
	if not _write_json(tmp_path, text):
		save_failed.emit(last_error)
		return false

	_ensure_parent_dir(backup_path)
	var main_abs: String = _absolute(save_path)
	var backup_abs: String = _absolute(backup_path)
	var tmp_abs: String = _absolute(tmp_path)
	var main_exists: bool = FileAccess.file_exists(save_path)
	var main_readable: bool = main_exists and not _read_file(save_path).is_empty()

	# Backup rotation only happens when a readable main file exists. If the main
	# file is missing or corrupt, the existing .bak is the only good copy and is
	# left untouched until the new main has been committed.
	if main_readable:
		if not _rotate_backup(main_abs, backup_abs):
			last_error = "backup_rotate_failed"
			save_failed.emit(last_error)
			_remove_file(tmp_path)
			return false
		var removed: Error = DirAccess.remove_absolute(main_abs)
		if removed != OK:
			last_error = "remove_main_failed: " + str(removed)
			save_failed.emit(last_error)
			_remove_file(tmp_path)
			return false
	elif main_exists:
		# Unreadable main: preserve it as .corrupt, never as .bak.
		_move_aside_corrupt()

	var renamed: Error = DirAccess.rename_absolute(tmp_abs, main_abs)
	if renamed != OK:
		var copied_main: Error = DirAccess.copy_absolute(tmp_abs, main_abs)
		if copied_main != OK:
			last_error = "rename_failed: " + str(renamed)
			save_failed.emit(last_error)
			if not FileAccess.file_exists(save_path) and FileAccess.file_exists(backup_path):
				DirAccess.copy_absolute(backup_abs, main_abs)
			return false
		_remove_file(tmp_path)

	last_error = ""
	save_succeeded.emit()
	return true


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))


## Copies the current main file to .bak through a temporary file so the old
## backup is only replaced once the new copy is complete.
func _rotate_backup(main_abs: String, backup_abs: String) -> bool:
	var bak_tmp_path: String = backup_path + ".tmp"
	var bak_tmp_abs: String = _absolute(bak_tmp_path)
	_remove_file(bak_tmp_path)
	if DirAccess.copy_absolute(main_abs, bak_tmp_abs) != OK:
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_abs)
	if DirAccess.rename_absolute(bak_tmp_abs, backup_abs) != OK:
		if DirAccess.copy_absolute(bak_tmp_abs, backup_abs) != OK:
			return false
		_remove_file(bak_tmp_path)
	return true


func save() -> bool:
	return save_game()


func persist() -> bool:
	return save_game()


func get_data() -> Dictionary:
	return _data.duplicate(true)


func get_setting(key: String, fallback: Variant = null) -> Variant:
	var settings: Variant = _data.get("settings", null)
	if settings is Dictionary:
		var dict: Dictionary = settings
		if dict.has(key):
			return dict[key]
	return fallback


func set_setting(key: String, value: Variant, persist: bool = true) -> void:
	var settings: Dictionary = _data.get("settings", {})
	var final_value: Variant = value
	if key == "language":
		final_value = _normalize_lang(str(value))
	elif key == "sound" or key == "music" or key == "vibration":
		final_value = bool(value)
	settings[key] = final_value
	_data["settings"] = settings
	if persist:
		save_game()
	settings_changed.emit(key, final_value)


func get_language() -> String:
	return _normalize_lang(str(get_setting("language", "tr")))


func set_language(lang: String) -> void:
	set_setting("language", _normalize_lang(lang))


func is_sound_enabled() -> bool:
	return bool(get_setting("sound", true))


func set_sound_enabled(enabled: bool) -> void:
	set_setting("sound", enabled)


func _progress(lang: String) -> Dictionary:
	var clean: String = _normalize_lang(lang)
	var progress: Dictionary = _data.get("progress", {})
	if not (progress.get(clean, null) is Dictionary):
		progress[clean] = _default_progress()
		_data["progress"] = progress
	return progress[clean]


func get_progress(lang: String) -> Dictionary:
	return _progress(lang).duplicate(true)


func get_coins(lang: String = "") -> int:
	var clean: String = get_language() if lang.strip_edges().is_empty() else _normalize_lang(lang)
	return int(_progress(clean).get("coins", DEFAULT_COINS))


func can_afford(lang: String, amount: int) -> bool:
	return amount >= 0 and get_coins(lang) >= amount


func _coin_args(first: Variant, second: int) -> Array:
	# Accept both add_coins("tr", 25) and the legacy add_coins(25) shape.
	if first is String or first is StringName:
		return [_normalize_lang(str(first)), int(second)]
	if typeof(first) == TYPE_INT or typeof(first) == TYPE_FLOAT:
		return [get_language(), int(first)]
	return [get_language(), int(second)]


func add_coins(lang_or_amount: Variant = "", amount: int = 0) -> int:
	var args: Array = _coin_args(lang_or_amount, amount)
	var lang: String = str(args[0])
	var add_amount: int = int(args[1])
	var progress: Dictionary = _progress(lang)
	var current: int = int(progress.get("coins", DEFAULT_COINS))
	var next: int = clampi(current + maxi(0, add_amount), 0, MAX_COINS)
	var snapshot: Dictionary = _data.duplicate(true)
	progress["coins"] = next
	if not save_game():
		_data = snapshot
		return current
	coins_changed.emit(lang, next)
	return next


func spend_coins(lang_or_amount: Variant = "", amount: int = 0) -> bool:
	var args: Array = _coin_args(lang_or_amount, amount)
	var lang: String = str(args[0])
	var spend_amount: int = int(args[1])
	if spend_amount < 0:
		return false
	var progress: Dictionary = _progress(lang)
	var current: int = int(progress.get("coins", DEFAULT_COINS))
	if spend_amount == 0:
		return true
	if current < spend_amount:
		return false
	var snapshot: Dictionary = _data.duplicate(true)
	progress["coins"] = current - spend_amount
	if not save_game():
		# Never claim a purchase that was not written to disk.
		_data = snapshot
		return false
	coins_changed.emit(lang, current - spend_amount)
	return true


func is_completed(lang: String, level_id: String) -> bool:
	var progress: Dictionary = _progress(lang)
	var completed: Variant = progress.get("completed", null)
	if completed is Dictionary:
		var dict: Dictionary = completed
		return bool(dict.get(level_id, false))
	return false


func complete_level(language: String = "", level_id: String = "") -> Dictionary:
	var clean: String = get_language() if language.strip_edges().is_empty() else _normalize_lang(language)
	var result: Dictionary = mark_level_completed(clean, level_id)
	result["first"] = bool(result.get("first_clear", false))
	result["reward"] = int(result.get("coins_awarded", 0))
	return result


func mark_completed(language: String = "", level_id: String = "") -> Dictionary:
	return complete_level(language, level_id)


func set_level_completed(language: String = "", level_id: String = "") -> Dictionary:
	return complete_level(language, level_id)


func mark_level_completed(lang: String, level_id: String, reward: int = COMPLETION_REWARD) -> Dictionary:
	var clean: String = _normalize_lang(lang)
	var progress: Dictionary = _progress(clean)
	var current: int = int(progress.get("coins", DEFAULT_COINS))
	if is_completed(clean, level_id):
		return {
			"success": true,
			"first_clear": false,
			"coins_awarded": 0,
			"coins": current,
			"already_completed": true,
		}
	var snapshot: Dictionary = _data.duplicate(true)
	var completed: Dictionary = progress.get("completed", {})
	completed[level_id] = true
	progress["completed"] = completed
	progress["total_wins"] = int(progress.get("total_wins", 0)) + 1
	progress["last_level"] = level_id
	var awarded: int = maxi(0, reward)
	var next: int = clampi(current + awarded, 0, MAX_COINS)
	progress["coins"] = next
	if not save_game():
		# Roll back: nothing is announced unless the completion reached disk.
		_data = snapshot
		return {
			"success": false,
			"first_clear": false,
			"coins_awarded": 0,
			"coins": current,
			"already_completed": false,
			"error": "save_failed",
		}
	coins_changed.emit(clean, next)
	level_completed.emit(clean, level_id, true)
	return {
		"success": true,
		"first_clear": true,
		"coins_awarded": next - current,
		"coins": next,
		"already_completed": false,
	}


func completed_ids(lang: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var progress: Dictionary = _progress(lang)
	var completed: Variant = progress.get("completed", null)
	if completed is Dictionary:
		var dict: Dictionary = completed
		for level_id: Variant in dict.keys():
			if bool(dict[level_id]):
				out.append(str(level_id))
	return out


func completed_count(lang: String) -> int:
	return completed_ids(lang).size()


func set_last_level(lang: String, level_id: String) -> void:
	var progress: Dictionary = _progress(lang)
	progress["last_level"] = level_id
	save_game()


func record_purchase(lang: String, kind: String) -> void:
	var progress: Dictionary = _progress(lang)
	if kind == "hint":
		progress["hints_used"] = int(progress.get("hints_used", 0)) + 1
	elif kind == "reveal":
		progress["reveals_used"] = int(progress.get("reveals_used", 0)) + 1
	save_game()


func reset_progress(lang: String) -> void:
	var clean: String = _normalize_lang(lang)
	var progress: Dictionary = _data.get("progress", {})
	progress[clean] = _default_progress()
	_data["progress"] = progress
	save_game()
	progress_reset.emit(clean)
	coins_changed.emit(clean, DEFAULT_COINS)
