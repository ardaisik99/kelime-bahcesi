class_name GardenApi
extends RefCounted

## Defensive adapter between the presentation layer and the core autoloads.
## Content is normalized once for presentation; economy remains in SaveStore.

const CORE_SESSION_PATH := "res://core/game_session.gd"
const UI_PREFS_PATH := "user://garden_ui.json"

static var _prefs: Dictionary = {}
static var _prefs_loaded := false


# ---------------------------------------------------------------------------
# Autoload access
# ---------------------------------------------------------------------------

static func _autoload(name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(name)
	return null


static func save_store() -> Node:
	return _autoload("SaveStore")


static func content() -> Node:
	return _autoload("Content")


static func audio() -> Node:
	return _autoload("AudioManager")


static func network() -> Node:
	return _autoload("NetworkClient")


static func i18n() -> Node:
	return _autoload("I18n")


# ---------------------------------------------------------------------------
# Reflective call helpers
# ---------------------------------------------------------------------------

static func _method_info(obj: Object, method: String) -> Dictionary:
	for info in obj.get_method_list():
		if str(info.get("name", "")) == method:
			return info
	return {}


static func call_mapped(obj: Object, method: String, params: Dictionary = {},
		positional: Array = []) -> Variant:
	if obj == null or not obj.has_method(method):
		return null
	var info := _method_info(obj, method)
	var arg_infos: Array = info.get("args", [])
	var defaults := 0
	var raw_defaults: Variant = info.get("default_args", [])
	if raw_defaults is Array:
		defaults = (raw_defaults as Array).size()
	var required := maxi(0, arg_infos.size() - defaults)
	var values: Array = []
	for i in arg_infos.size():
		var arg_name := str(arg_infos[i].get("name", ""))
		if params.has(arg_name):
			values.append(params[arg_name])
		elif i < positional.size():
			values.append(positional[i])
		else:
			values.append(null)
	while values.size() > required and values.size() > 0 and values[values.size() - 1] == null:
		values.pop_back()
	return obj.callv(method, values)


static func call_first(obj: Object, methods: Array, params: Dictionary = {},
		positional: Array = []) -> Variant:
	if obj == null:
		return null
	for method_v in methods:
		var method := str(method_v)
		if obj.has_method(method):
			var result: Variant = call_mapped(obj, method, params, positional)
			if result != null:
				return result
	return null


# ---------------------------------------------------------------------------
# Language
# ---------------------------------------------------------------------------

static func lang() -> String:
	var store := save_store()
	if store != null:
		for prop in ["language", "lang", "current_language", "current_lang"]:
			var value: Variant = store.get(prop)
			if typeof(value) == TYPE_STRING and str(value) in ["tr", "en"]:
				return str(value)
		for method in ["get_language", "get_lang", "current_language"]:
			if store.has_method(method):
				var value: Variant = store.call(method)
				if typeof(value) == TYPE_STRING and str(value) in ["tr", "en"]:
					return str(value)
	var meta: Variant = store.get_meta("garden_ui_lang", "") if store != null else ""
	if typeof(meta) == TYPE_STRING and str(meta) in ["tr", "en"]:
		return str(meta)
	var pref := str(prefs().get("language", "tr"))
	return pref if pref in ["tr", "en"] else "tr"


static func set_lang(code: String) -> void:
	if not code in ["tr", "en"]:
		return
	var store := save_store()
	if store != null:
		var wrote := false
		for prop in ["language", "lang", "current_language", "current_lang"]:
			if prop in store:
				store.set(prop, code)
				wrote = true
				break
		call_first(store, ["set_language", "set_lang"], {"language": code, "lang": code, "code": code}, [code])
		store.set_meta("garden_ui_lang", code)
		_save_store(store)
		if wrote:
			pass
	# Keep I18n in sync if it exposes a setter; UI text still uses local fallback.
	var i18n_node := i18n()
	call_first(i18n_node, ["set_language", "set_lang"], {"language": code, "lang": code, "code": code}, [code])
	set_pref("language", code)


# ---------------------------------------------------------------------------
# Player preferences (UI only; progress/coins live in the core SaveStore)
# ---------------------------------------------------------------------------

static func prefs() -> Dictionary:
	if not _prefs_loaded:
		_prefs_loaded = true
		if FileAccess.file_exists(UI_PREFS_PATH):
			var f := FileAccess.open(UI_PREFS_PATH, FileAccess.READ)
			if f != null:
				var parsed: Variant = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary:
					_prefs = parsed
	return _prefs


static func _flush_prefs() -> void:
	var f := FileAccess.open(UI_PREFS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs, "\t"))
		f.close()


static func set_pref(key: String, value: Variant) -> void:
	prefs()[key] = value
	_flush_prefs()


static func get_pref(key: String, default: Variant = null) -> Variant:
	return prefs().get(key, default)


static func player_name() -> String:
	var n := str(get_pref("player_name", "")).strip_edges()
	return n


static func set_player_name(value: String) -> void:
	set_pref("player_name", value.strip_edges())


# ---------------------------------------------------------------------------
# Coins
# ---------------------------------------------------------------------------

static func coins() -> int:
	var store := save_store()
	if store != null:
		if store.has_method("get_coins"):
			var value: Variant = store.call("get_coins", lang())
			if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				return int(value)
		for prop in ["coins", "gold", "money", "balance"]:
			var raw: Variant = store.get(prop)
			if typeof(raw) in [TYPE_INT, TYPE_FLOAT]:
				return int(raw)
		if store.has_meta("garden_ui_coins"):
			return int(store.get_meta("garden_ui_coins"))
		store.set_meta("garden_ui_coins", 100)
	return 100


static func _set_coins(value: int) -> void:
	var store := save_store()
	if store == null:
		return
	for prop in ["coins", "gold", "money", "balance"]:
		if prop in store:
			store.set(prop, value)
			_save_store(store)
			return
	store.set_meta("garden_ui_coins", value)
	_save_store(store)


static func add_coins(amount: int) -> int:
	if amount == 0:
		return coins()
	var store := save_store()
	if store != null:
		for method in ["add_coins", "add_gold", "earn_coins"]:
			if store.has_method(method):
				var result: Variant = call_first(store, [method], {"amount": amount, "n": amount, "value": amount}, [amount])
				if typeof(result) in [TYPE_INT, TYPE_FLOAT]:
					return int(result)
	_set_coins(coins() + amount)
	return coins()


static func spend_coins(amount: int) -> bool:
	if amount <= 0:
		return true
	var store := save_store()
	if store != null:
		if store.has_method("spend_coins"):
			return bool(store.call("spend_coins", lang(), amount))
		for method in ["try_spend", "spend_gold", "spend"]:
			if store.has_method(method):
				var result: Variant = call_first(store, [method], {"amount": amount, "n": amount, "cost": amount, "value": amount}, [amount])
				if typeof(result) == TYPE_BOOL:
					return bool(result)
				if result != null:
					return true
	var available := coins()
	if available < amount:
		return false
	_set_coins(available - amount)
	return true


static func _save_store(store: Node) -> void:
	if store == null:
		return
	if store.has_method("save"):
		store.call("save")
	elif store.has_method("_save"):
		store.call("_save")
	elif store.has_method("persist"):
		store.call("persist")


# ---------------------------------------------------------------------------
# Completion / progress
# ---------------------------------------------------------------------------

static func _completion_params(level_id: Variant, language: String) -> Dictionary:
	return {
		"language": language,
		"lang": language,
		"level_id": level_id,
		"id": level_id,
		"level": level_id,
		"category": "",
		"category_id": ""
	}


static func is_completed(language: String, level_id: Variant) -> bool:
	var store := save_store()
	if store != null and store.has_method("is_completed"):
		return bool(store.call("is_completed", language, str(level_id)))
	if store != null:
		for method in ["is_level_completed", "has_completed", "is_level_cleared", "is_cleared"]:
			if store.has_method(method):
				var result: Variant = call_mapped(store, method, _completion_params(level_id, language), [language, str(level_id)])
				if typeof(result) == TYPE_BOOL:
					return bool(result)
		for prop in ["completed", "completed_levels", "cleared", "progress"]:
			var data: Variant = store.get(prop)
			if data is Dictionary:
				if _dict_has_level(data, language, level_id):
					return true
			elif data is Array:
				if level_id in data or str(level_id) in data:
					return true
	if store != null and store.has_meta(_meta_key(language, level_id)):
		return true
	return false


static func _dict_has_level(data: Dictionary, language: String, level_id: Variant) -> bool:
	var keys := [
		"%s:%s" % [language, str(level_id)],
		"%s_%s" % [language, str(level_id)],
		"%s/%s" % [language, str(level_id)],
		str(level_id),
		level_id
	]
	for key in keys:
		if data.has(key):
			var value: Variant = data[key]
			if typeof(value) == TYPE_BOOL:
				return bool(value)
			if typeof(value) in [TYPE_DICTIONARY, TYPE_INT, TYPE_FLOAT]:
				return true
	return false


static func _meta_key(language: String, level_id: Variant) -> String:
	return "garden_completed_%s_%s" % [language, str(level_id)]


## Returns {first: bool, reward: int}. The core is the source of truth for coins.
static func complete_level(language: String, level_id: Variant) -> Dictionary:
	var already := is_completed(language, level_id)
	var store := save_store()
	var reward := 0
	var first := not already
	if store != null:
		for method in ["complete_level", "mark_completed", "set_level_completed", "complete"]:
			if not store.has_method(method):
				continue
			var result: Variant = call_mapped(store, method, _completion_params(level_id, language), [language, level_id])
			if result is Dictionary:
				var info: Dictionary = result
				if info.has("first"):
					first = bool(info["first"])
				if info.has("reward"):
					reward = int(info["reward"])
			elif typeof(result) == TYPE_BOOL:
				first = bool(result)
			break
	if store != null:
		store.set_meta(_meta_key(language, level_id), true)
		_save_store(store)
	if first and reward == 0:
		# Core is expected to award 25 itself. Only add coins locally when the
		# SaveStore had no completion method at all.
		if store == null or not (store.has_method("complete_level") or store.has_method("mark_completed")
				or store.has_method("set_level_completed") or store.has_method("complete")):
			add_coins(25)
			reward = 25
	return {"first": first, "reward": reward}


# ---------------------------------------------------------------------------
# Content
# ---------------------------------------------------------------------------

static func categories(language: String) -> Array:
	var node := content()
	var raw: Variant = null
	if node != null and node.has_method("categories"):
		raw = node.call("categories", language)
	else:
		raw = call_first(node, ["get_categories"], {"language": language, "lang": language}, [language])
	var result: Array = []
	if raw is Dictionary:
		var dict: Dictionary = raw
		for key in dict.keys():
			var item: Variant = dict[key]
			if item is Dictionary:
				var d: Dictionary = (item as Dictionary).duplicate(true)
				if not d.has("id"):
					d["id"] = str(key)
				result.append(d)
			else:
				result.append({"id": str(key), "name": str(item)})
	elif raw is Array:
		for item in raw:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
			else:
				result.append({"id": str(item)})
	for item in result:
		if item is Dictionary:
			var d: Dictionary = item
			d["id"] = str(d.get("id", d.get("key", "")))
			d["name"] = GardenLoc.category_name(d, language)
			if not d.has("color"):
				d["color"] = _category_color(str(d["id"]), result.find(d))
	return result


static func _category_color(id: String, index: int) -> String:
	var fixed := {
		"animals": "mint", "hayvanlar": "mint",
		"food": "yellow", "yemek": "yellow", "yiyecek": "yellow",
		"nature": "mint", "doğa": "mint", "doga": "mint",
		"daily": "pink", "günlük": "pink", "gunluk": "pink",
		"school": "lavender", "okul": "lavender",
		"body": "pink", "vücut": "pink", "vucut": "pink",
		"travel": "yellow", "seyahat": "yellow"
	}
	var key := id.to_lower()
	if fixed.has(key):
		return fixed[key]
	var palette := ["lavender", "pink", "yellow", "mint"]
	return palette[index % palette.size()]


static func levels(language: String, category_id: String = "") -> Array:
	var node := content()
	var raw: Variant = null
	if node != null and node.has_method("get_levels"):
		raw = node.call("get_levels", language, category_id)
	else:
		raw = call_first(node, ["levels_for", "levels"], {
			"language": language, "lang": language,
			"category": category_id, "category_id": category_id
		}, [language, category_id])
	var list: Array = []
	if raw is Dictionary:
		var d: Dictionary = raw
		if d.has("levels") and d["levels"] is Array:
			list = (d["levels"] as Array).duplicate()
		else:
			list = d.values()
	elif raw is Array:
		list = (raw as Array).duplicate()
	var out: Array = []
	for item in list:
		out.append(normalize_level(item, language))
	# Some cores return every level regardless of category; filter defensively.
	if not category_id.is_empty():
		var filtered: Array = []
		for lv in out:
			var cat := str(lv.get("category", ""))
			if cat.is_empty() or cat == category_id:
				filtered.append(lv)
		if not filtered.is_empty():
			out = filtered
	return out


static func get_level(language: String, level_id: Variant) -> Dictionary:
	var node := content()
	var raw: Variant = null
	if node != null and node.has_method("get_level"):
		raw = node.call("get_level", language, str(level_id))
	else:
		raw = call_first(node, ["get_level"], {
			"language": language, "lang": language,
			"level_id": level_id, "id": level_id, "level": level_id
		}, [language, str(level_id)])
	if raw == null or (raw is Dictionary and (raw as Dictionary).is_empty()):
		# Fall back to a linear scan; also covers cores without get_level().
		for category in categories(language):
			for lv in levels(language, str(category.get("id", ""))):
				if str(lv.get("id", "")) == str(level_id):
					return lv
		return {}
	return normalize_level(raw, language)


static func all_levels(language: String) -> Array:
	var out: Array = []
	for category in categories(language):
		for lv in levels(language, str(category.get("id", ""))):
			out.append(lv)
	return out


static func next_level(language: String, level_id: Variant) -> Dictionary:
	var all := all_levels(language)
	for i in all.size():
		if str(all[i].get("id", "")) == str(level_id):
			if i + 1 < all.size():
				return all[i + 1]
			return {}
	return {}


static func next_unfinished(language: String) -> Dictionary:
	var all := all_levels(language)
	var store := save_store()
	if store != null:
		var progress: Dictionary = store.call("get_progress", language)
		var last := str(progress.get("last_level", ""))
		for i in all.size():
			if str(all[i].get("id", "")) == last:
				if not is_completed(language, last):
					return all[i]
				for j in range(i + 1, all.size()):
					if not is_completed(language, all[j].get("id", "")):
						return all[j]
				break
	for lv in all:
		if not is_completed(language, lv.get("id", "")):
			return lv
	return all[all.size() - 1] if not all.is_empty() else {}


static func category_progress(language: String, category_id: String) -> Dictionary:
	var list := levels(language, category_id)
	var done := 0
	for lv in list:
		if is_completed(language, lv.get("id", "")):
			done += 1
	return {"done": done, "total": list.size()}


static func party_level(language: String, avoid_id: String = "") -> Dictionary:
	var node := content()
	var raw: Variant = null
	if node != null and node.has_method("party_chain"):
		raw = node.call("party_chain", language, avoid_id)
	else:
		raw = call_first(node, [
			"random_level", "random_chain", "get_party_level", "party", "random_party_chain"
		], {"language": language, "lang": language, "avoid": avoid_id, "exclude": avoid_id}, [language])
	if raw != null and not (raw is Array and (raw as Array).is_empty()) \
			and not (raw is Dictionary and (raw as Dictionary).is_empty()):
		var lv := normalize_level(raw, language)
		if not lv.is_empty() and not (lv.get("words", []) as Array).is_empty():
			return lv
	var candidates: Array = []
	for lv in all_levels(language):
		if str(lv.get("id", "")) != avoid_id:
			candidates.append(lv)
	if candidates.is_empty():
		candidates = all_levels(language)
	if candidates.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func normalize_level(raw: Variant, language: String) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var d: Dictionary = (raw as Dictionary).duplicate(true)
	var id: Variant = d.get("id", d.get("level_id", d.get("key", "")))
	var category: Variant = d.get("category", d.get("category_id", d.get("cat", "")))
	var words_src: Variant = d.get("words", d.get("chain", d.get("items", [])))
	var hints_src: Variant = d.get("hints", d.get("clues", []))
	var links_src: Variant = d.get("links", d.get("expressions", d.get("examples", [])))
	var words: Array = []
	if words_src is Array:
		for i in (words_src as Array).size():
			var entry: Variant = words_src[i]
			var word := _entry_word(entry, language)
			if word.is_empty():
				continue
			var hint := _entry_value(entry, ["hint", "clue", "ipucu"], language)
			if hint.is_empty():
				hint = _parallel_value(hints_src, i, word, language)
			var link := _entry_value(entry, ["link", "expression", "example", "ifade"], language)
			if link.is_empty():
				link = _parallel_value(links_src, i, word, language)
			words.append({"word": word, "hint": hint, "link": link, "raw": entry})
	elif words_src is Dictionary:
		var wd: Dictionary = words_src
		for key in wd.keys():
			var word := _entry_word(wd[key], language)
			if word.is_empty():
				word = str(key)
			words.append({"word": word, "hint": "", "link": "", "raw": wd[key]})
	var title := _entry_value(d, ["title", "name"], language)
	if title.is_empty():
		title = GardenLoc.category_name(category, language)
	return {
		"id": id,
		"id_str": str(id),
		"category": str(category),
		"title": title,
		"words": words,
		"raw": d,
		"word_count": words.size()
	}


static func _entry_word(entry: Variant, language: String) -> String:
	if entry is String:
		return (entry as String).strip_edges()
	if entry is Dictionary:
		var d: Dictionary = entry
		for key in ["word", "answer", "text", "value", "kelime"]:
			if d.has(key):
				var v := _localized_value(d[key], language)
				if not v.is_empty():
					return v.strip_edges()
		var lv := _localized_value(d, language)
		if not lv.is_empty():
			return lv.strip_edges()
	return ""


static func _entry_value(entry: Variant, keys: Array, language: String) -> String:
	if not (entry is Dictionary):
		return ""
	var d: Dictionary = entry
	for key in keys:
		if d.has(key):
			var v := _localized_value(d[key], language)
			if not v.is_empty():
				return v
	return ""


static func _parallel_value(src: Variant, index: int, word: String, language: String) -> String:
	if src is Array:
		var arr: Array = src
		if index < arr.size():
			var v := _localized_value(arr[index], language)
			if not v.is_empty():
				return v
	elif src is Dictionary:
		var d: Dictionary = src
		for key in [word, word.to_lower(), str(index), index]:
			if d.has(key):
				var v := _localized_value(d[key], language)
				if not v.is_empty():
					return v
		# links sometimes map word -> {text: ...}; already handled above.
	return ""


static func _localized_value(value: Variant, language: String) -> String:
	if value is String:
		return value as String
	if value is Array:
		var parts: Array = []
		for item in value:
			var s := _localized_value(item, language)
			if not s.is_empty():
				parts.append(s)
		return " · ".join(parts)
	if value is Dictionary:
		var d: Dictionary = value
		for key in [language, "text_" + language, "name_" + language, "title_" + language, "text", "value", "name", "title"]:
			if d.has(key):
				var v := _localized_value(d[key], language)
				if not v.is_empty():
					return v
		for key in ["tr", "en"]:
			if d.has(key):
				var v2 := _localized_value(d[key], language)
				if not v2.is_empty():
					return v2
	return ""


# ---------------------------------------------------------------------------
# Turkish-aware text helpers
# ---------------------------------------------------------------------------

static func upper_tr(text: String) -> String:
	var s := text.replace("i", "İ").replace("ı", "I")
	return s.to_upper()


static func upper(text: String, language: String = "") -> String:
	var use_language := lang() if language.is_empty() else language
	return upper_tr(text) if use_language == "tr" else text.to_upper()


static func lower_tr(text: String) -> String:
	var s := text.replace("I", "ı").replace("İ", "i")
	return s.to_lower()


static func fold(text: String) -> String:
	return lower_tr(text).replace(" ", "").replace("'", "").replace("’", "")


# ---------------------------------------------------------------------------
# Sound / motion
# ---------------------------------------------------------------------------

static func sound_enabled() -> bool:
	var node := audio()
	if node != null:
		for prop in ["enabled", "sound_enabled", "unmuted"]:
			var v: Variant = node.get(prop)
			if typeof(v) == TYPE_BOOL:
				return bool(v)
		for prop in ["muted", "is_muted"]:
			var v: Variant = node.get(prop)
			if typeof(v) == TYPE_BOOL:
				return not bool(v)
	var pref: Variant = get_pref("sound", true)
	return bool(pref)


static func set_sound_enabled(value: bool) -> void:
	var node := audio()
	if node != null:
		call_first(node, ["set_enabled", "set_sound_enabled"], {"enabled": value, "value": value}, [value])
		call_first(node, ["set_muted"], {"muted": not value, "value": not value}, [not value])
		for prop in ["enabled", "sound_enabled", "unmuted"]:
			if prop in node:
				node.set(prop, value)
				break
		for prop in ["muted", "is_muted"]:
			if prop in node:
				node.set(prop, not value)
				break
	set_pref("sound", value)


static func play_sound(name: String) -> void:
	if not sound_enabled():
		return
	var node := audio()
	if node == null:
		return
	call_first(node, ["play_sfx", "play", "sfx", "sound"], {"name": name, "id": name, "sound": name}, [name])


static func reduced_motion() -> bool:
	return bool(get_pref("reduced_motion", false))


static func set_reduced_motion(value: bool) -> void:
	set_pref("reduced_motion", value)


static func motion_time(seconds: float) -> float:
	return 0.01 if reduced_motion() else seconds


# ---------------------------------------------------------------------------
# Session (preferred gameplay engine)
# ---------------------------------------------------------------------------

static func create_session(save_store_ref: Variant = null) -> RefCounted:
	if not ResourceLoader.exists(CORE_SESSION_PATH):
		return null
	var script: Script = load(CORE_SESSION_PATH)
	if script == null:
		return null
	var instance: Variant = script.new(save_store_ref)
	if instance is RefCounted:
		return instance as RefCounted
	return null
