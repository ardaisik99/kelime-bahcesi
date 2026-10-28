extends Node
## Level content loader, validation, filtering and party-safe random selection.
##
## Autoload name: Content (res://core/content.gd)
## Data files: res://data/levels_tr.json and res://data/levels_en.json.
##
## Public API:
##   Content.get_levels(lang: String, category: String = "") -> Array[Dictionary]
##   Content.get_level(lang: String, level_id: String) -> Dictionary
##   Content.has_level(lang: String, level_id: String) -> bool
##   Content.categories(lang: String) -> Array[Dictionary]
##   Content.category_ids(lang: String) -> PackedStringArray
##   Content.category_count(lang: String, category: String) -> int
##   Content.count(lang: String, category: String = "") -> int
##   Content.level_ids(lang: String) -> PackedStringArray
##   Content.random_level(lang, category = "", avoid_id = "") -> Dictionary
##   Content.party_chain(lang = "", avoid = "") -> Dictionary
##   Content.random_level_avoiding(lang, category, recent_ids: Array, max_recent = 1) -> Dictionary
##   Content.languages() -> PackedStringArray
##   Content.has_language(lang) / is_loaded(lang = "")
##   Content.alphabet(lang), Content.normalize(text, lang), Content.word_count(level)
##   Content.category_display_name(lang, category_id) -> String
##   Content.errors() -> Array[String]
##   Content.reload() -> bool
## Returned levels are deep copies with keys:
##   id, category, language, words (uppercase roots), hints (one per word),
##   links (words.size() - 1), title (optional), order (within category).

signal content_loaded

const DATA_PATHS: Dictionary = {
	"tr": "res://data/levels_tr.json",
	"en": "res://data/levels_en.json",
}
const CATEGORY_IDS: Array = ["kitchen", "nature", "daily"]
const MIN_WORDS: int = 4
const MAX_WORDS: int = 5

var _levels: Dictionary = {"tr": [], "en": []}
var _by_id: Dictionary = {"tr": {}, "en": {}}
var _categories: Dictionary = {"tr": [], "en": []}
var _alphabet: Dictionary = {"tr": "ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ", "en": "ABCDEFGHIJKLMNOPQRSTUVWXYZ"}
var _errors: Array[String] = []
var _loaded: Dictionary = {"tr": false, "en": false}


func _ready() -> void:
	reload()


func _normalize_lang(lang: String) -> String:
	var clean: String = lang.strip_edges().to_lower()
	if clean == "tr" or clean == "en":
		return clean
	return ""


func languages() -> PackedStringArray:
	return PackedStringArray(["tr", "en"])


func has_language(lang: String) -> bool:
	return _normalize_lang(lang) != ""


func is_loaded(lang: String = "") -> bool:
	if lang.is_empty():
		return bool(_loaded.get("tr", false)) and bool(_loaded.get("en", false))
	var clean: String = _normalize_lang(lang)
	return clean != "" and bool(_loaded.get(clean, false))


func errors() -> Array[String]:
	return _errors.duplicate()


func reload() -> bool:
	_errors.clear()
	var all_ok: bool = true
	for lang: String in ["tr", "en"]:
		_levels[lang] = []
		_by_id[lang] = {}
		_categories[lang] = []
		_loaded[lang] = false
		if not _load_language(lang, str(DATA_PATHS[lang])):
			all_ok = false
	if all_ok:
		content_loaded.emit()
	return all_ok


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_errors.append("missing_file: " + path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("open_failed: " + path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		_errors.append("json_error: %s (%s)" % [path, json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		_errors.append("json_root_not_object: " + path)
		return {}
	return json.data


func _load_language(lang: String, path: String) -> bool:
	var raw: Dictionary = _read_json(path)
	if raw.is_empty():
		return false
	var declared: String = str(raw.get("language", lang))
	if declared != lang:
		_errors.append("%s: language field is '%s', expected '%s'" % [path, declared, lang])

	var raw_categories: Variant = raw.get("categories", null)
	if not (raw_categories is Array):
		_errors.append("%s: categories must be an array" % path)
		return false
	var seen_categories: Dictionary = {}
	for entry: Variant in raw_categories:
		if not (entry is Dictionary):
			_errors.append("%s: category entry is not an object" % path)
			continue
		var cat: Dictionary = entry
		var cat_id: String = str(cat.get("id", ""))
		if not CATEGORY_IDS.has(cat_id):
			_errors.append("%s: unknown category '%s'" % [path, cat_id])
			continue
		if seen_categories.has(cat_id):
			_errors.append("%s: duplicate category '%s'" % [path, cat_id])
			continue
		seen_categories[cat_id] = true
		var clean_cat: Dictionary = {
			"id": cat_id,
			"name_key": str(cat.get("name_key", "category." + cat_id)),
			"icon": str(cat.get("icon", "")),
			"order": _categories[lang].size(),
		}
		_categories[lang].append(clean_cat)
	if _categories[lang].is_empty():
		_errors.append("%s: no valid categories" % path)
		return false

	var raw_levels: Variant = raw.get("levels", null)
	if not (raw_levels is Array):
		_errors.append("%s: levels must be an array" % path)
		return false
	var seen_ids: Dictionary = {}
	var seen_chains: Dictionary = {}
	var category_order: Dictionary = {}
	var good_levels: Array = []
	for index: int in range((raw_levels as Array).size()):
		var raw_level: Variant = raw_levels[index]
		if not (raw_level is Dictionary):
			_errors.append("%s: level %d is not an object" % [path, index])
			continue
		var level: Dictionary = (raw_level as Dictionary).duplicate(true)
		var problem: String = _validate_level(level, lang, path, index, seen_ids, seen_chains)
		if not problem.is_empty():
			_errors.append(problem)
			continue
		var cat: String = str(level.get("category", ""))
		var next_order: int = int(category_order.get(cat, 0))
		level["order"] = next_order
		category_order[cat] = next_order + 1
		level["language"] = lang
		level.erase("_validation")
		good_levels.append(level)
		_by_id[lang][str(level["id"])] = level

	if good_levels.is_empty():
		_errors.append("%s: no valid levels" % path)
		return false
	_levels[lang] = good_levels
	for cat: Dictionary in _categories[lang]:
		cat["count"] = category_count(lang, str(cat["id"]))
	_loaded[lang] = true
	return true


func _valid_id(id: String) -> bool:
	if id.is_empty():
		return false
	for i: int in id.length():
		var ch: String = id.substr(i, 1)
		var ok: bool = (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"
		if not ok:
			return false
	return true


func _validate_level(level: Dictionary, lang: String, path: String, index: int, seen_ids: Dictionary, seen_chains: Dictionary) -> String:
	var id: String = str(level.get("id", ""))
	if not _valid_id(id):
		return "%s: level %d has invalid id '%s'" % [path, index, id]
	if seen_ids.has(id):
		return "%s: duplicate level id '%s'" % [path, id]
	var category: String = str(level.get("category", ""))
	if not CATEGORY_IDS.has(category):
		return "%s: level '%s' has unknown category '%s'" % [path, id, category]

	var raw_words: Variant = level.get("words", null)
	if not (raw_words is Array):
		return "%s: level '%s' words must be an array" % [path, id]
	var words: Array = raw_words
	if words.size() < MIN_WORDS or words.size() > MAX_WORDS:
		return "%s: level '%s' must have %d-%d words" % [path, id, MIN_WORDS, MAX_WORDS]
	var clean_words: Array[String] = []
	var alphabet: String = _alphabet[lang]
	for word_value: Variant in words:
		var word: String = str(word_value)
		if word.is_empty() or word != _upper(word, lang):
			return "%s: level '%s' word '%s' must be uppercase" % [path, id, word]
		for i: int in word.length():
			if not alphabet.contains(word.substr(i, 1)):
				return "%s: level '%s' word '%s' has a letter outside the %s alphabet" % [path, id, word, lang]
		clean_words.append(word)

	var chain_key: String = category + "|" + "|".join(clean_words)
	if seen_chains.has(chain_key):
		return "%s: duplicate chain '%s' in level '%s'" % [path, chain_key, id]

	var raw_hints: Variant = level.get("hints", null)
	if not (raw_hints is Array):
		return "%s: level '%s' hints must be an array" % [path, id]
	var hints: Array = raw_hints
	if hints.size() != clean_words.size():
		return "%s: level '%s' needs exactly %d hints" % [path, id, clean_words.size()]
	var clean_hints: Array[String] = []
	for hint_value: Variant in hints:
		var hint: String = str(hint_value).strip_edges()
		if hint.is_empty():
			return "%s: level '%s' has an empty hint" % [path, id]
		clean_hints.append(hint)

	var raw_links: Variant = level.get("links", null)
	if not (raw_links is Array):
		return "%s: level '%s' links must be an array" % [path, id]
	var links: Array = raw_links
	if links.size() != clean_words.size() - 1:
		return "%s: level '%s' needs exactly %d links" % [path, id, clean_words.size() - 1]
	var clean_links: Array[String] = []
	for link_index: int in range(links.size()):
		var link: String = str(links[link_index]).strip_edges()
		if link.is_empty():
			return "%s: level '%s' has an empty link" % [path, id]
		var left_root: String = _lower(clean_words[link_index], lang)
		if not _lower(link, lang).begins_with(left_root):
			return "%s: level '%s' link '%s' must contain the expression starting with '%s'" % [path, id, link, left_root]
		clean_links.append(link)

	seen_ids[id] = true
	seen_chains[chain_key] = true
	level["words"] = clean_words
	level["hints"] = clean_hints
	level["links"] = clean_links
	return ""


func _upper(text: String, lang: String) -> String:
	var i18n: Node = get_node_or_null("/root/I18n")
	if i18n != null and i18n.has_method("normalize"):
		return str(i18n.call("normalize", text, lang))
	return text.to_upper()


func _lower(text: String, lang: String) -> String:
	var i18n: Node = get_node_or_null("/root/I18n")
	if i18n != null and i18n.has_method("lower"):
		return str(i18n.call("lower", text, lang))
	return text.to_lower()


func get_levels(lang: String, category: String = "") -> Array[Dictionary]:
	var clean: String = _normalize_lang(lang)
	var out: Array[Dictionary] = []
	if clean.is_empty():
		return out
	var source: Array = _levels.get(clean, [])
	for level: Dictionary in source:
		if category.is_empty() or str(level.get("category", "")) == category:
			out.append(level.duplicate(true))
	return out


func get_level(lang: String, level_id: String) -> Dictionary:
	var clean: String = _normalize_lang(lang)
	if clean.is_empty():
		return {}
	var id_map: Dictionary = _by_id.get(clean, {})
	var level: Variant = id_map.get(level_id, null)
	if level is Dictionary:
		var dict: Dictionary = level
		return dict.duplicate(true)
	return {}


func has_level(lang: String, level_id: String) -> bool:
	var clean: String = _normalize_lang(lang)
	if clean.is_empty():
		return false
	var id_map: Dictionary = _by_id.get(clean, {})
	return id_map.has(level_id)


func categories(lang: String) -> Array[Dictionary]:
	var clean: String = _normalize_lang(lang)
	var out: Array[Dictionary] = []
	if clean.is_empty():
		return out
	var source: Array = _categories.get(clean, [])
	for cat: Dictionary in source:
		out.append(cat.duplicate(true))
	return out


func category_ids(lang: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cat: Dictionary in categories(lang):
		out.append(str(cat["id"]))
	return out


func category_count(lang: String, category: String) -> int:
	var count: int = 0
	for level: Dictionary in get_levels(lang):
		if str(level.get("category", "")) == category:
			count += 1
	return count


func count(lang: String, category: String = "") -> int:
	return get_levels(lang, category).size()


func level_ids(lang: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for level: Dictionary in get_levels(lang):
		out.append(str(level["id"]))
	return out


func party_chain(lang: String = "", avoid: String = "") -> Dictionary:
	return random_level(lang, "", avoid)


func random_level(lang: String, category: String = "", avoid_id: String = "") -> Dictionary:
	var candidates: Array[Dictionary] = get_levels(lang, category)
	if candidates.is_empty():
		return {}
	if not avoid_id.is_empty() and candidates.size() > 1:
		var filtered: Array[Dictionary] = []
		for level: Dictionary in candidates:
			if str(level.get("id", "")) != avoid_id:
				filtered.append(level)
		if not filtered.is_empty():
			candidates = filtered
	return candidates[randi() % candidates.size()]


func random_level_avoiding(lang: String, category: String = "", recent_ids: Array = [], max_recent: int = 1) -> Dictionary:
	var candidates: Array[Dictionary] = get_levels(lang, category)
	if candidates.is_empty():
		return {}
	var avoid: Dictionary = {}
	var start_index: int = maxi(0, recent_ids.size() - maxi(0, max_recent))
	if max_recent <= 0:
		start_index = recent_ids.size()
	for i: int in range(start_index, recent_ids.size()):
		avoid[str(recent_ids[i])] = true
	var filtered: Array[Dictionary] = []
	for level: Dictionary in candidates:
		if not avoid.has(str(level.get("id", ""))):
			filtered.append(level)
	if filtered.is_empty():
		filtered = candidates
	if filtered.size() > 1 and not recent_ids.is_empty():
		var newest: String = str(recent_ids[recent_ids.size() - 1])
		var without_newest: Array[Dictionary] = []
		for level: Dictionary in filtered:
			if str(level.get("id", "")) != newest:
				without_newest.append(level)
		if not without_newest.is_empty():
			filtered = without_newest
	return filtered[randi() % filtered.size()]


func word_count(level: Dictionary) -> int:
	var words: Variant = level.get("words", null)
	return (words as Array).size() if words is Array else 0


func alphabet(lang: String) -> String:
	var clean: String = _normalize_lang(lang)
	if clean.is_empty():
		return ""
	return str(_alphabet[clean])


func normalize(text: String, lang: String) -> String:
	return _upper(text, lang)


func category_display_name(lang: String, category_id: String) -> String:
	var i18n: Node = get_node_or_null("/root/I18n")
	if i18n != null and i18n.has_method("t"):
		return str(i18n.call("t", "category." + category_id))
	return category_id
